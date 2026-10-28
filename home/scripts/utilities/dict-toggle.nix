{ pkgs, ... }:

{
  home.file = {
    ".local/bin/dict-toggle" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        # Wayland forbids apps from focusing themselves/switching workspace -> sway pulls the window over.
        # Closing while focused = hide to tray (process stays, reopening is fast).
        set -u
        APP_ID="io.github.xiaoyifang.goldendict_ng"

        # Prefer the main window; fall back to any node (avoid catching the About dialog).
        node="$(swaymsg -t get_tree | jq -c --arg id "$APP_ID" '
          ([.. | objects | select(.app_id? == $id and .type? == "floating_con")][0]
           // [.. | objects | select(.app_id? == $id)][0]) // empty')"

        if [ -z "$node" ]; then
          # Sway may keep an older environment after Home Manager activates.
          # Fusion reads the shared Material palette through qt6ct.
          export QT_QPA_PLATFORMTHEME=qt6ct
          export QT_STYLE_OVERRIDE=Fusion
          export QT_PLUGIN_PATH="${pkgs.qt6Packages.qt6ct}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
          exec ${pkgs.goldendict-ng}/bin/goldendict
        fi

        cid="$(jq -rn --argjson n "$node" '$n.id')"
        focused="$(jq -rn --argjson n "$node" '$n.focused // false')"

        if [ "$focused" = "true" ]; then
          swaymsg "[con_id=$cid] kill"
        else
          # Pull to the current workspace + focus.
          swaymsg "[con_id=$cid] move container to workspace current"
          swaymsg "[con_id=$cid] focus"
        fi
      '';
    };
  };
}
