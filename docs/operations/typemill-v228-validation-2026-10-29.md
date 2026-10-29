# Typemill v2.28.0 / Chart 2.4.0 – Release-Validierung

## Umfang und Quellen

Update im bestehenden [PR #36](https://github.com/CodeOpsMS/typemill-helm-chart/pull/36)
auf `chore/update-typemill-v2.28.0`. Die Veröffentlichung erfolgt nach erfolgreichen
Pflichtprüfungen und Merge über `release.yml`: GitHub Release, Helm-Repository auf
GitHub Pages und OCI-Paket in GHCR.

Geprüft wurden die [Upstream-Release-Notizen](https://github.com/typemill/typemill/releases/tag/v2.28.0),
der [Vergleich mit v2.27.1](https://github.com/typemill/typemill/compare/v2.27.1...v2.28.0)
und die [Docker-Hub-Metadaten](https://hub.docker.com/v2/repositories/kixote/typemill/tags/v2.28.0).
Der neue Tag zeigt auf `2b5b2034ac4792059234a0ab40204ff4f8f67dfa` und umfasst vier
weitere Commits gegenüber v2.27.1.

Die zusätzlichen Sicherheitskorrekturen prüfen Ordnerberechtigungen bei mehrsprachigen
Seiten und Kixote-Übersetzungen. Freigegebene Ordner werden als vollständige URL-Präfixe
behandelt. Daneben ändern sich Abhängigkeiten und veraltete `finfo_close`-Aufrufe.
Dockerfile, Startskript, AI-Konfigurationsformat und Cyanine-Dateien ändern sich
gegenüber v2.27.1 nicht. Das stabile Release enthält außerdem die bereits im
v2.27.1-Zwischenstand veröffentlichten API-, Theme- und Sicherheitsänderungen.

## Weiterhin notwendige Theme-Korrektur

Die originale `Settings.php` hat auch in v2.28.0 den SHA-256
`a6a1a7751e5d735b8a2bea6c802b0407d5d629d0765bbb1ada075a334174044e`.
`addThemeSettings()` verwendet weiterhin den unbekannten Storage-Schlüssel `themes`
statt `themesFolder`. Ohne gespeicherte Theme-Einstellungen kann das unveränderte
Cyanine-Template deshalb weiterhin HTTP 500 auslösen.

Die bestehende Korrektur wird auf genau die beiden Laufzeitversionen 2.27.1 und
2.28.0 begrenzt. Der Hash nach der Korrektur bleibt
`f273572502d6960d4cf45f6a123bce3585e630187918c1d69e77285eca5efe87`.
Andere Versionen werden übersprungen, unbekannter Code einer betroffenen Version
wird abgewiesen und bereits korrigierter Code wird unverändert akzeptiert.
Die öffentliche Einstellung `compatibility.cyanineV2271.enabled` bleibt erhalten.
Es werden ausschließlich kurzlebige Anwendungsdateien korrigiert: kein Voranlegen
von `settings.yaml`, keine Änderungen an PVC-Themes oder vorhandenen Einstellungen.

Die historische v2.26-Cyanine-Migration bleibt auf ihrer unabhängigen Quelle.
Ihre drei zusätzlich anerkannten v2.27.1-Hashes gelten auch für das unveränderte
Cyanine 2.5.0 in v2.28.0. Es wird kein Theme zurückgesetzt oder vollständig ersetzt.

## Image-Pins

Alle vier Standard-Digests wurden mit `scripts/verify-image-digests.sh` gegen Docker
Hub verifiziert. Der BusyBox-Tag wurde upstream neu gebaut; dessen bisheriger Pin
stimmte nicht mehr mit dem Tag überein und wurde für den vorgeschriebenen Check erneuert.

| Container | Tag | OCI-Index-Digest |
|---|---|---|
| Typemill | `v2.28.0` | `sha256:dc92861ac28b6507ebc3a449430e77da1127de06371f73a15a73d7408b2ced32` |
| Historische Migration | `v2.26.0` | `sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156` |
| AI-Bootstrap | `4.53.3` | `sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977` |
| Helm-Test | `1.38.0` | `sha256:a46257e06c82ad85242d0d38077d0a52d9896389ca60a1a59d3463db586e5fa4` |

Das Linux/amd64-Manifest von Typemill ist
`sha256:70763dd1b69326f51ca948c253beb61f47e97ed9644ac6b02f27f722d5a165ba`.

## Prüfungen und Grenzen

Lokal mit Helm 4.3.1 erfolgreich: **153/153 Unit-Tests**, striktes Helm-Linting,
repräsentative OpenAI-/Responses-Renderings, Bash-Syntax, ShellCheck und
`git diff --check`.

Die vorgeschriebenen CI-Jobs für Helm 3.21.3 und 4.2.3 prüfen zusätzlich
Schema-/Negativfälle, Installation und Upgrade, Kubernetes-API-Dry-runs und den
neuen `scripts/test-v228-runtime.sh`. Der Test verweigert produktive Kontexte und
arbeitet ausschließlich in einem zufälligen, UID-geprüften kind-Test-Namespace:

- Upgrade von veröffentlichtem Chart 2.3.1 auf 2.4.0, PHP 8.5.12 und echte
  Typemill-Version 2.28.0 samt Index-/Plattform-Digest;
- unveränderte PVC-Identität, Datenmarker in allen sieben persistenten Pfaden,
  bytegleiche Theme-Dateien und erhaltene Site-Konfiguration nach Upgrade/Neustart;
- neue Cyanine-Installation, regulärer Setup-Assistent, Login und Startseite mit
  HTTP 200 nach Initialisierung sowie strikter Neustart ohne falsche Warnungen;
- eigene Theme-Einstellungen, idempotente Anwendungskorrektur, Ablehnung unbekannten
  Codes und Überspringen einer nicht freigegebenen Laufzeitversion;
- unveränderte eigene Themes bei abgewiesener strikter Migration;
- Neuinstallation ohne Persistenz und Helm-Verbindungstests;
- Entfernen des eigenen Test-Namespace einschließlich seiner Test-PVCs.

Die konkreten Laufzeitergebnisse stehen in den beiden erforderlichen Checks von
[PR #36](https://github.com/CodeOpsMS/typemill-helm-chart/pull/36/checks).
Beide müssen vor dem Merge vollständig erfolgreich sein.

Produktive Cluster wurden nicht verändert. Öffentliche TLS-/Ingress-Pfade,
produktive Plugins und externe AI-Inferenz sind nicht Teil dieses isolierten Tests.
Vor dem Produktivupgrade PVC sichern und explizite Image-Pins sowie eigene
Themes/Plugins prüfen.
