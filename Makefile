DOCKER_RUN_ARGS ?=
REGISTRY       ?= ghcr.io/sachnun/aqw-pocket
ANDROID_IMAGE  ?= $(REGISTRY):build-android
LINUX_IMAGE    ?= $(REGISTRY):build-linux
WINDOWS_IMAGE  ?= $(REGISTRY):build-windows
DOCKER_RUN      = docker compose run --rm $(DOCKER_RUN_ARGS) build

SKIP_PATCH     ?= 0
SKIP_ANE       ?= 0
ANDROID_TARGET ?= armv8
ANDROID_OUTPUT ?=
LINUX_OUTPUT   ?=
WINDOWS_OUTPUT ?=

_PATCH_FLAG          = $(if $(filter 1,$(SKIP_PATCH)),--skip-patch)
_ANE_FLAG            = $(if $(filter 1,$(SKIP_ANE)),--skip-ane)
_ANDROID_OUTPUT_FLAG = $(if $(strip $(ANDROID_OUTPUT)),--output "$(ANDROID_OUTPUT)")
_LINUX_OUTPUT_FLAG   = $(if $(strip $(LINUX_OUTPUT)),--output "$(LINUX_OUTPUT)")
_WINDOWS_OUTPUT_FLAG = $(if $(strip $(WINDOWS_OUTPUT)),--output "$(WINDOWS_OUTPUT)")

export KEYSTORE_PATH KEYSTORE_FILE KEY_ALIAS KEYSTORE_ALIAS KEYSTORE_PASS KEYSTORE_PASSWORD KEY_PASS KEY_PASSWORD

.PHONY: build build-android build-linux build-windows clean help

# ── Default: APK + Desktop ─────────────────────────────────

build: build-android build-linux build-windows

# ── Android builds ─────────────────────────────────────────

build-android:
	@case "$(ANDROID_TARGET)" in \
		armv7) target=apk-armv7 ;; \
		armv8) target=apk-armv8 ;; \
		*) echo "Invalid ANDROID_TARGET='$(ANDROID_TARGET)'. Use one of: armv7, armv8" >&2; exit 1 ;; \
	esac; \
	BUILD_IMAGE=$${BUILD_IMAGE:-$(ANDROID_IMAGE)} $(DOCKER_RUN) scripts/build-android.sh --target $$target $(_ANDROID_OUTPUT_FLAG) $(_PATCH_FLAG) $(_ANE_FLAG)

# ── Linux AppImage ──────────────────────────────────────────

build-linux:
	BUILD_IMAGE=$${BUILD_IMAGE:-$(LINUX_IMAGE)} $(DOCKER_RUN) scripts/build-linux.sh $(_LINUX_OUTPUT_FLAG) $(_PATCH_FLAG)

# ── Windows bundle ──────────────────────────────────────────

build-windows:
	BUILD_IMAGE=$${BUILD_IMAGE:-$(WINDOWS_IMAGE)} $(DOCKER_RUN) scripts/build-windows.sh $(_WINDOWS_OUTPUT_FLAG) $(_PATCH_FLAG)

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
	@echo "  build          Build armv8 APK + Linux AppImage + Windows bundle"
	@echo "  build-android  Build Android APK (default: armv8)"
	@echo "  build-linux    Build Linux AppImage"
	@echo "  build-windows  Build Windows portable exe"
	@echo ""
	@echo "Options (via environment or make args):"
	@echo "  ANDROID_TARGET  Android arch for build-android (default: armv8)"
	@echo "                  Values: armv7, armv8"
	@echo "  ANDROID_OUTPUT  Custom filename for build-android"
	@echo "  LINUX_OUTPUT    Custom filename for build-linux"
	@echo "  WINDOWS_OUTPUT  Custom filename for build-windows"
	@echo "  SKIP_PATCH=1    Skip Game.swf patching step"
	@echo "  SKIP_ANE=1      Skip foreground ANE rebuild (Android only)"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean          Remove all build artifacts"
	@echo "  help           Show this help message"
