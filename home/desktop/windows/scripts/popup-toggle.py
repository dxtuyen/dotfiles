"""Toggle native Sway popup groups and launch each new popup independently."""

import argparse
from dataclasses import dataclass
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import time


@dataclass
class Context:
    node: dict
    workspace: dict | None
    floating_root: dict | None
    parents: tuple = ()


def contexts(node, workspace=None, floating_root=None, parents=()):
    if node.get("type") == "workspace":
        workspace = node
    yield Context(node, workspace, floating_root, parents)
    for child in node.get("nodes", []):
        yield from contexts(child, workspace, floating_root, parents + (node,))
    for child in node.get("floating_nodes", []):
        yield from contexts(child, workspace, child, parents + (node,))


def select_popup(tree, pattern):
    """Prefer the focused match, then the active workspace, then a hidden popup."""
    entries = list(contexts(tree))
    focused = next((ctx for ctx in entries if ctx.node.get("focused")), None)
    current = focused.workspace if focused else None
    matcher = re.compile(pattern, re.IGNORECASE)
    matches = []
    for entry in entries:
        properties = entry.node.get("window_properties") or {}
        identity = (entry.node.get("app_id"), properties.get("class"))
        if any(matcher.fullmatch(value) for value in identity if value):
            matches.append(entry)
    if not matches:
        return None, current
    ctx = min(matches, key=lambda item: (
        not item.node.get("focused", False),
        item.workspace != current,
        (item.workspace or {}).get("name") != "__i3_scratch",
    ))
    return ctx, current


def popup_command(tree, pattern):
    ctx, current = select_popup(tree, pattern)
    if ctx is None:
        return None

    # A floating split is one popup: target its root, not a window inside it.
    target = ctx.floating_root if ctx.floating_root is not None else ctx.node
    selector = f'[con_id={target["id"]}] '
    hidden = (ctx.workspace or {}).get("name") == "__i3_scratch"
    if not hidden and current is not None and ctx.workspace == current:
        if any(item.node.get("focused") for item in contexts(target)):
            return selector + "fullscreen disable, move scratchpad"
        # Showing an already visible scratchpad toggles it off, so only focus it.
        return f'[con_id={ctx.node["id"]}] focus'
    if target.get("scratchpad_state", "none") != "none":
        return selector + "scratchpad show"

    # Adopt a window that was opened outside the scratchpad workflow.
    return selector + "fullscreen disable, move scratchpad, scratchpad show"


def prepare_launch(tree):
    """Focus the workspace so a new popup cannot join the focused floating split."""
    focused = next((ctx for ctx in contexts(tree) if ctx.node.get("focused")), None)
    if focused is None or focused.floating_root is None:
        return []
    for index, parent in enumerate(focused.parents):
        if parent.get("type") == "workspace":
            return ["focus parent"] * (len(focused.parents) - index)
    return []


def ipc(*args):
    result = subprocess.run(["swaymsg", "-r", *args], check=True, capture_output=True, text=True)
    response = json.loads(result.stdout)
    if isinstance(response, list) and any(item.get("success") is False for item in response):
        raise RuntimeError(str(response))
    return response


def toggle(args):
    # Ignore repeated presses during startup or another toggle of this popup.
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    key = hashlib.sha256(args.match.encode()).hexdigest()[:16]
    with (runtime / f"sway-popup-{key}.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        tree = ipc("-t", "get_tree")
        command = popup_command(tree, args.match)
        if command is None:
            launch = args.launch[1:] if args.launch[:1] == ["--"] else args.launch
            if not launch:
                raise ValueError("A launch command is required for an absent popup")
            for command in prepare_launch(tree):
                ipc(command)
            ipc("exec " + shlex.join(launch))
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if select_popup(ipc("-t", "get_tree"), args.match)[0] is not None:
                    return
                time.sleep(0.05)
            raise RuntimeError("Popup did not create a window within 15 seconds")
        ipc(command)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--match", required=True)
    parser.add_argument("launch", nargs=argparse.REMAINDER)
    toggle(parser.parse_args())


if __name__ == "__main__":
    main()
