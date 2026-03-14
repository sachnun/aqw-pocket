# AQW Pocket

Unofficial cross-platform AdventureQuest Worlds client.

## Download

Grab the latest build for your platform from [Releases](../../releases/latest).

> On Linux, make the AppImage executable first: `chmod +x AQWPocket-*-x86_64.AppImage`

## Features

- Touch controls (joystick + combat buttons)
- In-app update checker with release banner
- Background service support when app is minimized
- Built-in bot panel with simple farming/QoL modules

## Build

Requires [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/). All dependencies are bundled in the image.

| Target | Description |
|---|---|
| `make build` | Build all platforms (default) |
| `make build-universal` | Full pipeline: AAB -> universal APK |
| `make build-linux` | Build Linux AppImage |
| `make build-windows` | Build Windows x64 portable EXE |
| `make build-armv7` | Build armv7 APK only |
| `make build-armv8` | Build armv8 APK only |
| `make build-aab` | Build AAB |
| `make clean` | Remove all build artifacts |

Output artifacts will be in `build/`.

## Credits

Based on [aqw-mobile](https://github.com/anthony-hyo/aqw-mobile) and [Skua](https://github.com/auqw/Skua/).

## Contributing

PRs and issues are welcome.
