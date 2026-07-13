# Typemill Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/typemill-helm-chart)](https://artifacthub.io/packages/helm/typemill-helm-chart/typemill)

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
- Linux/amd64 nodes for the upstream Typemill v2.24.2 image
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
| `replicaCount` | Number of replicas; Typemill supports exactly one | `1` |
| `image.repository` | Container image repository | `kixote/typemill` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | Image tag (defaults to Chart appVersion) | `""` |
| `image.digest` | Immutable image digest; overrides tag when set | pinned; see `values.yaml` |
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
| `strategy.type` | Deployment strategy; only `Recreate` is supported | `Recreate` |

### Service

| Parameter | Description | Default |
|-----------|-------------|---------|
| `service.type` | Service type (`ClusterIP`, `NodePort`, or `LoadBalancer`) | `ClusterIP` |
| `service.port` | Service port | `80` |

### Ingress

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ingress.enabled` | Enable ingress | `false` |
| `ingress.className` | Ingress class name | `""` |
| `ingress.annotations` | Ingress annotations | `{}` |
| `ingress.hosts` | Ingress hosts configuration | see values.yaml |
| `ingress.tls` | Ingress TLS configuration | `[]` |

### AI Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `ai.enabled` | Enable initial Typemill AI configuration bootstrap | `false` |
| `ai.adapter` | AI adapter to configure (`openai`, `anthropic`, or `none`) | `openai` |
| `ai.baseUrl` | AI provider base URL; defaults to the adapter cloud endpoint when empty | `""` |
| `ai.model` | AI model name as expected by the provider; defaults to a provider-specific model when empty | `""` |
| `ai.providerName` | Provider name shown to Typemill users | `""` |
| `ai.providerTerms` | Provider terms URL shown to Typemill users; stays empty when unset | `""` |
| `ai.existingSecret` | Existing Secret containing the provider API key; optional for local providers | `""` |
| `ai.secretKeys.apiKey` | Secret key name for provider API key | `aiApiKey` |
| `ai.secretKeys.chatgptKey` | Deprecated legacy secret key name for OpenAI/ChatGPT API key | `chatgptKey` |
| `ai.secretKeys.claudeKey` | Deprecated legacy secret key name for Anthropic/Claude API key | `claudeKey` |
| `ai.service` | Deprecated legacy AI service value; use `ai.adapter` instead | `""` |
| `ai.chatgptModel` | Deprecated legacy ChatGPT/OpenAI model value; use `ai.model` instead | `gpt-4.1` |
| `ai.claudeModel` | Deprecated legacy Claude model value; use `ai.model` instead | `claude-sonnet-4-5` |
| `ai.temperature` | Typemill AI temperature setting | `"0.7"` |
| `ai.outputTokens` | Typemill maximum output tokens | `4000` |
| `ai.initContainer.image.repository` | yq image used for YAML bootstrap | `mikefarah/yq` |
| `ai.initContainer.image.tag` | yq image tag | `4.53.3` |
| `ai.initContainer.image.digest` | Optional yq image digest for immutable pinning; overrides tag when set | `""` |
| `ai.initContainer.securityContext` | Init container security context | `{"runAsGroup":0,"runAsUser":0}` |
| `ai.initContainer.resources` | Init container resource requests/limits | `{}` |

### Resources & Autoscaling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `resources` | CPU/Memory resource requests/limits | `{}` |
| `autoscaling.enabled` | Deprecated and unsupported; must remain disabled | `false` |
| `autoscaling.minReplicas` | Minimum replicas | `1` |
| `autoscaling.maxReplicas` | Maximum replicas | `10` |
| `autoscaling.targetCPUUtilizationPercentage` | Target CPU utilization | `80` |

### Scheduling

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nodeSelector` | Node selector constraints | `{}` |
| `tolerations` | Tolerations | `[]` |
| `affinity` | Affinity rules | `{}` |

#### Image digest pinning

The default Typemill image is pinned to the verified v2.24.2 manifest digest. When `image.digest` is set, it takes precedence over `image.tag`. To use a custom tag, clear the digest explicitly:

```yaml
image:
  repository: kixote/typemill
  tag: v2.24.2
  digest: ""
```

The AI bootstrap init-container supports the same pattern via `ai.initContainer.image.digest`.

## Persistence

| Parameter | Description | Default |
|-----------|-------------|---------|
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.storageClass` | Storage class | `""` |
| `persistence.accessMode` | Writable PVC access mode (`ReadWriteOnce` or `ReadWriteMany`) | `ReadWriteOnce` |
| `persistence.size` | PVC size | `5Gi` |
| `persistence.existingClaim` | Use existing PVC | `""` |
| `persistence.retain` | Retain a chart-managed PVC after Helm uninstall | `true` |
| `persistence.annotations` | Additional chart-managed PVC annotations | `{}` |

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

### Helm Test

| Parameter | Description | Default |
|-----------|-------------|---------|
| `tests.enabled` | Enable the hardened Helm connectivity test | `true` |
| `tests.image.repository` | Connectivity test image repository | `busybox` |
| `tests.image.tag` | Connectivity test image tag | `1.37.0` |
| `tests.image.digest` | Immutable connectivity test image digest | `sha256:9532d8...` |
| `tests.image.pullPolicy` | Connectivity test pull policy | `IfNotPresent` |
| `tests.resources` | Connectivity test resource requests and limits | see values.yaml |

Run the test after installation or upgrade:

```bash
helm test my-typemill --logs
```

### Typemill Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `typemill.timezone` | Container timezone | `"UTC"` |
| `typemill.phpIniConfig` | PHP INI overrides (map of filename → content) | see values.yaml |
| `typemill.htaccess` | Custom .htaccess content | `""` |

> **Note:** Plugin and theme installation is done via the Typemill admin UI at `/tm/plugins`
> and `/tm/themes`. Ensure the `plugins/` and `themes/` directories are persisted via the PVC.

### Persistent directories and lifecycle

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

Typemill uses mutable flat-file state and is supported only with one replica and the
`Recreate` deployment strategy. The chart rejects multiple replicas, autoscaling,
`RollingUpdate`, read-only persistence, and `ExternalName` Services.

Chart-managed PVCs are annotated with `helm.sh/resource-policy: keep` by default, so
`helm uninstall` does not delete site data. Set `persistence.retain=false` only when
automatic PVC deletion on uninstall is explicitly desired. Existing claims are never
created or deleted by this chart.

To use an existing PVC:

```yaml
persistence:
  enabled: true
  existingClaim: my-existing-pvc
```

## Typemill AI Bootstrap

Typemill stores AI configuration in persisted YAML files below `/var/www/html/settings`.
When `ai.enabled=true`, this chart runs an init container on every pod start before Typemill starts and updates:

- `settings/settings.yaml` with `ai_adapter`, `ai_base_url`, `ai_model`, optional provider display metadata, temperature, and output-token settings
- `settings/secrets.yaml` with `ai_api_key` from an existing Kubernetes Secret when `ai.existingSecret` is set

This requires `persistence.enabled=true`. API keys should not be stored directly in `values.yaml`; use `ai.existingSecret` when the provider requires a key. For local OpenAI-compatible providers such as Ollama or LM Studio, the Secret can be omitted.

> **Security note:** Typemill reads provider keys from `settings/secrets.yaml`, so the init container copies the selected API key from the Kubernetes Secret into the persisted PVC. Treat the PVC as secret-bearing storage and include it in your backup/encryption/access-control design.
> If `ai.existingSecret` is omitted or `ai.adapter=none`, the bootstrap removes `ai_api_key` and legacy `chatgptKey`/`claudeKey` entries from `settings/secrets.yaml`.

> **Supply-chain note:** Enabling AI bootstrap pulls an additional `mikefarah/yq` init-container image. You can override `ai.initContainer.image.*`; for high-security environments, pin the image by digest in your own values.

> **Security context note:** The bootstrap init-container defaults to `runAsUser: 0` and `runAsGroup: 0` because many dynamically provisioned PVC subPath directories are root-owned on first mount. Override `ai.initContainer.securityContext` only if your storage class or pod security policy guarantees write access for another user.

Because the bootstrap runs on every pod start, Helm values remain authoritative for these selected AI settings. Manual changes to the same fields in the Typemill UI may be overwritten on restart while `ai.enabled=true`.

Legacy `ai.service`, `ai.chatgptModel`, `ai.claudeModel`, `ai.secretKeys.chatgptKey`, and `ai.secretKeys.claudeKey` values from chart versions before Typemill 2.23 are still accepted for upgrade compatibility. Prefer the new `ai.adapter`, `ai.baseUrl`, `ai.model`, and `ai.secretKeys.apiKey` values for new deployments.

Example for OpenAI:

```bash
kubectl create secret generic typemill-ai-secret \
  --from-literal=aiApiKey='YOUR_OPENAI_API_KEY'

helm upgrade --install my-typemill typemill/typemill \
  --set ai.enabled=true \
  --set ai.adapter=openai \
  --set ai.baseUrl=https://api.openai.com/v1 \
  --set ai.model=gpt-4.1 \
  --set ai.existingSecret=typemill-ai-secret
```

Example for Claude:

```bash
kubectl create secret generic typemill-ai-secret \
  --from-literal=aiApiKey='YOUR_ANTHROPIC_API_KEY'

helm upgrade --install my-typemill typemill/typemill \
  --set ai.enabled=true \
  --set ai.adapter=anthropic \
  --set ai.baseUrl=https://api.anthropic.com/v1 \
  --set ai.model=claude-sonnet-4-5 \
  --set ai.providerName=Anthropic \
  --set ai.providerTerms=https://www.anthropic.com/legal/consumer-terms \
  --set ai.existingSecret=typemill-ai-secret
```

Example for Ollama without an API key:

```bash
helm upgrade --install my-typemill typemill/typemill \
  --set ai.enabled=true \
  --set ai.adapter=openai \
  --set ai.baseUrl=http://ollama.default.svc.cluster.local:11434/v1 \
  --set ai.model=llama3 \
  --set ai.providerName=Ollama \
  --set ai.providerTerms=
```

When Typemill and Ollama run in the same Kubernetes cluster, use Ollama's internal
Service DNS name. Ollama does not need a public Ingress for this integration.

Each Typemill user still has to agree to the selected AI provider in the Kixote AI interface before using the feature.

## Upgrading

Chart 2.0.0 is a major chart release because it makes previously unsafe or
unsupported configurations explicit: Typemill is restricted to one replica,
autoscaling is rejected, the deployment strategy is fixed to `Recreate`, and
the default application image is pinned by digest. Review custom values before
upgrading, especially `replicaCount`, `autoscaling`, `strategy`, `service.type`,
`persistence.accessMode`, and `image.*`.

When upgrading, the chart uses `strategy: Recreate` by default. This means:
1. The old pod is terminated
2. The new pod is started with the updated image

This ensures no two pods try to access the PVC simultaneously with `ReadWriteOnce` access mode.

```bash
helm repo update
helm upgrade my-typemill typemill/typemill
```

When overriding the application with a mutable tag, clear the default digest as well:

```bash
helm upgrade my-typemill typemill/typemill \
  --set image.tag=v2.24.2 \
  --set image.digest=
```

## Uninstalling

```bash
helm uninstall my-typemill
```

> **Note:** With the default `persistence.retain=true`, chart-managed PersistentVolumeClaims
> remain after uninstall. To remove all data intentionally:
>
> ```bash
> kubectl delete pvc my-typemill
> ```

## License

This Helm chart is licensed under the MIT License. See [LICENSE](LICENSE) for details.

Typemill itself is licensed under the [MIT License](https://github.com/typemill/typemill/blob/master/LICENSE).
