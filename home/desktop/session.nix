{ config, pkgs, ... }:

let
  theme = import ../theme.nix;
  hex = color: builtins.substring 1 6 color;
in
{
  programs.swaylock = {
    enable = true;
    settings = {
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

  # Lock after 300s, turn off the display after 310s, and suspend after 900s on battery.
  # Countdown temporarily stops and restarts this service.
  systemd.user.services.swayidle = {
    Unit = {
      Description = "Idle manager for Wayland (lock → screen off → suspend)";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "simple";
      ExecCondition = "%h/.local/bin/countdown-engine idle-allowed";
      # Commands started by swayidle need these tools on PATH.
      Environment = [
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          idlehint 300 \
          timeout 300 '%h/.local/bin/lock-screen' \
          timeout 310 'swaymsg "output * power off"' \
          resume 'swaymsg "output * power on"' \
          timeout 900 '%h/.local/bin/idle-suspend'
      '';
    };
    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };

  # A single unit serializes concurrent lock requests. swaylock -f returns only
  # after the compositor confirms the lock; systemctl start waits for that point.
  # Track the whole cgroup because swaylock also forks a PAM helper.
  systemd.user.services.swaylock = {
    Unit = {
      Description = "Sway screen lock";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      Type = "forking";
      ExitType = "cgroup";
      GuessMainPID = false;
      ExecStart = "${pkgs.swaylock}/bin/swaylock -f -e";
    };
  };

  # Keep logind events independent of idle inhibition by Countdown. Only this
  # daemon handles sleep/lock events, even when the main swayidle is running.
  systemd.user.services.session-lock = {
    Unit = {
      Description = "Lock the Sway session before sleep and on logind requests";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      StartLimitIntervalSec = 60;
    };
    Service = {
      Environment = [
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
      ];
      Restart = "always";
      RestartSec = 2;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          before-sleep '%h/.local/bin/lock-screen' \
          lock '%h/.local/bin/lock-screen' \
          after-resume 'swaymsg "output * power on"' \
          unlock 'swaymsg "output * power on"'
      '';
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  home.file = {
    ".local/bin/idle-suspend" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        # Only suspend on battery. Plugged in -> stay awake (screen still off & locked).
        # Use current state, since the supervised worker also runs while idle.
        if ! "$HOME/.local/bin/countdown-engine" idle-allowed; then
          exit 0
        fi

        # No battery (desktop) or no battery currently discharging (AC power) -> stay awake.
        for bat in /sys/class/power_supply/BAT*; do
          [ -e "$bat/status" ] || continue
          if [ "$(cat "$bat/status")" = Discharging ]; then
            exec ${pkgs.systemd}/bin/systemctl suspend
          fi
        done
      '';
    };
    ".local/bin/lock-screen" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        set -euo pipefail

        # Concurrent callers join the same start job; failures propagate to swayidle.
        ${pkgs.systemd}/bin/systemctl --user start swaylock.service

        # Lock first: a slow timer or notification must never postpone locking.
        # Unlocking keeps Countdown paused until the user presses ▶.
        ${pkgs.coreutils}/bin/timeout --kill-after=1s 2s \
          "$HOME/.local/bin/countdown-engine" lock-pause || true
      '';
    };
  };
}
