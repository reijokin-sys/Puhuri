#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-or-later
# Build and install Puhuri on the phone (service + click).
#
#   PUHELIMEN_SALASANA=... ./install.sh
#
# PUHURI_FEATURES=omemo adds the OMEMO layer (libsignal + the envelope); the
# phone now runs with it, so that encrypted messages can be read and sent.
# Without the variable the plain build is installed, as before.
#
# The service is a systemd *user* service, so nothing here needs root except
# the click package itself.
set -eu

PROJECT=$(cd "$(dirname "$0")" && pwd)

echo "--- rakennetaan palvelu (aarch64)"
PUHURI_FEATURES=${PUHURI_FEATURES:-} sh "$PROJECT/tools/build-daemon.sh"

echo "--- rakennetaan click (sisältää palvelun)"
sh "$PROJECT/tools/build.sh"

echo "--- asennetaan puhelimeen"
sh "$PROJECT/tools/deploy.sh"
