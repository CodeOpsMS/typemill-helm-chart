# Typemill Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/typemill-helm-chart)](https://artifacthub.io/packages/helm/typemill-helm-chart/typemill)
[![Release](https://img.shields.io/github/v/release/CodeOpsMS/typemill-helm-chart?label=Chart%20Version)](https://github.com/CodeOpsMS/typemill-helm-chart/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](charts/typemill/LICENSE)

> **This Helm chart is a custom helm chart packaged by Lämmerzahl GmbH.**
> There is no official support from Typemill itself.
> Fully automated — when a new Typemill Docker image is released, a new chart version is published automatically.

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

## Quick Start Values

```yaml
persistence:
  enabled: true
  storageClass: "longhorn"
  size: 5Gi

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

1. Deploy Typemill (without TLS for first setup)
2. Access your Typemill URL — the setup wizard will guide you through creating an admin user
3. If using a reverse proxy with TLS: Navigate to **Settings → System → Proxy** and enable "Use X-Forwarded Headers"
4. Upgrade your deployment with TLS enabled

## Migrating from an Existing Installation

Create a backup of your existing **settings**, **content**, **media**, **plugins**, **themes**, and **data** directories.
Copy them into the PVC of the new Typemill deployment.
If deploying behind a proxy with TLS, edit `settings/settings.yaml` and change `proxy: false` to `proxy: true`.

## Automation

This repository is fully automated:

| What | How | Interval |
|------|-----|----------|
| New Typemill Docker image | Auto-update workflow bumps chart version and releases | Every 6 hours |
| GitHub Actions updates | Dependabot PRs with auto-merge | Weekly |

No manual intervention is required for routine updates.

## Development

### Linting

```bash
helm lint charts/typemill --strict
```

### Unit Tests (100 tests, 10 suites)

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm unittest charts/typemill
```

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
