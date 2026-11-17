# Typemill v2.28.2 / Chart 2.4.2 – PR-Validierung

## Umfang und Quellen

Ergänzung des bestehenden [PR #44](https://github.com/CodeOpsMS/typemill-helm-chart/pull/44)
auf `chore/update-typemill-v2.28.2`. Der aktuelle main einschließlich
kind-action 1.15.2 wurde eingearbeitet. Der PR bleibt zur Prüfung offen;
Veröffentlichung und Paketierung erfolgen über den vorhandenen Release-Workflow
nach einem späteren Merge.

Quellen: [Upstream-Release](https://github.com/typemill/typemill/releases/tag/v2.28.2),
[Quellvergleich](https://github.com/typemill/typemill/compare/v2.28.1...v2.28.2),
[Docker-Hub-Metadaten](https://hub.docker.com/v2/repositories/kixote/typemill/tags/v2.28.2).
Upstream umfasst einen Commit, `632673616874ba0f7fe513cc5c61cd4a7f4efa1e`,
mit Änderungen in vier Dateien.

## Behobener Fehler und Upgrade

Das initiale Setup und die Plugin-Anmeldung laden den Benutzer jetzt über
`setUserWithPassword()`. Zusätzlich übernimmt `User::updateUser()` den bereits
gespeicherten Hash, wenn öffentliche Benutzerdaten kein Passwortfeld enthalten.
Damit wird ein gültiges Passwort bei diesen Schreibvorgängen nicht mehr entfernt.
Die native `User.php` hat SHA-256
`adce2bb0bf8a48a410b18a62aaf05b43cf5842374487c51b4a74c48e4baeec7d`.

Ein bereits fehlender Hash kann aus dem Image-Update nicht rekonstruiert werden.
Betroffene Konten über ein geprüftes Backup oder eine konfigurierte
Passwortwiederherstellung wiederherstellen. Deren FQDN-Anforderung aus v2.28.1
bleibt gültig. Vor dem Upgrade PVC sichern und explizite Image-Pins prüfen.

Dockerfile, Startskript, PHP 8.5.12, Port 80, die sieben persistenten Pfade,
Cyanine 2.5.1 und die native Theme-Korrektur bleiben gegenüber v2.28.1 gleich.
Die historischen Migrationsquellen und Dateihashes ändern sich nicht. Der Chart
überschreibt weder bestehende Benutzer noch Passwörter oder Anwendungsklassen.
Der separate yq-PR #47 wird nicht mit diesem Anwendungsupdate vermischt.

## Image-Pins

Alle vier Pins wurden mit `scripts/verify-image-digests.sh` gegen Docker Hub geprüft.

| Container | Tag | OCI-Index-Digest |
|---|---|---|
| Typemill | `v2.28.2` | `sha256:5b794a65fde9109b79ffd87df821fe6ac99ff60cfa7906083e2d4bd255def11f` |
| Historische Migration | `v2.26.0` | `sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156` |
| AI-Bootstrap | `4.54.1` | `sha256:4b3d9475d65571d28cbb19544d3820ec2945e4c8b2f18279394282b8dc3a592e` |
| Helm-Test | `1.38.0` | `sha256:a46257e06c82ad85242d0d38077d0a52d9896389ca60a1a59d3463db586e5fa4` |

Das Linux/amd64-Manifest von Typemill ist
`sha256:51ceb2ab362cf4acc03bb1486b4543d4ab5a644eb00b9b8887b47598006946ba`.

## Prüfungen

Lokal bestanden 156 Unit-Tests, striktes Helm-Linting, Bash-Syntax, ShellCheck,
Image-Digest-Prüfung, repräsentative AI-Renderings und Paketierung.
Die bestehenden Helm-Jobs 3.21.3, 4.2.3, 3.22.1 und 4.3.1 führen zusätzlich
`scripts/test-v2282-runtime.sh` aus. Dieser verweigert Nicht-kind-Kontexte und
verwendet ausschließlich einen zufälligen, UID-geprüften Test-Namespace.

Der neue Authentifizierungstest verwendet ein synthetisches Administratorkonto
mit zufälligem Passwort. Es wird nur über stdin in den Test-Pod übergeben und
weder protokolliert noch als Klartext auf dem PVC gespeichert. Die PHP-Fixture
erlaubt ausschließlich lokale HTTP-Ziele und benötigt ein ausdrückliches CI-Flag.

Geprüft werden:

- Upgrade vom veröffentlichten Chart 2.4.1 mit einem vorher angelegten gültigen
  Benutzer; Login und unveränderter Passwort-Fingerprint nach Upgrade und Neustart;
- tatsächliche HTTP-Ersteinrichtung über das Setup-Formular samt Cookies und
  Referer, Setup-Auto-Login sowie weiterhin gültiger gespeicherter Passwort-Hash;
- abgewiesenes falsches Passwort und erfolgreicher Login mit einer neuen Session;
- `setUser()` ohne öffentliches Passwortfeld, anschließendes `updateUser()` und
  erhaltener gespeicherter Hash;
- native Anwendungs- und Benutzerklasse, PHP-/Typemill-Version und Image-Identität;
- unveränderte PVC-Identität, alle sieben Datenpfade, Einstellungen und Themes;
- Cyanine-Initialisierung, strikter Neustart und Schutz angepasster Dateien;
- Installation ohne Persistenz, AI-Bootstrap, Service-Verbindungstests und Bereinigung.

Die Ergebnisse stehen in den vier Helm-CI-Jobs auf
[PR #44](https://github.com/CodeOpsMS/typemill-helm-chart/pull/44/checks).
Externe SSO-/Plugin-Anbieter und SMTP-Zustellung werden nicht aufgerufen; diese
Integrationstests prüfen den lokalen Passwort- und Setup-Ablauf.
Produktive Cluster werden für diesen PR nicht verändert.
