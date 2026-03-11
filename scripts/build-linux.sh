#!/bin/sh
# Shared Linux AppImage build script — used by both Makefile and CI workflows.
# Runs INSIDE the Docker build container.
#
# Usage: scripts/build-linux.sh [OPTIONS]
#
# Options:
#   --output NAME    Output AppImage filename (default: AQWPocket-x86_64.AppImage)
#   --skip-patch     Skip Game.swf patching

set -eu

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
  echo "[1/5] Patching latest Game.swf..."
  java scripts/patch.java
else
  echo "[1/5] Skip patch (--skip-patch)"
fi
test -f assets/Game.swf || { echo "Missing assets/Game.swf"; exit 1; }

# ── Step 2: Prepare gamefiles ──────────────────────────────
echo "[2/5] Preparing loader gamefiles..."
mkdir -p app/gamefiles && cp assets/Game.swf app/gamefiles/Game.swf

# ── Step 3: Compile Loader.swf ─────────────────────────────
echo "[3/5] Compiling Loader.swf (linux)..."
amxmlc -output app/Loader.swf app/src/Main.as

# ── Step 4: Assemble AIR bundle ────────────────────────────
echo "[4/5] Assembling AIR bundle..."
mkdir -p build && rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/META-INF/AIR"
cp -a "$RUNTIME/Adobe AIR" "$BUNDLE/"
cp "$RUNTIME/Adobe AIR/Versions/1.0/Resources/captiveappentry" "$BUNDLE/AQWPocket"
chmod +x "$BUNDLE/AQWPocket"
cp app/Loader.swf "$BUNDLE/Loader.swf"
cp app/app-linux.xml "$BUNDLE/META-INF/AIR/application.xml"
cp linux/license.txt "$BUNDLE/META-INF/AIR/license.txt"
echo -n "application/vnd.adobe.air-application-installer-package+zip" > "$BUNDLE/mimetype"
mkdir -p "$BUNDLE/icons"
for sz in 36 48 72 96 144 192; do
  cp "app/icons/android-icon-${sz}x${sz}.png" "$BUNDLE/icons/android-icon-${sz}x${sz}.png"
done
mkdir -p "$BUNDLE/gamefiles"
cp app/gamefiles/Game.swf "$BUNDLE/gamefiles/Game.swf"
java scripts/tools.java patch-air-license \
  "$BUNDLE/Adobe AIR/Versions/1.0/libCore.so"

# ── Step 5: Create AppImage ────────────────────────────────
echo "[5/5] Creating AppImage..."
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
rm -rf build/AQWPocket-linux build/AQWPocket.AppDir
echo "Done. AppImage: build/$APPIMAGE_NAME"
