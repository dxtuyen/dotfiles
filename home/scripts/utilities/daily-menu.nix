{ ... }:

let
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

        power_item() {
          printf '%s\0icon\x1f<span font_family="Font Awesome 7 Free" foreground="#d5c4a1" size="26pt">%s</span>\n' "$1" "$2"
        }

        if [ "''${1:-}" = "--power" ]; then
          PROMPT=""
          MESSAGE="⏻ Power  ·  Select an action  ·  Esc to close"
          ROFI_ARGS=(-dmenu -i -matching fuzzy -p "$PROMPT" -mesg "$MESSAGE" -show-icons)
          ROFI_ARGS+=(
            -no-sort
            -no-custom
            -theme-str '${powerMenuTheme}'
          )
          choice=$(
            {
              power_item "Lock" ""
              power_item "Suspend" ""
              power_item "Hibernate" ""
              power_item "Exit Sway" ""
              power_item "Reboot" ""
              power_item "Power off" ""
            } | rofi "''${ROFI_ARGS[@]}"
          )
        else
          MENU="👁 Idle
        ☀ Display
        📶 Wi-Fi
        🔵 Bluetooth
        🔊 Audio
        ⚡ Power Profile"
          PROMPT="Utilities"
          MESSAGE="Type to filter · Enter to select"
          ROFI_ARGS=(-dmenu -i -matching fuzzy -p "$PROMPT" -mesg "$MESSAGE" -sort -sorting-method normal)
          choice=$(printf '%s\n' "$MENU" | rofi "''${ROFI_ARGS[@]}")
        fi

        case "$choice" in
          "👁 Idle"*) exec ~/.local/bin/countdown-engine inhibit-toggle ;;
          "☀ Display"*) exec ~/.local/bin/wlsunset-menu ;;
          "📶 Wi-Fi"*) exec foot --app-id=wifitui -T "Wi-Fi" wifitui ;;
          "🔵 Bluetooth"*) exec foot --app-id=bluetui -T "Bluetooth" bluetui ;;
          "🔊 Audio"*) exec foot --app-id=wiremix -T "Audio" wiremix ;;
          "⚡ Power Profile"*) exec ~/.local/bin/power-profile-menu ;;
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
