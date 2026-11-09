"""Exercise session scripts without touching the real screen, power or timer state."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


SOURCE = Path(__file__).resolve().parents[1]


class SessionPowerTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix="session-power-test-")
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.bin = self.root / "bin"
        self.supply = self.root / "power_supply"
        self.home = self.root / "home"
        self.commands = self.root / "commands"
        for path in (self.bin, self.supply, self.home / ".local/bin"):
            path.mkdir(parents=True)
        self.env = dict(
            os.environ, HOME=str(self.home),
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            SESSION_TEST_COMMANDS=str(self.commands),
        )
        stub = self.bin / "command-stub"
        stub.write_text("#!" + shutil.which("python3") + "\n" + textwrap.dedent('''\
            import json, os, pathlib, sys
            name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
            with open(os.environ["SESSION_TEST_COMMANDS"], "a") as stream:
                stream.write(json.dumps([name, *args]) + "\\n")
            if name == "countdown-engine":
                if args == ["idle-allowed"]:
                    sys.exit(int(os.environ.get("SESSION_TEST_INHIBITED", "0")))
                sys.exit(int(os.environ.get("SESSION_TEST_ENGINE_FAILURE", "0")))
            if name == "systemctl" and args == ["--user", "start", "swaylock.service"]:
                sys.exit(int(os.environ.get("SESSION_TEST_LOCK_FAILURE", "0")))
            if name == "swaymsg":
                sys.exit(int(os.environ.get("SESSION_TEST_DISPLAY_FAILURE", "0")))
        '''))
        stub.chmod(0o755)
        for name in ("systemctl", "swaymsg"):
            (self.bin / name).symlink_to(stub)
        (self.home / ".local/bin/countdown-engine").symlink_to(stub)
        for name in ("idle-suspend", "lock-screen", "session-resume"):
            script = (SOURCE / "home/desktop/session/scripts" / (name + ".sh")).read_text()
            script = script.replace("/sys/class/power_supply", str(self.supply))
            (self.bin / name).write_text(script)

    def supply_device(self, name, **attributes):
        path = self.supply / name
        path.mkdir(exist_ok=True)
        for key, value in attributes.items():
            (path / key).write_text(str(value) + "\n")

    def run_script(self, name, *args, expected=0, **environment):
        self.commands.unlink(missing_ok=True)
        result = subprocess.run(
            ["bash", str(self.bin / name), *args],
            env=dict(self.env, **environment), capture_output=True, text=True, timeout=8,
        )
        self.assertEqual(result.returncode, expected, result.stderr)
        if not self.commands.exists():
            return []
        return [json.loads(line) for line in self.commands.read_text().splitlines()]

    def suspended(self, **environment):
        return ["systemctl", "suspend"] in self.run_script("idle-suspend", **environment)

    def test_battery_discharge_requests_suspend(self):
        self.supply_device("BAT0", type="Battery", status="Discharging")
        self.assertTrue(self.suspended())

    def test_external_power_overrides_discharging_battery(self):
        self.supply_device("BAT0", type="Battery", status="Discharging")
        for source_type in ("Mains", "USB", "USB_PD"):
            with self.subTest(source_type=source_type):
                self.supply_device("charger", type=source_type, online=1)
                self.assertFalse(self.suspended())

    def test_all_chargers_are_checked(self):
        self.supply_device("BAT0", type="Battery", status="Discharging")
        self.supply_device("AC", type="Mains", online=0)
        self.supply_device("USB", type="USB", online=1)
        self.assertFalse(self.suspended())

    def test_unplugging_during_same_idle_period_is_detected_on_next_check(self):
        self.supply_device("BAT0", type="Battery", status="Discharging")
        self.supply_device("AC", type="Mains", online=1)
        self.assertFalse(self.suspended())
        self.supply_device("AC", online=0)
        self.assertTrue(self.suspended())

    def test_inhibition_is_rechecked_before_suspend(self):
        self.supply_device("BAT0", type="Battery", status="Discharging")
        self.assertFalse(self.suspended(SESSION_TEST_INHIBITED="1"))

    def test_missing_or_unknown_battery_state_keeps_machine_awake(self):
        self.assertFalse(self.suspended())
        self.supply_device("BAT0", type="Battery")
        self.assertFalse(self.suspended())
        for status in ("Charging", "Not charging", "Full", "Unknown"):
            with self.subTest(status=status):
                self.supply_device("BAT0", status=status)
                self.assertFalse(self.suspended())

    def test_battery_name_does_not_need_bat_prefix(self):
        self.supply_device("CMB0", type="Battery", status="Discharging")
        self.assertTrue(self.suspended())

    def test_peripheral_battery_does_not_suspend_desktop(self):
        self.supply_device("mouse", type="Battery", scope="Device", status="Discharging")
        self.assertFalse(self.suspended())

    def test_powered_peripheral_does_not_hide_laptop_discharge(self):
        self.supply_device("BAT0", type="Battery", status="Discharging")
        self.supply_device("peripheral", type="USB", scope="Device", online=1)
        self.assertTrue(self.suspended())

    def test_lock_is_confirmed_before_countdown_is_paused(self):
        self.assertEqual(self.run_script("lock-screen"), [
            ["systemctl", "--user", "start", "swaylock.service"],
            ["countdown-engine", "lock-pause"],
        ])

    def test_lock_failure_propagates_without_pausing_countdown(self):
        self.assertEqual(self.run_script("lock-screen", expected=1, SESSION_TEST_LOCK_FAILURE="1"), [
            ["systemctl", "--user", "start", "swaylock.service"],
        ])

    def test_countdown_failure_does_not_fail_a_confirmed_lock(self):
        self.run_script("lock-screen", SESSION_TEST_ENGINE_FAILURE="1")

    def test_sleep_uses_same_lock_path_and_preserves_sleep_marker(self):
        self.assertEqual(self.run_script("lock-screen", "--sleep"), [
            ["systemctl", "--user", "start", "swaylock.service"],
            ["countdown-engine", "sleep-pause"],
        ])

    def test_invalid_lock_action_does_nothing(self):
        self.assertEqual(self.run_script("lock-screen", "invalid", expected=2), [])

    def test_wake_cancels_old_deadline_and_refreshes_active_idle_service(self):
        self.assertEqual(self.run_script("session-resume"), [
            ["systemctl", "--user", "--no-block", "stop", "idle-suspend.timer", "idle-suspend.service"],
            ["countdown-engine", "sleep-resume"],
            ["systemctl", "--user", "--no-block", "try-restart", "swayidle.service", "locked-display.service"],
            ["swaymsg", "output * power on"],
        ])

    def test_countdown_failure_does_not_prevent_display_wake(self):
        calls = self.run_script("session-resume", SESSION_TEST_ENGINE_FAILURE="1")
        self.assertIn(["swaymsg", "output * power on"], calls)

    def test_display_failure_does_not_skip_idle_reset(self):
        calls = self.run_script("session-resume", expected=1, SESSION_TEST_DISPLAY_FAILURE="1")
        self.assertIn(["systemctl", "--user", "--no-block", "try-restart", "swayidle.service", "locked-display.service"], calls)


if __name__ == "__main__":
    unittest.main()
