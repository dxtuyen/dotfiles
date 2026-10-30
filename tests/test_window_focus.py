"""Alt+Tab follows window history across workspaces, excluding hidden scratchpads."""

import io
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch


FOCUS = runpy.run_path(str(Path(__file__).resolve().parents[1]
                          / "home/desktop/window-focus.py"))


def window(wid, focused=False):
    return {"id": wid, "app_id": "test", "focused": focused}


class WindowFocusTests(unittest.TestCase):
    def test_previous_window_crosses_workspaces_and_skips_closed_windows(self):
        tree = {"nodes": [{"name": "1", "nodes": [window(1, True)]},
                          {"name": "2", "nodes": [window(2)]}]}
        self.assertEqual(FOCUS["previous_window"]([1, 99, 2], tree), 2)

    def test_hidden_scratchpad_is_skipped_but_shown_scratchpad_can_be_focused(self):
        tree = {"nodes": [{"name": "__i3_scratch", "floating_nodes": [window(2)]},
                          {"name": "1", "nodes": [window(1, True)],
                           "floating_nodes": [window(3)]}]}
        self.assertEqual(FOCUS["previous_window"]([1, 2, 3], tree), 3)

    def test_only_current_window_or_empty_history_is_a_noop(self):
        tree = {"nodes": [window(1, True)]}
        self.assertIsNone(FOCUS["previous_window"]([1], tree))
        self.assertIsNone(FOCUS["previous_window"]([], tree))

    def test_xwayland_windows_are_included(self):
        tree = {"nodes": [window(1, True), {"id": 2, "window": 42}]}
        self.assertEqual(FOCUS["previous_window"]([1, 2], tree), 2)

    def test_shared_subscription_tracks_focus_close_and_urgency(self):
        events = [{"first": True, "payload": ""}]
        for change, node in (
            ("focus", window(2)), ("focus", window(1, True)),
            ("focus", {"id": 99}), ("close", window(2)),
            ("urgent", dict(window(3), urgent=True)),
            ("urgent", dict(window(3), urgent=False)),
        ):
            events.append({"change": change, "container": node})
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "history.json"
            with patch("subprocess.Popen") as process, \
                 patch("subprocess.check_output", return_value=json.dumps(window(1, True))), \
                 patch("subprocess.run") as focus:
                process.return_value.__enter__.return_value.stdout = io.StringIO(
                    "\n".join(map(json.dumps, events)) + "\n")
                with self.assertRaisesRegex(RuntimeError, "subscription ended"):
                    FOCUS["watch"]("swaymsg", state)
                self.assertEqual(json.loads(state.read_text()), [1])
                focus.assert_called_once_with(
                    ["swaymsg", "-q", "[con_id=3] focus"], check=False)
