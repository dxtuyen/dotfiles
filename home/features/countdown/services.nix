{ config, ... }:

# Countdown: focus state, idle inhibition, and auto-pause when the machine sleeps.
# Menu is `countdown`, internal engine is `countdown-engine` (formerly `study`, `pomodoro`).

{
  systemd.user.services.countdown-engine = {
    Unit = {
      Description = "Countdown worker and idle-state reconciliation";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "exec";
      Environment = [
        "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin:%h/.local/bin"
      ];
      ExecStart = "%h/.local/bin/countdown-engine daemon";
      Restart = "always";
      RestartSec = 1;
    };
    Install.WantedBy = [ "sway-session.target" ];
  };

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
}
