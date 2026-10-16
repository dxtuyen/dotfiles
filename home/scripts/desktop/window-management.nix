{
  config,
  lib,
  pkgs,
  ...
}:

let
  iconSizes = [
    "16x16"
    "22x22"
    "24x24"
    "32x32"
    "48x48"
    "64x64"
    "scalable"
  ];
  iconDirs =
    map (size: "${config.home.homeDirectory}/.local/share/icons/hicolor/${size}/apps") iconSizes
    ++ map (
      size: "/etc/profiles/per-user/${config.home.username}/share/icons/hicolor/${size}/apps"
    ) iconSizes
    ++ map (size: "/run/current-system/sw/share/icons/hicolor/${size}/apps") iconSizes
    ++ [
      "/run/current-system/sw/share/icons/Adwaita/48x48/apps"
      "/run/current-system/sw/share/icons/Adwaita/scalable/apps"
      "/run/current-system/sw/share/pixmaps"
    ];
  desktopDirs = [
    "${config.home.homeDirectory}/.local/share/applications"
    "/etc/profiles/per-user/${config.home.username}/share/applications"
    "/run/current-system/sw/share/applications"
  ];

  windowMenu = pkgs.writeShellScript "window-menu" ''
    export WINDOW_MENU_ICON_DIRS=${lib.escapeShellArg (builtins.toJSON iconDirs)}
    export WINDOW_MENU_DESKTOP_DIRS=${lib.escapeShellArg (builtins.toJSON desktopDirs)}
    export WINDOW_MENU_ROFI=${lib.escapeShellArg "${pkgs.rofi}/bin/rofi"}
    exec ${pkgs.python3}/bin/python3 ${./window-menu.py} "$@"
  '';

  swayWindowEvents = pkgs.writeShellScript "sway-window-events" ''
    export SWAY_WINDOW_EVENTS_SWAYMSG=${lib.escapeShellArg "${pkgs.sway}/bin/swaymsg"}
    export SWAY_WINDOW_EVENTS_PKILL=${lib.escapeShellArg "${pkgs.procps}/bin/pkill"}
    exec ${pkgs.python3}/bin/python3 ${./sway-window-events.py} "$@"
  '';
in
{
  home.file = {
    ".local/bin/window-menu".source = windowMenu;
    ".local/bin/sway-window-events".source = swayWindowEvents;
  };

  # Refresh the Waybar away-window list from Sway events instead of polling.
  systemd.user.services.sway-waybar-window-events = {
    Unit = {
      Description = "Refresh Waybar scratchpad indicator on Sway events";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      ExecStart = "%h/.local/bin/sway-window-events";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
