{ ... }:

let
  theme = import ../../theme.nix;
in

{
  home.file = {
    ".local/bin/screenshot-menu" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        set -u

        menu_item() {
          printf '%s\0icon\x1f<span font_family="Font Awesome 7 Free" foreground="${theme.fg1}" size="12pt">%s</span>\n' "$1" "$2"
        }

        choice=$(
          {
            menu_item "Selection → Clipboard (Print)" ""
            menu_item "Fullscreen → Clipboard (Alt+Print)" ""
            menu_item "Selection → Save file (Shift+Print)" ""
            menu_item "Fullscreen → Save file (Ctrl+Print)" ""
          } | rofi -dmenu -i -show-icons -p "Screenshot" \
            -mesg "Select an action, then press Enter"
        )

        case "$choice" in
          "Selection → Clipboard (Print)")
            exec ~/.local/bin/screenshot selection-clipboard
            ;;
          "Fullscreen → Clipboard (Alt+Print)")
            exec ~/.local/bin/screenshot fullscreen-clipboard
            ;;
          "Selection → Save file (Shift+Print)")
            exec ~/.local/bin/screenshot selection-save
            ;;
          "Fullscreen → Save file (Ctrl+Print)")
            exec ~/.local/bin/screenshot fullscreen-save
            ;;
        esac
      '';
    };
  };
}
