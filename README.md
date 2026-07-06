# usbguard-applet-qt

A Qt system-tray applet to interact with the [USBGuard](https://usbguard.github.io/)
daemon: see the USB devices known to the daemon and allow or block them straight
from your desktop.

> Personal fork of [pinotree/usbguard-applet-qt](https://github.com/pinotree/usbguard-applet-qt),
> with Arch Linux packaging (a [`PKGBUILD`](PKGBUILD)) and a one-shot system
> setup script ([`scripts/postinstall.sh`](scripts/postinstall.sh)) added.

## How it works

The applet is only a **D-Bus client**. It talks to the `org.usbguard1` interface,
which is served by the `usbguard-dbus` bridge, which in turn connects to the
`usbguard` daemon over its IPC socket:

```
usbguard-applet-qt  ──D-Bus──▶  usbguard-dbus  ──IPC──▶  usbguard daemon
   (your session)               (usbguard-dbus.service)   (usbguard.service)
```

So three things must be true for the applet to work: the daemon runs, the D-Bus
bridge runs, and the bridge (which runs as `root`) is allowed on the daemon IPC.
The `postinstall.sh` script sets all three up.

## Requirements (Arch Linux)

- Runtime: `qt6-base`, `qt6-svg` (SVG tray icons), `usbguard`
- Build: `cmake`, `qt6-tools` (provides `lrelease`/`LinguistTools`), `pkgconf`, `gcc`, `git`

## Install

### Option A — as a pacman package (recommended)

The [`PKGBUILD`](PKGBUILD) is a VCS (`-git`) package that builds straight from
this fork:

```bash
git clone https://github.com/seeraiwer/usbguard-applet-qt.git
cd usbguard-applet-qt
makepkg -si          # builds + installs; pulls missing deps
```

Uninstall later with `sudo pacman -R usbguard-applet-qt`.

> The `pkgver()` function derives the version from `git describe`. It uses the
> upstream tag scheme (`usbguard-X.Y.Z`) when tags are present, and falls back to
> `0.r<commits>.g<sha>` when the fork has no tags — so it works either way.

### Option B — manual build

```bash
cmake -B build -S . -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build
sudo cmake --install build
```

## Post-install setup

Installing the package only drops the binary, the `.desktop` entry and the icon.
To make the applet actually operational, run the setup script once:

```bash
./scripts/postinstall.sh      # re-execs itself via sudo
```

It is idempotent (safe to re-run after every rebuild) and does exactly:

1. adds `root` to `IPCAllowedUsers` in `/etc/usbguard/usbguard-daemon.conf`
   (the root-run bridge needs IPC access to the daemon);
2. enables **and** starts `usbguard.service` and `usbguard-dbus.service`;
3. restarts the services in the right order so the bridge reconnects.

## Usage

Launch **USBGuard** from your application menu, or run `usbguard-applet-qt`.
It should show as *active* within ~5 seconds.

- Listing devices needs no password (polkit `allow_active=yes`).
- Allowing/blocking a device or editing a rule triggers a polkit admin prompt
  (`auth_admin`) — members of `wheel` can authenticate there.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `No D-Bus connection` | `usbguard-dbus.service` not running | `sudo systemctl enable --now usbguard-dbus.service` (or run `postinstall.sh`) |
| `USBGuard DBus service is not connected to the daemon` | `root` not in `IPCAllowedUsers` | run `postinstall.sh`, or add `IPCAllowedUsers=root` to `usbguard-daemon.conf` and restart both services |
| Tray icon missing / blank | `qt6-svg` not installed | `sudo pacman -S qt6-svg` |

## License

GPL-2.0-or-later. Original work by Pino Toscano and contributors — see
[`COPYING`](COPYING).