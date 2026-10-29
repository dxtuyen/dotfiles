{ ... }:

let
  theme = import ../../theme.nix;
in

{
  home.file = {
    ".local/bin/power-profile-menu" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        set -u

        current="$(powerprofilesctl get)"

        case "$current" in
          power-saver) current_label="Power Saver" ;;
          balanced) current_label="Balanced" ;;
          performance) current_label="Performance" ;;
          *) current_label="$current" ;;
        esac

        menu_item() {
          printf '%s\0icon\x1f<span font_family="Font Awesome 7 Free" foreground="${theme.fg1}" size="12pt">%s</span>\n' "$1" "$2"
        }

        choice=$(
          {
            menu_item "Power Saver" ""
            menu_item "Balanced" ""
            menu_item "Performance" ""
          } | rofi -dmenu -i -show-icons -p "Power Profile" \
            -mesg "Current: $current_label — Select a profile, then press Enter"
        )

        case "$choice" in
          "Power Saver")
            powerprofilesctl set power-saver
            notify-send -a power-profiles -i "battery" -t 2000 "Power Profile" "Power Saver"
            ;;
          "Balanced")
            powerprofilesctl set balanced
            notify-send -a power-profiles -i "power-profile-balanced" -t 2000 "Power Profile" "Balanced"
            ;;
          "Performance")
            powerprofilesctl set performance
            notify-send -a power-profiles -i "power-profile-performance" -t 2000 "Power Profile" "Performance"
            ;;
        esac
      '';
    };
  };
}
