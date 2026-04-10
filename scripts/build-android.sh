#!/bin/sh
# Shared Android build script — used by both Makefile and CI workflows.
# Runs INSIDE the Docker build container.
#
# Usage: scripts/build-android.sh [OPTIONS]
#
# Targets:
#   --target apk-armv7   Build armv7 APK
#   --target apk-armv8   Build armv8 APK (default)
#
# Options:
#   --output NAME        Output filename (placed under build/)
#   --skip-patch         Skip Game.swf patching
#   --skip-ane           Skip foreground ANE rebuild
#
# Signing (via environment, with local-dev defaults):
#   KEYSTORE_PATH / KEYSTORE_FILE   (default: .signing/dev.jks, auto-created)
#   KEY_ALIAS / KEYSTORE_ALIAS      (default: dev)
#   KEYSTORE_PASS / KEYSTORE_PASSWORD (default: devpass)
#   KEY_PASS / KEY_PASSWORD          (default: same as KEYSTORE_PASS)

set -eu

# Use pre-compiled class files if available, otherwise JEP 330 source execution
_java() { _c="$1"; shift; if [ -f "/opt/java-tools/${_c}.class" ]; then java -cp /opt/java-tools "$_c" "$@"; else java "scripts/${_c}.java" "$@"; fi; }

# ── Configuration (via environment with defaults) ──────────
KEYSTORE_PATH="${KEYSTORE_PATH:-${KEYSTORE_FILE:-.signing/dev.jks}}"
KEY_ALIAS="${KEY_ALIAS:-${KEYSTORE_ALIAS:-dev}}"
KEYSTORE_PASS="${KEYSTORE_PASS:-${KEYSTORE_PASSWORD:-devpass}}"
KEY_PASS="${KEY_PASS:-${KEY_PASSWORD:-${KEYSTORE_PASS}}}"

# ── Parse arguments ────────────────────────────────────────
TARGET="apk-armv8"
OUTPUT=""
SKIP_PATCH=0
SKIP_ANE=0

while [ $# -gt 0 ]; do
  case "$1" in
    --target)     TARGET="$2"; shift 2 ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    --skip-patch) SKIP_PATCH=1; shift ;;
    --skip-ane)   SKIP_ANE=1; shift ;;
    *)            echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

ICONS="icons/android-icon-36x36.png icons/android-icon-48x48.png icons/android-icon-72x72.png icons/android-icon-96x96.png icons/android-icon-144x144.png icons/android-icon-192x192.png"

# ── Step 1: Patch Game.swf ─────────────────────────────────
if [ "$SKIP_PATCH" != "1" ]; then
  echo "[1/5] Patching latest Game.swf..."
  _java patch
else
  echo "[1/5] Skip patch (--skip-patch)"
fi
test -f assets/Game.swf || { echo "Missing assets/Game.swf"; exit 1; }

# ── Step 2: Prepare gamefiles ──────────────────────────────
echo "[2/5] Preparing loader gamefiles..."
mkdir -p app/gamefiles && cp assets/Game.swf app/gamefiles/Game.swf

# ── Step 3: Build foreground ANE ───────────────────────────
if [ "$SKIP_ANE" != "1" ]; then
  echo "[3/5] Building foreground ANE..."
  mkdir -p ane/build/as3/core ane/build/android/classes ane/build/android-dist app/extensions
  rm -rf ane/build/android-dist/res
  if [ -d ane/android/res ]; then cp -R ane/android/res ane/build/android-dist/res; fi
  cp app/src/core/ForegroundService.as ane/build/as3/core/ForegroundService.as
  compc -source-path ane/build/as3 -include-classes core.ForegroundService \
    -swf-version=23 -output ane/build/foreground.swc
  if [ -f /opt/java-tools/foreground-ext.jar ]; then
    cp /opt/java-tools/foreground-ext.jar ane/build/foreground-ext.jar
  else
    javac --release 8 \
      -cp "$ANDROID_JAR:$AIR_HOME/lib/android/FlashRuntimeExtensions.jar" \
      -d ane/build/android/classes ane/android/src/com/aqw/foreground/*.java
    jar cf ane/build/foreground-ext.jar -C ane/build/android/classes .
  fi
  _java tools extract-library-swf \
    ane/build/foreground.swc ane/build/android-dist/library.swf
  cp ane/build/foreground-ext.jar ane/build/android-dist/foreground-ext.jar
  cp ane/extension.xml ane/build/extension.xml
  cp ane/platform-android.xml ane/build/android-dist/platform.xml
  adt -package -target ane ane/build/foreground.ane ane/build/extension.xml \
    -swc ane/build/foreground.swc \
    -platform Android-ARM -platformoptions ane/build/android-dist/platform.xml \
      -C ane/build/android-dist foreground-ext.jar library.swf res \
    -platform Android-ARM64 -platformoptions ane/build/android-dist/platform.xml \
      -C ane/build/android-dist foreground-ext.jar library.swf res
  cp ane/build/foreground.ane app/extensions/foreground.ane
else
  echo "[3/5] Skip ANE (--skip-ane)"
fi
test -f app/extensions/foreground.ane || { echo "Missing ANE: app/extensions/foreground.ane"; exit 1; }

# ── Step 4: Compile Loader.swf ─────────────────────────────
echo "[4/5] Compiling Loader.swf..."
amxmlc -external-library-path+=app/extensions/foreground.ane \
  -output app/Loader.swf app/src/Main.as

# ── Auto-generate dev keystore if missing ──────────────────
if [ ! -f "$KEYSTORE_PATH" ]; then
  echo "[keystore] Creating dev keystore at $KEYSTORE_PATH..."
  mkdir -p "$(dirname "$KEYSTORE_PATH")"
  keytool -genkeypair -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASS" -keypass "$KEY_PASS" \
    -dname "CN=AQW Pocket Dev, OU=Dev, O=Community, L=Unknown, S=Unknown, C=US"
fi

mkdir -p build

# ── Step 5: Package ────────────────────────────────────────
case "$TARGET" in
  apk-armv7)
    echo "[5/5] Building armv7 APK..."
    adt -package -target apk-captive-runtime -arch armv7 \
      -storetype JKS -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASS" -keypass "$KEY_PASS" \
      "build/${OUTPUT:-AQWPocket-armv7.apk}" app/app.xml -extdir app/extensions \
      -C app Loader.swf $ICONS gamefiles/Game.swf
    echo "Done. APK: build/${OUTPUT:-AQWPocket-armv7.apk}"
    ;;
  apk-armv8)
    echo "[5/5] Building armv8 APK..."
    adt -package -target apk-captive-runtime -arch armv8 \
      -storetype JKS -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASS" -keypass "$KEY_PASS" \
      "build/${OUTPUT:-AQWPocket-armv8.apk}" app/app.xml -extdir app/extensions \
      -C app Loader.swf $ICONS gamefiles/Game.swf
    echo "Done. APK: build/${OUTPUT:-AQWPocket-armv8.apk}"
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    exit 1
    ;;
esac
