{ pkgs, ... }:

{
  # Keep one static wallpaper for the lifetime of the Sway session.
  systemd.user.services.swaybg = {
    Unit = {
      Description = "Static Sway wallpaper";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${../../assets/wallpapers/nixos-gruvbox.png} -m fill";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
