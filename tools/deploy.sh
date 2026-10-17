#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Install Puhuri on the phone: the service and the click.
#
#   PUHELIMEN_SALASANA=... tools/deploy.sh
#
# The background service is a systemd *user* service, so installing it needs
# no root at all - it lives in the phablet user's own home directory. Only the
# click package needs the device password (it goes to /opt/click.ubuntu.com,
# which belongs to clickpkg), exactly like in the mail project.
#
# Everything goes over SSH (the phone is usually on Wi-Fi without USB);
# PUHURI_DEPLOY=adb switches to adb when the cable is plugged in.
set -eu

PROJECT=$(cd "$(dirname "$0")/.." && pwd)
. "$PROJECT/tools/phone-sudo-remote.sh"

SERIAL=${PUHELIN_SARJANUMERO:?aseta PUHELIN_SARJANUMERO}
HOST=${PHONE_HOST:?aseta PHONE_HOST}
KEY=${PHONE_KEY:?aseta PHONE_KEY}
MODE=${PUHURI_DEPLOY:-ssh}

SSH="ssh -F /dev/null -o BatchMode=yes -o ConnectTimeout=10 -i $KEY"

for binary in puhurid puhuri-ctl; do
    [ -x "$PROJECT/build/$binary" ] || {
        echo "Puuttuu $PROJECT/build/$binary. Aja ensin tools/build-daemon.sh" >&2
        exit 1
    }
done

# The click is rebuilt here on purpose. Installing whatever .click happened to
# be newest in dist/ once shipped a stale user interface to the phone: the
# linking page still showed a QR code the daemon had already replaced, and
# every scan failed. Set PUHURI_SKIP_BUILD=1 to install the package as it is.
if [ "${PUHURI_SKIP_BUILD:-0}" != "1" ]; then
    echo "--- click-paketti rakennetaan lähdekoodista"
    "$PROJECT/tools/build.sh"
fi

send() {  # send <local file> <remote path>
    if [ "$MODE" = "adb" ]; then
        adb -s "$SERIAL" push "$1" "$2" >/dev/null
    else
        # shellcheck disable=SC2086
        $SSH "$HOST" "cat > '$2'" < "$1"
    fi
}

remote() {  # remote <shell command>
    if [ "$MODE" = "adb" ]; then
        adb -s "$SERIAL" shell "$1"
    else
        # shellcheck disable=SC2086
        $SSH "$HOST" "$1"
    fi
}

PACKAGE=$(ls -t "$PROJECT"/dist/*.click 2>/dev/null | head -1 || true)
[ -n "$PACKAGE" ] || {
    echo "Ei .click-pakettia hakemistossa dist/. Aja ensin tools/build.sh" >&2
    exit 1
}
# The Rust binary is not rebuilt automatically (it takes a long time), but a
# newer source tree than the binary is worth saying out loud.
if [ -n "$(find "$PROJECT/daemon/src" -newer "$PROJECT/build/puhurid" -name '*.rs' -print -quit)" ]; then
    echo "VAROITUS: daemon/src on uudempi kuin build/puhurid - aja tools/build-daemon.sh" >&2
fi

NAME=$(basename "$PACKAGE")

echo "--- palvelu puhelimeen"
# The click hook generates the user service; stop the old instance before the
# hook files are replaced.
remote 'export XDG_RUNTIME_DIR=/run/user/$(id -u); systemctl --user stop puhurid.service 2>/dev/null || true'
# Remove the old pre-click-hook installation; the click now owns the service.
remote 'rm -f ~/.local/lib/fi.reijo.puhuri/puhurid ~/.local/lib/fi.reijo.puhuri/puhuri-ctl ~/.local/bin/puhuri-ctl; rmdir ~/.local/lib/fi.reijo.puhuri 2>/dev/null || true'

echo "--- click-paketti"
send "$PACKAGE" "/home/phablet/$NAME"
[ -n "${PUHELIMEN_SALASANA:-}" ] || {
    echo "VIRHE: aseta PUHELIMEN_SALASANA=... (click-asennus tarvitsee rootin)" >&2
    exit 1
}
phone_sudo_remote \
    "click install --user phablet --allow-unauthenticated /home/phablet/$NAME"
remote "rm -f /home/phablet/$NAME"

# Reinstalling the same version does not regenerate the AppArmor profile, so a
# change to the click's policy groups (for example adding `audio`) would never
# take effect. That cost an evening: the sound was denied silently.
echo "--- AppArmor-profiili uudistetaan"
phone_sudo_remote "aa-clickhook -f >/dev/null 2>&1; echo uudistettu"

echo "--- click-hookit uuteen tilaan"
remote \
    'export XDG_RUNTIME_DIR=/run/user/$(id -u); systemctl --user daemon-reload'

# A running app keeps the QML it loaded. Start the click after installation:
# its first Python connection installs and starts the bundled user service.
echo "--- sovellus käynnistetään (click asentaa palvelun itse)"
remote \
    'export XDG_RUNTIME_DIR=/run/user/$(id -u);
     pid=$(pgrep -f "qt5/bin/qmlscen[e]" | head -1);
     if [ -n "$pid" ]; then
         # Lomiri suspends a backgrounded app, and a stopped process does not
         # act on SIGTERM (it stays stopped with the signal pending), so the
         # app has to be woken first - otherwise the old user interface would
         # stay on screen and the install would look like it did nothing.
         kill -CONT "$pid" 2>/dev/null;
         kill "$pid" 2>/dev/null; sleep 2;
         if kill -0 "$pid" 2>/dev/null; then
             kill -KILL "$pid" 2>/dev/null; sleep 1;
         fi
     fi
     # `lomiri-app-launch` may abort when it is called from an ssh session
     # ("lost our connection with the registry"); the app starts anyway.
     setsid lomiri-app-launch fi.reijo.puhuri_puhuri_0.1.0 </dev/null >/dev/null 2>&1 &
     for i in $(seq 1 200); do
         systemctl --user is-active --quiet puhurid.service && break
         sleep 0.1
     done
     sleep 1
     if pgrep -f "qt5/bin/qmlscen[e]" >/dev/null; then
         echo "sovellus käynnissä";
     else
         echo "sovellusta ei saatu käyntiin - avaa se puhelimesta";
     fi'

echo "--- tila"
remote \
    'export XDG_RUNTIME_DIR=/run/user/$(id -u); systemctl --user is-active puhurid.service'
remote \
    'export XDG_RUNTIME_DIR=/run/user/$(id -u); /opt/click.ubuntu.com/fi.reijo.puhuri/current/lib/aarch64-linux-gnu/bin/puhuri-ctl status'
