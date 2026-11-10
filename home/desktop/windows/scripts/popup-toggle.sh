#!/usr/bin/env bash
# Let Sway toggle the marked scratchpad window; launch only when none exists.
set -euo pipefail

mark=$1
shift
[ "${1:-}" != -- ] || shift

# Read the command response only: never request or walk the window tree.
if response=$(swaymsg -r "[con_mark=\"^${mark}$\"] scratchpad show"); then
  exit 0
else
  status=$?
fi
case "$response" in
  *'"error": "No matching node."'*)
    # Sway launches the app asynchronously, preserving argument boundaries.
    printf -v launch '%q ' "$@"
    exec swaymsg -q "exec $launch"
    ;;
  *)
    printf '%s\n' "$response" >&2
    exit "$status"
    ;;
esac
