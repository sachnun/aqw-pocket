DOCKER     := docker compose run --rm build
SKIP_PATCH ?= 0
SKIP_ANE   ?= 0

_PATCH_FLAG = $(if $(filter 1,$(SKIP_PATCH)),--skip-patch)
_ANE_FLAG   = $(if $(filter 1,$(SKIP_ANE)),--skip-ane)

.PHONY: build build-armv7 build-armv8 build-aab build-universal \
        build-linux clean help

# ── Default: APK + Desktop ─────────────────────────────────

build: build-universal build-linux

# ── Android builds ─────────────────────────────────────────

build-armv7:
	$(DOCKER) scripts/build-android.sh --target apk-armv7 $(_PATCH_FLAG) $(_ANE_FLAG)

build-armv8:
	$(DOCKER) scripts/build-android.sh --target apk-armv8 $(_PATCH_FLAG) $(_ANE_FLAG)

build-aab:
	$(DOCKER) scripts/build-android.sh --target aab $(_PATCH_FLAG) $(_ANE_FLAG)

build-universal:
	$(DOCKER) scripts/build-android.sh --target universal $(_PATCH_FLAG) $(_ANE_FLAG)

# ── Linux AppImage ──────────────────────────────────────────

build-linux:
	$(DOCKER) scripts/build-linux.sh $(_PATCH_FLAG)

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
	@echo "  build            Build universal APK + Linux AppImage"
	@echo "  build-armv7      Build armv7 APK only"
	@echo "  build-armv8      Build armv8 APK only"
	@echo "  build-aab        Build AAB"
	@echo "  build-universal  Full pipeline: AAB -> normalize -> universal APK"
	@echo "  build-linux      Build Linux AppImage"
	@echo ""
	@echo "Options (via environment or make args):"
	@echo "  SKIP_PATCH=1     Skip Game.swf patching step"
	@echo "  SKIP_ANE=1       Skip foreground ANE rebuild (Android only)"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean            Remove all build artifacts"
	@echo "  help             Show this help message"
