#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="$(tr -d '[:space:]' < .flutter-version)"
CACHE_ROOT="${HOME}/.cache/hdc-flutter"
FLUTTER_ROOT="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}"
ARCHIVE="${CACHE_ROOT}/flutter-${FLUTTER_VERSION}.tar.xz"
mkdir -p "$CACHE_ROOT"

if [[ ! -x "${FLUTTER_ROOT}/bin/flutter" ]]; then
  rm -rf "$FLUTTER_ROOT" "${CACHE_ROOT}/flutter"
  if [[ ! -f "$ARCHIVE" ]]; then
    curl --fail --location --retry 3 --retry-delay 2 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      --output "$ARCHIVE"
  fi
  tar -xf "$ARCHIVE" -C "$CACHE_ROOT"
  mv "${CACHE_ROOT}/flutter" "$FLUTTER_ROOT"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"
git config --global --add safe.directory "$FLUTTER_ROOT" || true
flutter config --no-analytics >/dev/null
HDC_FLUTTER_BIN=flutter bash scripts/build-netlify-web.sh
