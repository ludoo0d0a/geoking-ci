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
#
# Semantics: version.properties versionCode is the last locally published / bumped
# floor. CI must never reuse it, so the floor contribution is props+1.
set -euo pipefail

ROOT="${GK_PROJECT_ROOT:-${GITHUB_WORKSPACE:-.}}"
PROPS="$ROOT/playstore/version.properties"
RUN_NUMBER="${GITHUB_RUN_NUMBER:-0}"
OVERRIDE="${1:-${VERSION_CODE_OVERRIDE:-}}"

if [[ "${OVERRIDE}" =~ ^[0-9]+$ ]] && [ "$OVERRIDE" -gt 0 ]; then
  printf '%s\n' "$OVERRIDE"
  exit 0
fi

if ! [[ "${RUN_NUMBER}" =~ ^[0-9]+$ ]]; then
  RUN_NUMBER=0
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

echo "resolve-version-code: run_number=${RUN_NUMBER} props_vc=${props_vc} → ${resolved}" >&2
printf '%s\n' "$resolved"
