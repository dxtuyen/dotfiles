{ config, ... }:

# Countdown owns focus state and idle inhibition. Desktop session-lock handles sleep/wake.
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
}
