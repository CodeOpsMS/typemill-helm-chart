# Typemill Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/typemill-helm-chart)](https://artifacthub.io/packages/helm/typemill-helm-chart/typemill)
[![Release](https://img.shields.io/github/v/release/CodeOpsMS/typemill-helm-chart?label=Chart%20Version)](https://github.com/CodeOpsMS/typemill-helm-chart/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](charts/typemill/LICENSE)

> **This Helm chart is a custom helm chart packaged by Lämmerzahl GmbH.**
> There is no official support from Typemill itself.
> New Typemill images are detected automatically and proposed in a pull request.
> Publishing starts only after the reviewed pull request is merged.

## About Typemill

The open-source flat-file CMS to create websites and eBooks from Markdown.
Use it for handbooks, documentations, manuals, web-novels, traditional websites, and more.

- **Official Documentation:** https://typemill.net/getting-started
- **Typemill GitHub:** https://github.com/typemill/typemill
- **Docker Image:** https://hub.docker.com/r/kixote/typemill

## Chart Info

| | |
|---|---|
| **Kubernetes** | >= 1.19.0 |
| **Helm** | >= 3.8.0 |
| **License** | MIT |
| **Source** | [GitHub](https://github.com/CodeOpsMS/typemill-helm-chart) |
| **OCI Registry** | `ghcr.io/codeopsms/helm-charts/typemill` |

The upstream `kixote/typemill` image for Typemill v2.26.2 currently supports Linux/amd64.

## Prerequisites

- Kubernetes cluster (>= 1.19)
- Helm installed and configured — [See here](https://helm.sh/docs/intro/install/)
- A StorageClass for persistent storage (e.g. Longhorn, local-path)

## Install

### Via Helm Repository (GitHub Pages)

```bash
helm repo add typemill https://codeopsms.github.io/typemill-helm-chart/
helm repo update
helm install typemill typemill/typemill --namespace typemill --create-namespace
```

### Via OCI Registry (GHCR)

```bash
helm install typemill oci://ghcr.io/codeopsms/helm-charts/typemill \
  --namespace typemill --create-namespace
```

### Install with custom values

```bash
helm install typemill typemill/typemill -f my-values.yaml --namespace typemill --create-namespace
```

See [charts/typemill/README.md](charts/typemill/README.md) for the full parameter reference.

## Upgrade notice for Typemill v2.26.x

Chart 2.2.0 is not a blanket Helm values/API breaking release, but upgrades from v2.25
require review of persisted security and proxy state:

- **XSS:** The new image contains the upstream fixes, but customized persisted Cyanine
  templates are never overwritten. Review preserved files against the upstream patch;
  otherwise the pod can start while the vulnerability remains.
- **Cyanine:** Verified old stock files are migrated automatically. Custom or missing files
  are preserved with warnings. Keep `securityMigrations.cyanineV226.failOnModified=false`
  until all custom files are reviewed; `true` intentionally blocks startup and leaves a
  `Recreate` deployment offline when any affected file has an unknown hash.
- **Proxy:** The chart neutralizes the new image-level proxy-detection default, but a
  persisted `proxy: true` remains active. Configure the exact immediate proxy IPs in
  `trustedproxies` and verify a `__Secure-typemill-session; Secure` login cookie before
  production rollout.
- **PHP compatibility:** The actual runtime compatibility break is the move to PHP 8.5
  and removal of PHP 8.1 support. Validate every persisted third-party plugin under PHP
  8.5 before rollout.
- **Helm command:** Do not use plain `--reuse-values`; it can retain the v2.25 image
  digest. Use `--reset-then-reuse-values` where supported and verify the rendered image.

See the [v2.26.x upgrade classification](charts/typemill/README.md#typemill-v226x-upgrade-classification)
for failure modes and the complete upgrade procedure.

## Quick Start Values

```yaml
persistence:
  enabled: true
  storageClass: "longhorn"
  size: 5Gi
  retain: true

typemill:
  timezone: "Europe/Berlin"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: typemill.example.com
      paths:
        - path: /
          pathType: Prefix
```

## First-Time Setup

1. Keep the Ingress disabled and reach the setup wizard through an authenticated
   administration path such as `kubectl port-forward`, or configure HTTPS, proxy
   detection, and the exact trusted proxy source IPs before exposing the site.
2. Access `/tm/setup` and create the admin user. Do not submit setup credentials over
   an unencrypted public HTTP endpoint.
3. When using a reverse proxy, set `typemill.proxyDetection=true`, configure its exact
   source IPs under **Settings → System → Trusted IPs for proxies**, and verify HTTPS
   links and redirects before opening the site to users. The login response should set a
   `__Secure-typemill-session` cookie with the `Secure` attribute; a plain
   `typemill-session` cookie means HTTPS proxy detection is not effective.

## Migrating from an Existing Installation

Create a backup of your existing **settings**, **content**, **media**, **plugins**, **themes**, and **data** directories.
Copy them into the PVC of the new Typemill deployment.
If deploying behind a proxy with TLS, configure `trustedproxies` in
`settings/settings.yaml` or through the admin UI. For a subpath deployment the proxy
must also send `X-Forwarded-Prefix`. The chart defaults `typemill.proxyDetection=false`
to neutralize the image's trust-all default; a persisted `proxy: true` remains active.

## Automation

This repository automates discovery, validation, and publishing while retaining a review gate:

| What | How | Interval |
|------|-----|----------|
| New Typemill Docker image | Auto-update workflow opens a version-and-digest PR | Every 6 hours |
| GitHub Actions updates | Dependabot PRs; allowlisted minor/patch updates auto-merge after required checks | Weekly |
| Docker dependency updates | Dependabot PRs with manual digest and chart-version review | Daily |
| GitHub Pages Helm repository | Healthcheck verifies `gh-pages` and `index.yaml` | Daily |

Chart releases are published from `main` after the update PR has passed the required Helm 3 and Helm 4 checks and has been merged.
The repository setting that allows GitHub Actions to create pull requests must remain enabled.

### GitHub Pages Helm Repository

The classic Helm repository is published from the `gh-pages` branch. Do not delete this branch: Artifact Hub indexes `https://codeopsms.github.io/typemill-helm-chart/index.yaml` from there.

If the branch or the published index is missing, restore `gh-pages` from the last known good commit and run the `Release Helm Charts` workflow manually. Repository admins may also need to re-enable GitHub Pages with source `Deploy from a branch`, branch `gh-pages`, folder `/`.

## Development

### Linting

```bash
helm lint charts/typemill --strict
```

### Unit Tests

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm unittest charts/typemill
```

CI validates the chart with pinned Helm 3 and Helm 4 versions.

### Template Rendering

```bash
helm template test-release charts/typemill
```

## Feature Request or Bug Found?

Please open a GitHub issue: [typemill-helm-chart](https://github.com/CodeOpsMS/typemill-helm-chart/issues)

## Maintainer

**Manfred Lämmerzahl** — [Lämmerzahl GmbH](https://www.laemmerzahl.de)

## License

MIT — see [charts/typemill/LICENSE](charts/typemill/LICENSE)
