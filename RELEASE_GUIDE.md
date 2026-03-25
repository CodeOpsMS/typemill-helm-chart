# Release Guide — Typemill Helm Chart

## What you need to do manually

### 1. Create GitHub Repository

- Go to github.com → New Repository
- Name: `typemill-helm-chart`
- Set to **Public** (required for ArtifactHub)
- Copy all files from this project into the new repository

```bash
cd typemill-helm-chart
git init
git add .
git commit -m "feat: initial Typemill Helm chart v1.0.0"
git branch -M main
git remote add origin https://github.com/codeopsms/typemill-helm-chart.git
git push -u origin main
```

### 2. Enable GitHub Pages

- Repository → Settings → Pages
- Source: **Deploy from a branch**
- Branch: `gh-pages` (will be created automatically by the GitHub Action)

### 3. Trigger First Release

- Push all files to the `main` branch
- The GitHub Action runs automatically
- After ~2 minutes: Chart is available as a GitHub Release
- GitHub Pages serves `index.yaml` at `https://codeopsms.github.io/typemill-helm-chart/`

### 4. Register on ArtifactHub

- Go to [artifacthub.io](https://artifacthub.io) → Sign in (GitHub OAuth)
- Control Panel → **Add Repository**
- Type: Helm Charts
- Name: `typemill`
- URL: `https://codeopsms.github.io/typemill-helm-chart/`
- After a few minutes, the chart will be indexed and searchable

### 5. Fill in Placeholders

Search for the following placeholders and replace them:

| File | Placeholder | Replace with |
|------|-------------|--------------|
| `charts/typemill/Chart.yaml` | `maintainer` (name) | Your name |
| `charts/typemill/Chart.yaml` | `maintainer@example.com` | Your email |
| `charts/typemill/Chart.yaml` | `https://example.com` | Your URL |
| `charts/typemill/Chart.yaml` | `maintainer@example.com` | Your email |
| `artifacthub-repo.yml` | `REPLACE_WITH_ARTIFACTHUB_REPOSITORY_ID` | ArtifactHub repo ID |
| `artifacthub-repo.yml` | `maintainer@example.com` | Your email |

### 6. Publishing New Typemill Versions

1. Open `charts/typemill/Chart.yaml`
2. Bump `version:` (e.g., `1.0.0` → `1.0.1`)
3. Update `appVersion:` to the new Typemill version
4. Update `artifacthub.io/changes:` annotation
5. Update `artifacthub.io/images:` with new image tag
6. Commit + Push to main → Release runs automatically
