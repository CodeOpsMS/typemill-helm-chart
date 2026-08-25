# Cyanine-XSS-Korrektur im SUSE-AI-Cluster (2026-08-24)

## Ergebnis

Die Custom-Themes der drei Typemill-v2.25.0-Instanzen wurden gegen den
[Upstream-Fix 1cd1459](https://github.com/typemill/typemill/commit/1cd145923f882b5f4ed1b6c3600240416a3e579c)
abgeglichen und manuell korrigiert. Vorhandene Struktur, Theme-Versionen,
Dateieigentümer und Modi blieben erhalten.

| Namespace | Release | Theme-Dateien | Ergebnis |
|---|---|---:|---|
| `typemilllissa` | `typemill` | 31 | PASS |
| `typemilllissatest` | `typemilltest` | 31 | PASS |
| `typemilluhlex` | `typemilluhlex` | 29 | PASS |

UHLEX besitzt absichtlich keine `landingpage.twig`; die Datei wurde weder erzeugt
noch aus einem Stock-Theme übernommen.

## Backup und Prüfdokumentation

Auf jedem PVC liegt das vollständige Rollback-Archiv unter:

```text
/var/www/html/themes/.security-backups/20260824T082535Z/
```

Das Verzeichnis enthält `cyanine.before.tar.gz`, das vollständige
`cyanine.sha256.before`-/`cyanine.sha256.after`-Manifest,
`changed-files.sha256.diff`, `verification.txt`, `metadata.txt` und
`documentation.sha256`. Archiv und Dokumentationsmanifest wurden mit
`sha256sum -c` verifiziert.

| Namespace | SHA-256 `cyanine.before.tar.gz` | SHA-256 `documentation.sha256` |
|---|---|---|
| `typemilllissa` | `837b0316db3de40cc9bd251848d22f42936606ef082155bf67180d905307874d` | `999ef19e15a6ce728d31eb5dd868f65f64c4f23792670bf930c07bdb4a815818` |
| `typemilllissatest` | `bd17bf17c12990835213e68f40c8ad006d126afbca0bf23c46477763695d4832` | `f4a0188e2baed866c1913025427af2f2ad5cc4e86bc27d1f030d07de2d558240` |
| `typemilluhlex` | `1d88ffdd69afaa951c58e24d3d93f270098cc757a05a974135914ea71cf25387` | `42f22e19bec7b19a0fc2760f75555101a17eb68f6f40e88aee5260a379e5aeb4` |

## Geänderte Dateihashes

LISSA und LISSA-Test:

| Datei | Vorher | Nachher |
|---|---|---|
| `blog.twig` | `424a12da9762c823389091384ed2912d72772093cf84b42a3157d1db269fb96a` | `71a885d3aaeb3dce70f1d5fb35510a6c3c29780e939d39daea98118dfefa26fa` |
| `home/landingpageNews.twig` | `551e6151436ddedf2415ee43118d8d3a31993634c41c9eb2942a440dbdf2b557` | `2b3a49c379bade6f367040ff6ebd270a907f5af7753d0a2a3006af46e4694c36` |
| `landingpage.twig` | `b49df2d3b6be481aa282c799b51c9a25ecb6ffd52a836fa0d091bd8113ba2bba` | `6eb5fdd81f0db06aefaf07aededa3d3d9fe1666b079a123ba43529012b7e3842` |
| `partials/posts.twig` | `905fe56739da86d434ed685069d559e89b2ab149bcbd5c2648440614ce1616b3` | `08e95d30374fd17a37e2cb477fb27facd6dc411de0dca61d1f6760e5fc899612` |

UHLEX:

| Datei | Vorher | Nachher |
|---|---|---|
| `blog.twig` | `424a12da9762c823389091384ed2912d72772093cf84b42a3157d1db269fb96a` | `71a885d3aaeb3dce70f1d5fb35510a6c3c29780e939d39daea98118dfefa26fa` |
| `home/landingpageNews.twig` | `aac90b3879b8bb5f193906612d310d725fc5e5d70eba862025a0068b3493902a` | `47d66888035243a6b0c9eee60a03d1e3e033a6db41ba6d97e438a5c804f681df` |
| `partials/posts.twig` | `c1598af477e6606206a7815c2081501ef995de4e21378627f2aedddf26a8f64b` | `dfe744c6d0490f3d6c001764789485c67ad4ce50df1410be4929ae59da281fe1` |

Alle nicht aufgeführten Theme-Dateien sind im Vorher-/Nachher-Manifest
bytegleich. `cyanine.yaml` wurde bewusst nicht auf Version `2.4.2` umdeklariert,
weil die individuellen Themes kein vollständiges Upstream-Theme-Upgrade erhalten
haben und die YAML-Änderung selbst keinen ausführbaren XSS-Fix enthält.

## Prüfungen

- Twig-Textpayload: `<b>TEST</b>` wurde als
  `&lt;b&gt;TEST&lt;/b&gt;` ausgegeben.
- Twig-Attributpayload: `" onerror="TEST` wurde als
  `&quot;&#x20;onerror&#x3D;&quot;TEST` ausgegeben; die Anführungszeichen können
  den Attributkontext nicht verlassen.
- Alle erwarteten `|e`- und `|e('html_attr')`-Sinks wurden in den tatsächlich
  installierten Custom-Dateien statisch gezählt; alte unsichere Fragmente sind
  nicht mehr vorhanden.
- Die vollständigen Nachher-Manifeste wurden mit `sha256sum -c` geprüft.
- Eigentümer/Gruppe und Modus blieben erhalten: LISSA `1001:988`, die beiden
  anderen Instanzen `1000:988`, jeweils `0660` für die geänderten Dateien.
- Alle drei Deployments sind vollständig ausgerollt und ihre Kubernetes-Services
  haben je einen bereiten Endpoint.
- Direkte Anwendungstests mit den korrekten Forwarded-Headern lieferten dreimal
  HTTP 200: LISSA 724737 Byte, LISSA-Test 707251 Byte und UHLEX 68883 Byte.
- Die HTTPS-Ingress-Tests für LISSA und LISSA-Test lieferten HTTP 200. Der
  UHLEX-Hostname liefert extern die nginx-Willkommensseite statt Typemill; der
  Typemill-Service selbst liefert HTTP 200. Das ist ein separates, bereits
  bestehendes Ingress-/Upstream-Routingproblem.
- Der Twig-Cache war in allen drei Instanzen leer; Typemill v2.25 setzt Debug und
  damit Auto-Reload, daher war kein Cache-Löschen oder Pod-Neustart notwendig.

## Einmalmigration

Die laufenden Releases verwenden Chart `typemill-2.1.0`; dort ist keine
Cyanine-Security-Migration gerendert und `securityMigrations` ist in allen drei
Release-Werten nicht gesetzt. Der vorbereitete Folgerelease im Repository behält
`securityMigrations.cyanineV226.failOnModified: false`. Das ist erforderlich,
solange die sicher geprüften Custom-Dateien erwartungsgemäß von Stock-Hashes
abweichen. Nach dem ersten Upgrade kann die Cyanine-v2.26-Einmalmigration
alternativ deaktiviert werden.
