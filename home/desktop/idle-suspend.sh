#!/usr/bin/env bash
set -euo pipefail

discharging=false
for supply in /sys/class/power_supply/*; do
  # Peripherals such as mice must affect neither AC nor battery detection.
  if IFS= read -r scope 2>/dev/null < "$supply/scope" && [ "$scope" = Device ]; then
    continue
  fi
  if ! IFS= read -r supply_type 2>/dev/null < "$supply/type"; then
    continue
  fi
  if [ "$supply_type" = Battery ]; then
    if IFS= read -r status 2>/dev/null < "$supply/status" && [ "$status" = Discharging ]; then
      discharging=true
    fi
    continue
  fi

  # External power wins even if the laptop battery is temporarily discharging.
  if IFS= read -r online 2>/dev/null < "$supply/online" && [ "$online" = 1 ]; then
    exit 0
  fi
done

# Missing/unknown battery state, or a desktop without a battery: stay awake.
[ "$discharging" = true ] || exit 0

# Recheck inhibition at execution time, not only when the timer was armed.
"$HOME/.local/bin/countdown-engine" idle-allowed || exit 0
exec systemctl suspend
