"""Regression tests with isolated state and fake desktop/system commands."""

import concurrent.futures
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import tempfile
import textwrap
import time
import unittest
import xml.etree.ElementTree as ET


SOURCE = Path(__file__).resolve().parents[1]


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="workflow-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.home = self.root / "home"
        self.runtime = self.root / "runtime"
        self.state = self.home / ".local/state"
        self.bin = self.root / "bin"
        for path in (self.home / ".local/bin", self.home / ".local/lib", self.runtime, self.state, self.bin):
            path.mkdir(parents=True, exist_ok=True)
        self.clock = self.root / "clock"
        self.clock.write_text("1000000000")
        self.calls = self.root / "calls"
        self.env = dict(
            os.environ,
            HOME=str(self.home),
            XDG_RUNTIME_DIR=str(self.runtime),
            XDG_STATE_HOME=str(self.state),
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            TEST_ROOT=str(self.root),
            TEST_CAPTURE_MENUS="1",
        )
        self.command_stub = self.executable(
            self.root / "command-stub",
            "#!/usr/bin/env python3\n"
            + textwrap.dedent('''\
                import json, os, pathlib, sys
                root = pathlib.Path(os.environ["TEST_ROOT"])
                name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]
                with (root / "calls").open("a") as f:
                    f.write(json.dumps([name, *args]) + "\\n")
                if name == "systemctl":
                    action = next(a for a in args if not a.startswith("-"))
                    unit = root / args[-1]
                    if action == "is-active":
                        sys.exit(0 if unit.exists() and unit.read_text() == "active" else 3)
                    if action in ("start", "stop"):
                        unit.write_text("active" if action == "start" else "inactive")
                elif name == "swaymsg" and args[:1] == ["-t"]:
                    print(os.environ.get("TEST_TREE", '{"nodes": []}'))
                elif name == "rofi":
                    import subprocess
                    index = root / "dialog-index"
                    i = int(index.read_text()) if index.exists() else 0
                    dialogs = json.loads(os.environ["TEST_DIALOGS"])
                    index.write_text(str(i + 1))
                    if os.environ.get("TEST_CAPTURE_MENUS"):
                        (root / f"menu-{i}").write_bytes(sys.stdin.buffer.read())
                    if os.environ.get("TEST_PAUSE_IN_MENU"):
                        subprocess.run([os.environ["HOME"] + "/.local/bin/countdown-engine", "pause"], check=True)
                    text, status = dialogs[i]
                    sys.stdout.write(text)
                    sys.exit(status)
                elif name == "powerprofilesctl":
                    if args[:1] == ["set"] and os.environ.get("TEST_PROFILE_FAILURE"):
                        print("Switch rejected", file=sys.stderr)
                        sys.exit(1)
                elif name == "pgrep":
                    sys.exit(1)
                elif name == "id":
                    print("0")
                elif name == "df":
                    print("Filesystem Size Used Avail Use% Mounted on\\ntest 1G 0 1G 0% /")
                elif name == "nix" and os.environ.get("TEST_BUILD_FAILURE"):
                    sys.exit(1)
                elif name == "nix-env" and "--delete-generations" in args:
                    profile = pathlib.Path(os.environ["TEST_PROFILE"])
                    for link in profile.parent.glob("system-*-link"):
                        if link.name != os.readlink(profile):
                            link.unlink()
                elif name == "nixos-rebuild":
                    profile = pathlib.Path(os.environ["TEST_PROFILE"])
                    (profile.parent / "system-2-link").symlink_to(root / "new-system")
                    profile.unlink()
                    profile.symlink_to("system-2-link")
            '''),
        )
        for name in (
            "systemctl", "pkill", "notify-send", "paplay", "swaymsg", "sioyek",
            "rofi", "id", "mountpoint", "df", "nix", "nix-env",
            "nixos-rebuild", "nix-collect-garbage", "powerprofilesctl", "pgrep",
            "wlsunset-apply", "screenshot", "foot",
        ):
            (self.bin / name).symlink_to(self.command_stub)
        for name in ("wlsunset-apply", "screenshot"):
            (self.home / ".local/bin" / name).symlink_to(self.command_stub)
        helper = (SOURCE / "home/desktop/rofi-menu.sh").read_text()
        (self.home / ".local/lib/rofi-menu.sh").write_text(helper.replace("@iconColor@", "#d4be98"))
        for name in ("wlsunset-menu", "screenshot-menu"):
            self.executable(self.home / ".local/bin" / name,
                            (SOURCE / "home/scripts/desktop" / (name + ".sh")).read_text())
        self.executable(
            self.bin / "date",
            '#!/usr/bin/env bash\nif [ "${1:-}" = +%s ]; then cat "$TEST_ROOT/clock"; '
            'else exec ' + shlex.quote(shutil.which("date")) + ' "$@"; fi\n',
        )
        text = (SOURCE / "home/features/countdown/countdown-engine.sh").read_text()
        text = text.replace("@flock@", shutil.which("flock")).replace("@jq@", shutil.which("jq"))
        self.engine_path = self.executable(self.home / ".local/bin/countdown-engine", text)
        self.menu = SOURCE / "home/features/countdown/countdown-menu.sh"

    def executable(self, path, text):
        if text.startswith("#!/usr/bin/env "):
            first, rest = text.split("\n", 1)
            text = "#!" + shutil.which(first.split()[-1]) + "\n" + rest
        path.write_text(text)
        path.chmod(0o755)
        return path

    def run_command(self, *args, expected=0, **environment):
        result = subprocess.run(
            list(map(str, args)), env=dict(self.env, **environment),
            text=True, capture_output=True, timeout=10,
        )
        self.assertEqual(result.returncode, expected, result.stderr)
        return result.stdout

    def engine(self, *args, **kwargs):
        return self.run_command(self.engine_path, *args, **kwargs)

    def field(self, name):
        text = (self.runtime / "countdown-state").read_text()
        return re.search(r'^' + name + r'="([^"]*)"', text, re.M).group(1)

    def recorded(self, name):
        if not self.calls.exists():
            return []
        return [c[1:] for line in self.calls.read_text().splitlines()
                if (c := json.loads(line))[0] == name]

    def advance(self, seconds):
        self.clock.write_text(str(int(self.clock.read_text()) + seconds))

    def wait_until(self, predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.05)
        self.fail("Worker did not reach the expected state")

    def worker(self):
        process = subprocess.Popen(
            [str(self.engine_path), "daemon"], env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, start_new_session=True,
        )
        def stop():
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
            process.communicate(timeout=5)
        self.addCleanup(stop)
        return process

    def history(self):
        path = self.state / "countdown-history.log"
        return path.read_text().splitlines() if path.exists() else []

    def power_menu(self, *args, dialogs, **environment):
        script = self.executable(
            self.home / ".local/bin/utilities",
            (SOURCE / "home/scripts/utilities/daily-menu.sh").read_text(),
        )
        return self.run_command(
            script, *args, TEST_DIALOGS=json.dumps(dialogs),
            TEST_CAPTURE_MENUS="1", **environment,
        )

    def test_power_profile_escape_closes_the_flow_without_actions(self):
        self.power_menu("--power", dialogs=[
            ["3", 0], ["", 1],
        ])
        self.assertIn("Power Profile", (self.root / "menu-0").read_text())
        self.assertIn("Balanced", (self.root / "menu-1").read_text())
        self.assertNotIn("Back", (self.root / "menu-1").read_text())
        self.assertEqual(len(self.recorded("rofi")), 2)
        self.assertFalse(self.recorded("systemctl"))
        self.assertFalse(self.recorded("swaymsg"))
        self.assertFalse(self.recorded("powerprofilesctl"))

    def test_power_profile_choices_only_set_the_selected_profile(self):
        profiles = (("power-saver", "Power Saver"), ("balanced", "Balanced"),
                    ("performance", "Performance"))
        for row, (profile, label) in enumerate(profiles):
            with self.subTest(profile=profile):
                (self.root / "dialog-index").unlink(missing_ok=True)
                self.calls.unlink(missing_ok=True)
                self.power_menu("--power-profile", dialogs=[[str(row), 0]])
                self.assertEqual(self.recorded("powerprofilesctl"), [["set", profile]])
                self.assertEqual(self.recorded("notify-send")[0][-1], label)

    def test_power_profile_failure_is_reported(self):
        self.power_menu("--power-profile", dialogs=[["2", 0]],
                        TEST_PROFILE_FAILURE="1", expected=1)
        notifications = self.recorded("notify-send")
        self.assertEqual(len(notifications), 1)
        self.assertIn("critical", notifications[0])
        self.assertIn("Switch rejected", notifications[0][-1])

    def test_direct_power_profile_has_no_parent_row(self):
        self.power_menu("--power-profile", dialogs=[["0", 0]])
        menu = (self.root / "menu-0").read_text()
        self.assertNotIn("Back", menu)
        self.assertNotIn("current", menu)
        self.assertEqual(len(menu.splitlines()), 3)
        self.assertEqual(self.recorded("powerprofilesctl"), [["set", "power-saver"]])

    def test_display_escape_does_not_reopen_utilities(self):
        self.power_menu(dialogs=[["1", 0], ["", 1]])
        self.assertEqual(len(self.recorded("rofi")), 2)
        self.assertNotIn("Back", (self.root / "menu-1").read_text())
        self.assertFalse(self.recorded("wlsunset-apply"))

    def test_display_choice_applies_one_mode(self):
        self.power_menu(dialogs=[["1", 0], ["2", 0]])
        self.assertEqual(self.recorded("wlsunset-apply"), [["natural"]])
        self.assertEqual(len(self.recorded("rofi")), 2)

    def test_screenshot_choices_keep_their_action_mapping(self):
        for row, action in enumerate(("selection-clipboard", "fullscreen-clipboard",
                                      "selection-save", "fullscreen-save")):
            with self.subTest(action=action):
                (self.root / "dialog-index").unlink(missing_ok=True)
                self.run_command(self.home / ".local/bin/screenshot-menu",
                                 TEST_DIALOGS=json.dumps([[str(row), 0]]))
                self.assertEqual(self.recorded("screenshot")[-1], [action])

    def test_screenshot_escape_does_not_capture(self):
        self.run_command(self.home / ".local/bin/screenshot-menu",
                         TEST_DIALOGS=json.dumps([["", 1]]))
        self.assertFalse(self.recorded("screenshot"))

    def test_power_profile_invalid_choice_has_no_actions(self):
        for choice in ("", "-1", "3", "invalid"):
            with self.subTest(choice=choice):
                (self.root / "dialog-index").unlink(missing_ok=True)
                self.calls.unlink(missing_ok=True)
                self.power_menu("--power-profile", dialogs=[[choice, 0]])
                self.assertFalse(self.recorded("powerprofilesctl"))
                self.assertFalse(self.recorded("notify-send"))

    def test_utilities_excludes_power_profile(self):
        self.power_menu(dialogs=[["", 1]])
        self.assertNotIn("Power Profile", (self.root / "menu-0").read_text())
        self.assertFalse(self.recorded("powerprofilesctl"))

    def test_rofi_menu_labels_remain_literal_text(self):
        label = 'A & B <b>literal</b> · tiếng Việt'
        row = self.run_command(
            "bash", "-c", 'source "$1"; rofi_item "$2" "$3"', "rofi-item",
            self.home / ".local/lib/rofi-menu.sh", label, "",
        )
        rendered = ET.fromstring("<root>" + row + "</root>")
        self.assertEqual("".join(rendered.itertext()), "\t" + label + "\n")
        self.assertEqual([child.tag for child in rendered], ["span"])

    def test_expiry_before_every_transition(self):
        for action in ("pause", "toggle", "resume", "lock-pause", "sleep-pause", "reset", "status"):
            with self.subTest(action=action):
                self.engine("start", "1")
                self.advance(61)
                before = len(self.history())
                self.engine(action)
                self.assertEqual(self.field("DURATION"), "")
                self.assertEqual(len(self.history()), before + 1)
                self.engine("resume")
                self.assertEqual(self.field("RUNNING"), "false")

    def test_old_paused_zero_is_finalized(self):
        self.engine("start", "1")
        path = self.runtime / "countdown-state"
        path.write_text(path.read_text().replace('RUNNING="true"', 'RUNNING="false"')
                        + '\nREMAINING="0"\n')
        self.engine("status")
        self.assertEqual(self.field("DURATION"), "")
        self.assertEqual(len(self.history()), 1)

    def test_pause_resume_and_add_are_consistent(self):
        self.engine("start", "10")
        self.advance(120)
        self.engine("pause")
        self.assertEqual(self.field("REMAINING"), "480")
        self.advance(30)
        self.engine("pause")
        self.assertEqual(self.field("REMAINING"), "480")
        self.engine("add", "5")
        self.assertEqual(self.field("REMAINING"), "780")
        self.assertEqual(self.field("INITIAL_DURATION"), "10")
        self.engine("resume")
        end = self.field("END_TIME")
        self.advance(30)
        self.engine("resume")
        self.assertEqual(self.field("END_TIME"), end)

    def test_sleep_and_lock_preserve_time_in_either_order(self):
        for order in (("sleep-pause", "lock-pause"), ("lock-pause", "sleep-pause")):
            with self.subTest(order=order):
                self.engine("start", "10")
                self.advance(120)
                for action in order:
                    self.engine(action)
                self.advance(3600)
                self.engine("sleep-resume")
                self.assertEqual(self.field("RUNNING"), "false")
                self.assertEqual(self.field("REMAINING"), "480")

    def test_concurrent_expiry_logs_once(self):
        self.engine("start", "1")
        self.advance(61)
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            list(pool.map(lambda _: self.engine("status"), range(8)))
        self.assertEqual(len(self.history()), 1)
        self.assertEqual(self.field("DURATION"), "")

    def test_worker_restart_finishes_without_waybar(self):
        self.engine("start", "1")
        first = self.worker()
        os.killpg(first.pid, signal.SIGKILL)
        first.wait(timeout=5)
        second = self.worker()
        self.advance(61)
        self.wait_until(lambda: self.field("DURATION") == "")
        self.assertIsNone(second.poll())
        self.assertEqual((self.root / "swayidle.service").read_text(), "active")
        self.wait_until(lambda: len(self.history()) == 1)

    def test_status_recovers_a_stopped_worker(self):
        self.engine("start", "10")
        (self.root / "countdown-engine.service").write_text("inactive")
        self.engine("status")
        self.assertEqual((self.root / "countdown-engine.service").read_text(), "active")

    def test_idle_condition_and_reconciliation(self):
        self.engine("idle-allowed")
        self.engine("start", "10")
        self.engine("idle-allowed", expected=1)
        idle = self.root / "swayidle.service"
        idle.write_text("active")
        self.worker()
        self.wait_until(lambda: idle.read_text() == "inactive")
        self.engine("pause")
        self.engine("idle-allowed")
        self.engine("inhibit-toggle")
        self.engine("idle-allowed", expected=1)
        idle.write_text("active")
        self.wait_until(lambda: idle.read_text() == "inactive")
        self.engine("inhibit-toggle")
        self.engine("idle-allowed")

    def test_stale_pause_menu_does_not_resume(self):
        self.engine("start", "10")
        self.run_command("bash", self.menu, TEST_DIALOGS=json.dumps([["0", 0]]),
                         TEST_PAUSE_IN_MENU="1")
        self.assertEqual(self.field("RUNNING"), "false")

    def test_countdown_add_cancel_does_not_change_the_session(self):
        self.engine("start", "25")
        before = (self.runtime / "countdown-state").read_text()
        self.run_command("bash", self.menu, TEST_DIALOGS=json.dumps([["2", 0], ["", 1]]))
        self.assertEqual((self.runtime / "countdown-state").read_text(), before)

    def test_countdown_add_accepts_surrounding_whitespace(self):
        self.engine("start", "25")
        end = int(self.field("END_TIME"))
        self.run_command("bash", self.menu, TEST_DIALOGS=json.dumps([["2", 0], ["  5 \t", 0]]))
        self.assertEqual(int(self.field("END_TIME")), end + 300)

    def test_menu_cancellation_empty_task_and_whitespace(self):
        cases = (
            ([("25   ", 0), ("", 0)], ["start", "25", ""]),
            ([(" \t25 \t", 0), ("Read", 0)], ["start", "25", "Read"]),
            ([("25", 0), ("", 1)], None),
            ([("25", 0), ("Discard", 1)], None),
            ([("25 ", 1)], None),
            ([("   ", 0)], None),
        )
        # Record menu requests rather than starting a real timer.
        self.executable(self.engine_path, '#!/usr/bin/env python3\nimport json,os,sys\n'
                        'with open(os.environ["TEST_ROOT"]+"/engine-calls","a") as f: '
                        'f.write(json.dumps(sys.argv[1:])+"\\n")\n')
        for dialogs, expected in cases:
            with self.subTest(dialogs=dialogs):
                for name in ("engine-calls", "dialog-index"):
                    (self.root / name).unlink(missing_ok=True)
                self.run_command("bash", self.menu, TEST_DIALOGS=json.dumps(dialogs))
                actions = [json.loads(line) for line in (self.root / "engine-calls").read_text().splitlines()]
                self.assertEqual(actions, [["status"]] + ([expected] if expected else []))

    def pdf_script(self):
        text = (SOURCE / "home/features/sioyek/open.nix").read_text()
        body = textwrap.dedent(re.search(r"text = ''\n(.*?)\n\s*'';", text, re.S).group(1))
        for package, command in (("jq", "jq"), ("sway", "swaymsg"), ("sioyek", "sioyek")):
            target = shutil.which("jq") if command == "jq" else str(self.bin / command)
            body = body.replace('${pkgs.' + package + '}/bin/' + command, target)
        return self.executable(self.root / "sioyek-open", body)

    def test_same_name_pdf_forwards_requested_path(self):
        tree = {"nodes": [{"id": 42, "app_id": "sioyek", "name": "notes.pdf - Sioyek"}]}
        path = "/new course/notes.pdf"
        self.run_command("bash", self.pdf_script(), path, TEST_TREE=json.dumps(tree))
        self.assertEqual(self.recorded("sioyek"), [[path]])
        self.assertEqual(self.recorded("swaymsg"), [])

    def test_pdf_launcher_without_path_focuses_existing_window(self):
        tree = {"nodes": [{"id": 42, "app_id": "sioyek", "name": "notes.pdf - Sioyek"}]}
        self.run_command("bash", self.pdf_script(), TEST_TREE=json.dumps(tree))
        self.assertEqual(self.recorded("sioyek"), [])
        self.assertIn(["[con_id=42] focus"], self.recorded("swaymsg"))

    def generation_script(self):
        profiles = self.root / "profiles"
        profiles.mkdir()
        for name in ("old-system", "running-system", "new-system", "boot/loader/entries", "flake"):
            (self.root / name).mkdir(parents=True)
        (self.root / "flake/flake.nix").touch()
        (profiles / "system-3-link").symlink_to(self.root / "old-system")
        (profiles / "system-7-link").symlink_to(self.root / "running-system")
        self.profile = profiles / "system"
        self.profile.symlink_to("system-7-link")
        text = (SOURCE / "home/shell/scripts/reset-generations.sh").read_text()
        text = text.replace("PROFILE=/nix/var/nix/profiles/system", "PROFILE=" + shlex.quote(str(self.profile)))
        text = text.replace("GEN_DIR=/nix/var/nix/profiles", "GEN_DIR=" + shlex.quote(str(profiles)))
        text = text.replace("/run/current-system", str(self.root / "running-system"))
        text = text.replace("/boot", str(self.root / "boot"))
        return self.executable(self.root / "reset-generations", text)

    def test_generation_cleanup_keeps_previous_configuration(self):
        script = self.generation_script()
        self.run_command("bash", script, self.root / "flake", TEST_PROFILE=str(self.profile))
        self.assertEqual(os.readlink(self.profile), "system-2-link")
        self.assertEqual((self.profile.parent / "system-1-link").resolve(), self.root / "running-system")
        self.assertEqual(self.recorded("nix-collect-garbage"), [[]])
        names = [json.loads(line)[0] for line in self.calls.read_text().splitlines()]
        self.assertLess(names.index("nix"), next(i for i, line in enumerate(self.calls.read_text().splitlines())
                                               if "--delete-generations" in line))

    def test_generation_build_failure_deletes_nothing(self):
        script = self.generation_script()
        self.run_command("bash", script, self.root / "flake", expected=1,
                         TEST_PROFILE=str(self.profile), TEST_BUILD_FAILURE="1")
        self.assertEqual(os.readlink(self.profile), "system-7-link")
        self.assertTrue((self.profile.parent / "system-3-link").exists())
        self.assertEqual(self.recorded("nix-collect-garbage"), [])


if __name__ == "__main__":
    unittest.main()
