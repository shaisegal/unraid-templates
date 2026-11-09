# Unraid Taskline installieren und prüfen

## Vorhandene GHCR-Anmeldung verwenden

Taskline kann wie Pipelinarr mit privatem Quellrepository und privatem Container-Image installiert werden. Docker verwendet beim Download automatisch die auf dem Unraid-Host gespeicherte Anmeldung für `ghcr.io`. Wenn Pipelinarr dort bereits privat geladen wird und das verwendete Konto/Token auch Taskline lesen darf, ist keine erneute Anmeldung nötig. Das Paket muss nicht öffentlich gestellt werden.

Nur bei einem tatsächlichen Zugriffsfehler die bestehende Anmeldung prüfen: Der GitHub-Benutzer benötigt Zugriff auf das Paket, ein verwendeter klassischer PAT mindestens `read:packages`. Bei eingeschränktem Repository-/Paketzugriff auch Taskline freigeben. Zugangsdaten nicht in das Template oder die Kommandozeile schreiben. Ein fehlgeschlagener anonymer Download sagt nichts über den bereits angemeldeten Unraid-Host aus.

## Installation über das Unraid-Webterminal

Das geprüfte Skript arbeitet ausschließlich mit dem neuen Container `unraid-taskline`, `/mnt/user/appdata/taskline` und `my-taskline.xml`. Es stoppt bei einer bereits vorhandenen Installation. Standard-Port: 18082. Es startet keine Backups, Scans oder anderen Ziel-Tasks.

```sh
curl -fsSL https://raw.githubusercontent.com/shaisegal/unraid-templates/main/scripts/taskline/install-unraid.sh -o /tmp/install-taskline.sh
sh /tmp/install-taskline.sh
```

Vor Ausführung kann das Skript mit `cat /tmp/install-taskline.sh` geprüft werden. Für einen anderen Port: `TASKLINE_PORT=18083 sh /tmp/install-taskline.sh`. Für einen bestimmten Versions-Tag: `TASKLINE_IMAGE=ghcr.io/shaisegal/unraid-taskline:0.1.0 sh /tmp/install-taskline.sh`.

Falls `docker pull` tatsächlich mit `denied` abbricht, die vorhandene Registry-Anmeldung und die Zugriffsrechte auf das neue Taskline-Paket prüfen; eine öffentliche Freigabe ist nicht erforderlich. Vor diesem Schritt werden weder Container noch Taskline-Appdata angelegt.

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

## Duplicati hinzufügen

Nach einem Taskline-Update unter **Container & Scans** beim Duplicati-Container **Tasks scannen** wählen. Adapter **Duplicati**, vom Container erreichbare Basis-URL (normalerweise Port 8200) und das **Passwort der Duplicati-Weboberfläche** eingeben. Es ist kein API-Key nötig; nicht die Verschlüsselungspassphrase eines Backup-Auftrags verwenden.

Taskline meldet sich für diesen Scan an und liest ausschließlich Backup-/Zeitplandaten. Passwort und Token werden nicht gespeichert. Backup-Ziele, Quellpfade und Verschlüsselungseinstellungen werden nicht in Taskline übernommen. Duplicati bleibt unverändert; kein Backup wird gestartet. Die Zugangsdaten ermöglichen grundsätzlich dieselben Rechte wie die Weboberfläche.

Backup-Namen, erlaubte Wochentage und nächste Starts mit Duplicati vergleichen. Jobs ohne Zeitplan oder deaktivierte Jobs bleiben in der Liste, aber ohne Kalendertermine. Komplexe nicht unterstützte Regeln bekommen eine Erklärung statt erfundener Prognosen. Der Adapter benötigt Duplicatis moderne Passwort-/JWT-API; getestet gegen eine isolierte offizielle Version 2.4.1.0.

Bei HTTP 401 das Web-Passwort prüfen. Bei HTTP 403 die Basis-URL und Duplicatis erlaubte Hostnamen gezielt prüfen; keine pauschale Abschaltung der Hostname-Prüfung ist erforderlich. HTTP 404 beim Login kann auf eine falsche Basis-URL oder eine ältere, nicht unterstützte Duplicati-Version hinweisen.

## Updates

`:latest` erlaubt die übliche Updateprüfung in Unraid Docker. Ein Update des Images übernimmt nicht automatisch neue Template-Variablen oder Mounts; Änderungen an der Vorlage bei Bedarf unter **Edit Container** nachziehen. `/config` vor Updates sichern. Diese Version speichert JSON-Snapshots und hat noch keine Datenbankmigrationen; künftige Versionen können das ändern.

## Stand der Live-Abnahme

Lokale Unit-/HTTP-/Docker-Prüfungen ersetzen den echten Unraid-/Radarr-Test nicht. Installation und Vergleich auf dem Host sind erst nach den obigen Schritten bestätigt.
