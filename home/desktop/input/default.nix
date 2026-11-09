{ pkgs, ... }:

let
  toggleTouchpad = pkgs.writeShellApplication {
    name = "toggle-touchpad";
    runtimeInputs = [
      pkgs.sway
      pkgs.jq
      pkgs.libnotify
    ];
    text = builtins.readFile ./scripts/toggle-touchpad.sh;
  };
in
{
  home.file.".local/bin/toggle-touchpad".source = "${toggleTouchpad}/bin/toggle-touchpad";
}
