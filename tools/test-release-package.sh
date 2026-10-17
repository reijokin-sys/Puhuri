#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# The OpenStore click must be self-contained: the daemon is a click hook and
# its binaries are inside the click, just like Dekko's dekkod service.
set -eu

PROJECT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE=$(ls -t "$PROJECT"/dist/fi.reijo.puhuri_*.click 2>/dev/null | head -1 || true)
[ -f "$PACKAGE" ] || {
    echo "FAIL: dist/-hakemistossa ei ole click-pakettia" >&2
    exit 1
}

[ -f "$PROJECT/tools/make-license-bundle.py" ] || {
    echo "FAIL: lisenssibundlen generaattori puuttuu" >&2
    exit 1
}
python3 "$PROJECT/tools/make-license-bundle.py" --check

manifest=$(cat "$PROJECT/app/manifest.json")
contents=$(ar p "$PACKAGE" data.tar.gz | tar -tz)

printf '%s\n' "$manifest" | grep -q '"architecture": "arm64"' || {
    echo "FAIL: click ei ole arm64, vaikka se sisältää aarch64-palvelun" >&2
    exit 1
}
printf '%s\n' "$manifest" | grep -q '"puhuri-setup"' || {
    echo "FAIL: puhuri-setup-hook puuttuu manifestista" >&2
    exit 1
}
printf '%s\n' "$manifest" | grep -q '"puhuri-daemon"' || {
    echo "FAIL: puhuri-daemon-hook puuttuu manifestista" >&2
    exit 1
}

for path in \
    ./LICENSE \
    ./THIRD_PARTY_NOTICES.md \
    ./THIRD_PARTY_LICENSES.txt \
    ./lib/aarch64-linux-gnu/bin/puhurid \
    ./lib/aarch64-linux-gnu/bin/puhuri-ctl \
    ./lib/aarch64-linux-gnu/bin/puhuri-indicator \
    ./lib/aarch64-linux-gnu/bin/puhuri-service-setup \
    ./puhuri-daemon.apparmor \
    ./puhuri-daemon.desktop \
    ./puhuri-setup.apparmor \
    ./puhuri-setup.desktop \
    ./puhuri-setup.url-dispatcher \
    ./puhurid.service
do
    printf '%s\n' "$contents" | grep -qx "$path" || {
        echo "FAIL: clickistä puuttuu $path" >&2
        exit 1
    }
done

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
ar p "$PACKAGE" data.tar.gz | tar -xz -C "$work" \
    ./LICENSE ./THIRD_PARTY_NOTICES.md ./THIRD_PARTY_LICENSES.txt
cmp -s "$PROJECT/LICENSE" "$work/LICENSE" || {
    echo "FAIL: clickin LICENSE ei vastaa projektin AGPL-tekstiä" >&2
    exit 1
}
cmp -s "$PROJECT/THIRD_PARTY_NOTICES.md" "$work/THIRD_PARTY_NOTICES.md" || {
    echo "FAIL: clickin third-party notice ei vastaa projektin tiedostoa" >&2
    exit 1
}
cmp -s "$PROJECT/THIRD_PARTY_LICENSES.txt" "$work/THIRD_PARTY_LICENSES.txt" || {
    echo "FAIL: clickin lisenssibundle ei vastaa projektin bundlea" >&2
    exit 1
}
for marker in \
    'Package: tokio-xmpp ' \
    'GNU GENERAL PUBLIC LICENSE' \
    'GNU LESSER GENERAL PUBLIC LICENSE' \
    'Mozilla Public License Version 2.0' \
    'Redistribution and use in source and binary forms, with or without'
do
    grep -q -F "$marker" "$work/THIRD_PARTY_LICENSES.txt" || {
        echo "FAIL: THIRD_PARTY_LICENSES.txt ei sisällä: $marker" >&2
        exit 1
    }
done

main_profile=$(ar p "$PACKAGE" data.tar.gz | tar -xzO ./fi.reijo.puhuri.apparmor)
if printf '%s\n' "$main_profile" | grep -q '"template": "unconfined"'; then
    echo "FAIL: pääsovellus ei saa olla unconfined" >&2
    exit 1
fi
daemon_profile=$(ar p "$PACKAGE" data.tar.gz | tar -xzO ./puhuri-daemon.apparmor)
if printf '%s\n' "$daemon_profile" | grep -q '"template": "unconfined"'; then
    echo "FAIL: daemon ei saa olla unconfined" >&2
    exit 1
fi
printf '%s\n' "$daemon_profile" | grep -q '"networking"' || {
    echo "FAIL: daemon-profiililta puuttuu networking" >&2
    exit 1
}
setup_profile=$(ar p "$PACKAGE" data.tar.gz | tar -xzO ./puhuri-setup.apparmor)
printf '%s\n' "$setup_profile" | grep -q '"template": "unconfined"' || {
    echo "FAIL: setup-helperin pitää olla erikseen merkitty unconfined" >&2
    exit 1
}
unit=$(ar p "$PACKAGE" data.tar.gz | tar -xzO ./puhurid.service)
printf '%s\n' "$unit" | grep -q '/usr/bin/aa-exec -p ' || {
    echo "FAIL: puhurid.service ei käytä confined daemonprofiilia" >&2
    exit 1
}
printf '%s\n' "$unit" | grep -q '^Restart=always$' || {
    echo "FAIL: puhurid.service ei käynnisty uudelleen puhtaan lopetuksen jälkeen" >&2
    exit 1
}

echo "PASS: click sisältää palvelun, binäärit ja täyden lisenssipaketin"
