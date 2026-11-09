{ ... }:

{
  systemd.user.services.trash-clean = {
    Unit.Description = "Clean trash older than 30 days";
    Service = {
      Type = "oneshot";
      ExecStart = "%h/.local/bin/trash-clean 30";
    };
  };

  systemd.user.timers.trash-clean = {
    Unit = {
      Description = "Clean old trash daily at 03:00";
      After = [ "graphical-session.target" ];
    };
    Timer = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
