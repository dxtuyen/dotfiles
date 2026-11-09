"""Exercise real window transitions in an isolated headless Sway session."""

import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "home/desktop/windows/scripts/popup-toggle.py"
contexts = runpy.run_path(str(SOURCE))["contexts"]


@unittest.skipUnless(shutil.which("sway") and shutil.which("foot"), "Sway and Foot are required")
class SwayWindowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="sway-window-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        config = self.root / "sway.conf"
        config.write_text(
            'xwayland disable\noutput * resolution 1280x800\n'
            'for_window [app_id="popup-check"] floating enable, move scratchpad, '
            'scratchpad show, resize set width 70 ppt height 85 ppt, move position center\n'
            'for_window [app_id="terminal-check"] floating enable, move scratchpad, scratchpad show\n'
        )
        self.env = dict(os.environ, HOME=str(self.root), XDG_RUNTIME_DIR=str(self.root),
                        XDG_CONFIG_HOME=str(self.root / "config"),
                        WLR_BACKENDS="headless", WLR_RENDERER="pixman", WLR_LIBINPUT_NO_DEVICES="1")
        self.env.pop("SWAYSOCK", None)
        self.env.pop("WAYLAND_DISPLAY", None)
        self.env.pop("DBUS_SESSION_BUS_ADDRESS", None)
        self.clients = []
        self.log = (self.root / "sway.log").open("w")
        self.addCleanup(self.log.close)
        self.compositor = subprocess.Popen(
            ["sway", "--unsupported-gpu", "-c", str(config)], env=self.env,
            stdout=self.log, stderr=self.log,
            start_new_session=True,
        )
        self.addCleanup(self.stop_processes)
        self.wait_for(lambda: list(self.root.glob("sway-ipc.*.sock")) and any(
            not path.name.endswith(".lock") for path in self.root.glob("wayland-*")))
        self.env["SWAYSOCK"] = str(next(self.root.glob("sway-ipc.*.sock")))
        self.env["WAYLAND_DISPLAY"] = next(
            path.name for path in self.root.glob("wayland-*") if not path.name.endswith(".lock"))

    def stop_processes(self):
        for client in self.clients:
            if client.poll() is None:
                client.terminate()
            client.wait(timeout=5)
        try:
            os.killpg(self.compositor.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        self.compositor.wait(timeout=5)

    def wait_for(self, predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if predicate():
                return
            if self.compositor.poll() is not None:
                break
            time.sleep(0.05)
        self.fail("Headless Sway check timed out:\n" + (self.root / "sway.log").read_text()[-2000:])

    def ipc(self, *args):
        result = subprocess.run(["swaymsg", "-r", *args], env=self.env,
                                capture_output=True, text=True, check=True, timeout=5)
        return json.loads(result.stdout)

    def windows(self, name):
        return [ctx for ctx in contexts(self.ipc("-t", "get_tree")) if ctx.node.get("app_id") == name]

    def start_window(self, name):
        self.clients.append(subprocess.Popen(
            ["foot", f"--app-id={name}", "sleep", "120"], env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ))
        self.wait_for(lambda: self.windows(name))

    def action(self, *args):
        subprocess.run([sys.executable, str(SOURCE), *args], env=self.env, check=True,
                       capture_output=True, text=True, timeout=20)

    def toggle(self):
        self.action("--match", "popup-check",
                    "--", "foot", "--app-id=popup-check", "sleep", "120")

    def settled_size(self, name, group=False):
        last = None
        stable = 0
        def unchanged():
            nonlocal last, stable
            ctx = self.windows(name)[0]
            rect = (ctx.floating_root if group else ctx.node)["rect"]
            size = (rect["width"], rect["height"])
            stable = stable + 1 if size == last else 0
            last = size
            return stable >= 3
        self.wait_for(unchanged)
        return last

    def toggle_terminal(self):
        self.action("--match", "terminal-check", "--", "foot", "--app-id=terminal-check", "sleep", "120")

    def assert_same_group(self, first, second):
        self.assertEqual(self.windows(first)[0].floating_root["id"],
                         self.windows(second)[0].floating_root["id"])

    def test_native_split_keeps_windows_floating_and_toggle_moves_whole_group(self):
        self.start_window("popup-check")
        self.ipc("splitv")
        self.start_window("other-check")
        self.assert_same_group("popup-check", "other-check")
        before = self.settled_size("popup-check", group=True)
        self.toggle()
        for name in ("popup-check", "other-check"):
            self.assertEqual(self.windows(name)[0].workspace["name"], "__i3_scratch")
        self.toggle()
        self.assert_same_group("popup-check", "other-check")
        self.assertEqual(self.windows("other-check")[0].workspace["name"], "1")
        self.assertEqual(self.settled_size("popup-check", group=True), before)

    def test_new_terminal_does_not_join_existing_popup_split(self):
        self.start_window("popup-check")
        self.ipc("splitv")
        self.start_window("other-check")
        self.toggle_terminal()
        self.assert_same_group("popup-check", "other-check")
        self.assertNotEqual(self.windows("terminal-check")[0].floating_root["id"],
                            self.windows("popup-check")[0].floating_root["id"])
        self.toggle()
        self.assertEqual(self.windows("terminal-check")[0].workspace["name"], "1")
        self.assertEqual(self.windows("other-check")[0].workspace["name"], "__i3_scratch")

    def test_split_then_terminal_shortcut_is_independent_for_both_directions(self):
        self.start_window("popup-check")
        for direction in ("splith", "splitv"):
            with self.subTest(direction=direction):
                self.ipc('[app_id="popup-check"] focus')
                self.ipc(direction)
                self.toggle_terminal()
                self.assertNotEqual(self.windows("terminal-check")[0].floating_root["id"],
                                    self.windows("popup-check")[0].floating_root["id"])
                self.toggle_terminal()
                self.assertEqual(self.windows("terminal-check")[0].workspace["name"], "__i3_scratch")
                self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")

    def test_hidden_terminal_is_recalled_without_joining_popup_group(self):
        self.toggle_terminal()
        self.toggle_terminal()
        self.start_window("popup-check")
        self.ipc("splitv")
        self.start_window("other-check")
        self.toggle_terminal()
        self.assert_same_group("popup-check", "other-check")
        self.assertNotEqual(self.windows("terminal-check")[0].floating_root["id"],
                            self.windows("popup-check")[0].floating_root["id"])

    def test_new_popup_does_not_join_terminal_split(self):
        self.toggle_terminal()
        self.ipc("splith")
        self.start_window("other-check")
        self.toggle()
        self.assert_same_group("terminal-check", "other-check")
        self.assertNotEqual(self.windows("terminal-check")[0].floating_root["id"],
                            self.windows("popup-check")[0].floating_root["id"])

    def test_terminal_toggle_preserves_its_split_group(self):
        self.toggle_terminal()
        self.ipc("splith")
        self.start_window("other-check")
        before = self.settled_size("terminal-check", group=True)
        self.toggle_terminal()
        self.assertEqual(self.windows("other-check")[0].workspace["name"], "__i3_scratch")
        self.toggle_terminal()
        self.assert_same_group("terminal-check", "other-check")
        self.assertEqual(self.settled_size("terminal-check", group=True), before)

    def test_resized_popup_keeps_dimensions_when_toggled(self):
        self.start_window("popup-check")
        self.ipc('[app_id="popup-check"] resize set width 600 px height 500 px')
        before = self.settled_size("popup-check")
        self.toggle()
        self.toggle()
        self.assertEqual(self.settled_size("popup-check"), before)

    def test_group_on_other_workspace_is_recalled_together(self):
        self.start_window("popup-check")
        self.ipc("splitv")
        self.start_window("other-check")
        self.ipc("workspace 2")
        self.toggle()
        for name in ("popup-check", "other-check"):
            self.assertEqual(self.windows(name)[0].workspace["name"], "2")
        self.assert_same_group("popup-check", "other-check")

    def test_absent_popup_launches_then_toggles_one_window(self):
        self.toggle()
        self.assertEqual(len(self.windows("popup-check")), 1)
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")
        self.toggle()
        self.assertEqual(len(self.windows("popup-check")), 1)
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")


if __name__ == "__main__":
    unittest.main()
