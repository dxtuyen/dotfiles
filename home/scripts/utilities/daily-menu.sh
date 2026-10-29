#!/usr/bin/env bash
set -u
# shellcheck source=../../desktop/rofi-menu.sh
source "$HOME/.local/lib/rofi-menu.sh"

case "${1:-}" in
  --power)
    choice=$(
      {
        rofi_item Lock ''
        rofi_item Suspend ''
        rofi_item Hibernate ''
        rofi_item 'Power Profile' ''
        rofi_item 'Exit Sway' ''
        rofi_item Reboot ''
        rofi_item 'Power off' ''
      } | rofi_pick Power 7
    ) || exit 0
    case "$choice" in
      0) exec "$HOME/.local/bin/lock-screen" ;;
      1) exec systemctl suspend ;;
      2) exec systemctl hibernate ;;
      3) exec "$0" --power-profile ;;
      4) exec swaymsg exit ;;
      5) exec systemctl reboot ;;
      6) exec systemctl poweroff ;;
    esac
    ;;
  --power-profile)
    # This laptop supports all three profiles; Waybar shows the active one.
    ids=(power-saver balanced performance)
    labels=('Power Saver' Balanced Performance)
    icons=('' '' '')
    choice=$(
      for i in "${!ids[@]}"; do
        rofi_item "${labels[i]}" "${icons[i]}"
      done | rofi_pick 'Power Profile' 3
    ) || exit 0
    [[ "$choice" =~ ^[0-2]$ ]] || exit 0
    if error=$(powerprofilesctl set "${ids[choice]}" 2>&1); then
      notify-send -a power-profiles -i "power-profile-${ids[choice]}" -t 2000 \
        'Power Profile' "${labels[choice]}"
    else
      notify-send -a power-profiles -u critical 'Power Profile' \
        "Could not switch to ${labels[choice]}: $error"
      exit 1
    fi
    ;;
  *)
    choice=$(
      {
        rofi_item Idle ''
        rofi_item Display ''
        rofi_item Wi-Fi ''
        rofi_item Bluetooth ''
        rofi_item Audio ''
      } | rofi_pick Utilities 5
    ) || exit 0
    case "$choice" in
      0) exec "$HOME/.local/bin/countdown-engine" inhibit-toggle ;;
      1) exec "$HOME/.local/bin/wlsunset-menu" ;;
      2) exec foot --app-id=wifitui -T Wi-Fi wifitui ;;
      3) exec foot --app-id=bluetui -T Bluetooth bluetui ;;
      4) exec foot --app-id=wiremix -T Audio wiremix ;;
    esac
    ;;
esac
exit 0
