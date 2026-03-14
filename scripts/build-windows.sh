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
#   --output NAME    Output exe filename (default: AQWPocket-windows-x64.exe)
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

EXE_NAME="${OUTPUT:-AQWPocket-windows-x64.exe}"
WIN_RUNTIME="${AIR_WIN_RUNTIME:-/opt/air_win_sdk/runtimes/air/win}"
SFX="${SFX_MODULE:-/opt/7z-sfx/7zSD.sfx}"
BUNDLE="build/AQWPocket"

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
echo "[3/6] Compiling Loader.swf (windows)..."
amxmlc -output app/Loader.swf app/src/Main.as

# ── Step 4: Assemble Windows bundle ───────────────────────
echo "[4/6] Assembling Windows bundle..."
mkdir -p build && rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/META-INF/AIR"

# Copy Windows AIR runtime
cp -a "$WIN_RUNTIME/Adobe AIR" "$BUNDLE/"

# The captive runtime entry point for Windows
cp "$WIN_RUNTIME/Adobe AIR/Versions/1.0/Resources/CaptiveAppEntry.exe" "$BUNDLE/AQWPocket.exe"

# Application descriptor and license
cp app/app-windows.xml "$BUNDLE/META-INF/AIR/application.xml"
cp windows/license.txt "$BUNDLE/META-INF/AIR/license.txt"
echo -n "application/vnd.adobe.air-application-installer-package+zip" > "$BUNDLE/mimetype"

# Loader SWF
cp app/Loader.swf "$BUNDLE/Loader.swf"

# Icons
mkdir -p "$BUNDLE/icons"
for sz in 36 48 72 96 144 192; do
  cp "app/icons/android-icon-${sz}x${sz}.png" "$BUNDLE/icons/android-icon-${sz}x${sz}.png"
done

# Game files
mkdir -p "$BUNDLE/gamefiles"
cp app/gamefiles/Game.swf "$BUNDLE/gamefiles/Game.swf"

# ── Step 5: Patch AIR license check ───────────────────────
echo "[5/6] Patching AIR license check..."
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

# ── Step 6: Create portable exe (7z SFX) ──────────────────
echo "[6/6] Creating portable exe..."

# Create 7z archive of the bundle contents
7z a -mx=5 -r build/_bundle.7z "./$BUNDLE/*" > /dev/null

# SFX config: auto-extract to subfolder and run AQWPocket.exe
cat > build/_sfx_config.txt << 'SFXEOF'
;!@Install@!UTF-8!
Title="AQW Pocket"
ExtractDialogText="Extracting AQW Pocket..."
ExtractPathText="Extract to:"
ExtractPathDefault="AQWPocket"
RunProgram="AQWPocket\\AQWPocket.exe"
;!@InstallEnd@!
SFXEOF

# Concatenate: SFX stub + config + 7z archive = portable exe
cat "$SFX" build/_sfx_config.txt build/_bundle.7z > "build/$EXE_NAME"

# Cleanup temp files
rm -f build/_bundle.7z build/_sfx_config.txt
rm -rf "$BUNDLE"

echo "Done. Portable exe: build/$EXE_NAME"
