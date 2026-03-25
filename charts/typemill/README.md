# Typemill Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/typemill)](https://artifacthub.io/packages/search?repo=typemill)

A Helm chart for deploying [Typemill](https://typemill.net/) on Kubernetes — a lightweight
open-source flat-file CMS for creating websites and eBooks from Markdown.

## Introduction

Typemill is a flat-file CMS that stores content as Markdown files. It requires no database
and is ideal for documentation sites, knowledge bases, and eBook publishing. This chart
deploys Typemill using the official [`kixote/typemill`](https://hub.docker.com/r/kixote/typemill)
Docker image.

## Prerequisites

- Kubernetes >= 1.19
- Helm >= 3.8
- (Optional) An Ingress controller for external access
- (Optional) A StorageClass for persistent storage

## Installation

### Add the Helm repository

```bash
helm repo add typemill https://codeopsms.github.io/typemill-helm-chart/
helm repo update
```

### Minimal installation

```bash
helm install my-typemill typemill/typemill
```

### Installation with Ingress

```bash
helm install my-typemill typemill/typemill \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=docs.example.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix"
```

### Installation with Ingress and TLS

```bash
helm install my-typemill typemill/typemill \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=docs.example.com" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix" \
  --set "ingress.tls[0].secretName=typemill-tls" \
  --set "ingress.tls[0].hosts[0]=docs.example.com" \
  --set ingress.annotations."cert-manager\.io/cluster-issuer"=letsencrypt-prod
```

### Installation with custom values file

```bash
helm install my-typemill typemill/typemill -f my-values.yaml
```

## Configuration

The following table lists the configurable parameters of the Typemill chart and their default values.

### General

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image repository | `kixote/typemill` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag (defaults to Chart appVersion) | `""` |
| `imagePullSecrets` | Image pull secrets | `[]` |
| `nameOverride` | Override chart name | `""` |
| `fullnameOverride` | Override full release name | `""` |

### Service Account

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a ServiceAccount | `true` |
| `serviceAccount.annotations` | ServiceAccount annotations | `{}` |
| `serviceAccount.name` | ServiceAccount name | `""` |
| `serviceAccount.automountServiceAccountToken` | Auto-mount token | `false` |

### Pod Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `podAnnotations` | Pod annotations | `{}` |
| `podLabels` | Pod labels | `{}` |
| `podSecurityContext` | Pod security context | `{}` |
| `securityContext` | Container security context | `{}` |
| `terminationGracePeriodSeconds` | Termination grace period | `60` |
| `strategy.type` | Deployment strategy | `Recreate` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | see values.yaml |
| `ingress.tls` | Ingress TLS configuration | `[]` |

### Resources & Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `autoscaling.enabled` | Enable HPA | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization | `80` |

### Scheduling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector constraints | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

### Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.storageClass` | Storage class | `""` |
| `persistence.accessMode` | PVC access mode | `ReadWriteOnce` |
| `persistence.size` | PVC size | `5Gi` |
| `persistence.existingClaim` | Use existing PVC | `""` |

### Health Checks

| Parameter | Description | Default |
|-----------|-------------|---------|
| `livenessProbe.enabled` | Enable liveness probe | `true` |
| `livenessProbe.path` | Liveness probe path | `/tm/login` |
| `livenessProbe.initialDelaySeconds` | Initial delay | `15` |
| `livenessProbe.periodSeconds` | Check interval | `10` |
| `livenessProbe.timeoutSeconds` | Timeout per check | `5` |
| `livenessProbe.failureThreshold` | Failures before restart | `3` |
| `readinessProbe.enabled` | Enable readiness probe | `true` |
| `readinessProbe.path` | Readiness probe path | `/tm/login` |
| `readinessProbe.initialDelaySeconds` | Initial delay | `10` |
| `readinessProbe.periodSeconds` | Check interval | `5` |
| `readinessProbe.timeoutSeconds` | Timeout per check | `3` |
| `readinessProbe.failureThreshold` | Failures before marking unready | `3` |
| `startupProbe.enabled` | Enable startup probe | `true` |
| `startupProbe.path` | Startup probe path | `/tm/login` |
| `startupProbe.failureThreshold` | Failure threshold | `30` |
| `startupProbe.periodSeconds` | Check interval during startup | `5` |
| `startupProbe.timeoutSeconds` | Timeout per check | `3` |

### Typemill Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `typemill.timezone` | Container timezone | `"UTC"` |
| `typemill.phpIniConfig` | PHP INI overrides (map of filename → content) | see values.yaml |
| `typemill.htaccess` | Custom .htaccess content | `""` |

> **Note:** Plugin and theme installation is done via the Typemill admin UI at `/tm/plugins`
> and `/tm/themes`. Ensure the `plugins/` and `themes/` directories are persisted via the PVC.

## Persistence

Typemill stores all data as flat files. The chart creates a single PVC with subPath mounts
for the following directories:

| Directory | Purpose |
|-----------|---------|
| `settings/` | Site configuration and user data |
| `media/` | Uploaded media files |
| `data/` | Navigation and plugin data |
| `cache/` | Template and content cache |
| `plugins/` | Installed plugins |
| `content/` | Markdown content files |
| `themes/` | Installed themes |

When using `ReadWriteOnce` access mode (default), the deployment strategy must be `Recreate`
to avoid multiple pods trying to mount the same volume. This is the default configuration.

To use an existing PVC:

```yaml
persistence:
  enabled: true
  existingClaim: my-existing-pvc
```

## Upgrading

When upgrading, the chart uses `strategy: Recreate` by default. This means:
1. The old pod is terminated
2. The new pod is started with the updated image

This ensures no two pods try to access the PVC simultaneously with `ReadWriteOnce` access mode.

```bash
helm upgrade my-typemill typemill/typemill --set image.tag=v2.22.0
```

## Uninstalling

```bash
helm uninstall my-typemill
```

> **Note:** PersistentVolumeClaims are not deleted automatically. To remove all data:
>
> ```bash
> kubectl delete pvc my-typemill-typemill
> ```

## License

This Helm chart is licensed under the MIT License. See [LICENSE](LICENSE) for details.

Typemill itself is licensed under the [MIT License](https://github.com/typemill/typemill/blob/master/LICENSE).
