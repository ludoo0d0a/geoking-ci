#!/usr/bin/env bash
# Write google-services.json from GOOGLE_SERVICES_JSON secret (plain JSON or base64).
# Usage: write-google-services.sh <dest-path>
set -euo pipefail
DEST="${1:?dest path}"
: "${GOOGLE_SERVICES_JSON:?GOOGLE_SERVICES_JSON secret required}"
mkdir -p "$(dirname "$DEST")"
tmp="$(mktemp)"
# Prefer base64 (geoking convention); fall back to raw JSON (legacy Gaston).
if printf '%s' "$GOOGLE_SERVICES_JSON" | base64 --decode >"$tmp" 2>/dev/null \
  && jq -e . "$tmp" >/dev/null 2>&1; then
  mv "$tmp" "$DEST"
  echo "google-services.json written from base64 ($(wc -c < "$DEST") bytes)"
elif printf '%s' "$GOOGLE_SERVICES_JSON" >"$tmp" && jq -e . "$tmp" >/dev/null 2>&1; then
  mv "$tmp" "$DEST"
  echo "google-services.json written from plain JSON ($(wc -c < "$DEST") bytes)"
else
  rm -f "$tmp"
  echo "::error::GOOGLE_SERVICES_JSON is neither valid base64-JSON nor plain JSON"
  exit 1
fi
