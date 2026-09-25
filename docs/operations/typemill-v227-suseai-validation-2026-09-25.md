# Typemill v2.27.0: Docker-/Chart-Prüfung und SUSE-AI-Test (2026-09-25)

## Ergebnis

Der vorhandene Branch `chore/update-typemill-v2.27.0` aus
[PR #30](https://github.com/CodeOpsMS/typemill-helm-chart/pull/30) wurde weiterverwendet.
Chart `2.3.0` unterstützt Typemill `v2.27.0` einschließlich der neuen AI-Optionen.
Die lokale Prüfung und der isolierte Cluster-Upgrade-Test von Chart `2.2.0` /
Typemill `2.26.2` sind erfolgreich. Produktive Releases wurden nicht aktualisiert.

## Upstream- und Docker-Befund

Grundlage sind die [Release-Notizen](https://github.com/typemill/typemill/releases/tag/v2.27.0),
der [Quellvergleich 2.26.2 → 2.27.0](https://github.com/typemill/typemill/compare/v2.26.2...v2.27.0),
das [Dockerfile](https://github.com/typemill/typemill/blob/v2.27.0/Dockerfile),
das [Startskript](https://github.com/typemill/typemill/blob/v2.27.0/docker-utils/init-server)
und die [Docker-Hub-Metadaten](https://hub.docker.com/v2/repositories/kixote/typemill/tags/v2.27.0).

| Bereich | Befund und Auswirkung auf das Chart |
|---|---|
| Docker-Laufzeit | Dockerfile und Startskript sind gegenüber 2.26.2 unverändert. Das tatsächlich gestartete Image verwendet PHP **8.5.10**, die Baseline **8.5.9**. Apache, Port 80 und Linux/amd64 bleiben bestehen. |
| Persistenz | Alle sieben Pfade bleiben gleich: `settings`, `media`, `cache`, `plugins`, `data`, `content`, `themes`. Keine zusätzliche PVC-Migration erforderlich. Die in den Release-Notizen erwähnte Setup-Verzeichniserstellung war bereits in 2.26.2 enthalten. |
| Reverse Proxy | Das Image setzt weiterhin `TYPEMILL_PROXY_DETECTION=true`. Das Chart behält sein explizites `false` bei; vorhandenes `proxy: true` in den gespeicherten Einstellungen bleibt wirksam. |
| AI | Neuer Adapter `openai-responses`; leere Temperatur bedeutet Weglassen des Parameters; zusätzliche Token-Optionen bis 128000. Schema, Deployment, Tests und Dokumentation wurden erweitert. Bestehende Standardwerte `openai`, `"0.7"` und 4000 bleiben erhalten. |
| Medien/API/SVG | Upstream korrigiert Dateipfad-/Berechtigungsprüfungen, Zugriffe auf Entwürfe und Metadaten, mehrsprachige Schreibzugriffe und SVG-Sanitizing. Artifact Hub ist deshalb wieder als Security-Update markiert. |
| Cyanine | Keine Theme-Änderung zwischen 2.26.2 und 2.27.0. Die historische Migration bleibt mit ihren geprüften Hashes und dem v2.26.0-Quellimage unverändert. |
| Weitere Funktionen | Verbesserte mehrsprachige Indizes/Startseiten, Kixote-Modellauswahl und Darstellung langer Texte; neue Soloprint-Veröffentlichung. Soloprint wird separat installiert, bestehende Themes/Plugins werden nicht ersetzt. |

Der zusätzliche [Dependabot-PR #31](https://github.com/CodeOpsMS/typemill-helm-chart/pull/31)
ändert ausschließlich den Tag der historischen Cyanine-Migrationsquelle von 2.26.0
auf 2.27.0, während deren Digest bei 2.26.0 bleibt. Er ist kein Anwendungsupdate
und wurde nicht übernommen. Tag, Digest und erwartete Dateihashes der Migration
müssen zusammenpassen.

## Verifizierte Image-Pins

| Container | Tag | OCI-Index-Digest |
|---|---|---|
| Anwendung | `kixote/typemill:v2.27.0` | `sha256:7dfb517d24f0c3b430f6f1bdf4b62e585aebd695dc6d18febc23e18674e945c4` |
| Cyanine-Migration | `kixote/typemill:v2.26.0` | `sha256:628f79a08cc75bc07777ae4b95312fb9770a531645789e698f12f96de6624156` |
| AI-Bootstrap | `mikefarah/yq:4.53.3` | `sha256:11a1f0b604b13dbbdc662260d8db6f644b22d8553122a25c1b5b2e8713ca6977` |
| Helm-Test | `busybox:1.38.0` | `sha256:fd7dc98638c8e305f4dc34e979f1c0fdfdcaeb0fbf8fcff77ae834b6da3d7e6e` |

BusyBox 1.38.0 wurde am 23. September erneut veröffentlicht; sein Testimage-Pin
wurde nach dem zunächst fehlgeschlagenen Digest-Abgleich aktualisiert.
Alle vier Pins stimmen mit Docker Hub überein. Der Typemill-amd64-Manifest-Digest
laut Registry ist `sha256:5cdd75c655447c0e7c3676e7999c0e7643d01a720a356d79748466a12ead586b`.
Containerd meldete im erfolgreichen Cluster-Test den zugehörigen OCI-Index als
`imageID`; die Prüfung akzeptiert beide verifizierten Darstellungen.

## Tests

- Helm **3.21.3** und **4.2.3**: jeweils striktes Linting und **140/140 Unit-Tests** erfolgreich.
- Die CI-Render- und Negativtests wurden unter beiden Versionen ausgeführt:
  Responses-Adapter, leere Temperaturen, `"0"`/`"0.0"`, Dezimalwerte als Strings und alle neuen
  Token-Optionen werden akzeptiert; ungültige Adapter, Wertebereiche und Datentypen
  werden abgewiesen. Bestehende Schema- und Skalierungsprüfungen bleiben grün.
- Alle vier Container-Pins geprüft, Chart erfolgreich paketiert; ShellCheck,
  Bash-Syntax, Workflow-YAML, JSON-Schema-Syntax und `git diff --check` erfolgreich.
- Die sechs gerenderten Ressourcen der Responses-Konfiguration bestehen den
  serverseitigen Kubernetes-Dry-run auf SUSE-AI (`v1.34.6+rke2r3`).
- Cluster-Test mit Helm **4.3.0**, eigenem Namespace und einem 1-GiB-PVC der
  StorageClass `longhorn`: Installation 2.26.2, Upgrade mit
  `--reset-then-reuse-values`, Neustart und `helm test` erfolgreich.

Im Cluster wurden die reale Anwendungs-/PHP-Version, der Image-Digest, beide
Init-Container, der Login-Endpunkt, PVC-/PV-Identität und Marker in allen sieben
persistenten Verzeichnissen geprüft. Alle fünf Cyanine-Dateien blieben nach
Upgrade und Neustart bytegleich. Die Migrationslogs melden bereits aktuelle Dateien.

Der AI-Bootstrap persistiert nach Upgrade und Neustart korrekt
`ai_adapter: openai-responses`, `aitemperature: ""` und `aioutputtoken: "128000"`.
Ohne Provider-Secret entstehen keine API-Key-Einträge. Die Medien-Regression
verwendet eine isolierte PDF-Fixture und aktivierte Frontend-Sessions:

| Testpfad | 2.26.2 | 2.27.0 |
|---|---|---|
| Direkter geschützter Download | 302 | 302 |
| Prozentkodierter Name | nicht als Baseline geprüft | 302 |
| Symlink auf dieselbe geschützte Datei | 200: Zugriff möglich | 404: Zugriff blockiert |

Erfolgreicher Lauf: `typemill-v227-e2e-20260925084241-851c37`, abgeschlossen
um 08:45 UTC mit Exitcode 0. Namespace und Test-PV
`pvc-6d8855b6-4b94-4ff2-9cd3-faced3e6d5ef` wurden entfernt; die abschließende
API-Abfrage bestätigte die Bereinigung. Auch die vorherigen Testläufe wurden bereinigt.

Reproduktion:

```bash
bash scripts/suse-ai-v2262-v227-e2e.sh
```

Das Skript verwendet standardmäßig `~/.kube/configs/suseai.yaml`, `helm` und
`longhorn`; über `KUBE_CONFIG`, `HELM_BIN` und `STORAGE_CLASS` können diese gewählt
werden. Es benötigt den Git-Tag `typemill-2.2.0`, erzeugt einen zufälligen Namespace
und prüft Namespace-/PVC-Identität vor der Bereinigung.

## Grenzen und Hinweise vor einem produktiven Upgrade

Der Cluster-Test prüft die AI-Konfiguration, führt aber keine Provider-Inferenz
aus. Dafür wird eine lokale, nicht angesprochene Test-URL verwendet. Cloud-Keys,
Ollama-Antwortqualität, Soloprint, produktive Plugins und öffentliche Ingress-/TLS-
Pfade wurden in diesem Lauf nicht funktional geprüft. Der frühere
[Ingress-/Secure-Cookie-Befund](typemill-v2262-suseai-validation-2026-08-25.md)
ist damit nicht als behoben bestätigt.

Vor einem produktiven Upgrade PVC sichern, bewusst gesetzte Image-Digests
aktualisieren und angepasste Cyanine-Dateien weiterhin manuell prüfen. Absichtlich
verwendete Medien-Symlinks sind von der neuen 404-Antwort betroffen. API-Clients
müssen die strengeren 403-/404-Antworten berücksichtigen. Aus dem Upload-Code
ergibt sich außerdem: Bereits gespeicherte SVGs werden nicht automatisch erneut
bereinigt; vorhandene nicht vertrauenswürdige Uploads benötigen gesonderte Prüfung.
