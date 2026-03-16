DOCKER         := docker compose run --rm build
SKIP_PATCH     ?= 0
SKIP_ANE       ?= 0
ANDROID_TARGET ?= universal

_PATCH_FLAG = $(if $(filter 1,$(SKIP_PATCH)),--skip-patch)
_ANE_FLAG   = $(if $(filter 1,$(SKIP_ANE)),--skip-ane)

.PHONY: build build-android build-linux build-windows clean help

# ── Default: APK + Desktop ─────────────────────────────────

build: build-android build-linux build-windows

# ── Android builds ─────────────────────────────────────────

build-android:
	@case "$(ANDROID_TARGET)" in \
		universal) target=universal ;; \
		aab) target=aab ;; \
		armv7) target=apk-armv7 ;; \
		armv8) target=apk-armv8 ;; \
		*) echo "Invalid ANDROID_TARGET='$(ANDROID_TARGET)'. Use one of: universal, aab, armv7, armv8" >&2; exit 1 ;; \
	esac; \
	$(DOCKER) scripts/build-android.sh --target $$target $(_PATCH_FLAG) $(_ANE_FLAG)

# ── Linux AppImage ──────────────────────────────────────────

build-linux:
	$(DOCKER) scripts/build-linux.sh $(_PATCH_FLAG)

# ── Windows bundle ──────────────────────────────────────────

build-windows:
	$(DOCKER) scripts/build-windows.sh $(_PATCH_FLAG)

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
	@echo "  build          Build universal APK + Linux AppImage + Windows bundle"
	@echo "  build-android  Build Android output (default: universal APK)"
	@echo "  build-linux    Build Linux AppImage"
	@echo "  build-windows  Build Windows x64 bundle (zip)"
	@echo ""
	@echo "Options (via environment or make args):"
	@echo "  ANDROID_TARGET  Android variant for build-android (default: universal)"
	@echo "                  Values: universal, aab, armv7, armv8"
	@echo "  SKIP_PATCH=1    Skip Game.swf patching step"
	@echo "  SKIP_ANE=1      Skip foreground ANE rebuild (Android only)"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean          Remove all build artifacts"
	@echo "  help           Show this help message"
