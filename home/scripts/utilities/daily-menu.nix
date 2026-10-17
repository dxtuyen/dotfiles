{ ... }:

# Utilities menu launchers:
#   $mod+u       -> daily tools
#   $mod+p       -> session and power actions
#   $mod+Shift+p -> same power menu, retained as an alias
{
  home.file = {
    ".local/bin/utilities" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        set -u

        if [ "''${1:-}" = "--power" ]; then
          MENU="🔒 Lock
        ⏾ Suspend
        ⏾ Hibernate
        ↻ Reload Sway
        ⏻ Exit Sway
        ↻ Reboot
        ⏻ Poweroff"
          PROMPT="System"
        else
          MENU="👁 Idle
        ☀ Display
        📶 Wi-Fi
        🔵 Bluetooth
        🔊 Audio
        ⚡ Power Profile"
          PROMPT="Utilities"
        fi

        choice=$(printf '%s\n' "$MENU" | rofi -dmenu -i -matching fuzzy -sort -sorting-method normal -p "$PROMPT" \
          -mesg "Type to filter · Enter to select")

        case "$choice" in
          "👁 Idle"*) exec ~/.local/bin/countdown-engine inhibit-toggle ;;
          "☀ Display"*) exec ~/.local/bin/wlsunset-menu ;;
          "📶 Wi-Fi"*) exec foot --app-id=wifitui -T "Wi-Fi" wifitui ;;
          "🔵 Bluetooth"*) exec foot --app-id=bluetui -T "Bluetooth" bluetui ;;
          "🔊 Audio"*) exec foot --app-id=wiremix -T "Audio" wiremix ;;
          "⚡ Power Profile"*) exec ~/.local/bin/power-profile-menu ;;
          "🔒 Lock"*) exec ~/.local/bin/lock-screen ;;
          "⏾ Suspend"*) exec systemctl suspend ;;
          "⏾ Hibernate"*) exec systemctl hibernate ;;
          "↻ Reload Sway"*) exec swaymsg reload ;;
          "⏻ Exit Sway"*) exec swaymsg exit ;;
          "↻ Reboot"*) exec systemctl reboot ;;
          "⏻ Poweroff"*) exec systemctl poweroff ;;
        esac
      '';
    };
  };
}
