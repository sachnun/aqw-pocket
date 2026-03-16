#!/bin/sh
# Shared Windows build script — used by both Makefile and CI workflows.
# Runs INSIDE the Docker build container.
#
# Produces a single portable .exe (7-Zip SFX) that auto-extracts and
# launches AQWPocket.exe on first run.
#
# Usage: scripts/build-windows.sh [OPTIONS]
#
# Options:
#   --output NAME    Output exe filename (default: AQWPocket-windows.exe)
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

EXE_NAME="${OUTPUT:-AQWPocket-windows.exe}"
WIN_RUNTIME="${AIR_WIN_RUNTIME:-/opt/air_win_sdk/runtimes/air/win}"
SFX="${SFX_MODULE:-/opt/7z-sfx/7zSD.sfx}"
BUNDLE="build/AQWPocket"

# ── Step 1: Patch Game.swf ─────────────────────────────────
if [ "$SKIP_PATCH" != "1" ]; then
  echo "[1/7] Patching latest Game.swf..."
  java scripts/patch.java
else
  echo "[1/7] Skip patch (--skip-patch)"
fi
test -f assets/Game.swf || { echo "Missing assets/Game.swf"; exit 1; }

# ── Step 2: Prepare gamefiles ──────────────────────────────
echo "[2/7] Preparing loader gamefiles..."
mkdir -p app/gamefiles && cp assets/Game.swf app/gamefiles/Game.swf

# ── Step 3: Compile Loader.swf ─────────────────────────────
echo "[3/7] Compiling Loader.swf (windows)..."
amxmlc -output app/Loader.swf app/src/Main.as

# ── Step 4: Sign content with adt ─────────────────────────
# CaptiveAppEntry.exe requires META-INF/signatures.xml and
# META-INF/AIR/hash to load the application. We create a signed
# .air package (cross-platform) and extract these artifacts.
# Uses a persistent PKCS12 certificate in CI, with a local dev fallback.
echo "[4/7] Signing application content..."
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
  app/app-windows.xml \
  -C app Loader.swf gamefiles icons

# ── Step 5: Assemble Windows bundle ───────────────────────
echo "[5/7] Assembling Windows bundle..."
rm -rf "$BUNDLE"

# Extract signed content (includes META-INF with signatures + hash)
mkdir -p "$BUNDLE"
cd "$BUNDLE" && unzip -q ../../build/_signed.air && cd ../..

# Copy Windows AIR runtime
cp -a "$WIN_RUNTIME/Adobe AIR" "$BUNDLE/"

# The captive runtime entry point for Windows
cp "$WIN_RUNTIME/Adobe AIR/Versions/1.0/Resources/CaptiveAppEntry.exe" "$BUNDLE/AQWPocket.exe"

# ── Step 6: Patch AIR runtime ──────────────────────────────
echo "[6/7] Patching AIR runtime..."
WIN_DLL="$BUNDLE/Adobe AIR/Versions/1.0/Adobe AIR.dll"
if [ -f "$WIN_DLL" ]; then
  java scripts/tools.java patch-air-license "$WIN_DLL"
else
  echo "Warning: Adobe AIR.dll not found at expected path, searching..."
  DLL_FOUND=0
  for dll in "$BUNDLE/Adobe AIR/Versions/1.0/"*.dll "$BUNDLE/Adobe AIR/"*.dll; do
    if [ -f "$dll" ]; then
      echo "Trying to patch: $dll"
      if java scripts/tools.java patch-air-license "$dll" 2>/dev/null; then
        DLL_FOUND=1
        break
      fi
    fi
  done
  if [ "$DLL_FOUND" = "0" ]; then
    echo "ERROR: Could not find and patch any Windows AIR runtime DLL"
    echo "Contents of $BUNDLE/Adobe AIR/:"
    find "$BUNDLE/Adobe AIR/" -type f -name "*.dll" 2>/dev/null || true
    exit 1
  fi
fi

# ── Step 7: Create portable exe (7z SFX) ──────────────────
echo "[7/7] Creating portable exe..."

# Create 7z archive of the bundle contents
7z a -mx=5 -r build/_bundle.7z "./$BUNDLE/*" > /dev/null

# SFX config: auto-extract to subfolder and run AQWPocket.exe
# 7zSD.sfx requires Windows CRLF line endings to parse the config
printf ';!@Install@!UTF-8!\r\n' > build/_sfx_config.txt
printf 'Title="AQW Pocket"\r\n' >> build/_sfx_config.txt
printf 'ExtractDialogText="Extracting AQW Pocket..."\r\n' >> build/_sfx_config.txt
printf 'ExtractPathText="Extract to:"\r\n' >> build/_sfx_config.txt
printf 'ExtractPathDefault="AQWPocket"\r\n' >> build/_sfx_config.txt
printf 'RunProgram="AQWPocket.exe"\r\n' >> build/_sfx_config.txt
printf ';!@InstallEnd@!\r\n' >> build/_sfx_config.txt

# Concatenate: SFX stub + config + 7z archive = portable exe
cat "$SFX" build/_sfx_config.txt build/_bundle.7z > "build/$EXE_NAME"

# Cleanup temp files
rm -f build/_bundle.7z build/_sfx_config.txt build/_signed.air
rm -rf "$BUNDLE"

echo "Done. Portable exe: build/$EXE_NAME"
