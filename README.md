# GNOME Live Wallpaper Toolkit (Hidamari)

Simple toolkit for Ubuntu GNOME to run video wallpapers with:
- one-key toggle (`Alt+W`)
- one-key next wallpaper (`Alt+X`)
- one-key screenshot tool (`F6`)
- random wallpaper on every login
- auto battery saver (disable on battery, enable on AC)

Works with `systemd --user` + Hidamari Flatpak.

## Demo

![Demo GIF](assets/demo.gif)

## Features

- Loops through all videos in a folder (new files are auto-detected)
- Stable service startup (no terminal window required)
- Random wallpaper pre-selected before each login session starts
- Hotkeys and Windows key behavior auto-enforced at every login
- Battery policy monitor auto-manages wallpaper on AC/battery
- One-command install

## Requirements

- Ubuntu GNOME (tested on Ubuntu 22.04 X11)
- `flatpak`
- `python3`
- Hidamari Flatpak: `io.github.jeffshee.Hidamari`

Install prerequisites:

```bash
sudo apt update
sudo apt install -y flatpak python3
flatpak install -y flathub io.github.jeffshee.Hidamari
```

## Step-by-step install

1. Clone this repo into your wallpapers folder:

```bash
mkdir -p ~/Pictures
git clone https://github.com/redafrix/gnome-live-wallpaper-toolkit.git ~/Pictures/wallpapers
cd ~/Pictures/wallpapers
```

2. Add your wallpaper videos into `~/Pictures/wallpapers`.

Supported formats:
- `.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, `.m4v`

3. Run installer:

```bash
bash ./install.sh
```

Installer actions:
- installs user services
- grants Flatpak folder access
- sets hotkeys
- restarts wallpaper service

## Hotkeys

- `Super` (Windows key) → GNOME overview
- `Alt+W` → toggle wallpaper on/off
- `Alt+X` → next wallpaper (loop)
- `F6` → open screenshot tool

`Alt+W` is always a manual override:
- if you toggle while on battery, your choice stays active
- on next power-source change (plug/unplug), auto policy resumes

## How login randomization works

On every new login:
1. `live-wallpaper-randomize.service` selects a random video
2. `hidamari-live-wallpaper.service` starts Hidamari using that selection
3. `live-wallpaper-hotkeys.service` reapplies hotkeys and Super key behavior
4. `live-wallpaper-power-policy.service` enforces AC/battery behavior

## Common commands

Service control:

```bash
systemctl --user start hidamari-live-wallpaper.service
systemctl --user stop hidamari-live-wallpaper.service
systemctl --user restart hidamari-live-wallpaper.service
systemctl --user status hidamari-live-wallpaper.service
systemctl --user status live-wallpaper-power-policy.service
```

Script control:

```bash
~/Pictures/wallpapers/live-wallpaper-toggle.sh
~/Pictures/wallpapers/live-wallpaper-next.sh
~/Pictures/wallpapers/live-wallpaper-randomize.sh && systemctl --user restart hidamari-live-wallpaper.service
```

## Troubleshooting

### Wallpaper shows static image or disappears

Re-apply Flatpak folder permission and restart:

```bash
flatpak override --user --filesystem="$HOME/Pictures/wallpapers" io.github.jeffshee.Hidamari
systemctl --user restart hidamari-live-wallpaper.service
```

### Check logs

```bash
tail -n 100 ~/Pictures/wallpapers/live-wallpaper.log
journalctl --user -u hidamari-live-wallpaper.service -n 100 --no-pager
```

## Project layout

Scripts:
- `install.sh`
- `setup-hotkeys.sh`
- `live-wallpaper-toggle.sh`
- `live-wallpaper-next.sh`
- `live-wallpaper-randomize.sh`
- `live-wallpaper-power-policy.sh`

Systemd units:
- `systemd/hidamari-live-wallpaper.service`
- `systemd/live-wallpaper-randomize.service`
- `systemd/live-wallpaper-hotkeys.service`
- `systemd/live-wallpaper-power-policy.service`
