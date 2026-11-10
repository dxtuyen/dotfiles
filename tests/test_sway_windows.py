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

    def tofi_menu(self, function, arguments, items, keys):
        helper = Path(__file__).resolve().parents[1] / "home/desktop/tofi/scripts/menu.sh"
        return self.run_tofi(
            ["bash", "-c", 'source "$1"; shift; "$@"', "menu-test",
             str(helper), function, *arguments], items, keys)

    def run_tofi(self, command, items, keys, **environment):
        if not shutil.which("tofi") or not shutil.which("wtype"):
            self.skipTest("Tofi and wtype are required")
        # A headless seat has no keyboard until a virtual device connects.
        # Keep one connected while the menu obtains keyboard focus.
        keyboard = subprocess.Popen(["wtype", "-s", "60000"], env=self.env)
        self.clients.append(keyboard)
        self.wait_for(lambda: any(device["type"] == "keyboard"
                                 for device in self.ipc("-t", "get_inputs")))
        config = self.root / "config/tofi/config"
        config.parent.mkdir(parents=True, exist_ok=True)
        config.write_text(Path(os.environ["TOFI_TEST_CONFIG"]).read_text()
                          if "TOFI_TEST_CONFIG" in os.environ else
                          "font=DejaVu Sans\nfont-size=12\nwidth=640\n")
        menu_input = self.root / "menu-input"
        menu_input.write_text(items)
        log_path = self.root / "tofi.log"
        output_path = self.root / "tofi.stdout"
        # A launched terminal can inherit stdout; wait for Tofi itself instead
        # of waiting for every descendant to close a pipe.
        with menu_input.open() as stdin, log_path.open("w") as stderr, output_path.open("w") as stdout:
            menu = subprocess.Popen(
                command,
                env=dict(self.env, WAYLAND_DEBUG="1", XDG_STATE_HOME=str(self.root / "state"),
                         XDG_CACHE_HOME=str(self.root / "cache"), **environment), stdin=stdin,
                stdout=stdout, stderr=stderr, text=True,
            )
        self.clients.append(menu)
        # Wait for keyboard focus rather than guessing a startup delay.
        self.wait_for(lambda: any("wl_keyboard" in line and ".enter(" in line
                                 for line in log_path.read_text().split('"launcher")')[-1].splitlines())
                      or menu.poll() is not None)
        self.assertIsNone(menu.poll(), log_path.read_text()[-2000:])
        subprocess.run(["wtype", *keys], env=self.env, check=True, timeout=5)
        menu.wait(timeout=5)
        self.assertNotIn("[ERROR]", log_path.read_text())
        return menu.returncode, output_path.read_text()

    def test_tofi_filtered_selection_preserves_the_original_action(self):
        self.assertEqual(self.tofi_menu(
            "menu_pick", ["Display", "3"], "Warm\nCool\nNatural\n",
            ["Natural", "-k", "Return"],
        ), (0, "2\n"))

    def test_tofi_current_row_is_selected_without_changing_its_action(self):
        self.assertEqual(self.tofi_menu(
            "menu_pick", ["Display", "3", "1"], "Warm\nCool\nNatural\n",
            ["-k", "Return"],
        ), (0, "1\n"))

    def test_tofi_empty_task_is_accepted(self):
        self.assertEqual(self.tofi_menu(
            "menu_input", ["Task", "Optional", "Enter task"], "",
            ["-k", "Return"],
        ), (0, "\n"))

    def test_tofi_escape_cancels_a_text_prompt(self):
        self.assertEqual(self.tofi_menu(
            "menu_input", ["Minutes", "1–480", "Enter minutes"], "",
            ["25", "-k", "Escape"],
        ), (1, ""))

    def test_tofi_launcher_opens_terminal_apps_in_foot_and_saves_history(self):
        if not shutil.which("xdg-terminal-exec"):
            self.skipTest("xdg-terminal-exec is required")
        applications = self.root / "data/applications"
        applications.mkdir(parents=True)
        foot = Path(shutil.which("foot")).resolve().parents[1] / "share/applications/foot.desktop"
        shutil.copy(foot, applications / "foot.desktop")
        (applications / "launcher-check.desktop").write_text(
            "[Desktop Entry]\nType=Application\nName=Tofi terminal check\n"
            "Exec=sleep 120\nTerminal=true\n")
        config = self.root / "config"
        config.mkdir(exist_ok=True)
        (config / "xdg-terminals.list").write_text("foot.desktop\n")
        self.addCleanup(self.ipc, '[app_id="foot"] kill')
        self.assertEqual(self.run_tofi(
            ["tofi-drun", "--drun-launch=true"], "", ["terminal check", "-k", "Return"],
            XDG_DATA_HOME=str(applications.parent), XDG_DATA_DIRS="",
        ), (0, ""))
        self.wait_for(lambda: self.windows("foot"))
        history = self.root / "state/tofi-drun-history"
        self.assertIn("Tofi terminal check", history.read_text())

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

    def test_unfocused_visible_popup_is_focused_before_hiding(self):
        self.start_window("popup-check")
        self.start_window("other-check")
        self.assertFalse(self.windows("popup-check")[0].node["focused"])
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")
        self.assertTrue(self.windows("popup-check")[0].node["focused"])
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")

    def test_visible_floating_popup_outside_scratchpad_can_be_hidden(self):
        self.start_window("popup-check")
        self.ipc('[con_mark="^popup-check$"] floating disable, floating enable')
        self.assertEqual(self.windows("popup-check")[0].node["scratchpad_state"], "none")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")

    def test_floating_popup_outside_scratchpad_is_recalled_from_other_workspace(self):
        self.start_window("popup-check")
        self.ipc('[con_mark="^popup-check$"] floating disable, floating enable')
        self.ipc("workspace 2")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "2")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")

    def test_fullscreen_popup_can_be_hidden(self):
        self.start_window("popup-check")
        self.ipc('[con_mark="^popup-check$"] fullscreen enable')
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "__i3_scratch")
        self.toggle()
        self.assertEqual(self.windows("popup-check")[0].workspace["name"], "1")

    def test_resized_popup_keeps_dimensions_when_toggled(self):
        self.start_window("popup-check")
        self.ipc('[app_id="popup-check"] resize set width 600 px height 500 px')
        before = self.settled_size("popup-check")
        self.toggle()
        self.toggle()
        self.assertEqual(self.settled_size("popup-check"), before)



if __name__ == "__main__":
    unittest.main()
