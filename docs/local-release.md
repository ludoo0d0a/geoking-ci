# Local Play release (CI fallback)

When GitHub Actions minutes/credits are exhausted, publish from a developer machine
with the same pipeline as [`release-play.yml`](../.github/workflows/release-play.yml):

1. Unit tests  
2. Signed AAB (upload keystore)  
3. `whatsnew` generation  
4. Play Developer API upload  

## Script (lives in geoking-tools)

```bash
# from any GeoKing app root
./scripts/release-play-local.sh
./scripts/release-play-local.sh --track internal -y
./scripts/release-play-local.sh --skip-tests --dry-run
./scripts/release-play-local.sh --track alpha --skip-review
```

Requires (same as CI secrets, already set up by `./scripts/setup-release.sh`):

- `release.keystore` + `scripts/.keystore-credentials`
- `scripts/.play-service-account.json` (Play API)
- `google-services.json` / `local.properties` as for a local release build

`versionCode` defaults to `max(Play tracks, playstore/version.properties) + 1`
(CI uses `github.run_number` instead).

Canonical implementation:  
[geoking-tools/bin/release-play-local.sh](https://github.com/ludoo0d0a/geoking-tools/blob/main/bin/release-play-local.sh)

Prefer the reusable Actions workflow again as soon as credits are available.
