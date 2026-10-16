{ config, pkgs, ... }:

# Countdown: focus state, idle inhibition, and auto-pause when the machine sleeps.
# Menu is `countdown`, internal engine is `countdown-engine` (formerly `study`, `pomodoro`).

{
  # Watcher runs via systemd (auto-restart, journald logging, stops with the Sway session).
  systemd.user.services.countdown-sleep-watch = {
    Unit = {
      Description = "Auto pause/resume Countdown timer on system sleep/wake (logind PrepareForSleep)";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "simple";
      # PATH for dbus-monitor + countdown-engine.
      Environment = [
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
      ];
      Restart = "on-failure";
      RestartSec = 3;
      ExecStart = "%h/.local/bin/countdown-sleep-watch";
    };
    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };

  # LOCK BEFORE THE MACHINE SLEEPS — runs INDEPENDENTLY of the main swayidle,
  # because the engine TURNS OFF the main swayidle for the whole session
  # (anti screen-off/suspend). Without this service, closing the lid/sleeping
  # during a session would power off WITHOUT locking anything.
  # `swayidle -w` holds a delay-inhibitor -> suspend only happens after the lock runs.
  systemd.user.services.countdown-lock-on-sleep = {
    Unit = {
      Description = "Lock screen before sleep while Countdown stops swayidle (logind before-sleep)";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "simple";
      # PATH for child commands (lock-screen, swaymsg).
      Environment = [
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
      ];
      # "always" so it restarts if anything touches this instance.
      Restart = "always";
      RestartSec = 2;
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          before-sleep '%h/.local/bin/lock-screen' \
          lock '%h/.local/bin/lock-screen' \
          after-resume 'swaymsg "output * power on"'
      '';
    };
    Install = {
      WantedBy = [ "sway-session.target" ];
    };
  };
}
