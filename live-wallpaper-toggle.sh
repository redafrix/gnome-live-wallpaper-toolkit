#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="hidamari-live-wallpaper.service"
APP_ID="io.github.jeffshee.Hidamari"
LOG_FILE="$SCRIPT_DIR/live-wallpaper.log"

app_running() {
  /usr/bin/flatpak ps | /bin/grep -q "$APP_ID"
}

mkdir -p "$(dirname "$LOG_FILE")"
{
  echo "[$(date '+%F %T')] toggle: start"
} >>"$LOG_FILE"

if systemctl --user is-active --quiet "$SERVICE"; then
  /usr/bin/systemctl --user stop "$SERVICE"
  /usr/bin/flatpak kill "$APP_ID" >/dev/null 2>&1 || true
  for _ in {1..20}; do
    if ! app_running; then
      break
    fi
    /usr/bin/flatpak kill "$APP_ID" >/dev/null 2>&1 || true
    sleep 0.2
  done
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Live Wallpaper" "Disabled"
  fi
  echo "[$(date '+%F %T')] toggle: disabled" >>"$LOG_FILE"
else
  /usr/bin/systemctl --user start "$SERVICE"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Live Wallpaper" "Enabled"
  fi
  echo "[$(date '+%F %T')] toggle: enabled" >>"$LOG_FILE"
fi
