import json
import os
import selectors
import subprocess
import time
from pathlib import Path

SWAYMSG = os.environ["SWAY_WINDOW_EVENTS_SWAYMSG"]
PKILL = os.environ["SWAY_WINDOW_EVENTS_PKILL"]
WAYBAR_SIGNAL = 9
DEBOUNCE_SECONDS = 0.15
SUBSCRIPTIONS = '["window", "workspace"]'
FOCUS_STATE = Path(os.environ.get(
    "XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"
)) / "sway-window-focus-mru.json"
SWAY_SOCKET = os.environ.get("SWAYSOCK")
focus_order = []

def save_focus_order():
    try:
        FOCUS_STATE.parent.mkdir(parents=True, exist_ok=True)
        temporary = FOCUS_STATE.with_suffix(f".tmp.{os.getpid()}")
        temporary.write_text(json.dumps({
            "socket": SWAY_SOCKET,
            "order": focus_order,
        }))
        temporary.replace(FOCUS_STATE)
    except OSError:
        pass

def remember_focus(message):
    if message.get("change") != "focus":
        return False
    container = message.get("container") or {}
    con_id = container.get("id")
    if con_id is None:
        return False
    if con_id in focus_order:
        focus_order.remove(con_id)
    focus_order.insert(0, con_id)
    save_focus_order()
    return True

def initialize_focus_order():
    try:
        tree = json.loads(subprocess.run(
            [SWAYMSG, "-t", "get_tree"], check=True,
            capture_output=True, text=True,
        ).stdout)
    except (OSError, subprocess.CalledProcessError, ValueError):
        return

    valid_ids = set()
    focused_ids = []
    def visit(node):
        if node.get("type") in ("con", "floating_con") and node.get("id") is not None:
            valid_ids.add(node["id"])
            if node.get("focused"):
                focused_ids.append(node["id"])
        for key in ("nodes", "floating_nodes"):
            for child in node.get(key, []):
                visit(child)
    visit(tree)

    try:
        previous = json.loads(FOCUS_STATE.read_text())
        if previous.get("socket") == SWAY_SOCKET:
            focus_order.extend(
                con_id for con_id in previous.get("order", [])
                if con_id in valid_ids
            )
    except (OSError, ValueError, AttributeError):
        pass
    for con_id in focused_ids:
        if con_id in focus_order:
            focus_order.remove(con_id)
        focus_order.insert(0, con_id)
    save_focus_order()

initialize_focus_order()

def refresh_waybar():
    subprocess.run(
        [PKILL, f"-RTMIN+{WAYBAR_SIGNAL}", "-x", ".waybar-wrapped"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )

def affects_away_list(message):
    if message.get("success") is True:
        return True
    change = message.get("change")
    # Workspace events carry a `current` workspace. Only switching the
    # focused workspace changes which floating windows are considered away.
    if "current" in message:
        return change == "focus"
    # Focus changes update the MRU order and the first app shown in Waybar.
    return change in {"new", "close", "move", "floating", "focus"}

while True:
    try:
        sway = subprocess.Popen(
            [SWAYMSG, "--monitor", "--raw", "--type", "subscribe", SUBSCRIPTIONS],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
    except OSError:
        time.sleep(2)
        continue

    selector = selectors.DefaultSelector()
    selector.register(sway.stdout, selectors.EVENT_READ)
    buffer = b""
    pending_refresh = False
    last_event = 0.0

    try:
        while sway.poll() is None:
            timeout = (
                max(0, DEBOUNCE_SECONDS - (time.monotonic() - last_event))
                if pending_refresh else None
            )
            ready = selector.select(timeout)

            if not ready:
                refresh_waybar()
                pending_refresh = False
                continue

            chunk = os.read(sway.stdout.fileno(), 4096)
            if not chunk:
                break
            buffer += chunk

            while b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                try:
                    message = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    continue
                if message.get("change") == "focus":
                    remember_focus(message)
                # The success response confirms the subscription is active;
                # refresh once, then coalesce bursts of relevant events.
                if affects_away_list(message):
                    pending_refresh = True
                    last_event = time.monotonic()
    finally:
        selector.close()
        if sway.poll() is None:
            sway.terminate()
            try:
                sway.wait(timeout=1)
            except subprocess.TimeoutExpired:
                sway.kill()
                sway.wait()

    if pending_refresh:
        refresh_waybar()
    time.sleep(1)
