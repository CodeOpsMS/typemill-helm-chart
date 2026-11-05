# Typemill v2.28.1 / Chart 2.4.1 – Release-Validierung

## Umfang

Das Sicherheitsupdate wird im bestehenden Branch
`chore/dependency-refresh-2026-10-29` und [PR #40](https://github.com/CodeOpsMS/typemill-helm-chart/pull/40)
mit den bereits vorbereiteten Abhängigkeitsupdates zusammengeführt.
Der automatisch angelegte [PR #42](https://github.com/CodeOpsMS/typemill-helm-chart/pull/42)
für dieselbe Chart-Version wird dadurch abgelöst. Nach erfolgreichen Pflichtprüfungen
und Merge veröffentlicht `release.yml` das GitHub Release, den Pages-Helm-Index
und das OCI-Paket in GHCR.

Geprüfte Quellen: [Upstream-Release](https://github.com/typemill/typemill/releases/tag/v2.28.1),
[Vergleich mit v2.28.0](https://github.com/typemill/typemill/compare/v2.28.0...v2.28.1),
[Docker-Metadaten](https://hub.docker.com/v2/repositories/kixote/typemill/tags/v2.28.1).
Der veröffentlichte Quellstand ist `5a9390d401e1584d359c98c9f95fb4df0d701124`.

## Anwendung und Upgrade-Hinweise

Upstream korrigiert Berechtigungen für Medienrestriktionen und lesende Inhalts-APIs,
die Ableitung von Passwort-Reset-URLs aus nicht vertrauenswürdigen Request-Headern,
namespaced SVG-Attribute und unsichere Theme-Markdown-Ausgabe.
Die vorhandene API `GET /api/v1/file` wurde entfernt. Berechtigungsfehler und
geänderte Markdown-Ausgabe sind bei eigenen Clients und Themes zu berücksichtigen.

**Handlungsbedarf bei aktiver Passwortwiederherstellung:** Vor dem Speichern anderer
Systemeinstellungen die kanonische Site-URL im Developer-Tab als `fqdn` konfigurieren,
einschließlich `https://` und gegebenenfalls Unterpfad. Ist `recoverpw` aktiv und die
FQDN fehlt, werden Wiederherstellungs-E-Mails unterdrückt und Einstellungsänderungen
abgewiesen. Der Chart schreibt diese bestehende Anwendungskonfiguration nicht um.

Dockerfile und Startskript ändern sich gegenüber v2.28.0 nicht:
`php:8.5.12-apache-trixie`, Linux/amd64, Port 80 und dieselben sieben persistenten
Datenpfade. Der Proxy-Standard des Charts bleibt explizit `false`.
Bestehende PVC-Daten, Themes und Plugins bleiben erhalten; diese werden nicht
automatisch auf neue Upstream-Versionen ersetzt. Vor dem Produktivupgrade PVC sichern
und explizit konfigurierte Image-Digests prüfen. Für Helm 3.14+ vorzugsweise
`--reset-then-reuse-values` verwenden.

## Nativer Theme-Fix und Cyanine 2.5.1

`Settings::addThemeSettings()` lädt jetzt selbst über `themesFolder` und verwendet
ein leeres Array statt `false`. Weitere Upstream-Korrekturen betreffen Setup-Auto-Login,
Setup-Redirects und Theme-CSP. Die native `Settings.php` hat SHA-256
`8c5530b58d44676fb03c609652d32cb9f7a641cbba9b4a0cf385a9fd2aafad4c`.

Der Chart rendert für v2.28.1 keinen Startup-Wrapper und verändert die Anwendungsklasse
nicht. Die bestehende Option `compatibility.cyanineV2271.enabled` bleibt für exakt
v2.27.1/v2.28.0 erhalten. Unit-Tests prüfen sowohl die historischen Versionen als auch
die unveränderte native Startkonfiguration von v2.28.1.

Cyanine 2.5.1 enthält eine neue `cyanine.yaml` mit SHA-256
`0abb520649186e4fbeb7b7de9b3a741bb358447397c9e73109d4346c8e584e15`.
Die historische v2.26-Migration erkennt genau dieses zusätzliche Pfad-/Hash-Paar
als bereits aktuell. Ihre Quelle, Ersetzungshashes und Behandlung eigener Dateien
bleiben unverändert. `home/landingpageNews.twig` und `partials/posts.twig` haben
weiterhin die bereits anerkannten v2.27.1-Hashes. Somit erkennt ein strikter Neustart
einer neuen Installation zwei alte und eine neue attestierte Datei, ohne etwas
zurückzusetzen. Angepasste Dateien bleiben geschützt.

Projekt-Startseiten erhalten im neuen Theme eine ausdrückliche Landingpage-Checkbox
im `cyhome`-Metadatentab. Bestehende Themes separat nach Prüfung der Anpassungen
aktualisieren.

## Verifizierte Image-Pins

Alle vier Pins wurden mit `scripts/verify-image-digests.sh` gegen Docker Hub geprüft.

| Container | Tag | OCI-Index-Digest |
|---|---|---|
| Typemill | `v2.28.1` | `sha256:45ec7f350014a09c44f2c49386420562593e6b97a2aaeb14115c17a588c1211d` |
| Historische Migration | `v2.26.0` | `sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156` |
| AI-Bootstrap | `4.54.1` | `sha256:4b3d9475d65571d28cbb19544d3820ec2945e4c8b2f18279394282b8dc3a592e` |
| Helm-Test | `1.38.0` | `sha256:a46257e06c82ad85242d0d38077d0a52d9896389ca60a1a59d3463db586e5fa4` |

Das Linux/amd64-Manifest von Typemill ist
`sha256:ee4f39625861983e7b63ea3543ceb654f867e3fc41a99d3adf6191d68aa94154`.

## Prüfungen und Grenzen

Lokal bestanden **156 Unit-Tests**, striktes Helm-Linting, Bash-Syntax, ShellCheck,
repräsentative AI-Renderings, Image-Digest-Prüfung und Paketierung.
Die vier bestehenden Helm-CI-Jobs prüfen Installation/Upgrade und Kubernetes-API-
Validierung. Der neue `scripts/test-v2281-runtime.sh` läuft ausschließlich in einem
zufälligen, UID-geprüften kind-Test-Namespace und prüft:

- Upgrade vom veröffentlichten Chart 2.4.0 mit unveränderter PVC-Identität,
  Datenmarkern in allen sieben Pfaden sowie bytegleichen Einstellungen und Themes;
- tatsächliche Typemill-/PHP-Version, Image-Identität und unveränderten nativen
  Anwendungshash ohne Chart-Startup-Wrapper;
- frisches Cyanine 2.5.1, erhaltenen Setup-Assistenten, Login und Startseite mit
  HTTP 200 nach Testinitialisierung und einen strikten Neustart ohne falsche Warnung;
- weiterhin wirksame eigene Theme-Einstellungen und inaktive historische Korrektur;
- Ablehnung angepasster Theme-Dateien ohne Überschreiben;
- Neuinstallation ohne Persistenz sowie AI-Bootstrap mit yq 4.54.1 und erhaltenen
  Einstellungswerten nach Neustart;
- Helm-Verbindungstests und abschließende Entfernung der eigenen Testressourcen.

Die konkreten Ergebnisse stehen in den Checks von
[PR #40](https://github.com/CodeOpsMS/typemill-helm-chart/pull/40/checks).
Vor dem Merge müssen alle vier Jobs erfolgreich sein. Die Upstream-Sicherheitsfixes
wurden anhand des Quellvergleichs geprüft; dieser Chart-Test ersetzt keinen
vollständigen Berechtigungs-, SMTP- oder Browser-Test der Anwendung.
Produktive Cluster und öffentliche TLS-/Ingress-Pfade werden für dieses Release
nicht verändert.
