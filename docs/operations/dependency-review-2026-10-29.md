# Abhängigkeitsprüfung und Branch-Bereinigung – 29. Oktober 2026

Die folgenden Updates werden separat in `chore/dependency-refresh-2026-10-29`
für Chart 2.4.1 vorbereitet. Typemill bleibt auf dem verifizierten v2.28.0-Image.
Dieser Bericht beschreibt einen Update-PR, kein bereits veröffentlichtes Release.

| Abhängigkeit | Bisher | Vorbereiteter Stand | Quelle |
|---|---|---|---|
| AI-Bootstrap: yq | 4.53.3 | 4.54.1 mit passendem OCI-Index-Digest | [Release](https://github.com/mikefarah/yq/releases/tag/v4.54.1) |
| helm-unittest | 1.1.1 | 1.2.1 | [Release](https://github.com/helm-unittest/helm-unittest/releases/tag/v1.2.1) |
| chart-releaser-action | 1.7.0 | 1.8.0 mit chart-releaser 1.9.0 | [Action](https://github.com/helm/chart-releaser-action/releases/tag/v1.8.0), [Binary](https://github.com/helm/chart-releaser/releases/tag/v1.9.0) |
| Helm für Release und Pages-Healthcheck | 4.2.3 | 4.3.1 | [Release](https://github.com/helm/helm/releases/tag/v4.3.1) |
| Zusätzliche CI-Kompatibilitätsprüfungen | – | Helm 3.22.1 und 4.3.1 | [Helm 3](https://github.com/helm/helm/releases/tag/v3.22.1), [Helm 4](https://github.com/helm/helm/releases/tag/v4.3.1) |

Der yq-Index-Digest wurde gegen Docker Hub verifiziert:
`sha256:4b3d9475d65571d28cbb19544d3820ec2945e4c8b2f18279394282b8dc3a592e`.
Tag, Digest, Image-Metadaten und Unit-Test-Erwartung werden gemeinsam aktualisiert.
PR #32 änderte dagegen nur den Tag und hätte mit dem bisherigen Digest weiterhin
das alte Image ausgeführt; seine Änderung wird hier vollständig übernommen.

## Bereits aktuelle Abhängigkeiten

Die verwendeten Major-Tags zeigen bereits auf diese stabilen Releases; eine
Änderung der Workflow-Referenzen ist dafür nicht erforderlich:

| Referenz | Verifizierter Release-Stand |
|---|---|
| `actions/checkout@v7` | v7.0.1 |
| `actions/setup-python@v7` | v7.1.0 |
| `azure/setup-helm@v5` | v5.0.1 |
| `dependabot/fetch-metadata@v3` | v3.1.0 |
| `peter-evans/create-pull-request@v8` | v8.1.1 |

`helm/chart-testing-action@v2.9.0`, `helm/kind-action@v1.15.1`, Typemill v2.28.0
und BusyBox 1.38.0 sind ebenfalls aktuell. Die Image-Digests bleiben verifiziert.

## Unabhängige historische Migrationsquelle

[PR #38](https://github.com/CodeOpsMS/typemill-helm-chart/pull/38) schlägt vor,
`securityMigrations.cyanineV226.image.tag` von v2.26.0 auf v2.28.0 zu ändern,
behält aber den v2.26.0-Digest. Diese Quelle ist absichtlich an die geprüften
v2.26-Dateihashes gebunden; sie ist keine veraltete Anwendungsversion.
Der Vorschlag wird geschlossen und nicht übernommen.

Dependabot ignoriert künftig `kixote/typemill` im Docker-Abschnitt, damit dieser
irreführende Migrations-PR nicht erneut entsteht. Die eigentliche Anwendung wird
weiterhin vom vorhandenen `auto-update.yml` mit Tag, Digest, Chart-Version und
anschließender CI-Prüfung aktualisiert. yq und BusyBox bleiben bei Dependabot.

## Validierung und verbleibende Prüfung

Die bestehenden, vom Branch-Schutz vorgeschriebenen Jobs `Helm v3.21.3` und
`Helm v4.2.3` bleiben bestehen. Die aktuellen stabilen Versionen kommen als zwei
weitere Jobs hinzu; es werden keine Schutzregeln abgeschwächt oder umbenannt.

Lokal bestanden die 153 Unit-Tests auch mit helm-unittest 1.2.1, striktes
Helm-Linting, alle vier Image-Digest-Prüfungen, Bash-Syntax, ShellCheck,
Paketierung und `git diff --check`. Das neue Plugin wurde in einem separaten
temporären Verzeichnis geprüft; das vorhandene lokale Plugin blieb erhalten.
Das Upstream-VCS-Installationsskript scheiterte auf diesem macOS an der verfügbaren
`sha256sum`-Variante. Stattdessen wurden die bereits geladenen offiziellen
Release-Dateien nach Abgleich mit der veröffentlichten SHA-256-Liste installiert.
Die CI verwendet Ubuntu mit GNU-Prüfsummenwerkzeugen und prüft dort auch den
regulären Installationspfad.

Der kind-Laufzeittest prüft zusätzlich den tatsächlichen AI-Bootstrap mit dem
neuen yq-Image, leere Temperatur, 128000 Tokens, erhaltene eigene Einstellungen
und idempotenten Neustart. Es werden keine externen AI-Anfragen gestellt.
Die Release-Action behält den vorhandenen Pages-/OCI-Ablauf und ihre weiterhin
unterstützten Eingaben bei; ihre Veröffentlichung läuft erst nach einem Merge.

Die alten Dependabot-PRs werden durch diesen separaten PR abgelöst bzw. verworfen.
Erledigte Arbeitsbranches werden lokal und auf GitHub entfernt; `main` und
`gh-pages` bleiben erhalten. Vor dem Löschen wurde eine lokale Git-Bundle-Sicherung
angelegt, damit auch ältere, per Squash integrierte Commit-Verläufe erhalten bleiben.
