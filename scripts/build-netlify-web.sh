#!/usr/bin/env bash
set -euo pipefail

HDC_FLUTTER_BIN="${HDC_FLUTTER_BIN:-flutter}"
HDC_EXPECTED_FLUTTER_VERSION="$(tr -d '[:space:]' < .flutter-version)"
HDC_MAP_SEARCH_URL_TEMPLATE="${HDC_MAP_SEARCH_URL_TEMPLATE:-https://www.openstreetmap.org/search?query={query}}"
export CI="${CI:-true}"
export FLUTTER_SUPPRESS_ANALYTICS="${FLUTTER_SUPPRESS_ANALYTICS:-true}"
export PUB_ENVIRONMENT="${PUB_ENVIRONMENT:-bot}"
export CLOUDSDK_CORE_CHECK_GCE_METADATA="${CLOUDSDK_CORE_CHECK_GCE_METADATA:-0}"
HDC_FLUTTER_VERSION_OUTPUT="$($HDC_FLUTTER_BIN --version)"

if [[ "$HDC_FLUTTER_VERSION_OUTPUT" != *"Flutter $HDC_EXPECTED_FLUTTER_VERSION"* ]]; then
  echo "HDC web builds require Flutter $HDC_EXPECTED_FLUTTER_VERSION."
  exit 1
fi

"$HDC_FLUTTER_BIN" pub get --enforce-lockfile
"$HDC_FLUTTER_BIN" analyze --no-pub
"$HDC_FLUTTER_BIN" test --no-pub
"$HDC_FLUTTER_BIN" build web \
  --release \
  --no-pub \
  --no-web-resources-cdn \
  --base-href=/ \
  --dart-define=HDC_BACKEND_PROVIDER=api \
  --dart-define=HDC_API_BASE_URL=same-origin \
  --dart-define="HDC_MAP_SEARCH_URL_TEMPLATE=$HDC_MAP_SEARCH_URL_TEMPLATE"

node scripts/prepare-netlify-web.mjs
