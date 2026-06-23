# geoking-ci

GitHub Actions partagées pour les apps Android GeoKing (KMP / Compose).

> **Intégrer dans une nouvelle app** → guide complet dans [geoking-tools/INTEGRATION.md](https://github.com/ludoo0d0a/geoking-tools/blob/main/INTEGRATION.md) (scripts + CI + secrets + Gradle).

## Bootstrap

```bash
# depuis la racine de l'app
../geoking-tools/templates/bootstrap-new-app.sh --package fr.geoking.myapp --name MyApp
```

Puis édite `artifact_name` et `package_name` dans `.github/workflows/`.

## Contenu

| Chemin | Rôle |
|---|---|
| `actions/setup-gradle/` | JDK 21 + Gradle (composite action) |
| `.github/workflows/android-ci.yml` | Workflow réutilisable — build debug + artefact APK |
| `.github/workflows/release-play.yml` | Workflow réutilisable — AAB signé + upload Play |

## Prérequis

1. Pousse ce dépôt sur GitHub (`ludoo0d0a/geoking-ci` ou autre).
2. Dans chaque app, des workflows fins appellent les workflows réutilisables.

## Workflows app (templates)

Copie depuis `geoking-tools/templates/` ou voir [INTEGRATION.md §6](https://github.com/ludoo0d0a/geoking-tools/blob/main/INTEGRATION.md#6-github-actions-geoking-ci).

### CI debug

```yaml
# .github/workflows/android-ci.yml
jobs:
  build:
    uses: ludoo0d0a/geoking-ci/.github/workflows/android-ci.yml@main
    with:
      artifact_name: myapp-debug-apk
    secrets: inherit
```

### Release Play

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
| `apk_glob` | `composeApp/build/outputs/apk/debug/*.apk` | Glob APK |
| `google_services_path` | `composeApp/google-services.json` | Destination decode Firebase |
| `geoking_ci_repo` | `ludoo0d0a/geoking-ci` | Repo actions |
| `gradle_version` | `8.13` | Version Gradle |
| `java_version` | `21` | Version JDK |

### `release-play.yml`

| Input | Défaut | Description |
|---|---|---|
| `package_name` | *(requis)* | `applicationId` Play |
| `gradle_module` | `:composeApp` | Module Gradle |
| `aab_glob` | `composeApp/build/outputs/bundle/release/composeApp-release.aab` | Glob AAB |
| `whatsnew_script` | `scripts/whatsnew.py` | Génération notes de version |
| `default_track` | `internal` | Piste Play par défaut |

## Secrets requis (par dépôt app)

`GOOGLE_SERVICES_JSON`, `WEB_CLIENT_ID`, `GEMINI_API_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`

Configurer via `./scripts/setup-release.sh` ([geoking-tools](https://github.com/ludoo0d0a/geoking-tools)).
