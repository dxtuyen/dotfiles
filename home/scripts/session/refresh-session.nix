{ ... }:

{
  home.file = {
    ".local/bin/refresh-session" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        # Restore the saved display mode.
        "$HOME/.local/bin/wlsunset-apply"
        # swaybg keeps the static wallpaper visible while Sway reloads.
        swaymsg reload
      '';
    };
  };
}
