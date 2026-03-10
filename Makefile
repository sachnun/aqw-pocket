DOCKER := docker compose run --build --rm build

.PHONY: build build-armv7 build-armv8 build-aab build-universal \
        clean help

## Build armv7 + armv8 APKs (default)
build:
	$(DOCKER) ./scripts/build.sh

## Build armv7 APK only
build-armv7:
	$(DOCKER) ./scripts/build.sh armv7

## Build armv8 APK only
build-armv8:
	$(DOCKER) ./scripts/build.sh armv8

## Build AAB
build-aab:
	$(DOCKER) ./scripts/build.sh --target-aab

## Full pipeline: AAB -> normalize -> universal APK
build-universal:
	$(DOCKER) sh -c '\
		./scripts/build.sh --target-aab && \
		java scripts/tools.java normalize-aab \
			build/AQWPocket.aab build/AQWPocket-normalized.aab && \
		java -jar $$BUNDLETOOL_JAR build-apks \
			--bundle=build/AQWPocket-normalized.aab \
			--output=build/AQWPocket.apks \
			--mode=universal \
			--ks="$$KEYSTORE_PATH" \
			--ks-key-alias="$$KEY_ALIAS" \
			--ks-pass=pass:"$$KEYSTORE_PASS" \
			--key-pass=pass:"$$KEY_PASS" && \
		unzip -p build/AQWPocket.apks universal.apk > build/AQWPocket-universal.apk && \
		rm -f build/AQWPocket.apks build/AQWPocket-normalized.aab && \
		java scripts/tools.java inspect-native-libs build/AQWPocket-universal.apk'

## Remove all build artifacts
clean:
	rm -rf build/ assets/ app/Loader.swf app/gamefiles/ \
		app/extensions/*.ane ane/build/ scripts/*.class

## Show available targets
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Build targets:"
	@echo "  build            Build armv7 + armv8 APKs (default)"
	@echo "  build-armv7      Build armv7 APK only"
	@echo "  build-armv8      Build armv8 APK only"
	@echo "  build-aab        Build AAB"
	@echo "  build-universal  Full pipeline: AAB -> normalize -> universal APK"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean            Remove all build artifacts"
	@echo "  help             Show this help message"
