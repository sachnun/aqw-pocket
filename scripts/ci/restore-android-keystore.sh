#!/bin/sh
set -eu

ANDROID_KEYSTORE_BASE64="${ANDROID_KEYSTORE_BASE64:-}"
ANDROID_KEY_ALIAS="${ANDROID_KEY_ALIAS:-}"
ANDROID_KEYSTORE_PASSWORD="${ANDROID_KEYSTORE_PASSWORD:-}"

if [ -z "$ANDROID_KEYSTORE_BASE64" ] || [ -z "$ANDROID_KEY_ALIAS" ] || [ -z "$ANDROID_KEYSTORE_PASSWORD" ]; then
  echo "Missing Android signing secrets." >&2
  exit 1
fi

mkdir -p .signing
printf '%s' "$ANDROID_KEYSTORE_BASE64" | base64 -d > .signing/release.jks
