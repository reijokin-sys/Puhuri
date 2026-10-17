#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later

import importlib.util
from importlib.machinery import SourceFileLoader
import json
import pathlib
import sys
import tempfile
import types
import unittest
from unittest import mock


APP_DIR = pathlib.Path(__file__).resolve().parents[1]
PUHURI_PY = APP_DIR / "puhuri.py"
SERVICE_HELPER = APP_DIR / "lib/aarch64-linux-gnu/bin/puhuri-service-setup"


class BundledServiceTest(unittest.TestCase):
    def setUp(self):
        pyotherside = types.ModuleType("pyotherside")
        pyotherside.send = lambda *args: None
        self.old_pyotherside = sys.modules.get("pyotherside")
        sys.modules["pyotherside"] = pyotherside

        spec = importlib.util.spec_from_file_location("puhuri_bundled_test", PUHURI_PY)
        self.puhuri = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.puhuri)

    def tearDown(self):
        if self.old_pyotherside is None:
            sys.modules.pop("pyotherside", None)
        else:
            sys.modules["pyotherside"] = self.old_pyotherside

    def test_service_helper_unit_starts_the_daemon_inside_the_click(self):
        loader = SourceFileLoader("puhuri_service_helper_test", str(SERVICE_HELPER))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        with tempfile.TemporaryDirectory() as directory:
            versioned = pathlib.Path(directory) / "0.1.1"
            versioned.mkdir()
            current = pathlib.Path(directory) / "current"
            current.symlink_to("0.1.1")
            root = str(current)
            unit = helper.service_unit_text(root)

            self.assertIn(
                "ExecStart=/usr/bin/aa-exec -p "
                "fi.reijo.puhuri_puhuri-daemon_0.1.1 -- "
                f"{root}/lib/aarch64-linux-gnu/bin/puhurid --engine xmpp",
                unit,
            )
            self.assertIn("WantedBy=graphical-session.target", unit)
            self.assertIn(
                f"ConditionPathExists={root}/lib/aarch64-linux-gnu/bin/puhurid",
                unit,
            )
            self.assertIn("Restart=always", unit)
            self.assertNotIn("PUHURI_PURGE_UI_DIRS", unit)
            self.assertIn("Environment=PUHURI_RESTART_AFTER_PURGE=1", unit)
            self.assertIn("Environment=PUHURI_CLICK_WATCHDOG=1", unit)

    def test_daemon_profile_is_confined_and_only_setup_is_unconfined(self):
        manifest = json.loads((APP_DIR / "manifest.json").read_text())
        self.assertEqual(
            manifest["hooks"]["puhuri-daemon"]["apparmor"],
            "puhuri-daemon.apparmor",
        )
        self.assertEqual(
            manifest["hooks"]["puhuri-setup"]["apparmor"],
            "puhuri-setup.apparmor",
        )
        daemon = json.loads((APP_DIR / "puhuri-daemon.apparmor").read_text())
        setup = json.loads((APP_DIR / "puhuri-setup.apparmor").read_text())
        self.assertNotEqual(daemon.get("template"), "unconfined")
        self.assertIn("networking", daemon["policy_groups"])
        self.assertEqual(setup.get("template"), "unconfined")

    def test_release_versions_are_0_1_1(self):
        manifest = json.loads((APP_DIR / "manifest.json").read_text())
        cargo = (APP_DIR.parent / "daemon/Cargo.toml").read_text()
        lock = (APP_DIR.parent / "daemon/Cargo.lock").read_text()
        self.assertEqual(manifest["version"], "0.1.1")
        self.assertIn('version = "0.1.1"', cargo)
        self.assertIn('name = "puhurid"\nversion = "0.1.1"', lock)

    def test_indicator_unit_keeps_the_systemd_runtime_specifier(self):
        loader = SourceFileLoader("puhuri_service_helper_test", str(SERVICE_HELPER))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(helper)
        unit = helper.indicator_unit_text("/opt/click.ubuntu.com/fi.reijo.puhuri/current")
        self.assertIn(
            "Environment=PUHURI_PURGE_REQUEST_DIR=%t/fi.reijo.puhuri",
            unit,
        )
        self.assertIn(
            "EnvironmentFile=-%h/.config/fi.reijo.puhuri/puhurid.env",
            unit,
        )

    def test_first_connection_dispatches_the_sandboxed_setup_helper(self):
        self.puhuri._service_started = False
        dbus = types.SimpleNamespace(SessionBus=mock.Mock())
        bus = dbus.SessionBus.return_value
        with mock.patch.dict("os.environ", {}, clear=True):
            with mock.patch.dict(sys.modules, {"dbus": dbus}):
                self.puhuri.ensure_bundled_service()
        bus.call_blocking.assert_called_once_with(
            "com.lomiri.URLDispatcher",
            "/com/lomiri/URLDispatcher",
            "com.lomiri.URLDispatcher",
            "DispatchURL",
            "ss",
            ("puhuri://start", ""),
        )

    def test_socket_override_never_starts_the_real_service(self):
        self.puhuri._service_started = False
        with mock.patch.dict("os.environ", {"PUHURI_SOCKET": "/tmp/test.sock"}):
            with mock.patch.object(self.puhuri, "ensure_bundled_service") as ensure:
                with mock.patch("socket.socket.connect", side_effect=OSError("missing")):
                    self.assertFalse(self.puhuri._backend._open(quiet=True))
        ensure.assert_not_called()

    def test_an_open_socket_does_not_dispatch_the_setup_helper(self):
        self.puhuri._service_started = False
        with mock.patch.dict("os.environ", {}, clear=True):
            with mock.patch.object(self.puhuri, "ensure_bundled_service") as ensure:
                with mock.patch("socket.socket.connect", return_value=None):
                    self.assertTrue(self.puhuri._backend._open(quiet=True))
        ensure.assert_not_called()
        self.puhuri._backend.close()

    def test_missing_socket_retries_the_service_helper(self):
        self.puhuri._service_started = False
        with mock.patch.dict("os.environ", {}, clear=True):
            with mock.patch.object(self.puhuri, "ensure_bundled_service") as ensure:
                with mock.patch("socket.socket.connect", side_effect=OSError("missing")):
                    with mock.patch.object(self.puhuri.time, "sleep"):
                        self.assertFalse(self.puhuri._backend._open(quiet=True))
        self.assertGreater(ensure.call_count, 1)


if __name__ == "__main__":
    unittest.main()
