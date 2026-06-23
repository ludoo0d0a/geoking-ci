# geoking-ci

GitHub Actions partagées pour les apps Android GeoKing (KMP / Compose).

> **Intégrer dans une nouvelle app** → [geoking-tools/INTEGRATION.md](https://github.com/ludoo0d0a/geoking-tools/blob/main/INTEGRATION.md)

## Prérequis

Ce dépôt doit être **public** (ou accessible via GitHub Team+) pour que les apps
appellent les workflows réutilisables :

```yaml
jobs:
  build:
    uses: ludoo0d0a/geoking-ci/.github/workflows/android-ci.yml@main
    secrets: inherit
```

## Contenu

| Chemin | Rôle |
|---|---|
| `actions/setup-gradle/` | JDK 21 + Gradle (composite action) |
| `.github/workflows/android-ci.yml` | Workflow réutilisable — build debug + artefact APK |
| `.github/workflows/release-play.yml` | Workflow réutilisable — AAB signé + upload Play |
| `scripts/netlify-ignore.sh` | Ignore build Netlify si les chemins surveillés n'ont pas changé |

## Workflows app (templates)

Copie depuis `geoking-tools/templates/` :

```yaml
# .github/workflows/android-ci.yml
jobs:
  build:
    uses: ludoo0d0a/geoking-ci/.github/workflows/android-ci.yml@main
    with:
      artifact_name: myapp-debug-apk
    secrets: inherit
```

```yaml
# .github/workflows/release-play.yml
jobs:
  release:
    uses: ludoo0d0a/geoking-ci/.github/workflows/release-play.yml@main
    with:
      package_name: fr.geoking.myapp
      is_workflow_dispatch: ${{ github.event_name == 'workflow_dispatch' && 'true' || 'false' }}
      workflow_dispatch_track: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.track || '' }}
      workflow_dispatch_skip_review: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.changesNotSentForReview && 'true' || 'false' }}
      version_name_override: ${{ github.ref_type == 'tag' && github.ref_name || '' }}
    secrets: inherit
```

## Inputs des workflows réutilisables

### `android-ci.yml`

| Input | Défaut | Description |
|---|---|---|
| `artifact_name` | *(requis)* | Nom de l'artefact APK uploadé |
| `gradle_module` | `:composeApp` | Module Gradle |
| `java_version` | `21` | Version JDK |

### `release-play.yml`

| Input | Défaut | Description |
|---|---|---|
| `package_name` | *(requis)* | `applicationId` Play |
| `gradle_module` | `:composeApp` | Module Gradle |
| `java_version` | `21` | Version JDK |

## Netlify (landing page)

Copie `scripts/netlify-ignore.sh` dans l'app (via `geoking-tools` bootstrap) et référence-le dans `netlify.toml` :

```toml
[build]
  publish = "website"
  command = ""
  ignore = "bash scripts/netlify-ignore.sh"

# optionnel — chemins à surveiller (défaut : website/ netlify.toml)
[build.environment]
  NETLIFY_WATCH_PATHS = "website/ netlify.toml"
```

Le script compare `CACHED_COMMIT_REF` et `COMMIT_REF` (variables Netlify). Exit 0 → build ignoré ; exit 1 → déploiement.

## Secrets requis (par dépôt app)

`GOOGLE_SERVICES_JSON`, `WEB_CLIENT_ID`, `GEMINI_API_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`

Configurer via `./scripts/setup-release.sh` ([geoking-tools](https://github.com/ludoo0d0a/geoking-tools)).
