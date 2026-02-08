#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$SCRIPT_DIR"
CONFIG_PATH="$HOME/.var/app/io.github.jeffshee.Hidamari/config/hidamari/config.json"
SERVICE="hidamari-live-wallpaper.service"
APP_ID="io.github.jeffshee.Hidamari"
LOG_FILE="$WALLPAPER_DIR/live-wallpaper.log"
LOCK_FILE="$WALLPAPER_DIR/.live-wallpaper-next.lock"
export WALLPAPER_DIR CONFIG_PATH

app_running() {
  /usr/bin/flatpak ps | /bin/grep -q "$APP_ID"
}

mkdir -p "$(dirname "$LOG_FILE")"
exec 9>"$LOCK_FILE"
if ! /usr/bin/flock -n 9; then
  exit 0
fi

echo "[$(date '+%F %T')] next: start" >>"$LOG_FILE"

NEXT_VIDEO="$(/usr/bin/python3 - <<'PY'
import json
import os
from pathlib import Path

wallpaper_dir = Path(os.environ["WALLPAPER_DIR"])
config_path = Path(os.environ["CONFIG_PATH"])
extensions = {'.mp4', '.mkv', '.webm', '.mov', '.avi', '.m4v'}

videos = sorted(str(path.resolve()) for path in wallpaper_dir.iterdir() if path.is_file() and path.suffix.lower() in extensions)
if not videos:
    raise SystemExit('NO_VIDEOS')

with config_path.open('r', encoding='utf-8') as handle:
    config = json.load(handle)

data_source = config.get('data_source', {})
if isinstance(data_source, dict):
    current = data_source.get('Default', '')
else:
    current = ''

current = os.path.realpath(current) if current else ''

if current in videos:
    next_index = (videos.index(current) + 1) % len(videos)
else:
    next_index = 0

next_video = videos[next_index]

config['mode'] = 'MODE_VIDEO'
config['is_static_wallpaper'] = False
config['is_pause_when_maximized'] = False
config['is_mute_when_maximized'] = False

if not isinstance(data_source, dict) or not data_source:
    data_source = {'Default': next_video}

for key in list(data_source.keys()):
    data_source[key] = next_video
if 'Default' not in data_source:
    data_source['Default'] = next_video
config['data_source'] = data_source

with config_path.open('w', encoding='utf-8') as handle:
    json.dump(config, handle, indent=3)

print(next_video)
PY
)"

if [[ "$NEXT_VIDEO" == "NO_VIDEOS" || -z "$NEXT_VIDEO" ]]; then
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Live Wallpaper" "No video files found in $WALLPAPER_DIR"
  fi
  echo "[$(date '+%F %T')] next: no-videos" >>"$LOG_FILE"
  exit 1
fi

/usr/bin/systemctl --user stop "$SERVICE" >/dev/null 2>&1 || true
for _ in {1..20}; do
  if ! app_running; then
    break
  fi
  /usr/bin/flatpak kill "$APP_ID" >/dev/null 2>&1 || true
  sleep 0.2
done
/usr/bin/systemctl --user start "$SERVICE"
sleep 1

if command -v notify-send >/dev/null 2>&1; then
  notify-send "Live Wallpaper" "Switched to: $(basename "$NEXT_VIDEO")"
fi

echo "[$(date '+%F %T')] next: switched -> $NEXT_VIDEO" >>"$LOG_FILE"

echo "$NEXT_VIDEO"
