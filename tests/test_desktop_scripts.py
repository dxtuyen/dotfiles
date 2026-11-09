"""Desktop command regressions with isolated state and fake Sway/systemd."""

import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "home/desktop"


def script_path(name):
    if name == "configure-btop":
        return SOURCE.parent / "programs/btop/scripts/configure-btop.sh"
    if name.startswith("wlsunset-"):
        feature = "display"
    elif name.startswith("screenshot"):
        feature = "screenshot"
    elif name == "toggle-touchpad":
        feature = "input"
    else:
        feature = "session"
    return SOURCE / feature / "scripts" / (name + ".sh")


class DesktopScriptTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="desktop-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bin = self.root / "bin"
        self.state = self.root / "state"
        self.runtime = self.root / "runtime"
        self.calls = self.root / "calls"
        for path in (self.bin, self.state, self.runtime, self.root / ".local/bin"):
            path.mkdir(parents=True)
        self.env = dict(os.environ, HOME=str(self.root),
                        XDG_STATE_HOME=str(self.state), XDG_RUNTIME_DIR=str(self.runtime),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
                        DESKTOP_TEST_ROOT=str(self.root))
        stub = self.bin / "stub"
        stub.write_text("#!" + shutil.which("python3") + "\n" + textwrap.dedent('''\
            import json, os, pathlib, sys
            root = pathlib.Path(os.environ["DESKTOP_TEST_ROOT"])
            name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
            with (root / "calls").open("a") as stream:
                stream.write(json.dumps([name, *args]) + "\\n")
            if name == "swaymsg":
                if args[:1] == ["-t"]:
                    print(os.environ.get("DESKTOP_TREE", "{}"))
                elif os.environ.get("DESKTOP_SWAY_FAILURE"):
                    sys.exit(2)
            elif name == "systemctl":
                action = next(arg for arg in args if not arg.startswith("-"))
                units = [arg for arg in args if arg.endswith(".service")]
                if action == "start":
                    if os.environ.get("DESKTOP_START_FAILURE"):
                        sys.exit(1)
                    (root / "active").write_text(units[0])
                elif action == "stop":
                    (root / "active").unlink(missing_ok=True)
                elif action == "is-active":
                    active = root / "active"
                    sys.exit(0 if not os.environ.get("DESKTOP_EARLY_EXIT") and
                             active.exists() and active.read_text() == units[0] else 3)
            elif name == "wlsunset-apply":
                sys.exit(int(os.environ.get("DESKTOP_APPLY_FAILURE", "0")))
        '''))
        stub.chmod(0o755)
        for name in ("swaymsg", "systemctl", "notify-send", "foot", "wlsunset"):
            (self.bin / name).symlink_to(stub)
        (self.root / ".local/bin/wlsunset-apply").symlink_to(stub)

    def run_script(self, name, *args, expected=0, **environment):
        script = script_path(name)
        result = subprocess.run(["bash", str(script), *args],
                                env=dict(self.env, **environment), capture_output=True,
                                text=True, timeout=10)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result.stdout

    def recorded(self, name):
        if not self.calls.exists():
            return []
        return [call[1:] for line in self.calls.read_text().splitlines()
                if (call := json.loads(line))[0] == name]

    def touchpad(self, state):
        return json.dumps([{"type": "touchpad", "libinput": {"send_events": state}}])

    def test_touchpad_changes_only_events(self):
        for current, target in (("enabled", "disabled"), ("disabled", "enabled"),
                                ("disabled_on_external_mouse", "disabled")):
            with self.subTest(current=current):
                self.calls.unlink(missing_ok=True)
                self.run_script("toggle-touchpad", DESKTOP_TREE=self.touchpad(current))
                self.assertEqual(self.recorded("swaymsg")[-1],
                                 ["input", "type:touchpad", "events", target])
                self.assertEqual(len(self.recorded("swaymsg")), 2)

    def test_touchpad_failure_does_not_report_success(self):
        self.run_script("toggle-touchpad", expected=1,
                        DESKTOP_TREE=self.touchpad("enabled"), DESKTOP_SWAY_FAILURE="1")
        notifications = self.recorded("notify-send")
        self.assertEqual(len(notifications), 1)
        self.assertIn("critical", notifications[0])

    def test_missing_touchpad_does_not_change_settings(self):
        self.run_script("toggle-touchpad", expected=1, DESKTOP_TREE="[]")
        self.assertEqual(self.recorded("swaymsg"), [["-t", "get_inputs"]])

    def test_display_saves_only_after_success(self):
        self.run_script("wlsunset-apply", "warm")
        self.assertEqual((self.state / "wlsunset-mode").read_text(), "warm\n")
        self.assertEqual((self.root / "active").read_text(), "wlsunset@warm.service")

    def test_display_failures_preserve_saved_preference(self):
        state = self.state / "wlsunset-mode"
        state.write_text("natural\n")
        for failure in ("DESKTOP_START_FAILURE", "DESKTOP_EARLY_EXIT"):
            with self.subTest(failure=failure):
                self.run_script("wlsunset-apply", "warm", expected=1, **{failure: "1"})
                self.assertEqual(state.read_text(), "natural\n")

    def test_display_restores_saved_preference(self):
        (self.state / "wlsunset-mode").write_text("white\n")
        self.run_script("wlsunset-apply")
        self.assertEqual((self.root / "active").read_text(), "wlsunset@white.service")

    def test_display_rejects_invalid_request_without_stopping_service(self):
        self.run_script("wlsunset-apply", "invalid", expected=2)
        self.assertEqual(self.recorded("systemctl"), [])

    def test_display_concurrent_requests_are_serialized(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            futures = [executor.submit(self.run_script, "wlsunset-apply", mode)
                       for mode in ("warm", "white")]
            for future in futures:
                future.result()
        calls = self.recorded("systemctl")
        actions = [next(arg for arg in call if not arg.startswith("-")) for call in calls]
        self.assertEqual(actions, ["stop", "start", "is-active"] * 2)
        mode = (self.state / "wlsunset-mode").read_text().strip()
        self.assertEqual((self.root / "active").read_text(), f"wlsunset@{mode}.service")

    def test_display_status_uses_active_service(self):
        (self.root / "active").write_text("wlsunset@white.service")
        self.assertEqual(self.run_script("wlsunset-menu", "status"), "Cool\n")

    def test_refresh_reloads_sway_even_when_display_restore_fails(self):
        self.run_script("refresh-session", expected=1, DESKTOP_APPLY_FAILURE="1")
        self.assertEqual(self.recorded("swaymsg"), [["reload"]])

    def test_display_runner_preserves_temperature_arguments(self):
        self.run_script("wlsunset-run", "warm")
        self.assertEqual(self.recorded("wlsunset"),
                         [["-t", "3900", "-T", "4000", "-l", "21.0", "-L", "105.8"]])

    def test_display_runner_rejects_unknown_mode(self):
        self.run_script("wlsunset-run", "invalid", expected=2)
        self.assertEqual(self.recorded("wlsunset"), [])

    def test_btop_theme_updates_preserve_preferences_and_original_backup(self):
        config = self.root / "btop.conf"
        original = 'color_theme = "old"\nproc_sorting = "cpu lazy"\ntruecolor = False\n'
        config.write_text(original)
        for _ in range(2):
            self.run_script("configure-btop", str(config), "/themes/gruvbox.theme")
        result = config.read_text()
        self.assertIn('proc_sorting = "cpu lazy"', result)
        self.assertEqual(result.count('color_theme = '), 1)
        self.assertIn('color_theme = "/themes/gruvbox.theme"', result)
        self.assertEqual(Path(str(config) + ".before-gruvbox-material").read_text(), original)
