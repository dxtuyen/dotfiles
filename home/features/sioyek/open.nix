{ pkgs, ... }:

{
  home.file = {
    ".local/bin/sioyek-open" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        # Always forward document arguments; a window title cannot identify a path.
        set -u
        JQ="${pkgs.jq}/bin/jq"
        SWAYMSG="${pkgs.sway}/bin/swaymsg"

        if [ $# -eq 0 ]; then
          # Launching Sioyek from drun has no document argument. Raise an
          # existing window instead of asking Sioyek to reopen the last PDF.
          cid="$($SWAYMSG -t get_tree | $JQ -r '
            [.. | objects
             | select((.app_id? // "") == "sioyek"
                      or ((.window_properties.class? // "") | test("^sioyek$"; "i")))]
             | .[0].id // empty')"
          if [ -n "$cid" ]; then
            $SWAYMSG "[con_id=$cid] move container to workspace current"
            $SWAYMSG "[con_id=$cid] focus"
            exit 0
          fi
        fi

        exec ${pkgs.sioyek}/bin/sioyek "$@"
      '';
    };
  };
}
