{ config, pkgs, ... }:

# Countdown owns its state, idle inhibitor and reactions to session events.
# The desktop session never calls into this feature.
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

  # A process-scoped logind lease is released on stop, crash or logout. Inhibit
  # only idle: explicit locking, sleep and lid actions remain available.
  systemd.user.services.countdown-idle-inhibit = {
    Unit = {
      Description = "Countdown idle inhibitor";
      BindsTo = [ "countdown-engine.service" ];
      After = [ "countdown-engine.service" ];
      PartOf = [
        "sway-session.target"
        "countdown-engine.service"
      ];
    };
    Service = {
      Type = "exec";
      ExecStart = ''
        ${pkgs.systemd}/bin/systemd-inhibit --what=idle --mode=block \
          --who=Countdown --why="Focus or manual keep-awake is active" \
          ${pkgs.coreutils}/bin/sleep infinity
      '';
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Subscribe to the generic confirmed-lock lifecycle. Remaining active until
  # unlock makes repeated lock requests idempotent; the next lock runs it again.
  systemd.user.services.countdown-lock-pause = {
    Unit = {
      Description = "Pause Countdown when the session locks";
      BindsTo = [ "session-locked.target" ];
      After = [ "session-locked.target" ];
      PartOf = [ "session-locked.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "%h/.local/bin/countdown-engine lock-pause";
      TimeoutStartSec = 3;
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "session-locked.target" ];
  };

  # Hold our own sleep delay lock so preserving the timer does not depend on
  # how quickly the screen locker starts. Both paths are safe in either order.
  systemd.user.services.countdown-sleep = {
    Unit = {
      Description = "Pause Countdown before sleep and preserve it on wake";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = ''
        ${pkgs.swayidle}/bin/swayidle -w \
          before-sleep '${pkgs.coreutils}/bin/timeout --kill-after=1s 2s %h/.local/bin/countdown-engine sleep-pause' \
          after-resume '${pkgs.coreutils}/bin/timeout --kill-after=1s 2s %h/.local/bin/countdown-engine sleep-resume'
      '';
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
