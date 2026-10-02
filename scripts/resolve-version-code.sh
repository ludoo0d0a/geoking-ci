#!/usr/bin/env bash
# Resolve Play VERSION_CODE for CI builds.
#
# Usage:
#   resolve-version-code.sh [override]
#   VERSION_CODE_OVERRIDE=42 resolve-version-code.sh
#   PLAY_LATEST_VERSION_CODE=5040 resolve-version-code.sh
#
# Prints a single integer to stdout:
#   - If override (arg1 or VERSION_CODE_OVERRIDE) is a positive int → that value
#   - Else max(GITHUB_RUN_NUMBER, playstore/version.properties+1, PLAY_LATEST+1)
#     plus (GITHUB_RUN_ATTEMPT - 1) so workflow re-runs do not collide on Play
#
# PLAY_LATEST_VERSION_CODE is the highest versionCode already known to Play
# (tracks + uploaded bundles). Callers should query Play before invoking this
# script so CI does not depend on manually bumping version.properties after
# every successful upload. version.properties remains a local/offline floor.
#
# Callers must not invent arithmetic in workflow expressions (GHA has no +/*);
# pass version_code_override only for rare forced codes, otherwise leave empty.
set -euo pipefail

ROOT="${GK_PROJECT_ROOT:-${GITHUB_WORKSPACE:-.}}"
PROPS="$ROOT/playstore/version.properties"
RUN_NUMBER="${GITHUB_RUN_NUMBER:-0}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
OVERRIDE="${1:-${VERSION_CODE_OVERRIDE:-}}"
PLAY_LATEST="${PLAY_LATEST_VERSION_CODE:-}"

log() { echo "resolve-version-code: $*" >&2; }

log "── VERSION_CODE origin ──"
log "workspace_root=${ROOT}"
log "props_path=${PROPS}"
log "props_exists=$([ -f "$PROPS" ] && echo yes || echo no)"
log "GITHUB_RUN_NUMBER(raw)=${GITHUB_RUN_NUMBER:-<unset>}"
log "GITHUB_RUN_ATTEMPT(raw)=${GITHUB_RUN_ATTEMPT:-<unset>}"
log "PLAY_LATEST_VERSION_CODE(raw)=${PLAY_LATEST:-<unset>}"
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

props_floor=$((props_vc + 1))

play_floor=0
play_raw="<unset>"
if [[ "${PLAY_LATEST}" =~ ^[0-9]+$ ]]; then
  play_raw="$PLAY_LATEST"
  play_floor=$((PLAY_LATEST + 1))
elif [ -n "${PLAY_LATEST}" ]; then
  log "play_latest_invalid=${PLAY_LATEST} → ignoring"
  play_raw="<invalid:${PLAY_LATEST}>"
fi

base="$RUN_NUMBER"
base_source="run_number"
if [ "$props_floor" -gt "$base" ]; then
  base="$props_floor"
  base_source="props_floor (version.properties versionCode + 1)"
fi
if [ "$play_floor" -gt "$base" ]; then
  base="$play_floor"
  base_source="play_floor (Play latest versionCode + 1)"
fi

attempt_bump=0
resolved="$base"
if [ "$RUN_ATTEMPT" -gt 1 ]; then
  attempt_bump=$((RUN_ATTEMPT - 1))
  resolved=$((base + attempt_bump))
fi

log "props_versionCode=${props_vc} (raw=${props_raw})"
log "props_floor=${props_floor}  (= props_versionCode + 1)"
log "play_latest=${play_raw}"
log "play_floor=${play_floor}  (= play_latest + 1, or 0 if unset)"
log "run_number=${RUN_NUMBER}"
log "run_attempt=${RUN_ATTEMPT}"
log "base=${base}  (winner=${base_source})"
log "attempt_bump=${attempt_bump}  (= max(0, run_attempt - 1))"
log "formula=max(run_number, props_floor, play_floor) + attempt_bump"
log "source=${base_source}$([ "$attempt_bump" -gt 0 ] && echo " + attempt_bump" || true)"
log "resolved=${resolved}"
if [ "$play_floor" -eq 0 ]; then
  log "note=PLAY_LATEST_VERSION_CODE unset; relying on run_number / version.properties only (manual props bumps still needed if props lag Play)"
fi
log "────────────────────────"

printf '%s\n' "$resolved"
