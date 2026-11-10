{ pkgs, ... }:

let
  popupToggle = pkgs.writeShellApplication {
    name = "sway-popup";
    runtimeInputs = [
      pkgs.sway
    ];
    text = builtins.readFile ./scripts/popup-toggle.sh;
  };
  obsidianToggle = pkgs.writeShellApplication {
    name = "obsidian-toggle";
    text = ''exec ${popupToggle}/bin/sway-popup popup-obsidian -- obsidian'';
  };
  ticktickToggle = pkgs.writeShellApplication {
    name = "ticktick-toggle";
    text = ''
      exec ${popupToggle}/bin/sway-popup popup-ticktick -- \
        ${pkgs.flatpak}/bin/flatpak run --user com.ticktick.TickTick
    '';
  };
  scratchpadTerminal = pkgs.writeShellApplication {
    name = "scratchpad-terminal";
    runtimeInputs = [
      pkgs.foot
    ];
    text = "exec ${popupToggle}/bin/sway-popup popup-terminal -- foot --app-id=scratchpad-terminal";
  };
  dictToggle = pkgs.writeShellApplication {
    name = "dict-toggle";
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.goldendict-ng
    ];
    text =
      builtins.replaceStrings
        [ "@qtPlugins@" "@popupToggle@" ]
        [ "${pkgs.qt6Packages.qt6ct}/lib/qt-6/plugins" "${popupToggle}/bin/sway-popup" ]
        (builtins.readFile ./scripts/dict-toggle.sh);
  };
in
{
  home.file = {
    ".local/bin/sway-popup".source = "${popupToggle}/bin/sway-popup";
    ".local/bin/obsidian-toggle".source = "${obsidianToggle}/bin/obsidian-toggle";
    ".local/bin/ticktick-toggle".source = "${ticktickToggle}/bin/ticktick-toggle";
    ".local/bin/scratchpad-terminal".source = "${scratchpadTerminal}/bin/scratchpad-terminal";
    ".local/bin/dict-toggle".source = "${dictToggle}/bin/dict-toggle";
  };
}
