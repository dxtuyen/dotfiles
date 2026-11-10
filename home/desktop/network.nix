{ pkgs, ... }:

let
  wifui = pkgs.callPackage ../../pkgs/wifui.nix { };
  wifiMenu = pkgs.writeShellApplication {
    name = "wifi-menu";
    text = "exec ${pkgs.foot}/bin/foot --app-id=wifui -T Wi-Fi ${wifui}/bin/wifui --backend nm";
  };
in
{
  home.packages = [
    wifui
    pkgs.networkmanagerapplet
  ];

  # The editor shares a package with nm-applet; keep its tray applet disabled
  # even if XDG autostart is enabled for the session later.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';

  home.file.".local/bin/wifi-menu".source = "${wifiMenu}/bin/wifi-menu";
}
