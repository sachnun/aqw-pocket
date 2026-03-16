#!/bin/sh
# Shared Linux AppImage build script — used by both Makefile and CI workflows.
# Runs INSIDE the Docker build container.
#
# Usage: scripts/build-linux.sh [OPTIONS]
#
# Options:
#   --output NAME    Output AppImage filename (default: AQWPocket-x86_64.AppImage)
#   --skip-patch     Skip Game.swf patching
#
# Signing (via environment, shared with CI release builds):
#   KEYSTORE_PATH / KEYSTORE_FILE   (default: .signing/dev.p12, auto-created)
#   KEYSTORE_PASS / KEYSTORE_PASSWORD (default: devpass)

set -eu

# ── Configuration (via environment with defaults) ──────────
KEYSTORE_PATH="${KEYSTORE_PATH:-${KEYSTORE_FILE:-.signing/dev.p12}}"
KEYSTORE_PASS="${KEYSTORE_PASS:-${KEYSTORE_PASSWORD:-devpass}}"

# ── Parse arguments ────────────────────────────────────────
OUTPUT=""
SKIP_PATCH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --output)     OUTPUT="$2"; shift 2 ;;
    --skip-patch) SKIP_PATCH=1; shift ;;
    *)            echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

APPIMAGE_NAME="${OUTPUT:-AQWPocket-x86_64.AppImage}"
RUNTIME="${AIR_HOME:-/opt/air_sdk}/runtimes/air/linux-x64"
BUNDLE="build/AQWPocket-linux"

# ── Step 1: Patch Game.swf ─────────────────────────────────
if [ "$SKIP_PATCH" != "1" ]; then
  echo "[1/6] Patching latest Game.swf..."
  java scripts/patch.java
else
  echo "[1/6] Skip patch (--skip-patch)"
fi
test -f assets/Game.swf || { echo "Missing assets/Game.swf"; exit 1; }

# ── Step 2: Prepare gamefiles ──────────────────────────────
echo "[2/6] Preparing loader gamefiles..."
mkdir -p app/gamefiles && cp assets/Game.swf app/gamefiles/Game.swf

# ── Step 3: Compile Loader.swf ─────────────────────────────
echo "[3/6] Compiling Loader.swf (linux)..."
amxmlc -output app/Loader.swf app/src/Main.as

# ── Step 4: Sign content with adt ─────────────────────────
# Captive runtime entry points require META-INF/signatures.xml and
# META-INF/AIR/hash to load the application. We create a signed
# .air package (cross-platform) and extract these artifacts.
# Uses a persistent PKCS12 certificate in CI, with a local dev fallback.
echo "[4/6] Signing application content..."
mkdir -p build

# Auto-generate dev AIR certificate if missing
if [ ! -f "$KEYSTORE_PATH" ]; then
  echo "[keystore] Creating dev AIR certificate at $KEYSTORE_PATH..."
  mkdir -p "$(dirname "$KEYSTORE_PATH")"
  adt -certificate -cn "AQW Pocket Dev" -ou Dev -o Community 2048-RSA \
    "$KEYSTORE_PATH" "$KEYSTORE_PASS"
fi

rm -f build/_signed.air
adt -package \
  -storetype pkcs12 -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASS" \
  -target air \
  build/_signed.air \
  app/app-linux.xml \
  -C app Loader.swf gamefiles icons

# ── Step 5: Assemble AIR bundle ────────────────────────────
echo "[5/6] Assembling AIR bundle..."
rm -rf "$BUNDLE"

# Extract signed content (includes META-INF with signatures + hash)
mkdir -p "$BUNDLE"
cd "$BUNDLE" && unzip -q ../../build/_signed.air && cd ../..

# Copy Linux AIR runtime
cp -a "$RUNTIME/Adobe AIR" "$BUNDLE/"
cp "$RUNTIME/Adobe AIR/Versions/1.0/Resources/captiveappentry" "$BUNDLE/AQWPocket"
chmod +x "$BUNDLE/AQWPocket"

# Patch AIR runtime license
java scripts/tools.java patch-air-license \
  "$BUNDLE/Adobe AIR/Versions/1.0/libCore.so"

# ── Step 6: Create AppImage ────────────────────────────────
echo "[6/6] Creating AppImage..."
rm -rf build/AQWPocket.AppDir
mkdir -p build/AQWPocket.AppDir/lib
cp -a "$BUNDLE" build/AQWPocket.AppDir/AQWPocket-linux
cp linux/AppRun build/AQWPocket.AppDir/AppRun
chmod +x build/AQWPocket.AppDir/AppRun
cp linux/AQWPocket.desktop build/AQWPocket.AppDir/AQWPocket.desktop
cp app/icons/android-icon-192x192.png build/AQWPocket.AppDir/AQWPocket.png
EXCLUDE="linux-vdso|ld-linux|libc\.so|libm\.so|libdl\.so|libpthread|librt\.so|libresolv|libgcc_s|libstdc\+\+"
CORE_SO="build/AQWPocket.AppDir/AQWPocket-linux/Adobe AIR/Versions/1.0/libCore.so"
ldd "$CORE_SO" | grep "=> /" | grep -vE "$EXCLUDE" | awk '{print $3}' | sort -u | while read lib; do
  cp -n "$lib" build/AQWPocket.AppDir/lib/ 2>/dev/null || true
done
echo "Bundled $(ls build/AQWPocket.AppDir/lib/ | wc -l) shared libraries"
ARCH=x86_64 "$APPIMAGETOOL" build/AQWPocket.AppDir "build/$APPIMAGE_NAME"

# Cleanup
rm -rf build/AQWPocket-linux build/AQWPocket.AppDir build/_signed.air
echo "Done. AppImage: build/$APPIMAGE_NAME"
