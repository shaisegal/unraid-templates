# Haben auf Unraid

Lokaler, inoffizieller Entwurf: drei DockerMan-Templates, nginx und offizieller Haben-Backup-Container mit Duplicati.
Noch nicht auf einem Unraid-Server getestet; kein Anspruch auf offizielle Haben-Unterstuetzung.
Eine Community-Applications-Freigabe fuer diese Templates steht aus.

## Voraussetzungen und Reihenfolge

Die Werte in dieser Anleitung sind Beispiele: freien Host-Port und endgueltige HTTPS-Domain
festlegen. Datenbank zuerst, dann App und optional Backup-Container installieren.
Die Konfiguration nutzt Nginx Proxy Manager im Bridge-Netz und optional Duplicati mit
Quellmount `/mnt/user/` -> `/backups/`. Andere Proxys und Backup-Systeme sind moeglich.
Die lokale XML-Installation funktioniert unabhaengig von einer Community-Applications-Freigabe.

## Installation

Auf dem Unraid-Terminal, fuer eine neue Installation:

```sh
docker network create haben
mkdir -p /mnt/user/appdata/haben/{db,belege,eric,eric-log,backup/repository,backup/state}
chown 1000:1000 /mnt/user/appdata/haben/{belege,eric,eric-log}
chmod 750 /mnt/user/appdata/haben/{belege,eric,eric-log}
```

Ist das Netzwerk bereits vorhanden, nicht erneut anlegen. Kein rekursives chown auf eine
bestehende Datenbank ausfuehren. Der DB-Container verwaltet seine eigenen Rechte.

Die drei XML-Dateien im Repository-Root nach
`/boot/config/plugins/dockerMan/templates-user/` kopieren, z.B. nach Merge des PR:

```sh
for name in haben-db haben-app haben-backup; do
  curl -fsSL "https://raw.githubusercontent.com/shaisegal/unraid-templates/main/$name.xml" \
    -o "/boot/config/plugins/dockerMan/templates-user/my-$name.xml" || exit 1
done
```

Fuer einen noch nicht gemergten Test-Branch die drei XML-Dateien manuell herunterladen;
die main-URLs funktionieren erst nach dem Merge. Dann Docker > Add Container und
jeweils das lokale Template auswaehlen (die genaue Beschriftung haengt von Unraid ab).
Kein Community-Applications-Eintrag erforderlich.

1. **haben-db**: Passwort mit `openssl rand -hex 24` erzeugen und eintragen.
   Containername `haben-db` und Netzwerk `haben` beibehalten.
2. Warten, bis `docker exec haben-db pg_isready -U haben -d haben` erfolgreich ist.
3. **haben-app**: DATABASE_URL nach dem Muster
   `postgres://haben:DEIN_HEX_PASSWORT@haben-db:5432/haben` setzen.
4. Zwei unabhaengige Werte mit `openssl rand -base64 32` fuer Auth-Secret und
   Verschluesselungsschluessel erzeugen. Beide eintragen, Schluessel separat im Passwortmanager sichern.
5. BETTER_AUTH_URL und den WebUI-Link auf die endgueltige HTTPS-Domain setzen.
6. App starten, Einrichtungscode mit `docker logs haben-app` ablesen.

Das App-Template veroeffentlicht **Host-Port 3087 -> Container-Port 3000/TCP**.
3087 ist ein Vorschlag und muss auf Unraid frei sein; bei Bedarf im Template aendern.
Die Datenbank hat keine Host-Portfreigabe. Beide Haben-Container bleiben im Netzwerk `haben`.
Der interne Port 3000 kollidiert nicht mit anderen Containern.

## Nginx Proxy Manager im Bridge-Netz

Ein vorhandener Nginx Proxy Manager kann im Bridge-Netz bleiben.
In NPM einen Proxy Host anlegen:

| Feld | Wert |
| --- | --- |
| Domain Names | endgueltige Haben-Domain |
| Scheme | `http` |
| Forward Hostname / IP | LAN-IP deines Unraid-Servers |
| Forward Port | `3087` (oder dein gewaehlter Host-Port) |
| SSL | passendes Zertifikat, Force SSL |

Unter Advanced `client_max_body_size 250M;` setzen. Zugriff auf eingebettete
Dokumentvorschauen testen; zusaetzliche Header duerfen Frames derselben Domain nicht sperren.
`127.0.0.1` bezeichnet im NPM-Container diesen Container, deshalb die Unraid-LAN-IP verwenden.
Die URL muss mit BETTER_AUTH_URL und dem WebUI-Link uebereinstimmen.

Den Header X-Forwarded-For auf eine vertrauenswuerdig ermittelte Client-IP setzen und
nicht ungeprueft vom Client uebernehmen. Vor Inbetriebnahme die effektive NPM-Konfiguration
pruefen, besonders bei vorgeschaltetem CDN/Proxy.
Port 3087 nicht am Router ins Internet weiterleiten; oeffentlicher Zugriff geht nur ueber
NPM/HTTPS. Die Host-Portfreigabe kann auch direkt im LAN erreichbar sein.

Alternative ohne Host-Port: NPM dauerhaft zusaetzlich in `haben` einbinden und auf
`haben-app:3000` leiten. Dann das Port-Mapping im App-Template entfernen. Das ist hier
nicht die Standardvariante. Caddy kann NPM alternativ ersetzen, ist aber nicht erforderlich.

## Offizieller Backup-Container und Duplicati

Dritter Container: `haben-backup.xml`, Image `tristanteu/haben-backup:latest`.
Keine Host-Skripte, SSH-Verbindung, Docker-Socket oder Aenderungen am Duplicati-Image noetig.
### Einrichtung

1. App und Datenbank zuerst einrichten und starten.
2. haben-backup aus dem lokalen Template installieren, Netzwerk `haben` beibehalten.
3. PGPASSWORD auf dasselbe Datenbankpasswort wie in haben-db setzen.
4. RESTIC_PASSWORD separat mit `openssl rand -base64 32` erzeugen und im Passwortmanager
   sichern. HABEN_ENCRYPTION_KEY der App ebenfalls getrennt sichern. Ohne diese Werte
   reicht das externe Backup nicht fuer eine vollstaendige Wiederherstellung.
5. BACKUP_TIME ist `12:30`, TZ ist `Europe/Berlin`. Duplicati startet im Beispiel um 13:00.
   Der Zeitplan steckt im Backup-Container; kein Unraid User Script erforderlich.
6. Erstes Backup von Hand ausloesen, da der Container nicht sofort nach Installation sichert:

```sh
docker exec haben-backup backup.sh
docker logs haben-backup
```

Das Backup nutzt PostgreSQL ueber das Netzwerk und Belege nur lesend. Es erstellt einen
geprueften SQL-Dump und legt ihn samt Belegen in einem verschluesselten restic-Repository ab.
Die App wird dabei **nicht pausiert**: Der Datenbank-Dump ist konsistent, Datenbank und
Dateien sind aber kein gemeinsam eingefrorener Zeitpunkt. Fuer den regulaeren Lauf eine
ruhige Nutzungszeit vorsehen. Ein strikt eingefrorener Gesamtstand braeuchte zusaetzliche
Koordination. Das entspricht dem Backup-Verfahren des Projekts.

RESTORE_CHECK_DAYS=7 aktiviert den projektseitigen Test-Restore. Dabei wird temporaer eine
zweite Datenbank erstellt; ausreichend freien Platz vorsehen. Ein fehlgeschlagener
Test-Restore kann trotz erfolgreichem Backup auftreten: Ergebnisse in Haben und Logs pruefen.

### Ablage und Duplicati-Filter

```text
/mnt/user/appdata/haben/
  db/                 laufende Datenbank
  belege/             Originalbelege
  eric/               optionale ELSTER-Bibliothek
  eric-log/           Protokolle
  backup/
    repository/       verschluesseltes restic-Repository -> extern sichern
    state/            Status, Lock und temporaerer Dump -> nicht extern sichern
```

Angenommener Duplicati-Mount: `/mnt/user/` -> `/backups/`. Im bestehenden appdata-Job:

| Aktion | Pfad im Duplicati-Container |
| --- | --- |
| Komplett einschliessen | `/backups/appdata/haben/backup/repository/` |
| Ausschliessen | `/backups/appdata/haben/db/` |
| Ausschliessen | `/backups/appdata/haben/belege/` |
| Ausschliessen | `/backups/appdata/haben/backup/state/` |

Alle Dateien im Repository einschliessen, auch `config`, `keys`, `snapshots`, `index` und
`data`; keine generischen Ausschlussfilter darauf anwenden. Das `locks`-Verzeichnis soll
beim Sichern leer sein. In der Duplicati-Quellvorschau pruefen, dass der Repository-Inhalt
nicht durch einen uebergeordneten Filter ausgeschlossen wird. eric/eric-log sind optional.

Duplicati kopiert verschluesselte restic-Dateien: Wiederherstellung erfolgt in zwei Schritten,
zuerst Duplicati, dann restic/Haben. Doppelte Versionierung und Aufraeumen im lokalen
Repository koennen den externen Speicherbedarf erhoehen; nach den ersten Laeufen beobachten.

**Wichtig:** restic darf das Repository waehrend des gesamten Duplicati-Backups nicht
veraendern (Backup, Prune, Restore-Test). Die 30 Minuten Vorlauf sind zunaechst ein Vorschlag.
Dauer einschliesslich woechentlichem Restore-Test messen und BACKUP_TIME bei Bedarf
vorverlegen. Keine manuellen restic-Laeufe waehrend Duplicati. Auch beim ersten Einrichten
erst nach Abschluss des manuellen Backups den Duplicati-Job starten.

### Pflicht-Pruefung in Duplicati

`scripts/haben/duplicati-before.sh` auf dem Host unter
`/mnt/user/appdata/duplicati/scripts/duplicati-before.sh` ablegen und ausfuehrbar machen.
Ueber den oben genannten Beispiel-Mount sieht Duplicati das Skript unter
`/backups/appdata/duplicati/scripts/duplicati-before.sh`.

Erweiterte Duplicati-Optionen:

```text
run-script-before-required = /backups/appdata/duplicati/scripts/duplicati-before.sh
run-script-timeout = 60s
```

Der Hook prueft den offiziellen Status auf Erfolg und Alter (maximal 120 Minuten), einen
vorhandenen Snapshot und fehlende restic-Lockdateien. Fehler brechen den Backup-Job ab.
Er startet kein Haben-Backup und setzt fuer den spaeteren Duplicati-Lauf keine Sperre.
Eine neue restic-Aktion nach der Pruefung kann er nicht verhindern: die Trennung der
Zeitplaene bleibt notwendig. Eine verwaiste restic-Sperre fuehrt ebenfalls zum Abbruch;
vor einem Entsperren immer sicherstellen, dass kein restic-Prozess mehr laeuft.
Duplicati braucht hierfuer `sh`, `grep` und `find` mit `-mmin` im Container.

Repository und Status muessen fuer Duplicatis Laufzeitnutzer lesbar sein. Beim ersten Lauf
im echten Duplicati-Container pruefen. Falls noetig gezielte Gruppen-/ACL-Rechte vergeben,
nicht pauschal chmod 777 oder PUID/PGID bei Haben setzen.

## Wiederherstellung und Updates

Zuerst auf einem isolierten Testsystem pruefen. Mit Duplicati das **gesamte Repository aus
GENAU EINER abgeschlossenen Backup-Version** wiederherstellen. Nicht mit einem aktiven
Repository vermischen. RESTIC_PASSWORD und urspruenglichen HABEN_ENCRYPTION_KEY bereithalten.
Danach den offiziellen Restore-Ablauf verwenden:
https://firsttris.github.io/haben/installation.html#backup-und-wiederherstellen

Fuer die Restic-Stufe muss die App gestoppt sein. Der Restore-Container braucht die
wiederhergestellte Repository-Kopie, Netzwerkzugriff auf die Ziel-Datenbank, deren Passwort
und einen **beschreibbaren** Beleg-Mount. Unser laufendes Backup-Template bindet Belege
absichtlich nur lesend ein und ist deshalb nicht direkt zum Restore geeignet. Einen
separaten einmaligen Container mit dem offiziellen Image und `restore.sh` verwenden.
Restore zuerst isoliert testen, da der offizielle Ablauf Datenbank und Belege ersetzt.
Der alte eigene Custom-Dump-Ablauf mit `pg_restore database.dump` gilt nicht mehr.

Updates ueber Unraids Docker-Oberflaeche. Vorher `docker exec haben-backup backup.sh`
ausfuehren, Erfolg und externes Backup pruefen. Datenbank zuerst aktualisieren und
Bereitschaft abwarten, danach App und Backup-Container auf zusammen passende Versionen.
Templates verwenden upstream `latest`; vor produktivem Betrieb getestete Versionen oder
Image-Digests dokumentieren/fixieren. Ein Rollback braucht passende Images UND alten
Datenbestand. Die DockerMan-Templates bieten keine Compose-Startabhaengigkeit: DB vor
App/Backup starten, Bereitschaft pruefen und Autostart nach Serverneustart testen.

## Pruefstatus

Lokal: XML-Struktur, Shell-Syntax und Erfolgs-/Fehlerpfade des Duplicati-Pruefhooks werden geprueft.
Ausstehend: echter Image-Start, Unraid-Import, nginx, Rechte des Duplicati-Containers,
Backup-/Restore-Probelauf und Updates auf dem Server. Hier wurde nichts installiert,
kein Server kontaktiert und nichts veroeffentlicht.

## Quellen

- https://github.com/firsttris/haben/blob/main/deploy/compose.yml
- https://firsttris.github.io/haben/installation.html
- https://ca.unraid.net/submit/help/xml-field-reference
- https://docs.duplicati.com/automation-and-integration/scripts

- https://github.com/firsttris/haben/blob/main/deploy/backup/backup.sh
- https://github.com/firsttris/haben/blob/main/deploy/backup/entrypoint.sh
