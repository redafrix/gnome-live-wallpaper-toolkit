#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE="hidamari-live-wallpaper.service"
LOG_FILE="$SCRIPT_DIR/live-wallpaper.log"
STATE_FILE="$SCRIPT_DIR/.live-wallpaper-power-source"
OVERRIDE_FILE="$SCRIPT_DIR/.live-wallpaper-power-override"
POLL_SECONDS="${LIVE_WALLPAPER_POWER_POLL_SECONDS:-5}"

normalize_bool() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
  case "$value" in
    yes|1|true|on)
      echo "1"
      ;;
    no|0|false|off)
      echo "0"
      ;;
    *)
      echo ""
      ;;
  esac
}

detect_with_upower_line_power() {
  command -v upower >/dev/null 2>&1 || return 1

  local dev online parsed found
  found=0
  while IFS= read -r dev; do
    [[ -n "$dev" ]] || continue
    online="$(upower -i "$dev" 2>/dev/null | /usr/bin/awk -F: '/online/ {gsub(/^ +| +$/,"",$2); print $2; exit}')"
    parsed="$(normalize_bool "$online")"
    [[ -n "$parsed" ]] || continue
    found=1
    if [[ "$parsed" == "1" ]]; then
      echo "ac"
      return 0
    fi
  done < <(upower -e 2>/dev/null | /usr/bin/grep -E '/line_power_|line_power' || true)

  if [[ "$found" == "1" ]]; then
    echo "battery"
    return 0
  fi
  return 1
}

detect_with_sysfs_mains() {
  [[ -d /sys/class/power_supply ]] || return 1

  local dir type online found
  found=0
  for dir in /sys/class/power_supply/*; do
    [[ -d "$dir" ]] || continue
    [[ -r "$dir/type" ]] || continue
    type="$(cat "$dir/type" 2>/dev/null || true)"
    [[ "$type" == "Mains" ]] || continue
    found=1
    if [[ -r "$dir/online" ]]; then
      online="$(cat "$dir/online" 2>/dev/null || true)"
      if [[ "$online" == "1" ]]; then
        echo "ac"
        return 0
      fi
    fi
  done

  if [[ "$found" == "1" ]]; then
    echo "battery"
    return 0
  fi
  return 1
}

detect_with_upower_battery_state() {
  command -v upower >/dev/null 2>&1 || return 1

  local battery_dev battery_state
  battery_dev="$(upower -e 2>/dev/null | /usr/bin/grep -E 'battery|BAT' | /usr/bin/head -n 1 || true)"
  [[ -n "$battery_dev" ]] || return 1

  battery_state="$(upower -i "$battery_dev" 2>/dev/null | /usr/bin/awk -F: '/state/ {gsub(/^ +| +$/,"",$2); print tolower($2); exit}')"
  case "$battery_state" in
    discharging|pending-discharge)
      echo "battery"
      ;;
    charging|fully-charged|pending-charge|unknown|"")
      echo "ac"
      ;;
    *)
      echo "ac"
      ;;
  esac
  return 0
}

get_power_source() {
  detect_with_upower_line_power && return
  detect_with_sysfs_mains && return
  detect_with_upower_battery_state && return
  echo "ac"  # safe default for desktops/no-battery environments
}

apply_policy_once() {
  local power_source confirm_source last_source desired service_active override
  power_source="$(get_power_source)"
  last_source=""
  if [[ -f "$STATE_FILE" ]]; then
    last_source="$(tr -d '[:space:]' <"$STATE_FILE" || true)"
  fi

  if [[ "$power_source" != "$last_source" ]]; then
    sleep 1
    confirm_source="$(get_power_source)"
    if [[ "$confirm_source" != "$power_source" ]]; then
      echo "[$(date '+%F %T')] power-policy: source-change ignored (unstable) first=$power_source second=$confirm_source" >>"$LOG_FILE"
      return
    fi
    power_source="$confirm_source"
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

if [[ "${1:-}" == "--probe" ]]; then
  get_power_source
  exit 0
fi

while true; do
  apply_policy_once
  sleep "$POLL_SECONDS"
done
