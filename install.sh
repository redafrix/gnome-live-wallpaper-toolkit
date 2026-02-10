#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEMD_DIR="$HOME/.config/systemd/user"
APP_ID="io.github.jeffshee.Hidamari"

mkdir -p "$SYSTEMD_DIR"

install -m 644 "$SCRIPT_DIR/systemd/hidamari-live-wallpaper.service" "$SYSTEMD_DIR/hidamari-live-wallpaper.service"
install -m 644 "$SCRIPT_DIR/systemd/live-wallpaper-randomize.service" "$SYSTEMD_DIR/live-wallpaper-randomize.service"
install -m 644 "$SCRIPT_DIR/systemd/live-wallpaper-hotkeys.service" "$SYSTEMD_DIR/live-wallpaper-hotkeys.service"
install -m 644 "$SCRIPT_DIR/systemd/live-wallpaper-power-policy.service" "$SYSTEMD_DIR/live-wallpaper-power-policy.service"

chmod +x \
  "$SCRIPT_DIR/live-wallpaper-toggle.sh" \
  "$SCRIPT_DIR/live-wallpaper-next.sh" \
  "$SCRIPT_DIR/live-wallpaper-randomize.sh" \
  "$SCRIPT_DIR/live-wallpaper-power-policy.sh" \
  "$SCRIPT_DIR/setup-hotkeys.sh"

/usr/bin/flatpak override --user --filesystem="$SCRIPT_DIR" "$APP_ID"
/usr/bin/systemctl --user daemon-reload
/usr/bin/systemctl --user enable hidamari-live-wallpaper.service live-wallpaper-randomize.service live-wallpaper-hotkeys.service live-wallpaper-power-policy.service

bash "$SCRIPT_DIR/setup-hotkeys.sh"

/usr/bin/systemctl --user restart hidamari-live-wallpaper.service
/usr/bin/systemctl --user start live-wallpaper-hotkeys.service
/usr/bin/systemctl --user restart live-wallpaper-power-policy.service
echo "Install complete."
