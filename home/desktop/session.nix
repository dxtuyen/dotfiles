{ config, pkgs, ... }:

let
  theme = import ../theme.nix;
  hex = color: builtins.substring 1 6 color;
  policy = {
    lockSeconds = 300;
    lockedDisplaySeconds = 10;
    suspendSeconds = 900;
    powerCheckSeconds = 30;
  };
  sessionEnvironment = [
    "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
  ];
  idleSuspend = pkgs.writeShellApplication {
    name = "idle-suspend";
    runtimeInputs = [ pkgs.systemd ];
    text = builtins.readFile ./idle-suspend.sh;
  };
  lockScreen = pkgs.writeShellApplication {
    name = "lock-screen";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
    ];
    text = builtins.readFile ./lock-screen.sh;
  };
  sessionResume = pkgs.writeShellApplication {
    name = "session-resume";
    runtimeInputs = [
      pkgs.systemd
      pkgs.coreutils
      pkgs.sway
    ];
    text = builtins.readFile ./session-resume.sh;
  };
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

  # Countdown inhibits automatic locking/sleep, but never a lock already requested.
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
      Environment = sessionEnvironment;
      Restart = "on-failure";
      RestartSec = 3;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          idlehint ${toString policy.lockSeconds} \
          timeout ${toString policy.lockSeconds} '%h/.local/bin/lock-screen' \
          timeout ${toString policy.suspendSeconds} '${pkgs.systemd}/bin/systemctl --user start idle-suspend.timer' \
          resume '${pkgs.systemd}/bin/systemctl --user stop idle-suspend.timer idle-suspend.service'
      '';
    };
    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };

  # Poll only after the idle deadline, so unplugging later is handled too.
  # Binding the timer to swayidle also cancels checks on inhibition or a crash.
  systemd.user.timers.idle-suspend = {
    Unit = {
      Description = "Recheck battery power while the Sway session is idle";
      # This timer starts during a session, after basic.target. The default
      # Before=timers.target would create a cycle through swayidle.service.
      DefaultDependencies = false;
      Conflicts = [ "shutdown.target" ];
      Before = [ "shutdown.target" ];
      BindsTo = [ "swayidle.service" ];
      After = [ "swayidle.service" ];
      PartOf = [ "swayidle.service" ];
    };
    Timer = {
      OnActiveSec = "1s";
      OnUnitInactiveSec = "${toString policy.powerCheckSeconds}s";
      AccuracySec = "1s";
    };
  };

  systemd.user.services.idle-suspend = {
    Unit = {
      Description = "Suspend an idle session only when running on battery";
      BindsTo = [ "idle-suspend.timer" ];
      After = [ "idle-suspend.timer" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${idleSuspend}/bin/idle-suspend";
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
      Wants = [ "locked-display.service" ];
    };
    Service = {
      Type = "forking";
      ExitType = "cgroup";
      GuessMainPID = false;
      ExecStart = "${pkgs.swaylock}/bin/swaylock -f -e";
    };
  };

  # Start only after swaylock confirms the lock, and stop as soon as it exits.
  # This stays independent of Countdown's manual inhibition of swayidle.
  systemd.user.services.locked-display = {
    Unit = {
      Description = "Turn off locked displays after a short idle period";
      BindsTo = [ "swaylock.service" ];
      After = [ "swaylock.service" ];
      PartOf = [ "swaylock.service" ];
    };
    Service = {
      Environment = sessionEnvironment;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          timeout ${toString policy.lockedDisplaySeconds} '${pkgs.sway}/bin/swaymsg "output * power off"' \
          resume '${pkgs.sway}/bin/swaymsg "output * power on"'
      '';
      # Unlocking swaylock does not emit logind's Unlock signal.
      ExecStopPost = "-${pkgs.sway}/bin/swaymsg 'output * power on'";
      Restart = "on-failure";
      RestartSec = 2;
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
      Environment = sessionEnvironment;
      Restart = "always";
      RestartSec = 2;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          before-sleep '%h/.local/bin/lock-screen --sleep' \
          lock '%h/.local/bin/lock-screen' \
          after-resume '%h/.local/bin/session-resume' \
          unlock 'swaymsg "output * power on"'
      '';
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

  home.file = {
    ".local/bin/idle-suspend".source = "${idleSuspend}/bin/idle-suspend";
    ".local/bin/lock-screen".source = "${lockScreen}/bin/lock-screen";
    ".local/bin/session-resume".source = "${sessionResume}/bin/session-resume";
  };
}
