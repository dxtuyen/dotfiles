#!/usr/bin/env bash
set -u
# shellcheck source=../../desktop/rofi-menu.sh
source "$HOME/.local/lib/rofi-menu.sh"

choice=$(
  {
    rofi_item 'Selection → Clipboard' ''
    rofi_item 'Screen → Clipboard' ''
    rofi_item 'Selection → File' ''
    rofi_item 'Screen → File' ''
  } | rofi_pick Screenshot 4 0 -1 \
    $'Print / Alt+Print: clipboard\nShift+Print / Ctrl+Print: file'
) || exit 0

case "$choice" in
  0) action=selection-clipboard ;;
  1) action=fullscreen-clipboard ;;
  2) action=selection-save ;;
  3) action=fullscreen-save ;;
  *) exit 0 ;;
esac
exec "$HOME/.local/bin/screenshot" "$action"
