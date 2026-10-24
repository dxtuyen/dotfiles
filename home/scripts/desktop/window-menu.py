import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

swaymsg = shutil.which("swaymsg")
if not swaymsg:
    sys.exit("window-menu: swaymsg is not in PATH")

# Modes: --away, --normal, or --scratchpad. Default lists all visible windows.
stashed_only = "--scratchpad" in sys.argv[1:]
away_only = "--away" in sys.argv[1:]
normal_only = "--normal" in sys.argv[1:]
first_only = "--first" in sys.argv[1:]
show_all = "--show-all" in sys.argv[1:]
waybar_only = "--waybar" in sys.argv[1:]
after_kill = "--after-kill" in sys.argv[1:]
after_open = "--after-open" in sys.argv[1:]

tree = json.loads(subprocess.run(
    [swaymsg, "-t", "get_tree"], check=True, capture_output=True, text=True
).stdout)

# The away list needs the focused workspace.
try:
    workspaces = json.loads(subprocess.run(
        [swaymsg, "-t", "get_workspaces"], check=True,
        capture_output=True, text=True).stdout)
    current_ws = next(w["name"] for w in workspaces if w.get("focused"))
except (subprocess.CalledProcessError, ValueError, StopIteration, KeyError):
    current_ws = None

def stashed(window):
    """Return whether the window is hidden in the scratchpad."""
    return (window.get("scratchpad_state") not in (None, "none")
            and not window.get("visible"))

def collect_windows(node, ws=None, in_floating_group=False, split_path=()):
    # Track workspace ancestry; hidden windows live under __i3_scratch.
    #
    # Stashed means `in scratchpad and not visible`. Comparing
    # scratchpad_state to "hidden" is too strict: Sway also parks windows in
    # "fresh"/"changed" after showing them, and those remain summonable.
    # `visible` alone is not enough either (it only reports the focused
    # workspace), so pair it with the scratchpad membership test.
    if node.get("type") == "workspace":
        ws = node.get("name") or ws
    node_type = node.get("type")
    floating = in_floating_group or node_type == "floating_con"
    children = node.get("nodes", []) + node.get("floating_nodes", [])
    properties = node.get("window_properties") or {}
    # Sway also represents split/tabbed/stacked layout containers as `con`.
    # Only offer real client windows in the picker, never those structural
    # containers (which otherwise appear as phantom "Window" rows).
    is_client = (
        node_type in ("con", "floating_con")
        and not children
        and bool(node.get("app_id") or node.get("window") is not None
                 or properties or node.get("pid"))
    )
    if node_type in ("con", "floating_con") and children:
        layout = node.get("layout")
        if layout == "splith":
            split_path = (*split_path, "horizontal")
        elif layout == "splitv":
            split_path = (*split_path, "vertical")
    if is_client:
        state = node.get("scratchpad_state")
        in_scratch = state not in (None, "none")
        hidden = stashed(node)
        elsewhere = (
            floating and ws is not None
            and current_ws is not None and ws != current_ws
        )
        if stashed_only:
            if hidden:
                yield (node, ws, floating, split_path)
        elif normal_only:
            # Keep this list limited to regular tiled windows.
            if not in_scratch and not floating:
                yield (node, ws, floating, split_path)
        elif away_only:
            if hidden or elsewhere:
                yield (node, ws, floating, split_path)
        elif not hidden:
            yield (node, ws, floating, split_path)
    for key in ("nodes", "floating_nodes"):
        for child in node.get(key, []):
            yield from collect_windows(child, ws, floating, split_path)

found = list(collect_windows(tree))

if away_only:
    # The event listener records most recently focused containers first.
    # Windows without a focus record retain their Sway tree order.
    focus_state = Path(os.environ.get(
        "XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"
    )) / "sway-window-focus-mru.json"
    try:
        focus_order = json.loads(focus_state.read_text()).get("order", [])
    except (OSError, ValueError, AttributeError):
        focus_order = []
    focus_rank = {con_id: index for index, con_id in enumerate(focus_order)}
    found = sorted(
        enumerate(found),
        key=lambda item: (
            focus_rank.get(item[1][0].get("id"), len(focus_rank)),
            item[0],
        ),
    )
    found = [pair for _, pair in found]
elif stashed_only:
    # Keep the scratchpad-only list ordered with the most recently stashed first.
    found = sorted(
        enumerate(found),
        key=lambda item: (0, -item[0]) if stashed(item[1][0]) else (1, item[0]),
    )
    found = [pair for _, pair in found]

windows = [item[0] for item in found]
window_ws = {window["id"]: ws for window, ws, _, _ in found}
window_context = {
    window["id"]: (floating, split_path)
    for window, _, floating, split_path in found
}
if not windows:
    if first_only:
        sys.exit(0)
    if waybar_only:
        print(json.dumps({"text": "", "tooltip": "No away windows"}))
        sys.exit(0)
    if not (after_kill or after_open):
        subprocess.run([
            shutil.which("notify-send") or "notify-send",
            ("Scratchpad" if stashed_only else "Away"),
            ("No hidden scratchpad window" if stashed_only
             else "Nothing away from this workspace" if away_only
             else "No open window"),
        ], check=False)
    sys.exit(0)

if first_only:
    window = windows[0]
    criteria = f"[con_id={window['id']}]"
    floating = window_context.get(window["id"], (False, ()))[0]
    if (stashed(window)
            or window_ws.get(window["id"]) == "__i3_scratch"):
        subprocess.run([swaymsg, f"{criteria} scratchpad show"], check=True)
    else:
        subprocess.run(
            [swaymsg, f"{criteria} move container to workspace current"],
            check=True,
        )
    if floating:
        subprocess.run([swaymsg, f"{criteria} floating enable"], check=True)
    subprocess.run([swaymsg, f"{criteria} focus"], check=True)
    sys.exit(0)

if show_all:
    for window in windows:
        criteria = f"[con_id={window['id']}]"
        ws = window_ws.get(window["id"])
        if stashed(window) or ws == "__i3_scratch":
            subprocess.run([swaymsg, f"{criteria} scratchpad show"], check=True)
        else:
            subprocess.run(
                [swaymsg, f"{criteria} move container to workspace current"],
                check=True,
            )
        if window_context.get(window["id"], (False, ()))[0]:
            subprocess.run([swaymsg, f"{criteria} floating enable"], check=True)
    sys.exit(0)

icon_dirs = [
    Path(path) for path in json.loads(os.environ["WINDOW_MENU_ICON_DIRS"])
]
desktop_dirs = [
    Path(path) for path in json.loads(os.environ["WINDOW_MENU_DESKTOP_DIRS"])
]
for data_dir in os.environ.get("XDG_DATA_DIRS", "").split(":"):
    if data_dir:
        desktop_dirs.append(Path(data_dir) / "applications")
        for size in ("16x16", "22x22", "24x24", "32x32", "48x48", "64x64", "128x128", "256x256", "scalable"):
            icon_dirs.append(Path(data_dir) / "icons" / "hicolor" / size / "apps")
        icon_dirs.append(Path(data_dir) / "pixmaps")

# Cache icon and desktop-entry lookups; directory metadata invalidates it.
cache_file = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "window-menu" / "index.json"
index_dirs = list(dict.fromkeys(icon_dirs + desktop_dirs))
directory_state = []
for directory in index_dirs:
    try:
        stat = directory.stat()
        directory_state.append([str(directory), stat.st_mtime_ns, stat.st_ino])
    except OSError:
        directory_state.append([str(directory), None, None])

icon_files = {}
app_info = {}
cache_loaded = False
try:
    cached = json.loads(cache_file.read_text())
    if cached.get("directories") == directory_state:
        icon_files = {key: Path(value) for key, value in cached["icons"].items()}
        app_info = {key: {"name": value["name"], "icon": Path(value["icon"]) if value["icon"] else None}
                    for key, value in cached["apps"].items()}
        cache_loaded = True
except (OSError, ValueError, KeyError, TypeError):
    pass

if not cache_loaded:
    for directory in icon_dirs:
        try:
            for path in directory.iterdir():
                if path.is_file() and path.suffix.lower() in (".png", ".svg", ".xpm", ".jpg"):
                    icon_files.setdefault(path.stem.casefold(), path)
        except OSError:
            pass

    for directory in desktop_dirs:
        try:
            for desktop in directory.glob("*.desktop"):
                try:
                    values = {}
                    in_main_section = False
                    for line in desktop.read_text(errors="replace").splitlines():
                        if line.startswith("["):
                            in_main_section = line == "[Desktop Entry]"
                        elif in_main_section and "=" in line:
                            key, value = line.split("=", 1)
                            if key in ("Name", "Icon", "StartupWMClass"):
                                values[key] = value

                    icon = values.get("Icon", "")
                    if icon:
                        icon_path = Path(icon) if Path(icon).is_file() else icon_files.get(Path(icon).stem.casefold())
                    else:
                        icon_path = None
                    info = {"name": values.get("Name", ""), "icon": icon_path}
                    app_info.setdefault(desktop.stem.casefold(), info)
                    wm_class = values.get("StartupWMClass", "").casefold()
                    if wm_class:
                        app_info.setdefault(wm_class, info)
                except OSError:
                    pass
        except OSError:
            pass

    try:
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        cache_file.write_text(json.dumps({
            "directories": directory_state,
            "icons": {key: str(value) for key, value in icon_files.items()},
            "apps": {key: {"name": value["name"], "icon": str(value["icon"]) if value["icon"] else None}
                     for key, value in app_info.items()},
        }))
    except OSError:
        pass

# The scratchpad terminal uses a custom app_id, so it does not match
# Foot's desktop entry during normal app lookup. Reuse Foot's name/icon.
if "scratchpad-terminal" not in app_info:
    app_info["scratchpad-terminal"] = app_info.get("foot", {"name": "Foot"})

pwa_id = re.compile(r"^(?:chrome|chromium)-[a-z0-9_-]{16,}(?:-[a-z0-9 _-]+)?$", re.I)
waybar_apps = []

def window_row(window):
    props = window.get("window_properties") or {}
    app_id = window.get("app_id") or ""
    wm_class = props.get("class") or ""
    title = window.get("name") or props.get("title") or ""
    entry = app_info.get(app_id.casefold()) or app_info.get(wm_class.casefold()) or {}
    app_name = entry.get("name") or app_id or wm_class or "Window"
    waybar_apps.append(app_name)

    if pwa_id.fullmatch(app_id):
        label = title or app_name
    elif title and title.casefold() != app_name.casefold():
        label = f"{app_name} — {title}"
    else:
        label = app_name

    icon_path = entry.get("icon")
    if not icon_path:
        icon_path = icon_files.get(app_id.casefold()) or icon_files.get(wm_class.casefold())
    row = label.encode("utf-8")
    if icon_path and Path(icon_path).is_file():
        row += b"\0icon\x1f" + str(icon_path).encode("utf-8")
    return label, row

rendered = [window_row(window) for window in windows]
labels = [label for label, _ in rendered]
groups = {}
for index, label in enumerate(labels):
    groups.setdefault(label, []).append(index)

# Keep ordinary rows clean; add context only when duplicate labels need help.
rows = []
display_labels = labels.copy()
for label, indices in groups.items():
    workspaces = {window_ws.get(windows[i]["id"]) for i in indices}
    floating_states = {
        window_context.get(windows[i]["id"], (False, ()))[0]
        for i in indices
    }
    split_paths = {
        window_context.get(windows[i]["id"], (False, ()))[1]
        for i in indices
    }
    for position, index in enumerate(indices, start=1):
        display_label, row = rendered[index]
        if len(indices) > 1:
            window = windows[index]
            contexts = []
            if away_only and len(workspaces) > 1:
                ws = window_ws.get(window["id"])
                contexts.append(
                    "scratchpad" if ws == "__i3_scratch"
                    else f"workspace {ws}" if ws is not None
                    else "workspace ?"
                )
            if len(floating_states) > 1:
                is_floating = window_context.get(window["id"], (False, ()))[0]
                contexts.append("floating" if is_floating else "tiled")
            if len(split_paths) > 1:
                split_path = window_context.get(window["id"], (False, ()))[1]
                if split_path:
                    contexts.append("split " + "/".join(split_path))
            display_label = f"{display_label} ({position})"
            if contexts:
                display_label += " [" + " · ".join(contexts) + "]"
            label_bytes, separator, icon = row.partition(b"\0")
            row = display_label.encode("utf-8") + (separator + icon if separator else b"")
        display_labels[index] = display_label
        rows.append((index, row))
rows.sort(key=lambda item: item[0])
rows = [row for _, row in rows]

if waybar_only:
    labels = display_labels
    count = len(windows)
    plural = "s" if count != 1 else ""
    print(json.dumps({
        "text": "{} ↓ {}".format(count, waybar_apps[0]),
        "tooltip": "{} window{} in the Mod+r list\r".format(count, plural) + "\r".join(labels),
    }))
    sys.exit(0)

# Build the list directly to preserve container IDs and row prefixes.
choice = subprocess.run(
    [
        os.environ["WINDOW_MENU_ROFI"], "-dmenu", "-i", "-matching", "normal",
        "-no-sort", "-no-custom", "-show-icons", "-format", "i",
        "-p", ("Scratchpad" if stashed_only else "Away" if away_only else "Windows"),
        # Shift+Delete kills the selected window.
        "-kb-delete-entry", "",
        "-kb-custom-1", "Shift+Delete",
        # Shift+Enter opens the selected window and reopens this menu.
        "-kb-accept-alt", "",
        "-kb-custom-2", "Shift+Return",
        "-mesg",
        # Show key hints for the selected list mode.
        ("Enter: show on this workspace · Shift+Enter: show and keep menu · Shift+Delete: kill"
         if stashed_only else
         "Enter: bring here · Shift+Enter: bring and keep menu · Shift+Delete: kill"
         if away_only else
         "Enter: jump to window · Shift+Enter: pull here and keep menu · Shift+Delete: kill"),
    ],
    input=b"\n".join(rows) + (b"\n" if rows else b""),
    capture_output=True,
    check=False,
)
# Rofi exit codes: 0 = Enter, 10 = kill, 11 = Shift+Enter.
if choice.returncode not in (0, 10, 11):
    sys.exit(0)
try:
    window = windows[int(choice.stdout.strip())]
except (ValueError, IndexError):
    sys.exit(0)  # Treat an unmatched query as cancel.

if choice.returncode == 10:
    subprocess.run([swaymsg, f"[con_id={window['id']}] kill"],
                   check=False)
    # Reopen the filtered list after closing a window.
    os.execv(sys.executable, [
        sys.executable, __file__, *sys.argv[1:], "--after-kill",
    ])

# Reuse the focused workspace captured above.
SCRATCH_WS = "__i3_scratch"

def enter_command(con_id, ws_of, ws_current, stashed=False, pull=False,
                  floating=False):
    """Build the focus or move command for a selected row."""
    criteria = f"[con_id={con_id}]"
    # `scratchpad show` toggles, so use it only for hidden windows.
    from_scratchpad = stashed or ws_of == SCRATCH_WS
    if from_scratchpad:
        commands = [f"{criteria} scratchpad show"]
    else:
        commands = []
    want_pull = pull or stashed_only or away_only
    if (not from_scratchpad and want_pull and ws_of is not None
            and ws_current is not None and ws_of != ws_current):
        commands.append(f"{criteria} move container to workspace current")
    # A child of a floating split is tiled inside its floating parent. When
    # pulled out on its own, restore floating mode before focusing that client.
    if floating:
        commands.append(f"{criteria} floating enable")
    commands.append(f"{criteria} focus")
    return commands

pull_here = choice.returncode == 11
# Use the same hidden-window test as the list builder.
is_stashed = stashed(window)
for command in enter_command(
        window["id"], window_ws.get(window["id"]), current_ws,
        stashed=is_stashed, pull=pull_here,
        floating=window_context.get(window["id"], (False, ()))[0]):
    subprocess.run([swaymsg, command], check=True)
if choice.returncode == 11:
    # Keep the menu available for another selection after opening this window.
    os.execv(sys.executable, [
        sys.executable, __file__, *sys.argv[1:], "--after-open",
    ])
