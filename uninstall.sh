#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Remove Puhuri from the phone (the click and both user services).
#
#   PUHELIMEN_SALASANA=... ./uninstall.sh [--purge]
#
# --purge also removes Puhuri's private data, settings and cache - without it
# the state stays, which is what an upgrade wants.
set -eu

PROJECT=$(cd "$(dirname "$0")" && pwd)
. "$PROJECT/tools/phone-sudo-remote.sh"

PURGE=0
[ "${1:-}" = "--purge" ] && PURGE=1

remote() {
    if [ "$MODE" = "adb" ]; then
        adb -s "$SERIAL" shell "$1"
    else
        # shellcheck disable=SC2086
        ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=10 -i "$KEY" "$HOST" "$1"
    fi
}

echo "--- palvelut pois"
remote 'export XDG_RUNTIME_DIR=/run/user/$(id -u);
  systemctl --user disable --now puhuri-indicator.service 2>/dev/null || true;
  systemctl --user disable --now puhurid.service 2>/dev/null || true;
  systemctl --user reset-failed puhuri-indicator.service puhurid.service 2>/dev/null || true;
  rm -f ~/.config/systemd/user/puhuri-indicator.service ~/.config/systemd/user/puhurid.service ~/.local/lib/fi.reijo.puhuri/puhurid ~/.local/lib/fi.reijo.puhuri/puhuri-ctl;
  rmdir ~/.local/lib/fi.reijo.puhuri 2>/dev/null || true;
  systemctl --user daemon-reload'

echo "--- click pois"
[ -n "${PUHELIMEN_SALASANA:-}" ] || {
    echo "VIRKE: aseta PUHELIMEN_SALASANA=..." >&2
    exit 1
}
phone_sudo_remote \
    "click unregister --user=phablet fi.reijo.puhuri"
phone_sudo_remote \
    "find /var/cache/apparmor -mindepth 2 -maxdepth 2 -type d -name 'click_fi.reijo.puhuri*' -exec rm -rf {} +"

if [ "$PURGE" = "1" ]; then
    echo "--- tila pois"
    remote 'rm -rf ~/.local/share/fi.reijo.puhuri ~/.config/fi.reijo.puhuri ~/.cache/fi.reijo.puhuri'
fi

echo "--- jäljellä:"
remote "click list | grep fi.reijo.puhuri || echo 'ei asennettu'"
