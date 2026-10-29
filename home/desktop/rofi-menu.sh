# shellcheck shell=bash
# Shared presentation; each workflow owns its actions and input validation.
rofi_item() {
  printf '%s\0icon\x1f<span font_family="Font Awesome 7 Free" foreground="@iconColor@" size="12pt">%s</span>\n' "$1" "$2"
}

rofi_hint() {
  printf '%s\n' "$1"
  [[ -z "${2:-}" ]] || printf '%s\n' "$2"
  printf 'Esc: close'
}

# Arguments: title, visible rows, selected row, active row, optional detail.
# Return the original zero-based index, independent of labels or filtering.
rofi_pick() {
  rofi -dmenu -i -no-sort -no-custom -show-icons -format i -p '' \
    -theme actions -theme-str "listview { lines: $2; }" \
    -mesg "$(rofi_hint "$1" "${5:-}")" \
    -kb-custom-1 '' -selected-row "${3:-0}" -a "${4:--1}"
}

# Arguments: title, detail, placeholder. An empty accepted input is valid.
rofi_input() {
  rofi -dmenu -format f -p '' -theme input \
    -mesg "$(rofi_hint "$1" "$2")" \
    -theme-str "entry { placeholder: \"$3\"; }" \
    -kb-custom-1 '' < /dev/null
}
