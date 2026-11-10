"""Exercise real window transitions in an isolated headless Sway session."""

import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import time
import unittest
from types import SimpleNamespace


def contexts(node, workspace=None, floating_root=None):
    if node.get("type") == "workspace":
        workspace = node
    yield SimpleNamespace(node=node, workspace=workspace, floating_root=floating_root)
    for child in node.get("nodes", []):
        yield from contexts(child, workspace, floating_root)
    for child in node.get("floating_nodes", []):
        yield from contexts(child, workspace, child)


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
            'scratchpad show, resize set width 70 ppt height 85 ppt, move position center, mark --add popup-check\n'
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

    def toggle(self, **environment):
        source = Path(__file__).resolve().parents[1] / "home/desktop/windows/scripts/popup-toggle.sh"
        return subprocess.run(
            ["bash", str(source), "popup-check", "--", "foot", "--app-id=popup-check", "sleep", "120"],
            env=dict(self.env, **environment), capture_output=True, text=True, timeout=5,
        )

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

    def test_native_toggle_hides_and_shows_existing_window(self):
        self.start_window("popup-check")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")
        self.assertEqual(len(self.windows("popup-check")), 1)

    def test_popup_on_another_workspace_is_recalled(self):
        self.start_window("popup-check")
        self.ipc("workspace 2")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "2")

    def test_absent_popup_launches_then_toggles(self):
        result = self.toggle()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.wait_for(lambda: self.windows("popup-check"))
        self.assertEqual(len(self.windows("popup-check")), 1)
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")
        self.assertEqual(len(self.windows("popup-check")), 1)

    def test_ipc_failure_is_reported_without_launching(self):
        result = self.toggle(SWAYSOCK=str(self.root / "missing.sock"))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.windows("popup-check"), [])

    def test_unfocused_visible_popup_hides_with_native_toggle(self):
        self.start_window("popup-check")
        self.start_window("other-check")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")

    def test_resized_popup_keeps_dimensions_when_toggled(self):
        self.start_window("popup-check")
        self.ipc('[app_id="popup-check"] resize set width 600 px height 500 px')
        before = self.settled_size("popup-check")
        self.toggle()
        self.toggle()
        self.assertEqual(self.settled_size("popup-check"), before)



if __name__ == "__main__":
    unittest.main()
