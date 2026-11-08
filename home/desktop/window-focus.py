"""Focus Sway windows when they report urgency."""

import json
import subprocess
import sys


def focus(swaymsg, wid):
    # Sway may have closed the window since the event or snapshot arrived.
    subprocess.run([swaymsg, "-q", f"[con_id={wid}] focus"], check=False)


def watch(swaymsg):
    with subprocess.Popen(
        [swaymsg, "-r", "-m", "-t", "subscribe", '["window"]'],
        stdout=subprocess.PIPE, text=True,
    ) as events:
        for line in events.stdout:
            event = json.loads(line)
            node = event.get("container", {})
            wid = node.get("id")
            if wid is None:
                continue
            if event.get("change") == "urgent" and node.get("urgent"):
                focus(swaymsg, wid)
    raise RuntimeError("Sway window event subscription ended")


def main():
    swaymsg, mode = sys.argv[1:]
    if mode == "--watch":
        watch(swaymsg)
    else:
        raise SystemExit("Usage: window-focus.py SWAYMSG --watch")


if __name__ == "__main__":
    main()
