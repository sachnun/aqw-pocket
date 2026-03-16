#!/bin/sh
set -eu

REQUIRE_SIGNING="${REQUIRE_SIGNING:-0}"
AIR_KEYSTORE_BASE64="${AIR_KEYSTORE_BASE64:-}"
AIR_KEYSTORE_PASSWORD="${AIR_KEYSTORE_PASSWORD:-}"

if [ -z "$AIR_KEYSTORE_BASE64" ] || [ -z "$AIR_KEYSTORE_PASSWORD" ]; then
  case "$REQUIRE_SIGNING" in
    1|true|TRUE|yes|YES)
      echo "Missing AIR signing secrets." >&2
      exit 1
      ;;
    *)
      echo "AIR signing secrets not set; using auto-generated dev certificate."
      exit 0
      ;;
  esac
fi

mkdir -p .signing
printf '%s' "$AIR_KEYSTORE_BASE64" | base64 -d > .signing/release.p12
