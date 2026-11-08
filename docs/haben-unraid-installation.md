# Haben auf Unraid installieren

Die Community-Applications-Veröffentlichung ist für diese Installation nicht erforderlich.
Die XML-Templates werden direkt aus diesem Repository geladen. Ein Git-Checkout und ein
Neustart des Unraid-Servers sind nicht nötig.

Diese Anleitung verwendet Unraids Docker-Oberfläche, Nginx Proxy Manager im Bridge-Netz
und optional Duplicati. Die Beispielwerte für die Backup-Zeiten sind 12:30 Uhr für Haben
und 13:00 Uhr für Duplicati, jeweils Europe/Berlin. Installation und Restore müssen noch
auf einem echten Unraid-System geprüft werden.

## 1. Verzeichnisse und Netzwerk anlegen

Im Unraid-Webinterface oben rechts **Terminal** öffnen. Die folgenden Befehle gelten für
eine neue Installation; bestehende Daten nicht überschreiben oder deren Eigentümer
pauschal ändern.

```sh
docker network inspect haben >/dev/null 2>&1 || docker network create haben
mkdir -p /mnt/user/appdata/haben/{db,belege,eric,eric-log,backup/repository,backup/state}
chown 1000:1000 /mnt/user/appdata/haben/{belege,eric,eric-log}
chmod 750 /mnt/user/appdata/haben/{belege,eric,eric-log}
```

Die App läuft als UID/GID 1000. Der Datenbankcontainer richtet seine eigenen Dateirechte
ein; kein `chown` auf dessen bestehende Daten anwenden.

Das Template verwendet Host-Port **3087**, intern bleibt es bei Port **3000**. Vorher prüfen,
ob 3087 bereits verwendet wird:

```sh
docker ps --format 'table {{.Names}}\t{{.Ports}}'
ss -lnt
```

Ist 3087 belegt, beim Installieren der App einen anderen freien Host-Port auswählen
und später denselben Port in Nginx Proxy Manager eintragen.

## 2. Templates herunterladen

Im selben Terminal ausführen:

```sh
mkdir -p /boot/config/plugins/dockerMan/templates-user
for name in haben-db haben-app haben-backup; do
  curl -fsSL "https://raw.githubusercontent.com/shaisegal/unraid-templates/main/$name.xml" \
    -o "/boot/config/plugins/dockerMan/templates-user/my-$name.xml" || exit 1
done
```

Diese Befehle installieren zunächst nur die drei auswählbaren Vorlagen. Die Container
werden im nächsten Schritt angelegt. Bei bereits existierenden gleichnamigen Vorlagen
diese vorher sichern, bevor der Download sie ersetzt.

Danach **Docker → Container hinzufügen / Add Container** öffnen. Im Template-Dropdown
sollten `haben-db`, `haben-app` und `haben-backup` erscheinen. Bei Bedarf die Seite neu laden.
Sie sind lokale Docker-Templates und müssen nicht im Apps-Katalog erscheinen.

## 3. Datenbank installieren

Zuerst das Template **haben-db** auswählen:

| Einstellung | Wert |
| --- | --- |
| Name | `haben-db` |
| Netzwerk | das zuvor angelegte Netzwerk `haben` |
| POSTGRES_USER | `haben` |
| POSTGRES_DB | `haben` |
| POSTGRES_PASSWORD | selbst erzeugtes Datenbankpasswort |
| Datenpfad | `/mnt/user/appdata/haben/db` |

Passwort im Terminal erzeugen:

```sh
openssl rand -hex 24
```

Das Passwort im Passwortmanager speichern. **Apply / Anwenden** klicken und warten,
bis der Container gestartet ist. Anschließend im Terminal prüfen:

```sh
docker exec haben-db pg_isready -U haben -d haben
```

Erst fortfahren, wenn die Datenbank Verbindungen annimmt. Bei Fehlern das Containerlog
über das Container-Symbol oder `docker logs haben-db` öffnen.

## 4. Haben installieren

Erneut **Container hinzufügen**, diesmal Template **haben-app**. Containername und
Netzwerk `haben` beibehalten. Folgende Werte setzen:

| Einstellung | Wert |
| --- | --- |
| DATABASE_URL | `postgres://haben:DEIN_DB_PASSWORT@haben-db:5432/haben` |
| BETTER_AUTH_URL | endgültige HTTPS-Adresse, z. B. `https://haben.example.de` |
| BETTER_AUTH_SECRET | erstes separat erzeugtes Secret |
| HABEN_ENCRYPTION_KEY | zweites separat erzeugtes Secret |
| Web-Port | `3087` oder anderer freier Host-Port |
| WebUI-Link | dieselbe endgültige HTTPS-Adresse |

Die beiden Secrets unabhängig erzeugen:

```sh
openssl rand -base64 32
openssl rand -base64 32
```

`DEIN_DB_PASSWORT` durch das zuvor erzeugte Hex-Passwort ersetzen. Keine echten
Zugangsdaten ins GitHub-Repository oder in Screenshots übernehmen. Den Verschlüsselungsschlüssel
zusätzlich im Passwortmanager sichern; er wird nach einem Restore wieder benötigt.

Die endgültige Domain gleich jetzt wählen, weil Passkeys daran gebunden sind.
Die drei App-Pfade für Belege, ERiC und Logs unverändert lassen. **Apply / Anwenden** klicken.

## 5. Nginx Proxy Manager einrichten

Ein vorhandener NPM-Container darf im Bridge-Netz bleiben. Einen Proxy Host erstellen:

| Feld | Wert |
| --- | --- |
| Domain Names | die Domain aus BETTER_AUTH_URL |
| Scheme | `http` |
| Forward Hostname / IP | LAN-IP des Unraid-Servers |
| Forward Port | `3087` bzw. gewählter Host-Port |
| SSL | gültiges Zertifikat auswählen/anfordern, Force SSL aktivieren |

Unter **Advanced** ergänzen:

```nginx
client_max_body_size 250M;
```

Nicht `localhost` oder `127.0.0.1` als Ziel verwenden: Das wäre der NPM-Container selbst.
Nur HTTP/HTTPS über NPM nach außen führen, keine Routerfreigabe für Haben-Port 3087
oder die Datenbank einrichten. Bei einem vorgeschalteten Proxy/CDN außerdem die
Ermittlung der vertrauenswürdigen Client-IP prüfen.

Nach dem Speichern die HTTPS-Adresse öffnen. Einrichtungscode im App-Log ablesen:

```sh
docker logs haben-app
```

Mit diesem Code das Konto anlegen. Anmeldung, Beleg-Upload und Dokumentvorschau testen.

## 6. Offiziellen Backup-Container installieren

Template **haben-backup** auswählen:

| Einstellung | Wert |
| --- | --- |
| Netzwerk | `haben` |
| PGHOST | `haben-db` |
| PGUSER / PGDATABASE | jeweils `haben` |
| PGPASSWORD | dasselbe Datenbankpasswort wie oben |
| RESTIC_PASSWORD | neues, separat erzeugtes Passwort |
| RESTIC_REPOSITORY | `/backups` |
| BACKUP_TIME | `12:30` |
| TZ | `Europe/Berlin` |
| RESTORE_CHECK_DAYS | `7` |

RESTIC_PASSWORD mit `openssl rand -base64 32` erzeugen und zusätzlich im Passwortmanager
sichern. Den Beleg-Mount nur lesend belassen. **Apply / Anwenden** klicken.

Das Repository liegt auf dem Host unter `/mnt/user/appdata/haben/backup/repository`.
Status und temporäre Dateien liegen getrennt unter `backup/state`.

Ein erstes Backup manuell starten und dessen Abschluss abwarten:

```sh
docker exec haben-backup backup.sh
cat /mnt/user/appdata/haben/backup/state/status
```

Der Status muss mit `ok ` beginnen. Der Container legt nicht unmittelbar beim ersten
Start automatisch ein Backup an, sondern wartet auf seine nächste geplante Uhrzeit.
Der wöchentliche Test-Restore braucht zeitweise Platz für eine zusätzliche Datenbank.
Ergebnisse dieses Tests separat in Haben bzw. im Log kontrollieren.

Der offizielle Ablauf erstellt einen konsistenten Datenbank-Dump, pausiert aber die App
nicht. Er friert Datenbank und Belegdateien daher nicht gemeinsam ein. Während dieser
Sicherung möglichst keine Belege importieren oder umfangreiche Änderungen vornehmen.

## 7. Duplicati anbinden

Die folgenden Container-Pfade gelten bei der Zuordnung **Host `/mnt/user/` → Container
`/backups/`**. Bei anderen Zuordnungen die Pfade anpassen.

Prüfskript auf dem Unraid-Host bereitstellen:

```sh
mkdir -p /mnt/user/appdata/duplicati/scripts
curl -fsSL \
  https://raw.githubusercontent.com/shaisegal/unraid-templates/main/scripts/haben/duplicati-before.sh \
  -o /mnt/user/appdata/duplicati/scripts/duplicati-before.sh
chmod 755 /mnt/user/appdata/duplicati/scripts/duplicati-before.sh
```

Im Duplicati-Job unter **Erweiterte Optionen** setzen:

```text
run-script-before-required = /backups/appdata/duplicati/scripts/duplicati-before.sh
run-script-timeout = 60s
```

Die Pflichtvariante verwenden, damit ein fehlgeschlagenes Prüfskript das Backup abbricht.
Der Hook prüft lediglich den zuvor abgeschlossenen Haben-Backup-Lauf; er erstellt selbst
kein Backup. Er braucht im Duplicati-Container `sh`, `grep` und `find` mit `-mmin`.

Quellen und Filter im vorhandenen appdata-Backup prüfen:

| Aktion | Container-Pfad |
| --- | --- |
| Vollständig sichern | `/backups/appdata/haben/backup/repository/` |
| Ausschließen | `/backups/appdata/haben/db/` |
| Ausschließen | `/backups/appdata/haben/belege/` |
| Ausschließen | `/backups/appdata/haben/backup/state/` |

Das gesamte restic-Repository inklusive `config`, `keys`, `snapshots`, `index` und `data`
sichern. In der Duplicati-Quellvorschau kontrollieren, dass kein übergeordneter Filter
Teile davon ausschließt. Der Duplicati-Nutzer muss alle Dateien lesen können; dies im
echten Container prüfen und bei Bedarf gezielte Gruppen-/ACL-Leserechte einrichten.

Duplicati startet im Beispiel täglich um **13:00 Uhr**. Die Haben-Sicherung inklusive
Prune und gegebenenfalls Restore-Test muss vorher fertig sein. Die Laufdauer zunächst
messen und bei Bedarf BACKUP_TIME vorverlegen. Auch manuelle restic-Läufe dürfen sich
nicht mit Duplicati überschneiden. Der Prüf-Hook erkennt vorhandene Locks, hält aber
keine Sperre für die gesamte Laufzeit von Duplicati.

## 8. Abschlussprüfung

- Haben ist über die HTTPS-Domain erreichbar; Anmeldung und Vorschauen funktionieren.
- App, Datenbank und optionaler Backup-Container starten nach einem Unraid-Neustart.
  DB vor App/Backup einordnen und ihre Bereitschaft prüfen.
- Manuelles Haben-Backup und Duplicati-Backup laufen erfolgreich durch.
- Ein komplettes Repository lässt sich aus **einer** Duplicati-Backup-Version zurückholen.
- Die anschließende Haben-Wiederherstellung wird auf isolierten Testcontainern geprüft.
- Datenbankpasswort, App-Secrets, restic-Passwort und Unraid-Containerkonfiguration sind
  zusätzlich gesichert. Die Containerkonfiguration liegt auf dem Boot-Stick, nicht im appdata-Ordner.

Für Restore-Besonderheiten und Updates siehe [Haben-Betriebsdokumentation](haben.md).
Die Installation der XML-Dateien ist keine Veröffentlichung bei Community Applications;
diese kann später erfolgen.
