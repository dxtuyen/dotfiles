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
    if ! available=$(LC_ALL=C powerprofilesctl list); then
      notify-send -a power-profiles -u critical 'Power Profile' 'Cannot read available power profiles.'
      exit 1
    fi
    # Read the current profile and supported profiles from one snapshot.
    current=''
    while IFS= read -r line; do
      if [[ "$line" =~ ^[[:space:]]*\*[[:space:]]+(power-saver|balanced|performance): ]]; then
        current=${BASH_REMATCH[1]}
        break
      fi
    done <<< "$available"
    if [[ -z "$current" ]]; then
      notify-send -a power-profiles -u critical 'Power Profile' 'Cannot determine the current power profile.'
      exit 1
    fi
    ids=()
    labels=()
    icons=()
    current_row=-1
    for profile in power-saver balanced performance; do
      [[ "$available" == *" $profile:"* ]] || continue
      case "$profile" in
        power-saver) label='Power Saver'; icon='' ;;
        balanced) label=Balanced; icon='' ;;
        performance) label=Performance; icon='' ;;
      esac
      [[ "$profile" != "$current" ]] || current_row=${#ids[@]}
      ids+=("$profile")
      labels+=("$label")
      icons+=("$icon")
    done
    choice=$(
      for i in "${!ids[@]}"; do
        label=${labels[i]}
        [[ "${ids[i]}" != "$current" ]] || label+=' · current'
        rofi_item "$label" "${icons[i]}"
      done | rofi_pick 'Power Profile' "${#ids[@]}" "$current_row" "$current_row"
    ) || exit 0
    [[ "$choice" =~ ^[0-2]$ ]] || exit 0
    ((choice < ${#ids[@]})) || exit 0
    [[ "${ids[choice]}" != "$current" ]] || exit 0
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
