{ ... }:

{
  home.file.".local/bin/scratchpad-terminal" = {
    executable = true;
    text = ''
      #! /usr/bin/env bash
      set -euo pipefail

      app_id="scratchpad-terminal"
      tree="$(swaymsg -t get_tree)"

      if jq -e --arg app_id "$app_id" \
        '[.. | objects | select(.app_id? == $app_id)] | length > 0' \
        <<< "$tree" >/dev/null; then
        swaymsg "[app_id=\"$app_id\"] scratchpad show" >/dev/null
      else
        exec foot --app-id="$app_id"
      fi
    '';
  };
}
