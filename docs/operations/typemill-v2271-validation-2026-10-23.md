# Typemill v2.27.1 / Chart 2.3.1 (2026-10-23)

## Ergebnis und Umfang

Chart 2.3.1 enthält neben dem PHP-Update einen ausdrücklich freigegebenen,
hashgesicherten Workaround für den im ersten CI-Lauf gefundenen Cyanine-Fehler.
Die Korrektur betrifft ausschließlich die flüchtige Anwendungsschicht; gespeicherte
Themes, Einstellungen und der Setup-Assistent bleiben erhalten. Die Release-Freigabe
setzt erfolgreiche Helm-3/4-Checks einschließlich der erweiterten Laufzeittests voraus.

Der automatisiert erstellte Branch `chore/update-typemill-v2.27.1` und
[PR #35](https://github.com/CodeOpsMS/typemill-helm-chart/pull/35) werden für das
geprüfte Update weiterverwendet. Chart 2.3.1 enthält Typemill v2.27.1 und den
kurzen Hinweis: **PHP-Sicherheitsfehler im Docker-Image durch PHP 8.5.12 behoben.**
Der Hinweis steht auch in den Helm-Installationsnotizen; Artifact Hub ist als
Security-Update markiert.

Die geplante Veröffentlichung erfolgt erst nach erfolgreicher CI und Merge über den vorhandenen
Release-Workflow: GitHub Release `typemill-2.3.1`, Chart-Archiv, GitHub-Pages-Index
und OCI-Paket `ghcr.io/codeopsms/helm-charts/typemill:2.3.1`. Produktive
Kubernetes-Releases werden dabei nicht aktualisiert.

## Upstream- und Docker-Prüfung

Quellen: [Release](https://github.com/typemill/typemill/releases/tag/v2.27.1),
[Vergleich](https://github.com/typemill/typemill/compare/v2.27.0...v2.27.1),
[Dockerfile](https://github.com/typemill/typemill/blob/fd3d1f3c202afe743d9fe93145d46836076c4b77/Dockerfile),
[Startskript](https://github.com/typemill/typemill/blob/fd3d1f3c202afe743d9fe93145d46836076c4b77/docker-utils/init-server),
[Docker-Hub-Metadaten](https://hub.docker.com/v2/repositories/kixote/typemill/tags/v2.27.1).

- Upstream veröffentlicht v2.27.1 ausdrücklich als unfertigen v2.28-Zwischenstand,
  um Docker-Nutzern die PHP-Sicherheitskorrektur bereitzustellen. Es ist kein reiner
  PHP-Neubau: 16 Commits enthalten weitere Anwendungsänderungen.
- Die Docker-Basis ist jetzt explizit `php:8.5.12-apache-trixie`. Linux/amd64,
  Apache/Port 80, Startskript und die sieben persistenten Verzeichnisse bleiben
  gleich. Zusätzliche Volumes sind nicht erforderlich; der Chart-Workaround erhält
  einen abschaltbaren Kompatibilitätswert.
- Weitere Korrekturen betreffen Zugriffe auf Entwürfe, Ordnerrestriktionen,
  Metadaten und Medien sowie mehrsprachige Seiten. API-Clients müssen strengere
  Berechtigungsprüfungen berücksichtigen. Keine neuen AI-Konfigurationswerte.
- Cyanine wird auf 2.5.0 aktualisiert, verschiebt Seitentemplates nach `pages/`
  und erweitert mehrsprachige Startseiten/Spracherkennung. Vorhandene Themes
  werden weiterhin nicht überschrieben; ein Theme-Upgrade ist separat zu prüfen.
- Proxy- und AI-Standardwerte des Charts bleiben unverändert. Das Upgrade ist
  keine Behebung des früher dokumentierten produktiven Secure-Cookie-Befunds.

## Image-Pins

`scripts/verify-image-digests.sh` bestätigt alle vier Standard-Digests gegen Docker Hub:

| Container | Tag | OCI-Index-Digest |
|---|---|---|
| Typemill | `v2.27.1` | `sha256:a1982fcfdde1317b41ddd83924f99bd44aa103cd86cceadb473c19275eef501a` |
| Historische Migration | `v2.26.0` | `sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156` |
| yq | `4.53.3` | `sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977` |
| BusyBox | `1.38.0` | `sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e` |

Das zugehörige Linux/amd64-Manifest von Typemill ist
`sha256:718e8c53232c1b296668a5aae00bd5f910349473f4fea5976915aca1184e0d65`.
Abhängigkeiten aus anderen PRs werden nicht mit diesem Update vermischt.

## Korrektur der historischen Cyanine-Migration

Die alte Migration würde drei neue, unveränderte Dateien als angepasst einstufen.
Mit `failOnModified=true` wäre der zweite Start einer neuen Installation blockiert.
Die bestehende Migration erkennt jetzt zusätzlich diese exakten Pfad-/Hash-Paare
aus Upstream-Commit `fd3d1f3c202afe743d9fe93145d46836076c4b77`:

| Pfad innerhalb von Cyanine | SHA-256 |
|---|---|
| `home/landingpageNews.twig` | `c19896524c3142fbb331d411337ccf9d221981a30043d9fcc16156080776dae4` |
| `partials/posts.twig` | `a4b94218d52b74ffd19fdee402d7060960909f592aa0fb098183a22994aab09c` |
| `cyanine.yaml` | `4484d7a6488205669472d2cadaacb9c8eb145b130472f3ad014a2582aa00234d` |

Die relevanten Escaping-Korrekturen bleiben in den neuen Templates erhalten.
Geprüfte Dateien werden nur erkannt, niemals auf v2.26 zurückgesetzt. Die alte
Migrationsquelle, ihre fünf Ersetzungshashes und der Umgang mit unbekannten
Dateien/Symlinks bleiben unverändert. Neue `pages/`-Dateien werden nicht von dieser
historischen Fünf-Pfade-Prüfung erfasst; sie ist keine vollständige Theme-Attestierung.

## Tests und Grenzen

Lokal mit Helm 4.3.1: striktes Linting, **151/151 Unit-Tests**, Bash-Syntax,
ShellCheck und `git diff --check` erfolgreich. Die bestehende CI prüft zusätzlich
Helm 3.21.3 und 4.2.3, Schema-/Negativtests, Installation/Upgrade und serverseitiges
Kubernetes-Rendering.

Der neue versionierte Test `scripts/test-v2271-runtime.sh` läuft in beiden
CI-Matrix-Jobs ausschließlich auf einem kind-Kontext und in einem zufälligen,
UID-geprüften Test-Namespace. Sein vorgesehener Prüfumfang ist:

- Upgrade von Chart 2.3.0 auf 2.3.1 mit strikter Migration, gleicher PVC-Identität,
  Markern in allen sieben Datenpfaden und bytegleichen vorhandenen Theme-Dateien;
- tatsächliche Typemill-Version 2.27.1, PHP **8.5.12**, Image-Digest, erfolgreiche
  Init-Container, Login/Startseite und unveränderten Proxy-Standard;
- neue Installation mit Cyanine 2.5.0 und anschließenden strikten Neustart ohne
  falsche Warnungen oder Theme-Änderungen;
- weiterhin blockierte, unverändert erhaltene Anpassungen an allen drei neu
  attestierten Dateien sowie Helm-Verbindungstests;
- Erhalt des Setup-Assistenten ohne vorzeitig angelegte `settings.yaml`, bytegleiche
  gespeicherte Konfiguration nach Upgrade/Neustart und weiterhin wirksame eigene
  Theme-Einstellungen;
- verifizierter Laufzeit-Hash der korrigierten Anwendungsklasse, idempotente
  Wiederholung und Abweisung unbekannten Codes ohne Überschreiben;
- abschließendes Entfernen seines eigenen Test-Namespace einschließlich Test-PVCs.

### Ursprünglicher CI-Befund vor dem Workaround

Im [Diagnoselauf](https://github.com/CodeOpsMS/typemill-helm-chart/actions/runs/39909163335)
bestanden unter Helm 3.21.3 und 4.2.3 die statischen Prüfungen, 143 Unit-Tests,
chart-testing-Installation/Upgrade und Kubernetes-Dry-runs. Der zusätzliche
persistente Upgrade-Test bestand ebenfalls: PHP 8.5.12, Typemill 2.27.1,
Login/Startseite HTTP 200, Neustart, PVC-Identität, Datenmarker, unveränderte alte
Theme-Dateien und Helm-Verbindungstest.

Die frische Installation startete, der Login lieferte HTTP 200; die Startseite
scheiterte in beiden Jobs mit HTTP 500:

```text
Twig\Error\RuntimeError
The "merge" filter expects a sequence or a mapping, got "bool" for argument 1
in "index.twig" at line 12.
```

Die isolierte Fixture speichert eine minimale Site-Konfiguration, aber keine
Theme-Einstellungen. Upstreams `Settings::addThemeSettings()` lädt deren Fallback
über `getObjectSettings('themes', 'cyanine')`; `Storage` kennt `themesFolder`,
nicht `themes`. Der Fallback wird dadurch `false`. Das neue Cyanine-Template
übergibt diesen Wert ohne Absicherung an `merge`. Die reguläre Setup-Methode
`Settings::createSettings()` legt ebenfalls keine Theme-Konfiguration an.
Dieser Befund ist kein PHP-Versionsfehler und kein Helm-Renderingfehler.

Wegen dieses Fehlers wurden im ursprünglichen Diagnoselauf der frische strikte
Neustart und die anschließenden Custom-Hash-Laufzeittests nicht erreicht.
Beide Test-Namespaces wurden entfernt. Der vorherige Setup-Redirect-Fehler der
Test-Fixture wurde bereits korrigiert, ohne die HTTP-200-Prüfung abzuschwächen.

Die Veröffentlichung wurde deshalb zunächst gestoppt. Kein fehlgeschlagener Check
wurde umgangen. Nach ausdrücklicher Zustimmung wurde folgender Workaround ergänzt.

### Freigegebener, begrenzter Workaround

`files/cyanine-v2271-fallback.php` korrigiert beim Containerstart genau den Aufruf
`getObjectSettings('themes', $settings['theme'])` in `Settings::addThemeSettings()`
zu `getObjectSettings('themesFolder', $settings['theme'])`. Es werden nur fehlende
Theme-Defaults zur Laufzeit geladen, keine bestehenden Konfigurationswerte geändert.

- Originalklasse: `a6a1a7751e5d735b8a2bea6c802b0407d5d629d0765bbb1ada075a334174044e`.
- Korrigierte Klasse: `f273572502d6960d4cf45f6a123bce3585e630187918c1d69e77285eca5efe87`.
- Tatsächliche Version muss 2.27.1 sein. Nur der exakte Originalhash wird geändert;
  der Zielhash ist idempotent, andere Hashes und Symlinks werden abgewiesen.
- Schreiben erfolgt geprüft und atomar im nicht persistenten Anwendungsverzeichnis.
  Es werden weder PVC-Dateien noch gebündelte Themes oder Standard-YAMLs verändert.
- Der ursprüngliche Docker-Entrypoint bleibt aktiv; nach erfolgreicher Korrektur
  wird das originale `docker-utils/init-server` ausgeführt. Fehler stoppen den Start.
- `compatibility.cyanineV2271.enabled=false` schaltet den Workaround für überprüfte
  eigene Images ab. Bei anderen deklarierten Versionen wird er nicht gerendert;
  Digest-Overrides werden zusätzlich anhand der tatsächlichen Version geprüft.
- Kein Vorab-Anlegen von `settings.yaml`: Das würde die Setup-Erkennung umgehen
  und könnte durch die reguläre Ersteinrichtung wieder überschrieben werden.

Die abschließenden Laufzeitergebnisse sind über die erforderlichen Helm-Checks von
[PR #35](https://github.com/CodeOpsMS/typemill-helm-chart/pull/35) nachvollziehbar.
Sie müssen vor dem Merge vollständig erfolgreich sein; die ursprünglichen Fehlerlogs
bleiben als Regressionsevidenz erhalten.

Der Test ist bewusst auf v2.27.1 begrenzt, damit spätere Releases
nicht an der historischen PHP-Versionsprüfung scheitern.

Ein SUSE-AI-Test war am 23. Oktober nicht möglich: Der API-Hostname wurde bereits
beim read-only Preflight nicht aufgelöst. Es wurde dort nichts geändert. Auch
produktive Plugins, öffentliche Ingress-/TLS-Pfade und externe AI-Inferenz sind
nicht Bestandteil dieses Tests. Vor einem Produktivupgrade PVC sichern, explizite
Image-Pins prüfen und eigene Themes/Plugins mit dem Zwischenstand testen.
