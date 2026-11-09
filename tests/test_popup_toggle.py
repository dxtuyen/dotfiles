"""Native floating roots define the popup group, even for deeply nested views."""

from pathlib import Path
import runpy
import unittest


SCRIPT = runpy.run_path(str(Path(__file__).resolve().parents[1] /
                           "home/desktop/windows/scripts/popup-toggle.py"))
popup = SCRIPT["popup_command"]
prepare_launch = SCRIPT["prepare_launch"]


def window(wid=42, **attributes):
    return dict(id=wid, type="con", app_id="obsidian", nodes=[], floating_nodes=[],
                scratchpad_state="none", **attributes)


def workspace(name, nodes=(), floating=(), focused=False):
    return dict(id=hash(name), type="workspace", name=name, focused=focused,
                nodes=list(nodes), floating_nodes=list(floating))


def tree(*workspaces):
    return {"type": "root", "nodes": list(workspaces)}


def group(*children):
    return dict(id=50, type="floating_con", scratchpad_state="changed", nodes=list(children))


class PopupToggleTests(unittest.TestCase):
    def test_visible_popup_group_hides_as_one_container(self):
        state = tree(workspace("1", floating=[group(window(focused=True), window(43))]))
        self.assertEqual(popup(state, "obsidian"),
                         "[con_id=50] fullscreen disable, move scratchpad")

    def test_hidden_group_shows_without_resizing_or_detaching_children(self):
        state = tree(workspace("__i3_scratch", floating=[group(window(), window(43))]),
                     workspace("1", focused=True))
        self.assertEqual(popup(state, "obsidian"), "[con_id=50] scratchpad show")

    def test_group_on_another_workspace_is_recalled(self):
        state = tree(workspace("1", focused=True), workspace("2", floating=[group(window())]))
        self.assertEqual(popup(state, "obsidian"), "[con_id=50] scratchpad show")

    def test_visible_unfocused_group_is_focused_without_hiding(self):
        other = window(99, focused=True)
        other["app_id"] = "code"
        state = tree(workspace("1", [other], [group(window())]))
        self.assertEqual(popup(state, "obsidian"), "[con_id=42] focus")

    def test_focused_sibling_hides_the_whole_popup_group(self):
        other = window(43, focused=True)
        other["app_id"] = "foot"
        state = tree(workspace("1", floating=[group(window(), other)]))
        self.assertEqual(popup(state, "obsidian"),
                         "[con_id=50] fullscreen disable, move scratchpad")

    def test_visible_unfocused_tiled_window_is_focused(self):
        other = window(99, focused=True)
        other["app_id"] = "code"
        state = tree(workspace("1", [other, window()]))
        self.assertEqual(popup(state, "obsidian"), "[con_id=42] focus")

    def test_tiled_popup_hides_without_immediately_reopening(self):
        state = tree(workspace("1", [window(focused=True)]))
        self.assertEqual(popup(state, "obsidian"),
                         "[con_id=42] fullscreen disable, move scratchpad")

    def test_launch_from_split_group_focuses_workspace_first(self):
        state = tree(workspace("1", floating=[group(window(focused=True))]))
        self.assertEqual(prepare_launch(state), ["focus parent", "focus parent"])

    def test_launch_from_focused_parent_needs_only_one_step(self):
        floating = group(window())
        floating["focused"] = True
        state = tree(workspace("1", floating=[floating]))
        self.assertEqual(prepare_launch(state), ["focus parent"])

    def test_launch_from_tiling_or_empty_workspace_does_not_change_focus(self):
        for state in (tree(workspace("1", [window(focused=True)])),
                      tree(workspace("1", focused=True))):
            self.assertEqual(prepare_launch(state), [])

    def test_match_supports_wayland_and_xwayland(self):
        for attributes in ({"app_id": "md.obsidian.Obsidian"},
                           {"app_id": None, "window_properties": {"class": "Obsidian"}}):
            item = window(focused=True)
            item.update(attributes)
            self.assertIsNotNone(popup(tree(workspace("1", [item])), r"(md\.obsidian\.)?obsidian"))

    def test_absent_app_returns_no_commands(self):
        self.assertIsNone(popup(tree(workspace("1", focused=True)), "obsidian"))
