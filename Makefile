DOCKER     := docker compose run --build --rm build
SKIP_PATCH ?= 0
SKIP_ANE   ?= 0

.PHONY: build build-armv7 build-armv8 build-aab build-universal \
        build-linux clean help

# ── Default: APK + Desktop ─────────────────────────────────

build: build-universal build-linux

# ── Target-specific variables ───────────────────────────────

build-armv7:     ARCHES = armv7
build-armv7:     PKG = apk
build-armv8:     ARCHES = armv8
build-armv8:     PKG = apk
build-aab:       PKG = aab
build-universal: PKG = universal

# ── Android builds (shared recipe) ─────────────────────────

build-armv7 build-armv8 build-aab build-universal:
	$(DOCKER) sh -c '\
	set -eu && \
	ICONS="icons/android-icon-36x36.png icons/android-icon-48x48.png icons/android-icon-72x72.png icons/android-icon-96x96.png icons/android-icon-144x144.png icons/android-icon-192x192.png" && \
	\
	if [ "$(SKIP_PATCH)" != "1" ]; then \
	  echo "[1/5] Patching latest Game.swf..." && java scripts/patch.java; \
	else \
	  echo "[1/5] Skip patch (SKIP_PATCH=1)"; \
	fi && \
	test -f assets/Game.swf || { echo "Missing assets/Game.swf"; exit 1; } && \
	\
	echo "[2/5] Preparing loader gamefiles..." && \
	mkdir -p app/gamefiles && cp assets/Game.swf app/gamefiles/Game.swf && \
	\
	if [ "$(SKIP_ANE)" != "1" ]; then \
	  echo "[3/5] Building foreground ANE..." && \
	  mkdir -p ane/build/as3/core ane/build/android/classes ane/build/android-dist app/extensions && \
	  rm -rf ane/build/android-dist/res && \
	  if [ -d ane/android/res ]; then cp -R ane/android/res ane/build/android-dist/res; fi && \
	  cp app/src/core/ForegroundService.as ane/build/as3/core/ForegroundService.as && \
	  compc -source-path ane/build/as3 -include-classes core.ForegroundService \
	    -swf-version=23 -output ane/build/foreground.swc && \
	  javac --release 8 \
	    -cp "$$ANDROID_JAR:$$AIR_HOME/lib/android/FlashRuntimeExtensions.jar" \
	    -d ane/build/android/classes ane/android/src/com/aqw/foreground/*.java && \
	  jar cf ane/build/foreground-ext.jar -C ane/build/android/classes . && \
	  java scripts/tools.java extract-library-swf \
	    ane/build/foreground.swc ane/build/android-dist/library.swf && \
	  cp ane/build/foreground-ext.jar ane/build/android-dist/foreground-ext.jar && \
	  cp ane/extension.xml ane/build/extension.xml && \
	  cp ane/platform-android.xml ane/build/android-dist/platform.xml && \
	  adt -package -target ane ane/build/foreground.ane ane/build/extension.xml \
	    -swc ane/build/foreground.swc \
	    -platform Android-ARM -platformoptions ane/build/android-dist/platform.xml \
	      -C ane/build/android-dist foreground-ext.jar library.swf res \
	    -platform Android-ARM64 -platformoptions ane/build/android-dist/platform.xml \
	      -C ane/build/android-dist foreground-ext.jar library.swf res && \
	  cp ane/build/foreground.ane app/extensions/foreground.ane; \
	else \
	  echo "[3/5] Skip ANE (SKIP_ANE=1)"; \
	fi && \
	test -f app/extensions/foreground.ane || { echo "Missing ANE: app/extensions/foreground.ane"; exit 1; } && \
	\
	echo "[4/5] Compiling Loader.swf..." && \
	amxmlc -external-library-path+=app/extensions/foreground.ane \
	  -output app/Loader.swf app/src/Main.as && \
	\
	KS="$${KEYSTORE_PATH:-$${KEYSTORE_FILE:-.signing/dev.jks}}" && \
	KA="$${KEY_ALIAS:-$${KEYSTORE_ALIAS:-dev}}" && \
	KP="$${KEYSTORE_PASS:-$${KEYSTORE_PASSWORD:-devpass}}" && \
	KKP="$${KEY_PASS:-$${KEY_PASSWORD:-$$KP}}" && \
	if [ ! -f "$$KS" ]; then \
	  echo "[keystore] Creating dev keystore at $$KS..." && \
	  mkdir -p "$$(dirname "$$KS")" && \
	  keytool -genkeypair -alias "$$KA" -keyalg RSA -keysize 2048 -validity 10000 \
	    -keystore "$$KS" -storepass "$$KP" -keypass "$$KKP" \
	    -dname "CN=AQW Pocket Dev, OU=Dev, O=Community, L=Unknown, S=Unknown, C=US"; \
	fi && \
	mkdir -p build && \
	\
	if [ "$(PKG)" = "apk" ]; then \
	  echo "[5/5] Building APK(s)..." && \
	  for arch in $(ARCHES); do \
	    echo "  - build/AQWPocket-$$arch.apk" && \
	    adt -package -target apk-captive-runtime -arch "$$arch" \
	      -storetype JKS -keystore "$$KS" -storepass "$$KP" -keypass "$$KKP" \
	      "build/AQWPocket-$$arch.apk" app/app.xml -extdir app/extensions \
	      -C app Loader.swf $$ICONS gamefiles/Game.swf; \
	  done; \
	elif [ "$(PKG)" = "aab" ]; then \
	  echo "[5/5] Building AAB..." && \
	  adt -package -target aab \
	    -storetype JKS -keystore "$$KS" -storepass "$$KP" -keypass "$$KKP" \
	    build/AQWPocket.aab app/app.xml -extdir app/extensions \
	    -C app Loader.swf $$ICONS gamefiles/Game.swf \
	    -platformsdk "$$ANDROID_SDK_ROOT" && \
	  echo "Done. AAB: build/AQWPocket.aab"; \
	elif [ "$(PKG)" = "universal" ]; then \
	  echo "[5/5] Building AAB..." && \
	  adt -package -target aab \
	    -storetype JKS -keystore "$$KS" -storepass "$$KP" -keypass "$$KKP" \
	    build/AQWPocket.aab app/app.xml -extdir app/extensions \
	    -C app Loader.swf $$ICONS gamefiles/Game.swf \
	    -platformsdk "$$ANDROID_SDK_ROOT" && \
	  echo "Normalizing AAB..." && \
	  java scripts/tools.java normalize-aab \
	    build/AQWPocket.aab build/AQWPocket-normalized.aab && \
	  java -jar $$BUNDLETOOL_JAR build-apks \
	    --bundle=build/AQWPocket-normalized.aab --output=build/AQWPocket.apks \
	    --mode=universal \
	    --ks="$$KS" --ks-key-alias="$$KA" \
	    --ks-pass=pass:"$$KP" --key-pass=pass:"$$KKP" && \
	  unzip -p build/AQWPocket.apks universal.apk > build/AQWPocket-universal.apk && \
	  rm -f build/AQWPocket.apks build/AQWPocket-normalized.aab && \
	  java scripts/tools.java inspect-native-libs build/AQWPocket-universal.apk && \
	  echo "Done. Universal APK: build/AQWPocket-universal.apk"; \
	fi && \
	echo "Done."'

# ── Linux bundle ────────────────────────────────────────────

build-linux:
	$(DOCKER) sh -c '\
	set -eu && \
	\
	if [ "$(SKIP_PATCH)" != "1" ]; then \
	  echo "[1/4] Patching latest Game.swf..." && java scripts/patch.java; \
	else \
	  echo "[1/4] Skip patch (SKIP_PATCH=1)"; \
	fi && \
	test -f assets/Game.swf || { echo "Missing assets/Game.swf"; exit 1; } && \
	\
	echo "[2/4] Preparing loader gamefiles..." && \
	mkdir -p app/gamefiles && cp assets/Game.swf app/gamefiles/Game.swf && \
	\
	echo "[3/4] Compiling Loader.swf (linux)..." && \
	amxmlc -output app/Loader.swf app/src/Main.as && \
	\
	P12=".signing/dev.p12" && \
	P12_PASS="devpass" && \
	if [ ! -f "$$P12" ]; then \
	  echo "[cert] Creating dev certificate at $$P12..." && \
	  mkdir -p .signing && \
	  adt -certificate -cn "AQW Pocket Dev" 2048-RSA "$$P12" "$$P12_PASS"; \
	fi && \
	\
	echo "[4/4] Packaging linux bundle..." && \
	mkdir -p build && rm -rf build/AQWPocket-linux && \
	adt -package \
	  -storetype pkcs12 -keystore "$$P12" -storepass "$$P12_PASS" \
	  -target bundle build/AQWPocket-linux app/app-linux.xml \
	  -C app Loader.swf \
	  icons/android-icon-36x36.png icons/android-icon-48x48.png \
	  icons/android-icon-72x72.png icons/android-icon-96x96.png \
	  icons/android-icon-144x144.png icons/android-icon-192x192.png \
	  gamefiles/Game.swf && \
	echo "Done. Linux bundle: build/AQWPocket-linux/"'

# ── Utilities ───────────────────────────────────────────────

## Remove all build artifacts
clean:
	rm -rf build/ assets/ app/Loader.swf app/gamefiles/ \
		app/extensions/*.ane ane/build/ scripts/*.class

## Show available targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build targets:"
	@echo "  build            Build universal APK + Linux bundle"
	@echo "  build-armv7      Build armv7 APK only"
	@echo "  build-armv8      Build armv8 APK only"
	@echo "  build-aab        Build AAB"
	@echo "  build-universal  Full pipeline: AAB -> normalize -> universal APK"
	@echo "  build-linux      Build Linux bundle"
	@echo ""
	@echo "Options (via environment or make args):"
	@echo "  SKIP_PATCH=1     Skip Game.swf patching step"
	@echo "  SKIP_ANE=1       Skip foreground ANE rebuild (Android only)"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean            Remove all build artifacts"
	@echo "  help             Show this help message"
