{ pkgs, ... }:

let
  theme = import ../../theme.nix;
  hex = color: builtins.substring 1 6 color;
in
{
  programs.swaylock = {
    enable = true;
    settings = {
      image = ../../assets/wallpapers/nixos-gruvbox.png;
      scaling = "fill";
      color = hex theme.bg0;
      font = "JetBrains Mono";
      font-size = 20;
      indicator-radius = 90;
      indicator-thickness = 6;
      inside-color = "${hex theme.bg0}ee";
      inside-clear-color = hex theme.bg1;
      inside-ver-color = hex theme.bg1;
      inside-wrong-color = hex theme.bg1;
      ring-color = hex theme.bg4;
      ring-clear-color = hex theme.yellow;
      ring-ver-color = hex theme.blue;
      ring-wrong-color = hex theme.red;
      key-hl-color = hex theme.green;
      bs-hl-color = hex theme.orange;
      separator-color = hex theme.bg0;
      line-uses-inside = true;
      text-color = hex theme.fg1;
      text-clear-color = hex theme.yellow;
      text-ver-color = hex theme.blue;
      text-wrong-color = hex theme.red;
      show-failed-attempts = true;
    };
  };

  home.file = {
    ".local/bin/lock-screen" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        # Locking -> pause the session immediately (no-op without a session/already paused);
        # unlocking does NOT auto-resume — press ▶ to continue. Runs BEFORE the guard so a
        # stacking lock (swaylock already running) still does not miss the pause.
        "$HOME/.local/bin/countdown-engine" lock-pause 2>/dev/null || true

        # Avoid stacking locks (otherwise you would unlock twice).
        if pgrep -x swaylock >/dev/null 2>&1; then
          exit 0
        fi

        # -f so swaylock does not block swayidle; -e so an empty Enter does not count as a wrong password.
        exec ${pkgs.swaylock}/bin/swaylock -f -e
      '';
    };
  };
}
