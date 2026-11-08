"""Offline template and Duplicati-hook checks; no Docker/Unraid integration."""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
templates = {}
for template in ROOT.glob('haben-*.xml'):
    r = ET.parse(template).getroot()
    name = r.findtext('Name')
    templates[name] = r
    assert r.tag == 'Container' and r.attrib['version'] == '2'
    assert r.findtext('Network') == 'haben'
    ports = [c for c in r.findall('Config') if c.get('Type') == 'Port']
    if name == 'haben-app':
        assert len(ports) == 1 and ports[0].get('Target') == '3000' and ports[0].text == '3087'
    else:
        assert not ports
    assert all(c.get('Target') for c in r.findall('Config'))
    for c in r.findall('Config'):
        if c.get('Mask') == 'true':
            assert not c.text, 'Secret must not be shipped'
assert set(templates) == {'haben-app', 'haben-db', 'haben-backup'}
backup = templates['haben-backup']
configs = {c.get('Target'):c for c in backup.findall('Config')}
assert backup.findtext('Repository') == 'tristanteu/haben-backup:latest'
assert configs['/belege'].get('Mode') == 'ro'
assert configs['PGHOST'].text == 'haben-db'
assert configs['BACKUP_TIME'].text == '12:30'
assert configs['TZ'].text == 'Europe/Berlin'
assert configs['/backups'].text == '/mnt/user/appdata/haben/backup/repository'
assert configs['/var/lib/haben-backup'].text == '/mnt/user/appdata/haben/backup/state'

with tempfile.TemporaryDirectory() as tmp:
    base = Path(tmp)
    def guard(**overrides):
        return subprocess.run(['sh', str(ROOT/'scripts/haben/duplicati-before.sh')],
                              env=dict(os.environ, HABEN_BACKUP_DIR=str(base)) | overrides,
                              capture_output=True, text=True)
    assert guard().returncode != 0, 'Missing backup must fail'
    (base/'state').mkdir()
    repo = base/'repository'
    (repo/'snapshots').mkdir(parents=True)
    (repo/'locks').mkdir()
    (repo/'config').write_text('encrypted restic config')
    snapshot = repo/'snapshots'/'example'
    snapshot.write_text('encrypted snapshot')
    status = base/'state/status'
    status.write_text('ok 2026-11-08T12:31:00+01:00\n')
    result = guard()
    assert result.returncode == 0, result.stderr
    status.write_text('fehler 2026-11-08T12:31:00+01:00\n')
    assert guard().returncode != 0, 'Failed backup must fail'
    status.write_text('ok 2026-11-08T12:31:00+01:00\n')
    old = time.time() - 3*3600
    os.utime(status, (old, old))
    assert guard().returncode != 0, 'Stale backup must fail'
    assert guard(DUPLICATI__OPERATIONNAME='Restore').returncode == 0
    os.utime(status, None)
    lock = repo/'locks'/'example'
    lock.write_text('restic lock')
    assert guard().returncode != 0, 'Locked repository must fail'
    lock.unlink()
    snapshot.unlink()
    assert guard().returncode != 0, 'Empty repository must fail'
    assert guard(HABEN_MAX_AGE_MINUTES='invalid').returncode != 0
print('OK: three templates, mounts, secrets, hook success/missing/failed/stale/locked/empty, restore bypass')
