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
set -euo pipefail

ROOT="${GK_PROJECT_ROOT:-${GITHUB_WORKSPACE:-.}}"
PROPS="$ROOT/playstore/version.properties"
RUN_NUMBER="${GITHUB_RUN_NUMBER:-0}"
RUN_ATTEMPT="${GITHUB_RUN_ATTEMPT:-1}"
OVERRIDE="${1:-${VERSION_CODE_OVERRIDE:-}}"

if [[ "${OVERRIDE}" =~ ^[0-9]+$ ]] && [ "$OVERRIDE" -gt 0 ]; then
  printf '%s\n' "$OVERRIDE"
  exit 0
fi

if ! [[ "${RUN_NUMBER}" =~ ^[0-9]+$ ]]; then
  RUN_NUMBER=0
fi

if ! [[ "${RUN_ATTEMPT}" =~ ^[0-9]+$ ]] || [ "$RUN_ATTEMPT" -lt 1 ]; then
  RUN_ATTEMPT=1
fi

props_vc=0
if [ -f "$PROPS" ]; then
  raw="$(grep '^versionCode=' "$PROPS" | head -1 | cut -d= -f2- || true)"
  if [[ "${raw}" =~ ^[0-9]+$ ]]; then
    props_vc="$raw"
  fi
fi

floor=$((props_vc + 1))
resolved="$RUN_NUMBER"
if [ "$floor" -gt "$resolved" ]; then
  resolved="$floor"
fi

# Same run_number on re-attempt; bump so Play accepts a new AAB.
if [ "$RUN_ATTEMPT" -gt 1 ]; then
  resolved=$((resolved + RUN_ATTEMPT - 1))
fi

echo "resolve-version-code: run_number=${RUN_NUMBER} attempt=${RUN_ATTEMPT} props_vc=${props_vc} → ${resolved}" >&2
printf '%s\n' "$resolved"
