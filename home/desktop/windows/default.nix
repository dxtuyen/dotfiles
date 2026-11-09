{ pkgs, ... }:

let
  popupToggle = pkgs.writeShellApplication {
    name = "sway-popup";
    runtimeInputs = [
      pkgs.python3
      pkgs.sway
    ];
    text = ''exec python3 ${./scripts/popup-toggle.py} "$@"'';
  };
  obsidianToggle = pkgs.writeShellApplication {
    name = "obsidian-toggle";
    text = ''exec ${popupToggle}/bin/sway-popup --match '(md\.obsidian\.)?obsidian' -- obsidian'';
  };
  scratchpadTerminal = pkgs.writeShellApplication {
    name = "scratchpad-terminal";
    runtimeInputs = [
      pkgs.foot
    ];
    text = "exec ${popupToggle}/bin/sway-popup --match scratchpad-terminal -- foot --app-id=scratchpad-terminal";
  };
  dictToggle = pkgs.writeShellApplication {
    name = "dict-toggle";
    bashOptions = [ "nounset" ];
    runtimeInputs = [
      pkgs.sway
      pkgs.jq
      pkgs.goldendict-ng
    ];
    text = builtins.replaceStrings [ "@qtPlugins@" ] [ "${pkgs.qt6Packages.qt6ct}/lib/qt-6/plugins" ] (
      builtins.readFile ./scripts/dict-toggle.sh
    );
  };
in
{
  home.file = {
    ".local/bin/sway-popup".source = "${popupToggle}/bin/sway-popup";
    ".local/bin/obsidian-toggle".source = "${obsidianToggle}/bin/obsidian-toggle";
    ".local/bin/scratchpad-terminal".source = "${scratchpadTerminal}/bin/scratchpad-terminal";
    ".local/bin/dict-toggle".source = "${dictToggle}/bin/dict-toggle";
  };
}
