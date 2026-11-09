# Unraid Taskline installieren und prüfen

## Einmalig vor der ersten Installation

Das GHCR-Paket `shaisegal/unraid-taskline` muss öffentlich abrufbar sein, oder Unraid benötigt eine Registry-Anmeldung. Das Quellrepository bleibt privat. GitHub veröffentlicht neue Pakete zunächst privat; die Sichtbarkeit lässt sich in den [Paketeinstellungen](https://github.com/users/shaisegal/packages/container/unraid-taskline/settings) über **Change visibility → Public** ändern. Diese Einstellung ist unabhängig von der Sichtbarkeit des Quellrepositories.

## Installation über das Unraid-Webterminal

Das geprüfte Skript arbeitet ausschließlich mit dem neuen Container `unraid-taskline`, `/mnt/user/appdata/taskline` und `my-taskline.xml`. Es stoppt bei einer bereits vorhandenen Installation. Standard-Port: 18082. Es startet keine Backups, Scans oder anderen Ziel-Tasks.

```sh
curl -fsSL https://raw.githubusercontent.com/shaisegal/unraid-templates/main/scripts/taskline/install-unraid.sh -o /tmp/install-taskline.sh
sh /tmp/install-taskline.sh
```

Vor Ausführung kann das Skript mit `cat /tmp/install-taskline.sh` geprüft werden. Für einen anderen Port: `TASKLINE_PORT=18083 sh /tmp/install-taskline.sh`. Für einen bestimmten Versions-Tag: `TASKLINE_IMAGE=ghcr.io/shaisegal/unraid-taskline:0.1.0 sh /tmp/install-taskline.sh`.

Falls `docker pull` mit `denied` abbricht, wurde das Image noch nicht auf Public gestellt bzw. es fehlt eine Registry-Anmeldung. Vor diesem Schritt werden weder Container noch Taskline-Appdata angelegt.

Das Skript bindet den Docker-Socket ein; `:ro` ist keine Begrenzung der Docker-Daemon-Rechte. Alternativ das Template manuell installieren und einen auf `GET /containers/json` beschränkten Proxy verwenden. Der Prozess muss die eingebundenen Quellen lesen können. Es werden keine rekursiven chmod/chown-Änderungen an Host-Daten ausgeführt.

## Live-Abnahme

1. `http://unraid.home.arpa:18082` öffnen (alternativ Server-IP).
2. Host-Cron-/User-Scripts-Fundstellen und Zeitpläne mit Unraid vergleichen. Quellenfehler dürfen nicht als leere Task-Liste interpretiert werden.
3. Unter **Container & Scans** prüfen, ob die Containerliste vollständig erscheint.
4. Radarr auswählen, erreichbare Basis-URL und API-Key eingeben, **Tasks auslesen**.
5. Task-Anzahl, Intervall und nächsten Start gegen **Radarr → System → Tasks** vergleichen. Keine Aufgabe zum Test starten.
6. Im Stundenplan gemeldete Starts, Cron-Termine und Prognosen vergleichen; Host-/Browser-Zeitzone beachten.
7. Taskline über die Docker-Oberfläche neu starten und prüfen, ob der Scan erhalten bleibt. Ein erneuter Scan muss aktuelle Werte liefern.

Zum Teilen des Ergebnisses reichen Task-Anzahl, Fehlermeldungen und der Vergleich mit Radarr. Keine API-Keys, Cron-Befehle mit Zugangsdaten oder vollständigen privaten Konfigurationsdateien posten.

## Updates

`:latest` erlaubt die übliche Updateprüfung in Unraid Docker. Ein Update des Images übernimmt nicht automatisch neue Template-Variablen oder Mounts; Änderungen an der Vorlage bei Bedarf unter **Edit Container** nachziehen. `/config` vor Updates sichern. Diese Version speichert JSON-Snapshots und hat noch keine Datenbankmigrationen; künftige Versionen können das ändern.

## Stand der Live-Abnahme

Lokale Unit-/HTTP-/Docker-Prüfungen ersetzen den echten Unraid-/Radarr-Test nicht. Installation und Vergleich auf dem Host sind erst nach den obigen Schritten bestätigt.
