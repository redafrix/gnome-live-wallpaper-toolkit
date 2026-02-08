# GNOME Live Wallpaper Toolkit (Hidamari)

Step-by-step setup for:
- looping video wallpaper
- hotkeys (`Super+W`, `Super+X`)
- random wallpaper at each login

This project is designed for Ubuntu GNOME with a user session (`systemd --user`).

---

## 1) Prerequisites

Install dependencies:

```bash
sudo apt update
sudo apt install -y flatpak python3
```

Install Hidamari from Flathub:

```bash
flatpak install -y flathub io.github.jeffshee.Hidamari
```

---

## 2) Put your videos in this folder

Use this folder as both project folder and wallpaper library:

`~/Pictures/wallpapers`

Supported formats:
- `.mp4`, `.mkv`, `.webm`, `.mov`, `.avi`, `.m4v`

---

## 3) Install everything

Run:

```bash
cd ~/Pictures/wallpapers
bash ./install.sh
```

This does all of the following:
- installs systemd user services
- grants Flatpak permission for this folder
- configures hotkeys
- restarts live wallpaper service

---

## 4) Hotkeys

- `Super+W` → toggle live wallpaper on/off
- `Super+X` → next wallpaper (loops through all videos in folder)

`Super` means the Windows key.

---

## 5) Random wallpaper at login

Enabled automatically by `install.sh`.

On each new login:
1. `live-wallpaper-randomize.service` picks a random video in this folder
2. `hidamari-live-wallpaper.service` starts with that selected video

---

## 6) Useful commands

Manual control:

```bash
systemctl --user start hidamari-live-wallpaper.service
systemctl --user stop hidamari-live-wallpaper.service
systemctl --user restart hidamari-live-wallpaper.service
systemctl --user status hidamari-live-wallpaper.service
```

Manual script usage:

```bash
~/Pictures/wallpapers/live-wallpaper-toggle.sh
~/Pictures/wallpapers/live-wallpaper-next.sh
~/Pictures/wallpapers/live-wallpaper-randomize.sh && systemctl --user restart hidamari-live-wallpaper.service
```

---

## 7) Troubleshooting

### Wallpaper becomes static or disappears

Re-apply Flatpak folder access and restart:

```bash
flatpak override --user --filesystem="$HOME/Pictures/wallpapers" io.github.jeffshee.Hidamari
systemctl --user restart hidamari-live-wallpaper.service
```

### Check script logs

```bash
tail -n 100 ~/Pictures/wallpapers/live-wallpaper.log
```

### Check service logs

```bash
journalctl --user -u hidamari-live-wallpaper.service -n 100 --no-pager
```

---

## 8) Project files

Scripts:
- `live-wallpaper-toggle.sh`
- `live-wallpaper-next.sh`
- `live-wallpaper-randomize.sh`
- `setup-hotkeys.sh`
- `install.sh`

Systemd units:
- `systemd/hidamari-live-wallpaper.service`
- `systemd/live-wallpaper-randomize.service`
