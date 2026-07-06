#!/usr/bin/env bash
#
# postinstall.sh -- make usbguard-applet-qt operational after installation.
#
# The applet only talks to the org.usbguard1 D-Bus interface; it does not set
# anything up on the system. This script performs the one-time system setup:
#
#   1. Enable + start the USBGuard daemon (usbguard.service).
#   2. Enable + start the D-Bus bridge (usbguard-dbus.service) that exposes the
#      org.usbguard1 interface the applet connects to.
#   3. Grant the root-run bridge access to the daemon IPC by making sure "root"
#      is listed in IPCAllowedUsers in usbguard-daemon.conf. Without this the
#      bridge owns the D-Bus name but stays "not connected to the daemon".
#
# It is idempotent: safe to run again after every rebuild/reinstall. It needs
# root and re-execs itself through sudo if necessary.
#
set -euo pipefail

CONF=/etc/usbguard/usbguard-daemon.conf

log()  { printf '\033[1;34m::\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

# Re-exec as root if we are not already.
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  log "Elevating privileges with sudo..."
  exec sudo -- "$0" "$@"
fi

# Sanity checks.
command -v usbguard >/dev/null 2>&1 || die "usbguard is not installed."
[[ -f "$CONF" ]] || die "Daemon config not found: $CONF"
systemctl list-unit-files usbguard-dbus.service >/dev/null 2>&1 \
  || die "usbguard-dbus.service unit is missing (reinstall usbguard)."

# --- 1. Ensure root is allowed on the daemon IPC. --------------------------
# IPCAllowedUsers grants full IPC access to the listed users. The bridge runs
# as root, so root must be present. We keep any existing entries.
changed=0
if grep -qE '^[[:space:]]*IPCAllowedUsers=' "$CONF"; then
  if grep -qE '^[[:space:]]*IPCAllowedUsers=.*\broot\b' "$CONF"; then
    log "IPCAllowedUsers already grants root -- leaving it as is."
  else
    log "Adding root to the existing IPCAllowedUsers line."
    sed -i -E 's/^([[:space:]]*IPCAllowedUsers=.*)$/\1 root/' "$CONF"
    changed=1
  fi
elif grep -qE '^[[:space:]]*#[[:space:]]*IPCAllowedUsers=' "$CONF"; then
  log "Uncommenting IPCAllowedUsers and setting it to root."
  sed -i -E '0,/^[[:space:]]*#[[:space:]]*IPCAllowedUsers=.*/s//IPCAllowedUsers=root/' "$CONF"
  changed=1
else
  log "Appending IPCAllowedUsers=root to $CONF."
  printf '\nIPCAllowedUsers=root\n' >> "$CONF"
  changed=1
fi

# --- 2. Enable services at boot. -------------------------------------------
log "Enabling usbguard.service and usbguard-dbus.service at boot..."
systemctl enable usbguard.service usbguard-dbus.service >/dev/null

# --- 3. (Re)start so the daemon picks up the config and the bridge reconnects.
# Restart the daemon only if we touched its config, to avoid re-evaluating the
# USB policy for nothing. Always (re)start the bridge afterwards so it connects
# to a running daemon; the applet's watcher then reconnects within ~5 s.
if [[ $changed -eq 1 ]]; then
  log "Restarting usbguard.service (config changed)..."
  systemctl restart usbguard.service
else
  systemctl start usbguard.service
fi
log "Starting usbguard-dbus.service..."
systemctl restart usbguard-dbus.service

# --- Report. ---------------------------------------------------------------
log "Done. Status:"
printf '    usbguard.service:      %s\n' "$(systemctl is-active usbguard.service)"
printf '    usbguard-dbus.service: %s\n' "$(systemctl is-active usbguard-dbus.service)"

cat <<'EOF'

usbguard-applet-qt should now connect within ~5 seconds.
If it was already running, just relaunch it:  usbguard-applet-qt
EOF
