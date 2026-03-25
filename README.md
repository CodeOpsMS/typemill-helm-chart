# Typemill Helm Chart Repository

Helm chart repository for [Typemill](https://typemill.net/) — a lightweight open-source
flat-file CMS for creating websites and eBooks from Markdown.

## Usage

### Add the Helm repository

```bash
helm repo add typemill https://codeopsms.github.io/typemill-helm-chart/
helm repo update
```

### Install Typemill

```bash
helm install my-typemill typemill/typemill
```

### Install with custom values

```bash
helm install my-typemill typemill/typemill -f my-values.yaml
```

See [charts/typemill/README.md](charts/typemill/README.md) for full documentation and
all available configuration options.

## Development

### Linting

```bash
helm lint charts/typemill
helm lint charts/typemill --strict
helm lint charts/typemill -f charts/typemill/ci/test-values.yaml
```

### Unit Tests

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
helm unittest charts/typemill
```

### Template Rendering

```bash
helm template test-release charts/typemill
helm template test-release charts/typemill --set ingress.enabled=true
```

## Releasing a New Version

1. Update `charts/typemill/Chart.yaml`:
   - Bump `version` (chart version, SemVer)
   - Update `appVersion` if Typemill version changed
   - Update `artifacthub.io/changes` annotation
2. Commit and push to `main`
3. The GitHub Action automatically packages and releases the chart
4. ArtifactHub picks up the new version within minutes

## License

MIT — see [charts/typemill/LICENSE](charts/typemill/LICENSE)
