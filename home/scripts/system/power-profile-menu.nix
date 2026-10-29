{ ... }:

{
  # Keep the Waybar shortcut while sharing the power menu's implementation.
  home.file.".local/bin/power-profile-menu" = {
    executable = true;
    text = ''
      #! /usr/bin/env bash
      exec ~/.local/bin/utilities --power-profile
    '';
  };
}
