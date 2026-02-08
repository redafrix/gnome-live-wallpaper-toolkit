#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$SCRIPT_DIR"
CONFIG_PATH="$HOME/.var/app/io.github.jeffshee.Hidamari/config/hidamari/config.json"
LOCK_FILE="$WALLPAPER_DIR/.live-wallpaper-randomize.lock"
export WALLPAPER_DIR CONFIG_PATH

exec 9>"$LOCK_FILE"
if ! /usr/bin/flock -n 9; then
  exit 0
fi

SELECTED_VIDEO="$(
/usr/bin/python3 - <<'PY'
import json
import random
import os
from pathlib import Path

wallpaper_dir = Path(os.environ["WALLPAPER_DIR"])
config_path = Path(os.environ["CONFIG_PATH"])
extensions = {".mp4", ".mkv", ".webm", ".mov", ".avi", ".m4v"}

videos = sorted(
    str(path.resolve())
    for path in wallpaper_dir.iterdir()
    if path.is_file() and path.suffix.lower() in extensions
)

if not videos:
    print("NO_VIDEOS")
    raise SystemExit(0)

selected = random.SystemRandom().choice(videos)

with config_path.open("r", encoding="utf-8") as handle:
    config = json.load(handle)

config["mode"] = "MODE_VIDEO"
config["is_static_wallpaper"] = False
config["is_pause_when_maximized"] = False
config["is_mute_when_maximized"] = False

data_source = config.get("data_source", {})
if not isinstance(data_source, dict) or not data_source:
    data_source = {"Default": selected}

for key in list(data_source.keys()):
    data_source[key] = selected
if "Default" not in data_source:
    data_source["Default"] = selected

config["data_source"] = data_source

with config_path.open("w", encoding="utf-8") as handle:
    json.dump(config, handle, indent=3)

print(selected)
PY
)"

if [[ "$SELECTED_VIDEO" == "NO_VIDEOS" || -z "$SELECTED_VIDEO" ]]; then
  exit 0
fi

if [[ "${1:-}" != "--prepare-only" ]] && command -v notify-send >/dev/null 2>&1; then
  notify-send "Live Wallpaper" "Random wallpaper: $(basename "$SELECTED_VIDEO")"
fi

echo "$SELECTED_VIDEO"
