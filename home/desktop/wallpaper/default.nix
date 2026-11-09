args@{
  pkgs,
  inputs,
  ...
}:

let
  images = import ./images.nix {
    inherit pkgs inputs;
    # This host metadata is optional; the generator owns the shared defaults.
    wallpaperResolution = args.wallpaperResolution or { };
  };
in
{
  programs.swaylock.settings.image = "${images.lockscreen}/share/wallpapers/nixos-wallpaper.png";

  systemd.user.services.swaybg = {
    Unit = {
      Description = "Static Sway wallpaper";
      After = [ "sway-session.target" ];
      PartOf = [ "sway-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${images.desktop}/share/wallpapers/nixos-wallpaper.png -m fill";
    };
    Install.WantedBy = [ "sway-session.target" ];
  };
}
