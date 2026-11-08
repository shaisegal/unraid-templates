# Prüfung offener Template-Sync-PRs am 8. November 2026

Geprüft wurden alle acht zu diesem Zeitpunkt offenen PRs gegen `main` nach Merge von #23.
Sie ändern ausschließlich den Repository-Image-Tag in `pipelinarr.xml` und enthalten keine
zusätzlichen Konfigurationsänderungen.

| PR | Vorgeschlagener alter Image-Tag |
| --- | --- |
| #12 | `0.2.0-beta.9` |
| #13 | `0.2.0-beta.10` |
| #14 | `0.3.0-beta.1` |
| #15 | `0.3.0-beta.2` |
| #16 | `0.3.0-beta.3` |
| #17 | `0.3.0-beta.4` |
| #18 | `0.3.0-beta.5` |
| #19 | `0.3.0-beta.6` |

Danach wurde mit [PR #20](https://github.com/shaisegal/unraid-templates/pull/20)
`0.3.0-beta.7` übernommen. [PR #21](https://github.com/shaisegal/unraid-templates/pull/21)
stellte anschließend auf `ghcr.io/shaisegal/pipelinarr:beta` um. Diese Änderung ist bereits
in `main` enthalten.

**Ergebnis:** #12–#19 sind überholt und sollten nicht mehr gemergt werden. Sie können
als überholt geschlossen werden. Im Rahmen dieser Prüfung wurden sie weder geschlossen
noch ihre Branches gelöscht. Die Prüfung betrifft dieses Template-Repository, nicht den
Workflow im Pipelinarr-Quellrepository, der die PRs erzeugt.
