#!/bin/sh
# Duplicati: Host /mnt/user ist nach /backups gemountet.
# Prueft nur den offiziellen Backup-Container, fuehrt selbst kein Backup aus.
set -eu
BACKUP_DIR=${HABEN_BACKUP_DIR:-/backups/appdata/haben/backup}
MAX_AGE_MINUTES=${HABEN_MAX_AGE_MINUTES:-120}
if [ "${DUPLICATI__OPERATIONNAME:-Backup}" != Backup ]; then exit 0; fi
fail() { echo "Haben: $*" >&2; exit 1; }
case "$MAX_AGE_MINUTES" in ''|*[!0-9]*) fail 'Ungueltiges Hoechstalter.';; esac
[ "$MAX_AGE_MINUTES" -gt 0 ] || fail 'Hoechstalter muss positiv sein.'
status="$BACKUP_DIR/state/status"
repo="$BACKUP_DIR/repository"
[ -r "$status" ] || fail 'Backup-Status fehlt oder ist nicht lesbar.'
grep -q '^ok ' "$status" || fail 'Letztes Haben-Backup fehlgeschlagen.'
[ -n "$(find "$status" -mmin "-$MAX_AGE_MINUTES" -print)" ] || fail 'Haben-Backup ist zu alt.'
[ -s "$repo/config" ] || fail 'restic-Repository fehlt oder ist nicht lesbar.'
[ -d "$repo/snapshots" ] || fail 'Snapshot-Verzeichnis fehlt.'
[ -n "$(find "$repo/snapshots" -type f -print)" ] || fail 'Kein restic-Snapshot vorhanden.'
[ -d "$repo/locks" ] || fail 'Repository-Lockverzeichnis fehlt.'
[ -z "$(find "$repo/locks" -type f -print)" ] || fail 'restic-Repository ist gesperrt; nicht parallel sichern.'
echo 'Haben: aktuelles Backup vorhanden, keine restic-Sperre gefunden.'
# Das ist eine Momentaufnahme, keine Sperre fuer die Dauer des Duplicati-Laufs.
