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
- Linux/amd64 nodes for the upstream Typemill v2.26.2 image
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
| `ai.timeoutSeconds` | AI provider request timeout in seconds | `120` |
| `ai.reasoningEffort` | Reasoning effort for compatible OpenAI-style models (`""`, `none`, `low`, `medium`, `high`) | `""` |
| `ai.initContainer.image.repository` | yq image used for YAML bootstrap | `mikefarah/yq` |
| `ai.initContainer.image.tag` | yq image tag | `4.53.3` |
| `ai.initContainer.image.digest` | Immutable yq image digest; overrides tag when set | pinned; see `values.yaml` |
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

### Security migrations

| Parameter | Description | Default |
|-----------|-------------|---------|
| `securityMigrations.cyanineV226.enabled` | Update unchanged persisted Cyanine v2.24.2/v2.25 files to the v2.26 security-fixed versions | `true` |
| `securityMigrations.cyanineV226.failOnModified` | Fail startup whenever affected files do not match verified stock hashes | `false` |
| `securityMigrations.cyanineV226.image.repository` | Dedicated v2.26 migration-source image repository | `kixote/typemill` |
| `securityMigrations.cyanineV226.image.tag` | Dedicated migration-source image tag | `v2.26.0` |
| `securityMigrations.cyanineV226.image.digest` | Immutable migration-source digest; overrides its tag | pinned; see `values.yaml` |
| `securityMigrations.cyanineV226.image.pullPolicy` | Migration-source image pull policy | `IfNotPresent` |
| `securityMigrations.cyanineV226.securityContext` | Cyanine migration init-container security context | hardened; see `values.yaml` |
| `securityMigrations.cyanineV226.resources` | Cyanine migration init-container resource requests/limits | `{}` |

#### Image digest pinning

The default Typemill image is pinned to the verified v2.26.2 manifest digest. When `image.digest` is set, it takes precedence over `image.tag`. To use a custom tag, clear the digest explicitly:

```yaml
image:
  repository: kixote/typemill
  tag: v2.26.2
  digest: ""
```

The dedicated Cyanine migration source, AI bootstrap, and Helm connectivity test use the
same pattern via `securityMigrations.cyanineV226.image.digest`,
`ai.initContainer.image.digest`, and `tests.image.digest`. Every default container image
is pinned to a verified OCI index digest.

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
| `tests.image.tag` | Connectivity test image tag | `1.38.0` |
| `tests.image.digest` | Immutable connectivity test image digest | `sha256:dc2d74...` |
| `tests.image.pullPolicy` | Connectivity test pull policy | `IfNotPresent` |
| `tests.resources` | Connectivity test resource requests and limits | see values.yaml |

Run the test after installation or upgrade:

```bash
helm test my-typemill --logs
```

The completed test pod is retained so Helm can collect its logs. It is deleted
automatically before the next test run; delete it manually if no further test is planned.

### Typemill Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `typemill.timezone` | Container timezone | `"UTC"` |
| `typemill.proxyDetection` | Force upstream Docker reverse-proxy detection; false stops the image-level force but does not override persisted settings | `false` |
| `typemill.phpIniConfig` | PHP INI overrides (map of filename → content) | see values.yaml |
| `typemill.htaccess` | Custom .htaccess content | `""` |

> **Note:** Plugin and theme installation is done via the Typemill admin UI at `/tm/plugins`
> and `/tm/themes`. Ensure the `plugins/` and `themes/` directories are persisted via the PVC.

Typemill v2.26.1 enables reverse-proxy detection in its Docker image, but this chart
explicitly overrides that new default with `typemill.proxyDetection=false` so upgrades do
not unexpectedly begin trusting forwarded headers. A `proxy: true` value already persisted
in `settings/settings.yaml` remains active for backwards compatibility.

For an Ingress or another reverse proxy, set `typemill.proxyDetection=true` or enable proxy
mode in the admin UI, then configure the exact proxy source IPs under
**Settings → System → Trusted IPs for proxies**. Leaving the list empty trusts forwarded
headers from every source that can reach the pod. When Typemill is published below a
subpath, the proxy must also send `X-Forwarded-Prefix` with that path.

Typemill v2.26.1 accepts only exact IP literals in `trustedproxies`, separated by commas
without spaces; CIDRs, DNS names, and Kubernetes Service names are not supported. If the
Ingress source IPs are dynamic, provide a stable proxy source address or leave the list
empty only together with a NetworkPolicy that limits pod access to the Ingress controller
and a controller configuration that overwrites client-supplied forwarded headers.

Do not use correct-looking canonical URLs alone as proof that proxy detection works: a
persisted `fqdn` can make generated URLs appear correct while the request scheme is still
treated as HTTP. Verify the public login response sets
`__Secure-typemill-session; Secure; HttpOnly; SameSite=Lax`. A plain
`typemill-session` cookie without `Secure` means the immediate proxy source is not trusted;
session protection and `X-Forwarded-Prefix` handling are then ineffective. For an
HTTPS-only site, `session.cookie_secure = 1` in `typemill.phpIniConfig` can provide a
temporary cookie safeguard, but it does not repair host, port, or prefix detection and
must not be used for installations that still require direct HTTP access.

### Persistent directories and lifecycle

Typemill stores all data as flat files. The chart creates a single PVC with subPath mounts
for the following directories:

| Directory | Purpose |
|-----------|---------|
| `settings/` | Site configuration and user data |
| `media/` | Uploaded media files |
| `data/` | Navigation and plugin data |
| `cache/` | Template/content cache and generated export assets under `cache/generated/` |
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

### Typemill v2.26 Cyanine security migration

Typemill only initializes bundled themes when their persisted directories are empty.
Chart 2.2.0 therefore runs a hash-guarded init container during upgrades with persistence.
The verified old hashes cover the stock Cyanine files shipped with both Typemill v2.24.2
and v2.25.0, so direct upgrades from chart 2.0.0 are covered as well:

- five unchanged Cyanine v2.24.2/v2.25 stock files are replaced with the verified v2.26 versions;
- files already matching v2.26 are left unchanged, making the migration idempotent;
- missing or customized files are never overwritten;
- customized affected files produce a warning and require manual review against the
  [upstream v2.26 Cyanine security patch](https://github.com/typemill/typemill/commit/1cd145923f882b5f4ed1b6c3600240416a3e579c).

The migration source remains independently pinned to the v2.26.0 image even after later
application-image upgrades. Replacement files are hash-verified, written to a random
temporary file on the same PVC, and atomically moved into place. Symlinks and unsafe
directory paths are treated as custom content and preserved.

Atomically replaced stock files are created with mode `0644` and the UID/GID of the
migration container (`33:33` by default); inode-specific ACLs and extended attributes are
not retained. Review or override the migration security context when external storage
workflows depend on different file ownership.

Set `securityMigrations.cyanineV226.failOnModified=true` to block startup whenever an
affected file has a hash the chart cannot attest. A byte-identical v2.26 file unblocks
automatically; an equivalently patched custom file still has a custom hash. After manually
reviewing such a file, either turn strict mode off or disable this migration explicitly.
Strict mode completes a read-only preflight of all five paths before replacing any file.
Inspect the result after upgrading:

```bash
kubectl logs deployment/my-typemill -c cyanine-v226-security-migration
```

Disable the migration only after applying and verifying equivalent theme fixes manually.
With `persistence.enabled=false`, the init container is not needed and is not rendered
because the v2.26 image supplies the current theme directly.

## Typemill AI Bootstrap

Typemill stores AI configuration in persisted YAML files below `/var/www/html/settings`.
When `ai.enabled=true`, this chart runs an init container on every pod start before Typemill starts and updates:

- `settings/settings.yaml` with `ai_adapter`, `ai_base_url`, `ai_model`, optional provider display metadata, temperature, output-token, request-timeout, and reasoning-effort settings
- `settings/secrets.yaml` with `ai_api_key` from an existing Kubernetes Secret when `ai.existingSecret` is set

This requires `persistence.enabled=true`. API keys should not be stored directly in `values.yaml`; use `ai.existingSecret` when the provider requires a key. For local OpenAI-compatible providers such as Ollama or LM Studio, the Secret can be omitted.

> **Security note:** Typemill reads provider keys from `settings/secrets.yaml`, so the init container copies the selected API key from the Kubernetes Secret into the persisted PVC. Treat the PVC as secret-bearing storage and include it in your backup/encryption/access-control design.
> If `ai.existingSecret` is omitted or `ai.adapter=none`, the bootstrap removes `ai_api_key` and legacy `chatgptKey`/`claudeKey` entries from `settings/secrets.yaml`.

> **GitSync note:** The separately installed GitSync plugin stores its Git provider PAT in
> `settings/secrets.yaml` on the PVC and requires outbound HTTPS to the configured GitHub or
> GitLab API. Include that credential in the same backup, encryption, and access-control design.

> **Supply-chain note:** Enabling AI bootstrap pulls an additional `mikefarah/yq` init-container image. Its default is pinned by digest. When overriding `ai.initContainer.image.tag`, clear or replace `ai.initContainer.image.digest` explicitly.

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
  --set ai.timeoutSeconds=180 \
  --set ai.providerTerms=
```

Set `ai.reasoningEffort` only when the selected provider and model explicitly
support that OpenAI-compatible parameter. Leave it empty for general-purpose
Ollama models.

When Typemill and Ollama run in the same Kubernetes cluster, use Ollama's internal
Service DNS name. Ollama does not need a public Ingress for this integration.

Each Typemill user still has to agree to the selected AI provider in the Kixote AI interface before using the feature.

## Upgrading

### Typemill v2.26.x upgrade classification

This release requires operator review, but the XSS fix, Cyanine migration, and proxy
change are not the same kind of breaking change:

| Area | Classification | What happens during the upgrade | Required action / failure mode |
|------|----------------|---------------------------------|--------------------------------|
| XSS fixes | Security update, not a Helm values/API break | The v2.26 application image contains the fixes. On a persisted Cyanine theme, the chart can update only files whose hashes match verified v2.24.2/v2.25 stock files. Customized or missing files are preserved. | Compare every preserved affected template with the [upstream XSS patch](https://github.com/typemill/typemill/commit/1cd145923f882b5f4ed1b6c3600240416a3e579c). With `failOnModified=false` the pod starts, but an unpatched custom file can leave the vulnerability present. |
| Cyanine migration | Persistent-state migration; conditionally startup-blocking | Before Typemill starts, the init container atomically replaces attested old stock files, leaves current files unchanged, and warns about custom state. Replaced files use mode `0644` and the migration UID/GID. | Back up the PVC and inspect the migration log. Keep `failOnModified=false` while reviewed custom files have non-stock hashes. Setting it to `true` deliberately blocks startup before any replacement if one affected path is not attested; with `Recreate`, the site then remains offline. |
| Proxy configuration | Runtime/configuration compatibility change | The upstream v2.26.1+ image enables proxy detection by default. Chart 2.2.0 neutralizes only that image default with `typemill.proxyDetection=false`; a persisted `proxy: true` setting still wins. Typemill accepts only exact IP literals in `trustedproxies`. | Configure the stable, immediate proxy source IPs and verify the public login cookie is `__Secure-typemill-session; Secure`. A wrong trust path can cause insecure cookies or broken subpath handling; an empty trust list permits forwarded-header spoofing from any source that can reach the pod unless NetworkPolicy provides equivalent isolation. |
| PHP runtime | Breaking plugin/runtime compatibility change | The upstream container moves from PHP 8.3 to PHP 8.5 and no longer supports PHP 8.1. Persisted plugins are not upgraded by the chart. | Syntax-check and functionally test every third-party plugin under PHP 8.5 before production rollout. Deprecation warnings do not necessarily stop startup, but removed or stricter PHP behavior can break a plugin at runtime. |
| Helm value reuse | Upgrade-command hazard, not an application break | Plain `--reuse-values` can retain the v2.25 image digest even though Helm records Chart 2.2.0. | Prefer `--reset-then-reuse-values` with Helm 3.14+, or `--reset-values` plus all intentional overrides, and verify the rendered v2.26.2 digest before rollout. |

In other words, this is not a blanket configuration-format break. It is an
**upgrade-action-required** release because persisted theme and proxy state can prevent
the security fixes from becoming effective even when the new pod itself starts normally.

Before every upgrade, back up the Typemill PVC or create a storage snapshot. Chart 2.2.0
updates Typemill to v2.26.2, including the v2.26.0 media-download authorization and XSS
fixes, the v2.26.1 date-sorting, reverse-proxy, SMTP-username, and PHP 8.5 fixes, and the
v2.26.2 creation of missing directories plus its corrected PHP 8.2 minimum check during
first-time setup.
The upstream container now runs PHP 8.5 and no longer supports PHP 8.1. The chart-managed
persistent paths do not change. Update custom Typemill images to PHP 8.2 or newer before
using them with this release, and verify all persisted third-party plugins for PHP 8.5
compatibility. Also verify routes generated from unconventional Markdown filenames without
numeric prefixes because upstream corrected their filename parsing. See the
[Typemill v2.26.0 release notes](https://github.com/typemill/typemill/releases/tag/v2.26.0)
and [Typemill v2.26.1 release notes](https://github.com/typemill/typemill/releases/tag/v2.26.1),
plus the [Typemill v2.26.2 release notes](https://github.com/typemill/typemill/releases/tag/v2.26.2),
for the complete application-level changes.

Typemill v2.26.2 creates missing setup directories recursively with mode `0755`. Its upstream
setup check can, however, treat an existing but non-writable directory as successfully
created. The chart requires the mounted PVC paths to be writable by the application; verify
storage ownership and permissions explicitly when reusing a partially initialized or
manually populated claim.

Helm's `--reuse-values` mode can retain defaults from the previously installed chart,
including an old image digest. With Helm 3.14 or newer, prefer
`--reset-then-reuse-values` so that new chart defaults are loaded before explicitly
supplied release values are reapplied:

```bash
helm repo update
helm upgrade my-typemill typemill/typemill \
  --version 2.2.0 \
  --reset-then-reuse-values
```

With Helm 3.8 through 3.13, use `--reset-values` and explicitly reapply every custom
values file and command-line override instead:

```bash
helm repo update
helm upgrade my-typemill typemill/typemill \
  --version 2.2.0 \
  --reset-values \
  --values my-values.yaml
```

Review `helm get values my-typemill` first. If `image.digest` was explicitly configured,
replace it with the v2.26.2 digest or intentionally keep the custom pin.

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

When overriding the application with a mutable tag, clear the default digest as well:

```bash
helm upgrade my-typemill typemill/typemill \
  --set image.tag=v2.26.2 \
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
