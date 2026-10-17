#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later

import importlib.util
from importlib.machinery import SourceFileLoader
import os
import pathlib
import tempfile
import unittest
from unittest import mock


APP_DIR = pathlib.Path(__file__).resolve().parents[1]
INDICATOR = APP_DIR / "lib/aarch64-linux-gnu/bin/puhuri-indicator"


def load_indicator():
    loader = SourceFileLoader("puhuri_indicator_test", str(INDICATOR))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module


class IndicatorTest(unittest.TestCase):
    def setUp(self):
        self.indicator = load_indicator()

    def test_unread_state_sums_the_conversations_and_keeps_the_newest_time(self):
        conversations = [
            {"id": "a", "unread": 2, "last_ts": 100},
            {"id": "b", "unread": 0, "last_ts": 300},
            {"id": "c", "unread": 3, "last_ts": 200},
        ]
        self.assertEqual(self.indicator.unread_state(conversations), (5, 300))
        self.assertEqual(self.indicator.unread_state([]), (0, 0))
        self.assertEqual(self.indicator.unread_state(None), (0, 0))

    def test_desktop_and_application_ids_follow_the_manifest_version(self):
        version = self.indicator.app_version()
        self.assertTrue(version)
        self.assertEqual(
            self.indicator.desktop_id(),
            "fi.reijo.puhuri_puhuri_%s.desktop" % version,
        )
        self.assertEqual(
            self.indicator.app_id(),
            "fi.reijo.puhuri_puhuri_%s" % version,
        )

    def test_the_installed_click_version_comes_from_the_current_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            versioned = pathlib.Path(directory) / "0.1.0"
            versioned.mkdir()
            current = pathlib.Path(directory) / "current"
            current.symlink_to("0.1.0")
            with mock.patch.object(self.indicator, "manifest", return_value={}):
                with mock.patch.object(self.indicator, "click_root", return_value=str(current)):
                    self.assertEqual(self.indicator.app_version(), "0.1.0")

    def test_the_source_is_generic_variant_with_the_unread_count(self):
        source = self.indicator.Indicator._source_value(3, 1790000000)
        self.assertEqual(source[0], "inbox")
        self.assertEqual(source[1], "Puhuri")
        self.assertEqual(int(source[3]), 3)
        self.assertEqual(int(source[4]), 1790000000)
        self.assertEqual(bool(source[6]), True)

    def test_message_row_has_the_sender_and_generic_text(self):
        message = self.indicator.Indicator._message_value(
            {"id": "maija@example.org", "name": "Maija", "unread": 1, "last_ts": 1790000000})
        self.assertEqual(message[0], "maija@example.org")
        self.assertEqual(message[2], "Maija")
        self.assertEqual(message[4], "New message")
        self.assertEqual(int(message[5]), 1790000000)
        self.assertTrue(bool(message[7]))

    def test_peer_names_cannot_select_menu_markup(self):
        self.assertEqual(self.indicator.plain_label("<b>Friend</b>\n"), "Friend")
        self.assertEqual(self.indicator.plain_label("   "), "Puhuri")

    def test_the_source_text_follows_the_selected_language(self):
        with tempfile.TemporaryDirectory() as directory:
            config = pathlib.Path(directory) / "fi.reijo.puhuri"
            config.mkdir()
            (config / "language").write_text("fi\n", encoding="utf-8")
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}):
                self.assertEqual(self.indicator.summary_text(), "Uusi viesti")
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": directory}):
                self.assertEqual(self.indicator.summary_text(), "New message")


if __name__ == "__main__":
    unittest.main()
