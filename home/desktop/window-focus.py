"""Share Sway window events between urgency handling and Alt+Tab history."""

import json
import os
from pathlib import Path
import subprocess
import sys


def windows(node):
    if node.get("name") == "__i3_scratch":
        return
    if node.get("app_id") is not None or node.get("window") is not None:
        yield node
    for child in node.get("nodes", []) + node.get("floating_nodes", []):
        yield from windows(child)


def previous_window(history, tree):
    available = {node["id"]: node for node in windows(tree)}
    return next((wid for wid in history
                 if wid in available and not available[wid].get("focused")), None)


def remember(history, wid):
    return [wid] + [old for old in history if old != wid]


def save_history(state, history):
    temporary = state.with_suffix(".tmp")
    temporary.write_text(json.dumps(history))
    temporary.replace(state)


def focus(swaymsg, wid):
    # Sway may have closed the window since the event or snapshot arrived.
    subprocess.run([swaymsg, "-q", f"[con_id={wid}] focus"], check=False)


def watch(swaymsg, state):
    with subprocess.Popen(
        [swaymsg, "-r", "-m", "-t", "subscribe", '["window", "tick"]'],
        stdout=subprocess.PIPE, text=True,
    ) as events:
        # The initial tick confirms subscription before the focus snapshot.
        initial_tick = json.loads(events.stdout.readline())
        if not initial_tick.get("first"):
            raise RuntimeError("Could not subscribe to Sway window events")
        tree = json.loads(subprocess.check_output([swaymsg, "-t", "get_tree"]))
        history = [node["id"] for node in windows(tree) if node.get("focused")]
        save_history(state, history)
        for line in events.stdout:
            event = json.loads(line)
            node = event.get("container", {})
            wid = node.get("id")
            if wid is None:
                continue
            if event.get("change") == "focus":
                if node.get("app_id") is None and node.get("window") is None:
                    continue
                history = remember(history, wid)
                save_history(state, history)
            elif event.get("change") == "close":
                history = [old for old in history if old != wid]
                save_history(state, history)
            elif event.get("change") == "urgent" and node.get("urgent"):
                focus(swaymsg, wid)
    raise RuntimeError("Sway window event subscription ended")


def main():
    swaymsg, mode = sys.argv[1:]
    state = Path(os.environ["XDG_RUNTIME_DIR"]) / "sway-window-focus.json"
    if mode == "--watch":
        watch(swaymsg, state)
    elif mode == "--previous":
        try:
            history = json.loads(state.read_text())
        except FileNotFoundError:
            return
        tree = json.loads(subprocess.check_output([swaymsg, "-t", "get_tree"]))
        wid = previous_window(history, tree)
        if wid is not None:
            focus(swaymsg, wid)
    else:
        raise SystemExit("Usage: window-focus.py SWAYMSG --watch|--previous")


if __name__ == "__main__":
    main()
