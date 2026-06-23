# geoking-ci

GitHub Actions partagées pour les apps Android GeoKing (KMP / Compose).

## Contenu

| Chemin | Rôle |
|---|---|
| `actions/setup-gradle/` | JDK 17 + Gradle (composite action) |
| `.github/workflows/android-ci.yml` | Workflow réutilisable — build debug + artefact APK |
| `.github/workflows/release-play.yml` | Workflow réutilisable — AAB signé + upload Play |

## Prérequis

1. Pousse ce dépôt sur GitHub (`ludoo0d0a/geoking-ci` ou autre).
2. Dans chaque app, des workflows fins appellent les workflows réutilisables.

## Exemple — CI debug (dans l'app)

```yaml
# .github/workflows/android-ci.yml
name: Android CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
jobs:
  build:
    uses: ludoo0d0a/geoking-ci/.github/workflows/android-ci.yml@main
    with:
      artifact_name: myapp-debug-apk
    secrets: inherit
```

## Exemple — release Play

```yaml
# .github/workflows/release-play.yml
name: Release to Play Store
on:
  push:
    branches: [main]
    tags: ['v*']
  workflow_dispatch:
    inputs:
      track:
        default: internal
        type: choice
        options: [internal, alpha, beta, production]
      changesNotSentForReview:
        default: false
        type: boolean
concurrency:
  group: play-release
  cancel-in-progress: false
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

## Secrets requis (par dépôt app)

`GOOGLE_SERVICES_JSON`, `WEB_CLIENT_ID`, `GEMINI_API_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`

Configurer via `./scripts/setup-release.sh` dans l'app (scripts fournis par [geoking-tools](../geoking-tools)).

## Scripts locaux

Les workflows réutilisables checkout ce dépôt à l'exécution. Pour le développement local des actions, clone `geoking-ci` à côté de tes apps — les workflows sur GitHub utilisent `actions/checkout` avec `repository: ludoo0d0a/geoking-ci`.
