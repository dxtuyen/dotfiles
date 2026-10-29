#!/usr/bin/env bash
set -u

mode=unknown
pid=$(pgrep -xo wlsunset 2>/dev/null || true)
temperature=''
expect_temperature=false
if [[ -n "$pid" ]]; then
  while IFS= read -r -d $'\0' arg; do
    if [[ "$expect_temperature" == true ]]; then
      temperature=$arg
      expect_temperature=false
    elif [[ "$arg" == -t ]]; then
      expect_temperature=true
    fi
  done < "/proc/$pid/cmdline" 2>/dev/null || true
fi
case "$temperature" in
  3900) mode=warm; label=Warm ;;
  6400) mode=white; label=Cool ;;
  4000) mode=natural; label=Natural ;;
  *) label='Not running' ;;
esac
if [[ "${1:-}" == status ]]; then
  printf '%s\n' "$label"
  exit 0
fi

# shellcheck source=../../desktop/rofi-menu.sh
source "$HOME/.local/lib/rofi-menu.sh"
ids=(warm white natural)
labels=('Warm · 4000K' 'Cool · 6500K' 'Natural · automatic')
icons=('' '' '')
active=-1
selected=0
for i in "${!ids[@]}"; do
  if [[ "${ids[i]}" == "$mode" ]]; then
    active=$i
    selected=$i
  fi
done
choice=$(
  for i in "${!ids[@]}"; do
    text=${labels[i]}
    [[ "${ids[i]}" != "$mode" ]] || text+=' · current'
    rofi_item "$text" "${icons[i]}"
  done | rofi_pick Display 3 "$selected" "$active"
) || exit 0
[[ "$choice" =~ ^[0-2]$ ]] || exit 0
next_mode=${ids[choice]}
[[ "$mode" != "$next_mode" ]] || exit 0
case "$next_mode" in
  warm) icon=weather-clear-night; label=Warm ;;
  white) icon=weather-clear; label=Cool ;;
  natural) icon=preferences-system-time; label=Natural ;;
esac
if "$HOME/.local/bin/wlsunset-apply" "$next_mode"; then
  notify-send -a wlsunset -i "$icon" -t 2000 Display "$label"
else
  notify-send -a wlsunset -u critical Display 'Could not apply the display mode.'
  exit 1
fi
