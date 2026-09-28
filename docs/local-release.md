# Local Play release (CI fallback)

When GitHub Actions minutes/credits are exhausted, publish from a developer machine
with the same pipeline as [`release-play.yml`](../.github/workflows/release-play.yml):

1. Unit tests  
2. Signed AAB (upload keystore)  
3. `whatsnew` generation  
4. Play Developer API upload  

## Prerequisites (app repo)

Same stack as CI, wired by **geoking-tools**:

- `scripts/project.manifest.json` — package / Gradle module / Play IDs  
  (`./scripts/project-manifest.sh validate`)
- `release.keystore` + `scripts/.keystore-credentials`
- `scripts/.play-service-account.json` (Play API)
- `google-services.json` / `local.properties` as for a local release build

Setup once: `./scripts/setup-release.sh`  
(see [geoking-tools/INTEGRATION.md](https://github.com/ludoo0d0a/geoking-tools/blob/main/INTEGRATION.md)).

## Script (lives in geoking-tools)

```bash
# from any GeoKing app root
./scripts/build-and-publish.sh
./scripts/build-and-publish.sh --track internal -y
./scripts/build-and-publish.sh --skip-tests --dry-run
./scripts/build-and-publish.sh --track alpha --skip-review
```

`versionCode` defaults to `max(Play tracks, playstore/version.properties) + 1`
(CI uses `github.run_number` instead).

Canonical implementation:  
[geoking-tools/bin/build-and-publish.sh](https://github.com/ludoo0d0a/geoking-tools/blob/main/bin/build-and-publish.sh)

Prefer the reusable Actions workflow again as soon as credits are available.
