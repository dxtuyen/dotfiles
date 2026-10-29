{ ... }:

let
  theme = import ../../theme.nix;
  powerMenuTheme = ''
    window { width: 50%; }
    mainbox { padding: 22px; spacing: 16px; }
    inputbar { enabled: false; }
    listview {
      columns: 3;
      lines: 2;
      flow: horizontal;
      fixed-columns: true;
      scrollbar: false;
      spacing: 12px;
    }
    element {
      orientation: vertical;
      children: [ element-icon, element-text ];
      padding: 18px 12px;
    }
    element-icon {
      size: 56px;
      margin: 2px 0 8px 0;
      horizontal-align: 0.5;
      vertical-align: 0.5;
    }
    element-text {
      font: "JetBrains Mono 15";
      horizontal-align: 0.5;
      vertical-align: 0.5;
      text-align: center;
    }
  '';
in

# Utilities menu launchers:
#   $mod+u       -> daily tools
#   $mod+p and the Waybar power button -> session and power actions
#   $mod+Escape -> lock the screen directly
{
  home.file = {
    ".local/bin/utilities" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        set -u

        menu_item() {
          printf '%s\0icon\x1f<span font_family="Font Awesome 7 Free" foreground="${theme.fg1}" size="%spt">%s</span>\n' "$1" "''${3:-12}" "$2"
        }

        if [ "''${1:-}" = "--power" ]; then
          PROMPT=""
          MESSAGE="Power  ·  Select an action  ·  Esc to close"
          ROFI_ARGS=(-dmenu -i -matching fuzzy -p "$PROMPT" -mesg "$MESSAGE" -show-icons)
          ROFI_ARGS+=(
            -no-sort
            -no-custom
            -theme-str '${powerMenuTheme}'
          )
          choice=$(
            {
              menu_item "Lock" "" 26
              menu_item "Suspend" "" 26
              menu_item "Hibernate" "" 26
              menu_item "Exit Sway" "" 26
              menu_item "Reboot" "" 26
              menu_item "Power off" "" 26
            } | rofi "''${ROFI_ARGS[@]}"
          )
        else
          PROMPT="Utilities"
          MESSAGE="Type to filter · Enter to select"
          ROFI_ARGS=(-dmenu -i -matching fuzzy -p "$PROMPT" -mesg "$MESSAGE" -sort -sorting-method normal -show-icons)
          choice=$(
            {
              menu_item "Idle" ""
              menu_item "Display" ""
              menu_item "Wi-Fi" ""
              menu_item "Bluetooth" ""
              menu_item "Audio" ""
              menu_item "Power Profile" ""
            } | rofi "''${ROFI_ARGS[@]}"
          )
        fi

        case "$choice" in
          "Idle") exec ~/.local/bin/countdown-engine inhibit-toggle ;;
          "Display") exec ~/.local/bin/wlsunset-menu ;;
          "Wi-Fi") exec foot --app-id=wifitui -T "Wi-Fi" wifitui ;;
          "Bluetooth") exec foot --app-id=bluetui -T "Bluetooth" bluetui ;;
          "Audio") exec foot --app-id=wiremix -T "Audio" wiremix ;;
          "Power Profile") exec ~/.local/bin/power-profile-menu ;;
          "Lock") exec ~/.local/bin/lock-screen ;;
          "Suspend") exec systemctl suspend ;;
          "Hibernate") exec systemctl hibernate ;;
          "Exit Sway") exec swaymsg exit ;;
          "Reboot") exec systemctl reboot ;;
          "Power off") exec systemctl poweroff ;;
        esac
      '';
    };
  };
}
