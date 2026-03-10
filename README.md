# AQW Pocket

Unofficial AdventureQuest Worlds client for Android.

## Download

Get the latest APK from [Releases](../../releases/latest).

## Features

- Native Android client (Adobe AIR)
- Touch controls (joystick + combat buttons)
- In-app update checker with release banner
- Background service support when app is minimized
- Built-in bot panel with simple farming/QoL modules

## Build

Requires [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/). All dependencies are bundled in the image.

```bash
git clone https://github.com/sachnun/aqw-pocket.git
cd aqw-pocket
make build
```

| Target | Description |
|---|---|
| `make build` | Build armv7 + armv8 APKs (default) |
| `make build-armv7` | Build armv7 APK only |
| `make build-armv8` | Build armv8 APK only |
| `make build-aab` | Build AAB |
| `make build-universal` | Full pipeline: AAB -> universal APK |
| `make clean` | Remove all build artifacts |

Output APKs will be in `build/`.

## Credits

Based on [aqw-mobile](https://github.com/anthony-hyo/aqw-mobile) by [@anthony-hyo](https://github.com/anthony-hyo).

## Contributing

PRs and issues are welcome.
