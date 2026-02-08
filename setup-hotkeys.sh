#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOGGLE_SCRIPT="$SCRIPT_DIR/live-wallpaper-toggle.sh"
NEXT_SCRIPT="$SCRIPT_DIR/live-wallpaper-next.sh"
export TOGGLE_SCRIPT NEXT_SCRIPT

/usr/bin/python3 - <<'PY'
import ast
import os
import subprocess

schema = "org.gnome.settings-daemon.plugins.media-keys"
key = "custom-keybindings"
path_toggle = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/live-wallpaper-toggle/"
path_next = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/live-wallpaper-next/"
toggle_script = os.environ["TOGGLE_SCRIPT"]
next_script = os.environ["NEXT_SCRIPT"]

raw = subprocess.check_output(["gsettings", "get", schema, key], text=True).strip()
if raw.startswith("@as "):
    raw = raw[4:]
try:
    arr = ast.literal_eval(raw)
except Exception:
    arr = []

for item in [path_toggle, path_next]:
    if item not in arr:
        arr.append(item)

subprocess.check_call(["gsettings", "set", schema, key, str(arr)])

base_toggle = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path_toggle}"
subprocess.check_call(["gsettings", "set", base_toggle, "name", "Toggle Live Wallpaper"])
subprocess.check_call(["gsettings", "set", base_toggle, "command", f"/usr/bin/env bash {toggle_script}"])
subprocess.check_call(["gsettings", "set", base_toggle, "binding", "<Super>w"])

base_next = f"org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path_next}"
subprocess.check_call(["gsettings", "set", base_next, "name", "Next Live Wallpaper"])
subprocess.check_call(["gsettings", "set", base_next, "command", f"/usr/bin/env bash {next_script}"])
subprocess.check_call(["gsettings", "set", base_next, "binding", "<Super>x"])
PY

echo "Hotkeys configured:"
echo "  Super+W -> toggle live wallpaper"
echo "  Super+X -> next wallpaper in loop"
