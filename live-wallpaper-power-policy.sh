#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="hidamari-live-wallpaper.service"
LOG_FILE="$SCRIPT_DIR/live-wallpaper.log"
STATE_FILE="$SCRIPT_DIR/.live-wallpaper-power-source"
OVERRIDE_FILE="$SCRIPT_DIR/.live-wallpaper-power-override"

get_power_source() {
  if [[ -d /sys/class/power_supply ]]; then
    local ac_online
    ac_online="$(/usr/bin/find /sys/class/power_supply -maxdepth 2 -name online -path '*/AC*/*' 2>/dev/null | /usr/bin/head -n 1 || true)"
    if [[ -n "$ac_online" && -r "$ac_online" ]]; then
      if [[ "$(/usr/bin/cat "$ac_online" 2>/dev/null)" == "1" ]]; then
        echo "ac"
      else
        echo "battery"
      fi
      return
    fi
  fi

  if command -v upower >/dev/null 2>&1; then
    local battery_dev battery_state
    battery_dev="$(upower -e | /usr/bin/grep -E 'battery|BAT' | /usr/bin/head -n 1 || true)"
    if [[ -n "$battery_dev" ]]; then
      battery_state="$(upower -i "$battery_dev" | /usr/bin/awk -F: '/state/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
      if [[ "$battery_state" == "discharging" ]]; then
        echo "battery"
      else
        echo "ac"
      fi
      return
    fi
  fi

  echo "ac"
}

apply_policy_once() {
  local power_source last_source desired service_active override
  power_source="$(get_power_source)"
  last_source=""
  if [[ -f "$STATE_FILE" ]]; then
    last_source="$(tr -d '[:space:]' <"$STATE_FILE" || true)"
  fi

  if [[ "$power_source" != "$last_source" ]]; then
    rm -f "$OVERRIDE_FILE"
    printf '%s\n' "$power_source" >"$STATE_FILE"
    echo "[$(date '+%F %T')] power-policy: source-changed -> $power_source (manual override cleared)" >>"$LOG_FILE"
  fi

  override=""
  if [[ -f "$OVERRIDE_FILE" ]]; then
    override="$(tr -d '[:space:]' <"$OVERRIDE_FILE" || true)"
  fi

  if [[ "$override" == "enabled" || "$override" == "disabled" ]]; then
    desired="$override"
  else
    if [[ "$power_source" == "battery" ]]; then
      desired="disabled"
    else
      desired="enabled"
    fi
  fi

  service_active="disabled"
  if /usr/bin/systemctl --user is-active --quiet "$SERVICE"; then
    service_active="enabled"
  fi

  if [[ "$desired" != "$service_active" ]]; then
    if [[ "$desired" == "enabled" ]]; then
      /usr/bin/systemctl --user start "$SERVICE" || true
    else
      /usr/bin/systemctl --user stop "$SERVICE" || true
    fi
    echo "[$(date '+%F %T')] power-policy: enforce=$desired source=$power_source override=${override:-none}" >>"$LOG_FILE"
  fi
}

if [[ "${1:-}" == "--once" ]]; then
  apply_policy_once
  exit 0
fi

while true; do
  apply_policy_once
  sleep 15
done
