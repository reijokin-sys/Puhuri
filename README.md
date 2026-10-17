# Puhuri - a native XMPP messenger for Ubuntu Touch

An XMPP client for Ubuntu Touch 24.04 (arm64): a user interface (the click
`fi.reijo.puhuri`) that speaks **English and Finnish**, and a Rust background
service that speaks XMPP through the **`tokio-xmpp`** libraries.

Why it exists: the Signal client (`ubuntu-touch-sahke`) needs a phone number
and Signal's servers. XMPP needs neither - the account lives on any server,
the protocol is an open standard, and the server can be your own.

## What it does

| Piece | What it is |
| --- | --- |
| 1:1 text | messages both ways, delivery receipts and "typing…" (XEP-0184/0085) |
| Attachments | pictures and voice messages (XEP-0363), also as encrypted media (XEP-0454) |
| OMEMO | end-to-end encryption (XEP-0384) with a fingerprint view; OMEMO 2 is planned |
| Encryption default | a new conversation starts encrypted; an explicit plaintext choice is remembered, and a contact without OMEMO stays locked until you unlock it |
| Archive | the server-side history and the copies from your other devices (XEP-0313/0280) |
| Background | a systemd *user* service keeps the session alive or uses battery-saving polling; the push path (XEP-0357) is prepared for later |
| Notifications | Lomiri notifications with the phone's configured message sound, and Puhuri's unread count lights the notifications indicator |
| Local-data delete | removes local messages, attachments, backups, OMEMO keys, settings and cache; server history and other devices are separate |
| Languages | English (default) and Finnish, chosen in Settings |

## The division of work

| Piece | Who |
| --- | --- |
| XMPP protocol, TLS, SASL, SRV, stream management, the OMEMO ratchet | the `tokio-xmpp`, `xmpp-parsers` and `libsignal-protocol-c` libraries |
| Message store | SQLite (`rusqlite`) |
| The bridge, the XEP choices and keeping the connection alive | this repository |

## Building

```sh
# the service first (the click carries it; aarch64, zig as the C toolchain)
PUHURI_FEATURES=omemo sh tools/build-daemon.sh   # -> build/puhurid, build/puhuri-ctl

# then the click (QML + Python + the built service, architecture "arm64")
sh tools/build.sh                     # -> dist/fi.reijo.puhuri_0.1.1_arm64.click

# both, and install over SSH on a phone
PUHELIMEN_SALASANA=... PUHURI_FEATURES=omemo ./install.sh
```

The click is self-contained: it carries the Rust service and its systemd unit
template. The XMPP daemon runs under an enforced click AppArmor profile, and
the main messenger stays in its normal click profile. The only unconfined
part is a short-lived URL helper that installs and starts the user service on
first launch.

## Installing and removing

The install and removal tools read the phone password from
`PUHELIMEN_SALASANA` and send it to `sudo` through standard input. The password
does not appear in the command arguments of `adb` or `ssh`.

```sh
# install and replace the installed version
PUHELIMEN_SALASANA=... PUHURI_FEATURES=omemo ./install.sh

# remove the click, both user services and Puhuri's local data
PUHELIMEN_SALASANA=... ./uninstall.sh --purge
```

Without `--purge`, uninstall removes the click and services but keeps the
messages, account and settings.

## Tests

```sh
sh tools/testit.sh        # phone tools, the app, library and service tests
sh tools/check.sh --qml   # loads the installed interface with qmlscene
```

## Privacy and local data

Messages and OMEMO keys stay on the phone in Puhuri's private data directory;
there is no cloud service or third-party message relay. The Settings page has
a separate, confirmed **Delete all local data** action. It clears the local
database, attachments, migration backups, encryption state, saved account,
settings, Content Hub cache and push token, then restarts the service to drop
its SQLite page cache.

System-wide journal entries, messages retained by the XMPP server and copies
on other devices are not removed by that local action. The app's current
logging does not write message bodies, JIDs or contact names by default.

## The local test server

`tools/testserver/` installs a throwaway Prosody with two accounts and a local
CA, so the whole feature set can be exercised without touching a real server.
The setup prints per-run test passwords (`PUHURI_TEST_PASSWORD1` and
`PUHURI_TEST_PASSWORD2`) for the e2e scripts; they are not committed. The test
daemons set `PUHURI_ATTACHMENT_ALLOW_PRIVATE=1` and
`PUHURI_ATTACHMENT_ALLOW_HTTP=1` because the local server lives on a LAN.

## Licence

Puhuri is **AGPL-3.0-or-later** (the full text is in `LICENSE`); the
third-party parts and how they are checked are in `THIRD_PARTY_NOTICES.md`.
The click also carries the generated `THIRD_PARTY_LICENSES.txt` bundle with
the licence and notice texts of its final aarch64/OMEMO dependency graph.
Puhuri is an unofficial app, not affiliated with the XMPP Standards Foundation
or UBports.
