#!/usr/bin/env bash
# Resolve Play VERSION_CODE for CI builds.
#
# Usage:
#   resolve-version-code.sh [override]
#   VERSION_CODE_OVERRIDE=42 resolve-version-code.sh
#
# Prints a single integer to stdout:
#   - If override (arg1 or VERSION_CODE_OVERRIDE) is a positive int → that value
#   - Else max(GITHUB_RUN_NUMBER, playstore/version.properties versionCode + 1)
#     plus (GITHUB_RUN_ATTEMPT - 1) so workflow re-runs do not collide on Play
#
# Semantics: version.properties versionCode is the last locally published / bumped
# floor. CI must never reuse it, so the floor contribution is props+1.
# Callers must not invent arithmetic in workflow expressions (GHA has no +/*);
# pass version_code_override only for rare forced codes, otherwise leave empty.
#
# After a successful Play upload of code N, bump playstore/version.properties to N
# (or higher). Otherwise the next run keeps resolving to N again when run_number
# is still below the Play floor.
set -euo pipefail

ROOT="${GK_PROJECT_ROOT:-${GITHUB_WORKSPACE:-.}}"
PROPS="$ROOT/playstore/version.properties"
RUN_NUMBER="${GITHUB_RUN_NUMBER:-0}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
OVERRIDE="${1:-${VERSION_CODE_OVERRIDE:-}}"

log() { echo "resolve-version-code: $*" >&2; }

log "── VERSION_CODE origin ──"
log "workspace_root=${ROOT}"
log "props_path=${PROPS}"
log "props_exists=$([ -f "$PROPS" ] && echo yes || echo no)"
log "GITHUB_RUN_NUMBER(raw)=${GITHUB_RUN_NUMBER:-<unset>}"
log "GITHUB_RUN_ATTEMPT(raw)=${GITHUB_RUN_ATTEMPT:-<unset>}"
log "VERSION_CODE_OVERRIDE(env)=${VERSION_CODE_OVERRIDE:-<empty>}"
log "override(arg1)=${1:-<none>}"

if [[ "${OVERRIDE}" =~ ^[0-9]+$ ]] && [ "$OVERRIDE" -gt 0 ]; then
  log "source=override"
  log "formula=VERSION_CODE_OVERRIDE (or arg1)"
  log "resolved=${OVERRIDE}"
  log "────────────────────────"
  printf '%s\n' "$OVERRIDE"
  exit 0
fi

if [ -n "${OVERRIDE}" ]; then
  log "override_ignored=${OVERRIDE} (not a positive integer)"
fi

if ! [[ "${RUN_NUMBER}" =~ ^[0-9]+$ ]]; then
  log "run_number_invalid=${RUN_NUMBER} → treating as 0"
  RUN_NUMBER=0
fi

if ! [[ "${RUN_ATTEMPT}" =~ ^[0-9]+$ ]] || [ "$RUN_ATTEMPT" -lt 1 ]; then
  log "run_attempt_invalid=${RUN_ATTEMPT} → treating as 1"
  RUN_ATTEMPT=1
fi

props_vc=0
props_raw="<missing>"
if [ -f "$PROPS" ]; then
  props_raw="$(grep '^versionCode=' "$PROPS" | head -1 | cut -d= -f2- || true)"
  if [[ "${props_raw}" =~ ^[0-9]+$ ]]; then
    props_vc="$props_raw"
  else
    log "props_versionCode_unparseable=${props_raw}"
    props_raw="<unparseable:${props_raw}>"
  fi
fi

floor=$((props_vc + 1))
base="$RUN_NUMBER"
base_source="run_number"
if [ "$floor" -gt "$base" ]; then
  base="$floor"
  base_source="props_floor (version.properties versionCode + 1)"
fi

attempt_bump=0
resolved="$base"
if [ "$RUN_ATTEMPT" -gt 1 ]; then
  attempt_bump=$((RUN_ATTEMPT - 1))
  resolved=$((base + attempt_bump))
fi

log "props_versionCode=${props_vc} (raw=${props_raw})"
log "props_floor=${floor}  (= props_versionCode + 1)"
log "run_number=${RUN_NUMBER}"
log "run_attempt=${RUN_ATTEMPT}"
log "base=${base}  (winner=${base_source})"
log "attempt_bump=${attempt_bump}  (= max(0, run_attempt - 1))"
log "formula=max(run_number, props_floor) + attempt_bump"
log "source=${base_source}$([ "$attempt_bump" -gt 0 ] && echo " + attempt_bump" || true)"
log "resolved=${resolved}"
if [ "$base_source" != "run_number" ] && [ "$RUN_NUMBER" -lt "$floor" ]; then
  log "note=run_number (${RUN_NUMBER}) < props_floor (${floor}); Play floor dominates until version.properties is bumped after each successful upload"
fi
log "────────────────────────"

printf '%s\n' "$resolved"
