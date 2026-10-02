# geoking-ci

GitHub Actions partagées pour les apps Android GeoKing (KMP / Compose).

> **Intégrer dans une nouvelle app** → [geoking-tools/INTEGRATION.md](https://github.com/ludoo0d0a/geoking-tools/blob/main/INTEGRATION.md)  
> **App from zero** → skill [gk-new-geoking-app](https://github.com/ludoo0d0a/geoking-tools/blob/main/skills/gk-new-geoking-app/SKILL.md)  
> **Manifest app** → [project-manifest.sh](https://github.com/ludoo0d0a/geoking-tools/blob/main/bin/project-manifest.sh) + skill [gk-project-manifest](https://github.com/ludoo0d0a/geoking-tools/blob/main/skills/gk-project-manifest/SKILL.md)

## Prérequis

Ce dépôt doit être **public** (ou accessible via GitHub Team+) pour que les apps
appellent les workflows réutilisables :

```yaml
jobs:
  build:
    uses: ludoo0d0a/geoking-ci/.github/workflows/android-ci.yml@main
    secrets: inherit
```

Les scripts locaux (release, manifest, adb) vivent dans
**[geoking-tools](https://github.com/ludoo0d0a/geoking-tools)** — ce repo ne
contient que les Actions réutilisables + la composite `setup-gradle`.

## Contenu

| Chemin | Rôle |
|---|---|
| `actions/setup-gradle/` | JDK 21 + Gradle (composite action) |
| `.github/workflows/android-ci.yml` | Workflow réutilisable — build debug + artefact APK |
| `.github/workflows/release-play.yml` | Workflow réutilisable — AAB signé + upload Play |
| `.github/workflows/cloudflare-pages.yml` | Workflow réutilisable — deploy `website/` → Cloudflare Pages |
| `.github/workflows/website-screenshots.yml` | Workflow réutilisable — Roborazzi + sync `website/assets` |
| `docs/local-release.md` | **Fallback hors CI** — `geoking-tools` `build-and-publish.sh` |
| `docs/play-service-account-permissions.md` | Pointeur vers la doc permissions Play (geoking-tools) |

## Bootstrap (côté app)

Depuis la racine d’une app sibling de `geoking-tools` :

```bash
../geoking-tools/templates/bootstrap-new-app.sh --package fr.geoking.myapp --name MyApp
```

Ça crée les callers CI (templates ci-dessous), les wrappers `scripts/`, et le
manifest via `./scripts/project-manifest.sh init`. Ensuite :

```bash
./scripts/project-manifest.sh apply --project-id … --play-developer-id … --play-app-id …
./scripts/project-manifest.sh validate
./scripts/setup-release.sh
```

Aligner les inputs CI avec le manifest (`build.gradleModule`, package) —
voir INTEGRATION §1 et §6.

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

Si le module n’est pas `:composeApp`, passer aussi `gradle_module`, `apk_glob`,
`aab_glob` (mêmes valeurs que `build.*` dans `scripts/project.manifest.json`).

## Concurrency (allowOneBuildAtOnce)

Tous les workflows réutilisables appliquent **cancelPreviousRunningBuild** via
`concurrency` + `cancel-in-progress: true` (un seul run à la fois ; le nouveau
annule l’ancien) :

| Workflow | Groupe |
|---|---|
| `android-ci.yml` | `android-ci-${{ github.repository }}-${{ github.ref }}` |
| `release-play.yml` | `play-release-${{ github.repository }}` |
| `cloudflare-pages.yml` | `cloudflare-pages-${{ github.repository }}-${{ github.ref }}` |
| `website-screenshots.yml` | `website-screenshots-${{ github.repository }}` |

Les templates app (`geoking-tools`) gardent aussi un `concurrency` côté caller
pour annuler **tout** le workflow appelant (jobs locaux + `uses:`). Ne pas
désactiver ce comportement.

## Inputs des workflows réutilisables

### `android-ci.yml`

| Input | Défaut | Description |
|---|---|---|
| `artifact_name` | *(requis)* | Nom de l'artefact APK uploadé |
| `gradle_module` | `:composeApp` | Module Gradle (aligner avec le manifest) |
| `java_version` | `21` | Version JDK |

### `release-play.yml`

| Input | Défaut | Description |
|---|---|---|
| `package_name` | *(requis)* | `applicationId` Play (= `project.package` du manifest) |
| `gradle_module` | `:composeApp` | Module Gradle |
| `bundle_task` | `bundleRelease` | Task Gradle (`bundlePlaystoreRelease` pour flavors) |
| `version_code_override` | `max(run_number, props+1, Play+1)` | Force `VERSION_CODE` (rare; leave empty) |
| `java_version` | `21` | Version JDK |

## Landing page (Cloudflare Pages + screenshots)

Callers minces dans l’app (templates `geoking-tools`) :

```yaml
# .github/workflows/cloudflare-pages.yml
jobs:
  deploy:
    uses: ludoo0d0a/geoking-ci/.github/workflows/cloudflare-pages.yml@main
    with:
      pages_project_name: myapp   # ← wrangler / Pages project
    secrets: inherit
```

```yaml
# .github/workflows/website-screenshots.yml
jobs:
  screenshots:
    uses: ludoo0d0a/geoking-ci/.github/workflows/website-screenshots.yml@main
    with:
      screenshot_locales: ${{ github.event.inputs.screenshot_locales || 'en,fr' }}
      copy_only: ${{ github.event.inputs.copy_only || 'false' }}
    secrets: inherit
```

| Input (`cloudflare-pages`) | Défaut | Description |
|---|---|---|
| `pages_project_name` | *(requis)* | Nom du projet Cloudflare Pages |
| `deploy_dir` | `website` | Dossier publié |
| `production_branch` | `main` | Branche prod à la création du projet |

| Input (`website-screenshots`) | Défaut | Description |
|---|---|---|
| `screenshot_locales` | `en,fr` | Locales Roborazzi / fill |
| `copy_only` | `false` | `true` = skip Gradle, fill only |
| `gradle_command` | `generateWebsiteScreenshots` | Task Gradle |

Secrets GitHub : `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`.

## Secrets requis (par dépôt app)

`GOOGLE_SERVICES_JSON`, `WEB_CLIENT_ID`, `GEMINI_API_KEY`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`

Optional (passed through to Gradle when present; blank if unset): `REVENUECAT_API_KEY`, `PEXELS_API_KEY`, `UNSPLASH_ACCESS_KEY`, `UNSPLASH_SECRET_KEY`, `PIXABAY_API_KEY`, `COVERR_API_KEY`, `EUROPEANA_API_KEY`, `HARVARD_API_KEY`, `SMITHSONIAN_API_KEY`, `DEBUG_DEV`

Configurer via `./scripts/setup-release.sh` ([geoking-tools](https://github.com/ludoo0d0a/geoking-tools)).  
Le manifest (`project.id`, Play IDs, chemins Gradle) se remplit avec
`./scripts/project-manifest.sh` — pas dans ce dépôt.

### Actions minutes épuisés ?

Publie depuis la machine locale (même flux que ce workflow) :

```bash
./scripts/build-and-publish.sh              # piste internal
./scripts/build-and-publish.sh --track alpha -y
```

Détail : [`docs/local-release.md`](docs/local-release.md).

**Play Console permissions** for that service account (testing / production / listing):  
→ [`docs/play-service-account-permissions.md`](docs/play-service-account-permissions.md)  
(canonical detail in [geoking-tools](https://github.com/ludoo0d0a/geoking-tools/blob/main/playstore-listing/service-account-permissions.md))
