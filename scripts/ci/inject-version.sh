#!/bin/sh
set -eu

usage() {
  echo "Usage: $0 --manifest PATH --app-version VERSION --tag-version VERSION" >&2
  exit 1
}

MANIFEST=""
APP_VERSION=""
TAG_VERSION=""

while [ $# -gt 0 ]; do
  case "$1" in
    --manifest)
      MANIFEST="$2"
      shift 2
      ;;
    --app-version)
      APP_VERSION="$2"
      shift 2
      ;;
    --tag-version)
      TAG_VERSION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

[ -n "$MANIFEST" ] || usage
[ -n "$APP_VERSION" ] || usage
[ -n "$TAG_VERSION" ] || usage

python3 - "$MANIFEST" "$APP_VERSION" "$TAG_VERSION" <<'PY'
from pathlib import Path
import re
import sys

manifest_path = Path(sys.argv[1])
app_version = sys.argv[2]
tag_version = sys.argv[3]
config_path = Path("app/src/Config.as")

config_text = config_path.read_text(encoding="utf-8")
config_text, config_count = re.subn(
    r'APP_VERSION:String = "[^"]*"',
    f'APP_VERSION:String = "{tag_version}"',
    config_text,
    count=1,
)
if config_count != 1:
    raise SystemExit(f"Failed to update APP_VERSION in {config_path}")
config_path.write_text(config_text, encoding="utf-8")

manifest_text = manifest_path.read_text(encoding="utf-8")
manifest_text, version_count = re.subn(
    r"<versionNumber>[^<]*</versionNumber>",
    f"<versionNumber>{app_version}</versionNumber>",
    manifest_text,
    count=1,
)
manifest_text, label_count = re.subn(
    r"<versionLabel>[^<]*</versionLabel>",
    f"<versionLabel>{tag_version}</versionLabel>",
    manifest_text,
    count=1,
)

if version_count != 1 or label_count != 1:
    raise SystemExit(f"Failed to update version metadata in {manifest_path}")

manifest_path.write_text(manifest_text, encoding="utf-8")
PY
