"""The urgency watcher focuses urgent windows without tracking focus history."""

import io
import json
from pathlib import Path
import runpy
import unittest
from unittest.mock import patch


FOCUS = runpy.run_path(str(Path(__file__).resolve().parents[1]
                          / "home/desktop/sway/scripts/window-focus.py"))


def window(wid, focused=False):
    return {"id": wid, "app_id": "test", "focused": focused}


class WindowFocusTests(unittest.TestCase):
    def test_only_urgent_windows_trigger_focus(self):
        events = [{"success": True}]
        for change, node in (
            ("focus", window(2)), ("focus", window(1, True)),
            ("focus", {"id": 99}), ("close", window(2)),
            ("urgent", dict(window(3), urgent=True)),
            ("urgent", dict(window(3), urgent=False)),
            ("urgent", {"urgent": True}),
        ):
            events.append({"change": change, "container": node})
        with patch("subprocess.Popen") as process, \
             patch("subprocess.run") as focus:
            process.return_value.__enter__.return_value.stdout = io.StringIO(
                "\n".join(map(json.dumps, events)) + "\n")
            with self.assertRaisesRegex(RuntimeError, "subscription ended"):
                FOCUS["watch"]("swaymsg")
            focus.assert_called_once_with(
                ["swaymsg", "-q", "[con_id=3] focus"], check=False)
