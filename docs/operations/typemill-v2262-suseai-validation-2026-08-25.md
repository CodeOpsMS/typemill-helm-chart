# Typemill v2.26.2: SUSE-AI-Validierung (2026-08-25)

## Ergebnis

Chart `2.2.0` ist auf Typemill `v2.26.2` aktualisiert und lokal sowie in einem
isolierten SUSE-AI-Namespace erfolgreich geprüft. Die drei produktiven Instanzen
blieben unverändert auf Chart `2.1.0` / Typemill `v2.25.0`.

Der Anwendungspfad ist technisch upgradefähig, aber noch nicht zur produktiven
Ausrollung freigegeben. Vorher muss ein betriebliches Stop-Kriterium erfüllt
werden:

1. Der unmittelbare Ingress-Trust-Pfad muss korrigiert werden. Der öffentliche
   Login von Lissa-Test setzt derzeit `typemill-session` ohne `Secure`, statt
   `__Secure-typemill-session; Secure`.

Der zuvor offene eBook-Punkt wurde mit einer schreibgeschützten Kopie des realen
Lissa-Test-Plugins in einem isolierten v2.26.2-/PHP-8.5.9-Pod funktional geprüft.
Der Export ist erfolgreich, erzeugt jedoch zusätzliche Deprecation-Meldungen.
Ein vollständiger UI-/Download-Canary auf Lissa-Test bleibt nach dem Upgrade
empfohlen, ist aber kein vorab offenes Chart-Stop-Kriterium mehr.

Zu Beginn der Konsolidierung existierten gleichzeitig die Update-PRs `#22`
(v2.26.0), `#23` (v2.26.1) und `#25` (v2.26.2). Die älteren PRs enthielten keine
eigenständigen Änderungen und wurden durch den vollständigen
v2.26.2-/Chart-2.2.0-Stand auf PR `#25` ersetzt.

## Offizieller v2.26.2-Stand

`v2.26.2` ist am Prüftag der neueste stabile Typemill-Tag. Der offizielle
[v2.26.1→v2.26.2-Vergleich](https://github.com/typemill/typemill/compare/v2.26.1...v2.26.2)
enthält drei Commits und zehn Dateien. Gegenüber v2.26.1 wurden nur folgende
Bereiche geändert:

- fehlende Setup-Verzeichnisse werden angelegt;
- der Setup-Check nennt und prüft PHP 8.2 als Mindestversion;
- Setup-Text und sieben Übersetzungsdateien wurden sprachlich angepasst;
- `defaults.yaml` meldet Version `2.26.2`.

Dockerfile, Entrypoint, Volumes, PHP-Basis, Composer-Abhängigkeiten, Cyanine,
Plugins, Proxy- und AI-Code sind zwischen v2.26.1 und v2.26.2 unverändert. Die
kumulativen Sicherheits- und Laufzeitänderungen stammen weiterhin aus den
[v2.26.0](https://github.com/typemill/typemill/releases/tag/v2.26.0)- und
[v2.26.1](https://github.com/typemill/typemill/releases/tag/v2.26.1)-Releases.

Bekannte reine Upstream-Randfehler in v2.26.2:

- ein bereits vorhandenes, aber nicht schreibbares Setup-Verzeichnis kann als
  erfolgreich erstellt behandelt werden;
- die niederländische Übersetzung enthält `Activeer jTypeMille licentie.`;
- der neue Setup-Slogan besitzt keinen Übersetzungsschlüssel und fällt auf
  Englisch zurück.

Der Fresh-Setup-/Read-only-Verzeichnis-Regressionspunkt wurde auf ausdrücklichen
Wunsch in diesem Lauf übersprungen. Er ist daher keine bestandene Testposition.

## Verifizierte Container

| Zweck | Referenz | Ergebnis |
|---|---|---|
| Anwendung | `kixote/typemill:v2.26.2@sha256:4e9dff1795190fb3f09fc9e967643a030a0b8ee51e5e57aff086c270976ada07` | PASS |
| Anwendung, linux/amd64 | `sha256:88b1d058dd57a56127a3bd2a7137aad4d60706ca752925a6e8f70fd6157395f4` | PASS |
| Cyanine-Migrationsquelle | `kixote/typemill:v2.26.0@sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156` | PASS |
| AI-Bootstrap | `mikefarah/yq:4.53.3@sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977` | PASS |
| Helm-Test | `busybox:1.38.0@sha256:dc2d74b28e4cf8984fa52af1f39bc7c3d9c73760b41a74d629f5d11b1ab28616` | PASS |

Das v2.26.2-Image läuft auf PHP `8.5.9`, enthält `defaults.yaml` mit Version
`2.26.2` und die fünf erwarteten Cyanine-Zielhashes. Die Artifact-Hub-Metadaten
listen nun auch die separate v2.26.0-Migrationsquelle auf.

## Implementierte Chart- und CI-Änderungen

- Chart und unveränderlicher Hauptimage-Pin wurden auf v2.26.2 aktualisiert.
- Die v2.26.0-Cyanine-Migrationsquelle bleibt bewusst separat und unveränderlich
  gepinnt.
- Der Containerdefault `TYPEMILL_PROXY_DETECTION=true` wird vom Chart standardmäßig
  mit `false` neutralisiert; persistiertes `proxy: true` bleibt wirksam.
- Die hash-geschützte Cyanine-Einmalmigration bewahrt Custom-Dateien und kann mit
  `failOnModified` kontrolliert werden.
- AI/Ollama kann ohne öffentliches Ollama und ohne API-Key über einen internen
  OpenAI-kompatiblen Kubernetes-Service konfiguriert werden.
- CI lädt `.github/ct.yaml` explizit und führt `ct install --upgrade` aus.
- Der Auto-Updater erkennt alte Digests bei mutable Tags, konkurrierende interne
  Typemill-Update-PRs und verwaiste Branches fail-closed. Fork-PRs werden nicht als
  interner Update-Branch übernommen.
- Der Setup-Quickstart über unverschlüsseltes öffentliches HTTP wurde entfernt.
- Der isolierte Test ist reproduzierbar in
  `scripts/suse-ai-v225-v2262-e2e.sh` hinterlegt. Namespace-Erzeugung und Cleanup
  sind durch Name, UID und Labels geschützt; ein vorhandener Namespace wird nie
  übernommen.

Der erfolgreiche Abschlusslauf erfolgte vor der letzten rein statischen
Überarbeitung dieses Skripts. Die danach unveränderten Chart-Runtime-Templates
sind durch den Lauf abgedeckt; die aktuelle Skriptfassung selbst wurde danach
mit `bash -n` und ShellCheck, aber nicht noch einmal vollständig ausgeführt.

## Isolierter SUSE-AI-E2E

Erfolgreicher Abschlusslauf:

| Feld | Wert |
|---|---|
| Run-ID | `v2262-20260825080235-fb3a42` |
| Test-Namespace | `typemill-v2262-e2e-20260825080235-fb3a42` |
| Upgrade | Chart `2.1.0` / v2.25.0 → Chart `2.2.0` / v2.26.2 |
| Storage | 1-GiB-Longhorn-PVC, gleiche PVC/PV-Identität während Upgrade und Neustart |
| Ollama | nur intern, `suse-ai-ollama.suse-private-ai.svc.cluster.local:11434/v1` |
| Modell | `mistral-small3.2:latest`, in `/v1/models` vorhanden |
| Ergebnis | Exit `0`, vollständiger Cleanup |

Geprüfte Eigenschaften:

- sieben persistierte Verzeichnis-Marker blieben bytegleich;
- der Main-Runtime-Digest wechselte exakt von v2.25.0 auf v2.26.2;
- vier unveränderte Cyanine-Dateien wurden ersetzt, eine absichtlich angepasste
  Datei wurde bewahrt;
- der zweite Podstart meldete viermal `already current`, schrieb keine Datei erneut
  und bewahrte die Custom-Datei;
- der anonyme Media-Test reproduzierte unter v2.25.0 den Pfadäquivalenz-Bypass
  (`302` normal, `200` mit Doppel-Slash); unter v2.26.2 lieferten beide Pfade `302`;
- Traversal-Eingabe wurde mit `400`/`404` abgewiesen;
- AI-Werte wurden ohne Secret korrekt persistiert, Ollama blieb nur intern erreichbar;
- der verpackte Helm-Verbindungstest war erfolgreich;
- `Recreate`-Neustart, Retain-PVC nach Helm-Uninstall und anschließende
  Longhorn-Reclamation waren erfolgreich;
- Test-Namespace und Test-PV sind nachweislich nicht mehr vorhanden.

Die Vorher-/Nachher-Snapshots der produktiven Namespace-, Deployment- und
PVC-Invarianten waren bytegleich. Beide besitzen SHA-256
`3605575c62142d9b89df7a73b14547cda1730d9ff2aa58ac31835ce6872b3a38`.

## Produktive Instanzen: erwartete Auswirkung

Alle drei Deployments sind weiterhin `1/1` bereit, verwenden den v2.25.0-Digest
`sha256:52e081c1149d8b4c8ae6b03b03099411d9d95f32ee7ce6b61890b391700471bd`
und PHP `8.3.32`. Sie verwenden statische 50-GiB-NFS-Existing-Claims mit
`ReclaimPolicy=Retain`. Der Zielchart rendert für diese Values kein PVC-Objekt und
kann die Claims daher nicht erstellen, ändern, vergrößern oder löschen.

| Namespace | Release | Cyanine-Migration | AI/Ollama | Plugin-Risiko |
|---|---|---|---|---|
| `typemilllissatest` | `typemilltest` | 0 Writes; Warnungen für `partials/posts.twig` und `cyanine.yaml` | intern, `mistral-small3.2:latest` vorhanden | eBooks 2.4.0; bester Canary |
| `typemilllissa` | `typemill` | 0 Writes; Warnungen für `partials/posts.twig` und `cyanine.yaml` | intern, `gemma4:31b` vorhanden | eBooks 2.4.0 |
| `typemilluhlex` | `typemilluhlex` | 0 Writes; Warnungen für News, Posts und `cyanine.yaml`; `landingpage.twig` bleibt bewusst abwesend | nicht konfiguriert | ältere Plugins/eBooks 2.2.0; höchstes Risiko |

UID/GID `33:33` kann auf allen drei NFS-Claims die vorhandenen migrationsrelevanten
Pfade lesen und traversieren. Die manuell eingespielten XSS-Fixes sind weiterhin
vorhanden. Deshalb entfällt auch der früher erwartete Eigentümer-/Moduswechsel:
keine der aktuellen produktiven Dateien entspricht noch einem ersetzbaren alten
Stock-Hash. `failOnModified=false` bleibt trotzdem zwingend; mit `true` würden alle
drei Instanzen wegen der absichtlich angepassten Dateien blockieren.

Alle aktuellen Helm-Values rendern lokal auf v2.26.2 und bestehen vollständige
Kubernetes-Server-Dry-runs. Die bestehende manuelle AI-Konfiguration von Lissa und
Lissa-Test bleibt unberührt, weil `ai.enabled` in den produktiven Helm-Values nicht
gesetzt ist.

### `--reuse-values`-Falle

Ein echter, rein lesender `helm upgrade --reuse-values --dry-run=server` gegen alle
drei Releases rendert zwar Migration, Proxy-Fallback und die richtigen Existing-Claims,
übernimmt aber den alten v2.25.0-Hauptimage-Digest. Ein scheinbar erfolgreiches
manuelles Upgrade würde damit Chart `2.2.0`, aber weiterhin Anwendung v2.25.0 starten.

Für den Rollout daher Fleet-Source/Values aktualisieren oder mit Helm >= 3.14
`--reset-then-reuse-values` verwenden. Bei älteren Helm-Versionen sind
`--reset-values` plus alle bewusst erneut angegebenen Custom-Values erforderlich.
Der gerenderte Main-Digest muss vor Freigabe exakt `4e9dff...ada07` sein.

## Proxy-/Session-Sicherheitsbefund

Alle drei Instanzen besitzen inzwischen `proxy: true` und
`trustedproxies: "10.5.12.222"`. Die tatsächlich am Apache sichtbaren unmittelbaren
Ingress-Quellen sind jedoch dynamische `10.42.x`-Pod-IPs; `10.5.12.222` ist weder
eine dieser Pod-IPs noch eine Worker-Node-IP.

Anonyme Runtime-Prüfung auf Lissa-Test:

- öffentliche Startseite und Login liefern HTTPS 200;
- Canonical, `og:url` und Assets sehen korrekt aus, weil das persistierte `fqdn`
  die öffentliche HTTPS-Basis vorgibt;
- öffentliches HTTP wird am vorgeschalteten Edge auf HTTPS umgeleitet;
- Forwarded Host/Proto/Port/Prefix werden von der eigentlichen Proxylogik nicht
  akzeptiert; insbesondere wird `X-Forwarded-Prefix` ignoriert;
- der öffentliche HTTPS-Login setzt `typemill-session; HttpOnly; SameSite=Lax`,
  aber kein `Secure` und kein `__Secure-`-Präfix;
- HSTS war in der geprüften Antwort ebenfalls nicht vorhanden.

Damit ist der Trust-Mismatch funktional bewiesen. Die korrekten Canonical-URLs
sind kein ausreichender Proxytest. Vor dem Rollout muss ein stabiler unmittelbarer
Proxy-Trust-Pfad hergestellt werden. Danach muss Lissa-Test öffentlich
`__Secure-typemill-session; Secure; HttpOnly; SameSite=Lax` setzen. Dynamische
Ingress-Pod-IPs statisch einzutragen ist keine dauerhafte Lösung. Ein erzwungenes
`session.cookie_secure = 1` kann bei einer ausschließlich per HTTPS erreichbaren
Instanz das Cookie vorübergehend härten, ersetzt aber weder korrekte Proxy- noch
Subpath-Erkennung.

## PHP-/Plugin-Prüfung

Unter dem aktuell laufenden PHP 8.3 sind `166/166`, `166/166` und `165/165`
persistierte Plugin-PHP-Dateien syntaktisch gültig. v2.26.2 verwendet dieselbe
PHP-8.5.9-Basis wie v2.26.1; der v2.26.2-Diff verändert weder Plugins noch PHP.

Die eBooks-Vendorbäume aller drei Instanzen sind trotz der Plugin-Versionen 2.4.0
und 2.2.0 bytegleich; ihr deterministischer Gesamt-Hash ist
`7e18c2d7e6e2161302aec34b46b2b1bc7eae6d38253af3fcddf7bda0308ed078`.

Ein funktionaler, synthetischer EPUB-Export wurde mit genau diesem persistierten
Vendorbaum in einem isolierten Pod des v2.26.2-Images unter PHP 8.5.9 ausgeführt.
Der 54.627-Byte-Testinhalt wurde in sieben Kapiteldateien geteilt und als 12.207
Byte großes EPUB gespeichert. `unzip -t`, MIME-Typ und OPF-Titelprüfung waren
erfolgreich. Der kurzlebige Namespace hatte weder PVC noch Service oder Ingress
und wurde anschließend vollständig entfernt.

Der Export erzeugte 14 Deprecation-Meldungen an sieben eindeutigen Stellen; die
Anzahl der Wiederholungen hängt von der Zahl der gesplitteten Kapitel ab:

- `EPubChapterSplitter.php:103`
- `EPub.php:369`
- `EPub.php:440`
- `EPubChapterSplitter.php:200`
- `EPubChapterSplitter.php:206`
- `StringHelper.php:36`
- `BinStringStatic.php:114`

Die ersten drei Stellen verwenden die unter PHP 8.5 veraltete Semikolon-Syntax
nach `case`. Die beiden DOM-Stellen übergeben `null` als Encoding,
`StringHelper.php` verwendet das seit PHP 8.2 veraltete `utf8_encode()`, und der
ZIP-Finalizer reicht einmal `null` an `strlen()` weiter. Keine Meldung war fatal;
das erzeugte EPUB war strukturell und semantisch gültig. Da ausschließlich eine
lokale Plugin-Kopie und synthetische Daten verwendet wurden, fand kein
Produktionsschreibzugriff statt. Das ältere eBooks-Plugin sollte dennoch nach
dem Lissa-Test-Canary auf Uhlex separat über die echte Anwendung geprüft werden.

## Testmatrix

| Prüfung | Ergebnis |
|---|---|
| Helm `3.21.3` Strict-Lint | PASS |
| Helm `4.2.3` Strict-Lint | PASS |
| helm-unittest `1.1.1` | 13 Suites, 136/136 PASS unter beiden Helm-Versionen |
| Schema-Negativtests | 17/17 erwartete Ablehnungen |
| chart-testing `3.14.0` | PASS unter Helm 3 und 4; `.github/ct.yaml`, 600-s-Timeout und Version 2.1.0→2.2.0 bestätigt |
| OCI-Digestprüfung | 4/4 PASS gegen Docker Hub |
| Repräsentativer AI/Ollama-Render | PASS unter Helm 3 und 4 |
| Drei produktive Values-Render + Server-Dry-run | 3/3 PASS |
| Drei echte `--reuse-values`-Server-Dry-runs | erwartete Alt-Digest-Falle nachgewiesen |
| Helm-Paket `typemill-2.2.0.tgz` | PASS; Metadaten und Inhalt geprüft |
| `actionlint` 1.7.12 | PASS für alle Workflows |
| Workflow-YAML, JSON, `bash -n`, ShellCheck, `git diff --check` | PASS |
| Isolierter SUSE-AI-E2E | PASS, Setup-Punkt ausdrücklich SKIPPED |
| Isolierter eBooks-2.4.0/2.2.0-Vendor-Export unter PHP 8.5.9 | PASS; gültiges EPUB, 7 eindeutige Deprecation-Stellen |

`ct install --upgrade` wurde lokal mangels Docker/kind nicht ausgeführt und bleibt
ein GitHub-CI-Gate. Der manuelle SUSE-AI-E2E prüfte den wichtigeren echten
v2.25→v2.26.2-PVC-Pfad erfolgreich.

## Freigabereihenfolge

1. Auf dem konsolidierten PR `#25` die Pflichtchecks für Helm 3.21.3 und 4.2.3
   bestätigen; Main-Digest `4e9dff...ada07` und Chart `2.2.0` unverändert lassen.
2. NFS-/Applikationsbackup bzw. Storage-Snapshot und Wartungsfenster vorbereiten.
3. Stabilen Proxy-Trust-Pfad herstellen und den Secure-Cookie-Nachweis auf
   Lissa-Test erbringen.
4. `failOnModified=false`, Main-Digest und Existing-Claim im finalen Fleet-Render
   nochmals prüfen.
5. `typemilllissatest` ausrollen; Frontend, Admin, Proxy/Cookie, AI und bei Bedarf
   EPUB-Export testen.
6. Danach `typemilllissa` und zuletzt `typemilluhlex` ausrollen. Durch `Recreate`
   entsteht je Instanz eine kurze Unterbrechung.
