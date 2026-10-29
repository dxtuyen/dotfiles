"""Media controls must stay responsive when notification delivery is slow."""

import concurrent.futures
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import textwrap
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1]


class MediaNotifyTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="media-notify-test-")
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.bin = self.root / "bin"
        self.runtime = self.root / "runtime"
        self.bin.mkdir()
        self.runtime.mkdir()
        self.env = dict(os.environ, TEST_MEDIA_ROOT=str(self.root),
                        XDG_RUNTIME_DIR=str(self.runtime),
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])
        self.processes = []
        self.addCleanup(self.stop_processes)
        for name, value in (("volume", "50"), ("brightness", "50"), ("brightness-max", "100"),
                            ("sink-muted", "0"), ("source-muted", "0")):
            (self.root / name).write_text(value)
        stub = self.bin / "command-stub"
        stub.write_text("#!" + shutil.which("python3") + "\n" + textwrap.dedent('''\
            import json, os, pathlib, sys, time
            root = pathlib.Path(os.environ["TEST_MEDIA_ROOT"])
            name, args = pathlib.Path(sys.argv[0]).name, sys.argv[1:]

            def gate(name):
                if (root / ("hold-" + name)).exists():
                    (root / ("entered-" + name)).touch()
                    while not (root / ("release-" + name)).exists():
                        time.sleep(0.01)

            if name == "wpctl":
                if args[0] == "get-volume":
                    muted = root / ("source-muted" if args[1] == "@DEFAULT_AUDIO_SOURCE@" else "sink-muted")
                    print("Volume: %.2f%s" % (int((root / "volume").read_text()) / 100,
                                             " [MUTED]" if muted.read_text() == "1" else ""))
                elif args[0] == "set-mute":
                    if (root / "fail-write").exists():
                        sys.exit(1)
                    path = root / ("source-muted" if args[1] == "@DEFAULT_AUDIO_SOURCE@" else "sink-muted")
                    path.write_text(str(1 - int(path.read_text())) if args[-1] == "toggle" else args[-1])
                else:
                    if (root / "fail-write").exists():
                        sys.exit(1)
                    gate("volume-set")
                    path = root / "volume"
                    value = int(path.read_text())
                    time.sleep(0.01)  # Expose lost read/modify/write updates without a control lock.
                    step = round(float(args[-1].rstrip("+-").rstrip("%")))
                    value += step if args[-1].endswith("+") else -step
                    limit = round(float(args[args.index("-l") + 1]) * 100) if "-l" in args else 150
                    path.write_text(str(max(0, min(limit, value))))
            elif name == "brightnessctl":
                path = root / "brightness"
                maximum = int((root / "brightness-max").read_text())
                if "set" in args:
                    if (root / "fail-write").exists():
                        sys.exit(1)
                    value = int(path.read_text())
                    time.sleep(0.01)
                    step = max(1, round(maximum * 0.1))
                    value += step if args[-1].startswith("+") else -step
                    minimum = next((int(a.split("=", 1)[1]) for a in args if a.startswith("--min-value=")), 0)
                    path.write_text(str(max(minimum, min(maximum, value))))
                elif "max" in args:
                    print(maximum)
                else:
                    value = int(path.read_text())
                    print("backlight,backlight,%s,%s%%,%s" % (value, round(value * 100 / maximum), maximum))
            elif name == "notify-send":
                channel = next(a.removeprefix("string:x-canonical-private-synchronous:media-")
                               for a in args if a.startswith("string:x-canonical-private-synchronous:media-"))
                with (root / "notifications").open("a") as stream:
                    stream.write(json.dumps([channel, args]) + "\\n")
                gate("notify-" + channel)
                if (root / "fail-notify").exists():
                    sys.exit(1)
        '''))
        stub.chmod(0o755)
        for name in ("wpctl", "brightnessctl", "notify-send"):
            (self.bin / name).symlink_to(stub)
        text = (SOURCE / "home/scripts/media/media-notify.sh").read_text()
        text = text.replace("@flock@", shutil.which("flock")).replace("@timeout@", shutil.which("timeout"))
        self.script = self.root / "media-notify"
        self.script.write_text(text)

    def stop_processes(self):
        for process in self.processes:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            process.communicate(timeout=5)

    def start(self, action):
        process = subprocess.Popen(
            ["bash", str(self.script), action], env=self.env, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,
        )
        self.processes.append(process)
        return process

    def finish(self, process, expected=0):
        stdout, stderr = process.communicate(timeout=3)
        self.assertEqual(process.returncode, expected, stderr)
        return stdout

    def run_action(self, action):
        return self.finish(self.start(action))

    def wait_until(self, predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.01)
        self.fail("Media worker did not reach the expected state")

    def worker_idle(self, channel):
        with (self.runtime / f"media-notify-{channel}.worker.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return False
        return True

    def notifications(self, channel):
        path = self.root / "notifications"
        if not path.exists():
            return []
        return [args for name, args in map(json.loads, path.read_text().splitlines()) if name == channel]

    def test_slow_notification_does_not_delay_or_lose_volume_changes(self):
        (self.root / "hold-notify-volume").touch()
        self.run_action("volume-up")
        self.wait_until(lambda: (self.root / "entered-notify-volume").exists())
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            list(pool.map(self.run_action, ["volume-up"] * 6))
        self.assertEqual((self.root / "volume").read_text(), "85")
        self.assertFalse(self.worker_idle("volume"))
        self.assertEqual(len(self.notifications("volume")), 1)
        (self.root / "release-notify-volume").touch()
        self.wait_until(lambda: self.worker_idle("volume"))
        notifications = self.notifications("volume")
        self.assertEqual(len(notifications), 2)
        self.assertEqual(notifications[-1][-2:], ["Volume", "85%"])
        self.assertIn("int:value:85", notifications[-1])

    def test_volume_and_brightness_writes_do_not_block_each_other(self):
        (self.root / "hold-volume-set").touch()
        volume = self.start("volume-up")
        self.wait_until(lambda: (self.root / "entered-volume-set").exists())
        self.run_action("brightness-up")
        self.assertEqual((self.root / "brightness").read_text(), "60")
        self.assertIsNone(volume.poll())
        (self.root / "release-volume-set").touch()
        self.finish(volume)
        self.wait_until(lambda: self.worker_idle("volume") and self.worker_idle("brightness"))

    def test_concurrent_brightness_changes_keep_every_step(self):
        (self.root / "hold-notify-brightness").touch()
        self.run_action("brightness-down")
        self.wait_until(lambda: (self.root / "entered-notify-brightness").exists())
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
            list(pool.map(self.run_action, ["brightness-down"] * 3))
        self.assertEqual((self.root / "brightness").read_text(), "10")
        (self.root / "release-notify-brightness").touch()
        self.wait_until(lambda: self.worker_idle("brightness"))
        self.assertEqual(self.notifications("brightness")[-1][-2:], ["Brightness", "10%"])

    def test_mute_and_microphone_have_independent_popups(self):
        for action, channel, summary, body in (
            ("volume-mute", "volume", "Volume", "Muted"),
            ("mic-mute", "microphone", "Microphone", "Muted"),
            ("volume-mute", "volume", "Volume", "50%"),
            ("mic-mute", "microphone", "Microphone", "On"),
        ):
            with self.subTest(action=action, body=body):
                self.run_action(action)
                self.wait_until(lambda: self.worker_idle(channel))
                self.assertEqual(self.notifications(channel)[-1][-2:], [summary, body])

    def test_volume_stays_capped_and_notification_failure_is_nonfatal(self):
        (self.root / "volume").write_text("98")
        (self.root / "fail-notify").touch()
        self.run_action("volume-up")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "100")
        self.run_action("volume-down")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "95")

    def test_brightness_never_falls_below_five_percent_on_different_devices(self):
        for maximum in (100, 24242, 3):
            with self.subTest(maximum=maximum):
                (self.root / "brightness-max").write_text(str(maximum))
                (self.root / "brightness").write_text("0")
                minimum = (maximum * 5 + 99) // 100
                for _ in range(2):
                    self.run_action("brightness-down")
                    self.wait_until(lambda: self.worker_idle("brightness"))
                    self.assertEqual(int((self.root / "brightness").read_text()), minimum)
                self.assertEqual(self.notifications("brightness")[-1][-1], f"{round(minimum * 100 / maximum)}%")
                (self.root / "brightness").write_text(str(maximum))
                self.run_action("brightness-up")
                self.wait_until(lambda: self.worker_idle("brightness"))
                self.assertEqual(int((self.root / "brightness").read_text()), maximum)
                self.assertEqual(self.notifications("brightness")[-1][-1], "100%")

    def test_volume_bounds_and_zero_remain_consistent(self):
        for initial, action, expected in ((2, "volume-down", 0), (0, "volume-down", 0),
                                          (0, "volume-up", 5), (150, "volume-down", 100)):
            with self.subTest(initial=initial, action=action):
                (self.root / "volume").write_text(str(initial))
                (self.root / "sink-muted").write_text("0")
                self.run_action(action)
                self.wait_until(lambda: self.worker_idle("volume"))
                self.assertEqual(int((self.root / "volume").read_text()), expected)
                self.assertEqual((self.root / "sink-muted").read_text(), "1" if expected == 0 else "0")
                self.assertEqual(self.notifications("volume")[-1][-1], "Muted" if expected == 0 else f"{expected}%")

    def test_volume_up_unmutes_but_down_preserves_mute(self):
        (self.root / "sink-muted").write_text("1")
        (self.root / "source-muted").write_text("1")
        self.run_action("volume-down")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "45")
        self.assertEqual((self.root / "sink-muted").read_text(), "1")
        self.assertEqual(self.notifications("volume")[-1][-1], "Muted")
        self.run_action("volume-up")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "45")
        self.assertEqual((self.root / "sink-muted").read_text(), "0")
        self.assertEqual((self.root / "source-muted").read_text(), "1")
        self.assertEqual(self.notifications("volume")[-1][-1], "45%")
        self.run_action("volume-up")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "50")
        self.assertEqual(self.notifications("volume")[-1][-1], "50%")

    def test_reducing_to_zero_mutes_and_raising_restores_one_step(self):
        (self.root / "volume").write_text("2")
        self.run_action("volume-down")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "0")
        self.assertEqual((self.root / "sink-muted").read_text(), "1")
        self.assertEqual(self.notifications("volume")[-1][-1], "Muted")
        self.run_action("volume-up")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "5")
        self.assertEqual((self.root / "sink-muted").read_text(), "0")
        self.assertEqual(self.notifications("volume")[-1][-1], "5%")

    def test_mute_toggle_preserves_selected_volume(self):
        (self.root / "volume").write_text("37")
        for muted in ("1", "0"):
            self.run_action("volume-mute")
            self.wait_until(lambda: self.worker_idle("volume"))
            self.assertEqual((self.root / "volume").read_text(), "37")
            self.assertEqual((self.root / "sink-muted").read_text(), muted)

    def test_hung_notification_times_out_and_later_updates_recover(self):
        (self.root / "hold-notify-volume").touch()
        self.run_action("volume-up")
        self.wait_until(lambda: (self.root / "entered-notify-volume").exists())
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual((self.root / "volume").read_text(), "55")
        (self.root / "release-notify-volume").touch()
        self.run_action("volume-down")
        self.wait_until(lambda: self.worker_idle("volume"))
        self.assertEqual(self.notifications("volume")[-1][-2:], ["Volume", "50%"])

    def test_failed_control_writes_do_not_report_success(self):
        (self.root / "fail-write").touch()
        for action in ("volume-up", "volume-mute", "mic-mute", "brightness-up"):
            with self.subTest(action=action):
                self.finish(self.start(action), expected=1)
        self.assertEqual((self.root / "volume").read_text(), "50")
        self.assertEqual((self.root / "brightness").read_text(), "50")
        self.assertFalse((self.root / "notifications").exists())

    def test_unknown_action_does_not_change_controls(self):
        self.finish(self.start("unknown"), expected=2)
        self.assertEqual((self.root / "volume").read_text(), "50")
        self.assertEqual((self.root / "brightness").read_text(), "50")
        self.assertFalse(self.notifications("volume"))


if __name__ == "__main__":
    unittest.main()
