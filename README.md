# geoking-ci

GitHub Actions partagées pour les apps Android GeoKing (KMP / Compose).

> **Intégrer dans une nouvelle app** → [geoking-tools/INTEGRATION.md](https://github.com/ludoo0d0a/geoking-tools/blob/main/INTEGRATION.md)  
> **App from zero** → skill [gk-new-geoking-app](https://github.com/ludoo0d0a/geoking-tools/blob/main/skills/gk-new-geoking-app/SKILL.md)  
> **Manifest app** → [project-manifest.sh](https://github.com/ludoo0d0a/geoking-tools/blob/main/bin/project-manifest.sh) + skill [gk-project-manifest](https://github.com/ludoo0d0a/geoking-tools/blob/main/skills/gk-project-manifest/SKILL.md)

## Prérequis

Ce dépôt doit être **public** (ou accessible via GitHub Team+) pour que les apps
appellent les actions / workflows `gk-*` :

```yaml
jobs:
  release:
    runs-on: ubuntu-latest
    env:
      # Secrets mappés dans le YAML de l'APP — jamais dans geoking-ci
      KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
      GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
      WEB_CLIENT_ID: ${{ secrets.WEB_CLIENT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: ludoo0d0a/geoking-ci/actions/gk-release-play@main
        with:
          package_name: fr.geoking.myapp
```

Les scripts locaux (release, manifest, adb) vivent dans
**[geoking-tools](https://github.com/ludoo0d0a/geoking-tools)** — ce repo ne
contient que les Actions `gk-*` (logique générique). **Aucun**
`${{ secrets.* }}` app ni liste d’API keys ici : l’app exporte l’env ; geoking-ci
lit l’env.

## Contenu

| Chemin | Rôle |
|---|---|
| `actions/gk-setup-gradle/` | JDK 21 + Gradle (composite) |
| `actions/gk-release-play/` | Composite — tests → AAB signé → upload Play (lit l’env caller) |
| `.github/workflows/gk-android-ci.yml` | Workflow réutilisable optionnel — assemble debug (lit l’env caller) |
| `.github/workflows/gk-cloudflare-pages.yml` | Workflow réutilisable — deploy `website/` → Cloudflare Pages |
| `.github/workflows/gk-website-screenshots.yml` | Workflow réutilisable — Roborazzi + sync `website/assets` |
| `docs/local-release.md` | **Fallback hors CI** — `geoking-tools` `build-and-publish.sh` |
| `docs/play-service-account-permissions.md` | Pointeur vers la doc permissions Play (geoking-tools) |

Les YAML **app** gardent des noms courts (`android-ci.yml`, `release-play.yml`).
Les YAML **partagés** sont préfixés `gk-` pour éviter la confusion.

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

Copie depuis `geoking-tools/templates/` — l’app déclare **tout** le mapping
`secrets → env` (signing, Play, Firebase, API keys produit).

```yaml
# .github/workflows/android-ci.yml (inline + env app)
env:
  GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
  WEB_CLIENT_ID: ${{ secrets.WEB_CLIENT_ID }}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # checkout geoking-ci + geoking-tools, then:
      - uses: ./geoking-ci/actions/gk-setup-gradle
      - run: bash geoking-ci/scripts/write-google-services.sh composeApp/google-services.json
      - run: ./gradlew :composeApp:assembleDebug
        env:
          GK_TOOLS: ${{ github.workspace }}/geoking-tools
```

```yaml
# .github/workflows/release-play.yml
env:
  KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 || secrets.SIGNING_KEY }}
  KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD || secrets.KEY_STORE_PASSWORD }}
  KEY_ALIAS: ${{ secrets.KEY_ALIAS || secrets.ALIAS }}
  KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
  PLAY_SERVICE_ACCOUNT_JSON: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON || secrets.SERVICE_ACCOUNT_JSON }}
  GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
  WEB_CLIENT_ID: ${{ secrets.WEB_CLIENT_ID }}
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ludoo0d0a/geoking-ci/actions/gk-release-play@main
        with:
          package_name: fr.geoking.myapp
          is_workflow_dispatch: ${{ github.event_name == 'workflow_dispatch' && 'true' || 'false' }}
          workflow_dispatch_track: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.track || '' }}
          workflow_dispatch_skip_review: ${{ github.event_name == 'workflow_dispatch' && github.event.inputs.changesNotSentForReview && 'true' || 'false' }}
          version_name_override: ${{ github.ref_type == 'tag' && github.ref_name || '' }}
```

Si le module n’est pas `:composeApp`, passer aussi `gradle_module`, `apk_glob`,
`aab_glob` (mêmes valeurs que `build.*` dans `scripts/project.manifest.json`).

## Concurrency (allowOneBuildAtOnce)

Les workflows réutilisables `gk-*` et les templates app appliquent
`concurrency` + `cancel-in-progress: true` :

| Artefact | Groupe |
|---|---|
| `gk-android-ci.yml` | `android-ci-${{ github.repository }}-${{ github.ref }}` |
| app `release-play` / composite | `play-release` (côté app) |
| `gk-cloudflare-pages.yml` | `cloudflare-pages-${{ github.repository }}-${{ github.ref }}` |
| `gk-website-screenshots.yml` | `website-screenshots-${{ github.repository }}` |

## Inputs `gk-release-play`

| Input | Défaut | Description |
|---|---|---|
| `package_name` | *(requis)* | `applicationId` Play |
| `gradle_module` | `:composeApp` | Module Gradle |
| `bundle_task` | `bundleRelease` | Task Gradle (`bundlePlaystoreRelease` pour flavors) |
| `version_code_override` | empty | Force `VERSION_CODE` (rare) |
| `java_version` | `21` | Version JDK |

Env attendu du caller (non exhaustif) : `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`, `KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`, `GOOGLE_SERVICES_JSON`,
plus toute API key lue par le `build.gradle.kts` de l’app.

## Landing page (Cloudflare Pages + screenshots)

```yaml
# .github/workflows/cloudflare-pages.yml
jobs:
  deploy:
    uses: ludoo0d0a/geoking-ci/.github/workflows/gk-cloudflare-pages.yml@main
    with:
      pages_project_name: myapp
    secrets: inherit
```

```yaml
# .github/workflows/website-screenshots.yml
jobs:
  screenshots:
    uses: ludoo0d0a/geoking-ci/.github/workflows/gk-website-screenshots.yml@main
    with:
      screenshot_locales: ${{ github.event.inputs.screenshot_locales || 'en,fr' }}
      copy_only: ${{ github.event.inputs.copy_only || 'false' }}
    secrets: inherit
```

Secrets Cloudflare (déclarés sur le reusable) : `CLOUDFLARE_API_TOKEN`,
`CLOUDFLARE_ACCOUNT_ID`.

## Secrets (dépôt app uniquement)

Configurer via `./scripts/setup-release.sh` ([geoking-tools](https://github.com/ludoo0d0a/geoking-tools)).
Mapper chaque secret vers `env:` dans les workflows **de l’app**.
Le manifest (`project.id`, Play IDs, chemins Gradle) se remplit avec
`./scripts/project-manifest.sh` — pas dans ce dépôt.

### Actions minutes épuisés ?

```bash
./scripts/build-and-publish.sh              # piste internal
./scripts/build-and-publish.sh --track alpha -y
```

Détail : [`docs/local-release.md`](docs/local-release.md).

**Play Console permissions** for that service account:  
→ [`docs/play-service-account-permissions.md`](docs/play-service-account-permissions.md)
