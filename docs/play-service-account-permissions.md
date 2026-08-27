# Play Console — service account permissions (for `release-play`)

The reusable workflow [`.github/workflows/release-play.yml`](../.github/workflows/release-play.yml)
uploads a signed AAB (and optional what’s new) with a Play **service account** JSON
(`SERVICE_ACCOUNT_JSON` secret).

That SA must have the right **app-level** permissions in Play Console.
Full checklist (FR/EN UI labels + API enums):

**→ [geoking-tools/playstore-listing/service-account-permissions.md](https://github.com/ludoo0d0a/geoking-tools/blob/main/playstore-listing/service-account-permissions.md)**

### Quick minimum for GeoKing CI

| Need | Permission (FR) |
|------|-----------------|
| Base | Afficher les informations sur l'application (lecture seule) |
| Listing / metadata (if used) | Gérer la présence sur le Play Store |
| Upload to internal / test tracks | Déployer les applications sur des canaux de test |
| Upload / edit production | Mettre les applications à disposition de tous les utilisateurs… |

Do **not** grant **Administrateur** to the CI service account.

Without testing/production release permissions, track commits (including release notes) fail with **403**.
