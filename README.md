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
| `make build` | Build all primary targets |
| `make build-android` | Build Android app |
| `make build-linux` | Build Linux app |
| `make build-windows` | Build Windows app |
| `make clean` | Remove build artifacts |

Output artifacts will be in `build/`.

## Credits

Based on [aqw-mobile](https://github.com/anthony-hyo/aqw-mobile) and [Skua](https://github.com/auqw/Skua/).


