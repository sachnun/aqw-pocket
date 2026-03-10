#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/build}"
AIR_HOME="${AIR_HOME:-/opt/air_sdk}"
EXT_DIR="$ROOT_DIR/ane"
ANE_BUILD_DIR="$EXT_DIR/build"
ANDROID_CLASSES_DIR="$ANE_BUILD_DIR/android/classes"
ANDROID_DIST_DIR="$ANE_BUILD_DIR/android-dist"
ANDROID_RES_DIR="$EXT_DIR/android/res"
COMPILER_CLASSPATH="$AIR_HOME/lib/android/FlashRuntimeExtensions.jar"
ANDROID_JAR="${ANDROID_JAR:-/opt/android-sdk/platforms/android-34/android.jar}"

APP_XML="$ROOT_DIR/app/app.xml"
LOADER_SWF="$ROOT_DIR/app/Loader.swf"
GAME_SWF="$ROOT_DIR/assets/Game.swf"
GAME_SWF_IN_LOADER="$ROOT_DIR/app/gamefiles/Game.swf"
ANE_PATH="$ROOT_DIR/app/extensions/foreground.ane"

TEMP_KEYSTORE_PATH="$ROOT_DIR/temp_keystore.jks"
KEYSTORE_PATH="${KEYSTORE_PATH:-${KEYSTORE_FILE:-$TEMP_KEYSTORE_PATH}}"
KEY_ALIAS="${KEY_ALIAS:-${KEYSTORE_ALIAS:-tempalias}}"
KEYSTORE_PASS="${KEYSTORE_PASS:-${KEYSTORE_PASSWORD:-temppass}}"
KEY_PASS="${KEY_PASS:-${KEY_PASSWORD:-$KEYSTORE_PASS}}"

SKIP_PATCH="${SKIP_PATCH:-0}"
SKIP_ANE="${SKIP_ANE:-0}"
PACKAGE_TARGET="${PACKAGE_TARGET:-apk}"

ARCHES=()
for arg in "$@"; do
  case "$arg" in
    --skip-patch)
      SKIP_PATCH=1
      ;;
    --skip-ane)
      SKIP_ANE=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: ./scripts/build.sh [--skip-patch] [--skip-ane] [armv7] [armv8]

Options:
  --skip-patch  Skip Game.swf patching step
  --skip-ane    Skip foreground ANE rebuild step
  --target-aab  Build AAB instead of APK(s)
  -h, --help    Show this help message
EOF
      exit 0
      ;;
    --target-aab)
      PACKAGE_TARGET="aab"
      ;;
    armv7|armv8)
      ARCHES+=("$arg")
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Use --help to see available options."
      exit 1
      ;;
  esac
done

if [[ ${#ARCHES[@]} -eq 0 ]]; then
  ARCHES=(armv7 armv8)
fi

resolve_android_sdk_root() {
  if [[ -n "${ANDROID_SDK_ROOT:-}" && -d "${ANDROID_SDK_ROOT}" ]]; then
    printf '%s\n' "${ANDROID_SDK_ROOT}"
    return
  fi

  if [[ -n "${ANDROID_JAR:-}" ]]; then
    local sdk_root
    sdk_root="$(dirname "$(dirname "$(dirname "${ANDROID_JAR}")")")"
    if [[ -d "${sdk_root}" ]]; then
      printf '%s\n' "${sdk_root}"
      return
    fi
  fi

  return 1
}

build_foreground_ane() {
  mkdir -p "$ANE_BUILD_DIR/as3/core" "$ANDROID_CLASSES_DIR" "$ANDROID_DIST_DIR" "$ROOT_DIR/app/extensions"

  rm -rf "$ANDROID_DIST_DIR/res"
  if [[ -d "$ANDROID_RES_DIR" ]]; then
    cp -R "$ANDROID_RES_DIR" "$ANDROID_DIST_DIR/res"
  fi

  cp "$ROOT_DIR/app/src/core/ForegroundService.as" "$ANE_BUILD_DIR/as3/core/ForegroundService.as"

  "$AIR_HOME/bin/compc" \
    -source-path "$ANE_BUILD_DIR/as3" \
    -include-classes core.ForegroundService \
    -swf-version=23 \
    -output "$ANE_BUILD_DIR/foreground.swc"

  javac --release 8 \
    -cp "$ANDROID_JAR:$COMPILER_CLASSPATH" \
    -d "$ANDROID_CLASSES_DIR" \
    "$EXT_DIR/android/src/com/aqw/foreground/"*.java

  jar cf "$ANE_BUILD_DIR/foreground-ext.jar" -C "$ANDROID_CLASSES_DIR" .

  java scripts/tools.java extract-library-swf \
    "$ANE_BUILD_DIR/foreground.swc" \
    "$ANDROID_DIST_DIR/library.swf"

  cp "$ANE_BUILD_DIR/foreground-ext.jar" "$ANDROID_DIST_DIR/foreground-ext.jar"
  cp "$EXT_DIR/extension.xml" "$ANE_BUILD_DIR/extension.xml"
  cp "$EXT_DIR/platform-android.xml" "$ANDROID_DIST_DIR/platform.xml"

  "$AIR_HOME/bin/adt" -package -target ane \
    "$ANE_BUILD_DIR/foreground.ane" \
    "$ANE_BUILD_DIR/extension.xml" \
    -swc "$ANE_BUILD_DIR/foreground.swc" \
    -platform Android-ARM \
    -platformoptions "$ANDROID_DIST_DIR/platform.xml" \
    -C "$ANDROID_DIST_DIR" foreground-ext.jar library.swf res \
    -platform Android-ARM64 \
    -platformoptions "$ANDROID_DIST_DIR/platform.xml" \
    -C "$ANDROID_DIST_DIR" foreground-ext.jar library.swf res

  cp "$ANE_BUILD_DIR/foreground.ane" "$ROOT_DIR/app/extensions/foreground.ane"
}

cd "$ROOT_DIR"
mkdir -p "$OUTPUT_DIR"

if [[ "$SKIP_PATCH" != "1" ]]; then
  echo "[1/5] Patching latest Game.swf..."
  java scripts/patch.java
else
  echo "[1/5] Skip patch step (--skip-patch / SKIP_PATCH=1)"
fi

if [[ ! -f "$GAME_SWF" ]]; then
  echo "Missing file: $GAME_SWF"
  exit 1
fi

echo "[2/5] Preparing loader gamefiles..."
mkdir -p "$ROOT_DIR/app/gamefiles"
cp "$GAME_SWF" "$GAME_SWF_IN_LOADER"

if [[ "$SKIP_ANE" != "1" ]]; then
  echo "[3/5] Building foreground ANE..."
  build_foreground_ane
else
  echo "[3/5] Skip ANE rebuild (--skip-ane / SKIP_ANE=1)"
fi

if [[ ! -f "$ANE_PATH" ]]; then
  echo "Missing ANE: $ANE_PATH"
  exit 1
fi

echo "[4/5] Compiling Loader.swf..."
"$AIR_HOME/bin/amxmlc" \
  -external-library-path+="$ANE_PATH" \
  -output "$LOADER_SWF" \
  "$ROOT_DIR/app/src/Main.as"

if [[ ! -f "$KEYSTORE_PATH" ]]; then
  echo "[keystore] Creating temporary keystore: $KEYSTORE_PATH"
  keytool -genkeypair \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -keystore "$KEYSTORE_PATH" \
    -storepass "$KEYSTORE_PASS" \
    -keypass "$KEY_PASS" \
    -dname "CN=Unknown, OU=Unknown, O=Unknown, L=Unknown, S=Unknown, C=US"
fi

if [[ "$PACKAGE_TARGET" == "aab" ]]; then
  echo "[5/5] Building AAB..."
  out_aab="$OUTPUT_DIR/AQWPocket.aab"
  PLATFORM_SDK="$(resolve_android_sdk_root)"
  "$AIR_HOME/bin/adt" -package \
    -target aab \
    -storetype JKS \
    -keystore "$KEYSTORE_PATH" \
    -storepass "$KEYSTORE_PASS" \
    -keypass "$KEY_PASS" \
    "$out_aab" \
    "$APP_XML" \
    -extdir "$ROOT_DIR/app/extensions" \
    -C "$ROOT_DIR/app" \
      Loader.swf \
      icons/android-icon-36x36.png \
      icons/android-icon-48x48.png \
      icons/android-icon-72x72.png \
      icons/android-icon-96x96.png \
      icons/android-icon-144x144.png \
      icons/android-icon-192x192.png \
      gamefiles/Game.swf \
    -platformsdk "$PLATFORM_SDK"
  echo "Done. AAB output:"
  echo "- $out_aab"
else
  echo "[5/5] Building APK(s)..."
  for arch in "${ARCHES[@]}"; do
    out_apk="$OUTPUT_DIR/AQWPocket-${arch}.apk"
    echo "  - $out_apk"

    "$AIR_HOME/bin/adt" -package \
      -target apk-captive-runtime \
      -arch "$arch" \
      -storetype JKS \
      -keystore "$KEYSTORE_PATH" \
      -storepass "$KEYSTORE_PASS" \
      -keypass "$KEY_PASS" \
      "$out_apk" \
      "$APP_XML" \
      -extdir "$ROOT_DIR/app/extensions" \
      -C "$ROOT_DIR/app" \
        Loader.swf \
        icons/android-icon-36x36.png \
        icons/android-icon-48x48.png \
        icons/android-icon-72x72.png \
        icons/android-icon-96x96.png \
        icons/android-icon-144x144.png \
        icons/android-icon-192x192.png \
        gamefiles/Game.swf
  done

  echo "Done. APK output:"
  for arch in "${ARCHES[@]}"; do
    echo "- $OUTPUT_DIR/AQWPocket-${arch}.apk"
  done
fi
