#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOGGLE_SCRIPT="$SCRIPT_DIR/live-wallpaper-toggle.sh"
NEXT_SCRIPT="$SCRIPT_DIR/live-wallpaper-next.sh"
AUTOSTART_SRC="/etc/xdg/autostart/anydesk.desktop"
AUTOSTART_DST="$HOME/.config/autostart/anydesk.desktop"
SCREENSHOT_COMMAND=""

if command -v gnome-screenshot >/dev/null 2>&1; then
  SCREENSHOT_COMMAND="gnome-screenshot -i"
elif command -v flameshot >/dev/null 2>&1; then
  SCREENSHOT_COMMAND="flameshot gui"
elif command -v spectacle >/dev/null 2>&1; then
  SCREENSHOT_COMMAND="spectacle -r"
else
  SCREENSHOT_COMMAND="gnome-control-center screenshot"
fi

mkdir -p "$HOME/.config/autostart"
if [[ ! -f "$AUTOSTART_SRC" && -f "/usr/share/applications/anydesk.desktop" ]]; then
  AUTOSTART_SRC="/usr/share/applications/anydesk.desktop"
fi
if [[ -f "$AUTOSTART_SRC" ]]; then
  cp "$AUTOSTART_SRC" "$AUTOSTART_DST"
  if grep -q '^Hidden=' "$AUTOSTART_DST"; then
    sed -i 's/^Hidden=.*/Hidden=true/' "$AUTOSTART_DST"
  else
    printf '\nHidden=true\n' >>"$AUTOSTART_DST"
  fi
  if grep -q '^X-GNOME-Autostart-enabled=' "$AUTOSTART_DST"; then
    sed -i 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' "$AUTOSTART_DST"
  else
    printf 'X-GNOME-Autostart-enabled=false\n' >>"$AUTOSTART_DST"
  fi
fi

TRAY_PIDS="$( (ps -C anydesk -o pid=,args= 2>/dev/null || true) | awk '/--tray/{print $1}')"
for pid in $TRAY_PIDS; do
  if [[ -n "$pid" ]]; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
done

for _ in {1..20}; do
  if gsettings get org.gnome.mutter overlay-key >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done

export TOGGLE_SCRIPT NEXT_SCRIPT SCREENSHOT_COMMAND

/usr/bin/python3 - <<'PY'
import ast
import os
import subprocess

schema = "org.gnome.settings-daemon.plugins.media-keys"
key = "custom-keybindings"
path_toggle = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
path_next = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
path_shot = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
toggle_script = os.environ["TOGGLE_SCRIPT"]
next_script = os.environ["NEXT_SCRIPT"]
screenshot_command = os.environ["SCREENSHOT_COMMAND"]


def gsettings_set(schema_name: str, value_key: str, value: str) -> None:
    subprocess.check_call(["gsettings", "set", schema_name, value_key, value])

raw = subprocess.check_output(["gsettings", "get", schema, key], text=True).strip()
if raw.startswith("@as "):
    raw = raw[4:]
try:
    arr = ast.literal_eval(raw)
except Exception:
    arr = []

legacy_paths = {
    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/live-wallpaper-toggle/",
    "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/live-wallpaper-next/",
}
arr = [item for item in arr if item not in legacy_paths]

for item in [path_toggle, path_next, path_shot]:
    if item not in arr:
        arr.append(item)

gsettings_set(schema, key, str(arr))

base_toggle = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path_toggle}"
gsettings_set(base_toggle, "name", "Toggle Live Wallpaper")
gsettings_set(base_toggle, "command", f"/usr/bin/env bash {toggle_script}")
gsettings_set(base_toggle, "binding", "<Alt>w")

base_next = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path_next}"
gsettings_set(base_next, "name", "Next Live Wallpaper")
gsettings_set(base_next, "command", f"/usr/bin/env bash {next_script}")
gsettings_set(base_next, "binding", "<Alt>x")

base_shot = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path_shot}"
gsettings_set(base_shot, "name", "Open Screenshot Tool")
gsettings_set(base_shot, "command", screenshot_command)
gsettings_set(base_shot, "binding", "F6")

gsettings_set("org.gnome.mutter", "overlay-key", "'Super_L'")
gsettings_set("org.gnome.shell.keybindings", "toggle-overview", "['<Super>']")
gsettings_set("org.gnome.desktop.wm.keybindings", "panel-main-menu", "['<Alt>F1']")
PY

echo "Hotkeys configured:"
echo "  Super (Windows key) -> overview"
echo "  Alt+W -> toggle live wallpaper"
echo "  Alt+X -> next wallpaper in loop"
echo "  F6 -> screenshot tool"
