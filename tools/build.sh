#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Build the Puhuri click package into dist/.
#
#   tools/build.sh
#
# The user interface is QML + Python (architecture "all"), so no cross
# compilation is needed for the click itself. The background service is a
# separate Rust binary: tools/build-daemon.sh builds it for the phone.
set -eu

PROJECT=$(cd "$(dirname "$0")/.." && pwd)
cd "$PROJECT"

if command -v click >/dev/null 2>&1; then
    CLICK=click
else
    CLICK="$PROJECT/tools/click-host.sh"
fi

python3 tools/make-icon.py
python3 tools/make-license-bundle.py --check

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

stage="$work/package"
mkdir -p "$stage"
cp app/manifest.json app/fi.reijo.puhuri.apparmor app/push.apparmor \
   app/puhurid.service app/puhuri-setup.apparmor app/puhuri-daemon.apparmor \
   app/puhuri-setup.desktop app/puhuri-setup.url-dispatcher \
   app/puhuri-daemon.desktop \
   app/push.json app/puhuri.desktop app/puhuri.py "$stage/"
cp LICENSE THIRD_PARTY_NOTICES.md THIRD_PARTY_LICENSES.txt "$stage/"
# `app/Lomiri` carries Puhuri's own theme modules. They belong in the click's
# **root** - not under `qml/` - because the toolkit's theme loader finds a theme
# module on the QML import paths, and `qmlscene` finds it in the working
# directory, which for a click is the click root (measured on the phone
# 2026-10-16, docs/TEEMAT-TOTEUTUS.md).
cp -r app/qml app/assets app/lib app/Lomiri "$stage/"
# The background service is a click hook, like Dekko's `dekkod`: clickd creates
# a user service from the hook name and the conventional binary path. Keeping
# both binaries inside the click means an OpenStore installation is complete.
for binary in puhurid puhuri-ctl; do
    [ -x "$PROJECT/build/$binary" ] || {
        echo "Puuttuu $PROJECT/build/$binary. Aja ensin tools/build-daemon.sh" >&2
        exit 1
    }
    cp "$PROJECT/build/$binary" "$stage/lib/aarch64-linux-gnu/bin/$binary"
done
chmod -R u=rwX,go=rX "$stage"
# The push helper is an executable: the push service runs it directly.
chmod u+x,go+x "$stage/lib/aarch64-linux-gnu/bin/puhuri-push-helper"
chmod u+x,go+x "$stage/lib/aarch64-linux-gnu/bin/puhurid" \
    "$stage/lib/aarch64-linux-gnu/bin/puhuri-ctl" \
    "$stage/lib/aarch64-linux-gnu/bin/puhuri-service-setup" \
    "$stage/lib/aarch64-linux-gnu/bin/puhuri-indicator"

cd "$work"
"$CLICK" build --no-validate "$stage"

mkdir -p "$PROJECT/dist"
rm -f "$PROJECT"/dist/fi.reijo.puhuri_*.click
mv "$work"/*.click "$PROJECT/dist/"

echo "--- built:"
ls -l "$PROJECT/dist/"
