# shellcheck shell=bash
# Shared presentation; each workflow owns its actions and input validation.
menu_item() {
  printf '%s  %s\n' "$2" "$1"
}

menu_hint() {
  printf '%s\n' "$1"
  [[ -z "${2:-}" ]] || printf '%s\n' "$2"
  printf 'Esc: close'
}

# Arguments: title, visible rows, selected row, optional detail.
# Return the original zero-based index, independent of labels or filtering.
menu_pick() {
  fuzzel --dmenu --index --only-match --no-sort --no-icons \
    --lines="$2" --select-index="${3:-0}" --placeholder='' \
    --mesg="$(menu_hint "$1" "${4:-}")"
}

# Arguments: title, detail, placeholder. An empty accepted input is valid.
menu_input() {
  # The normal execute action ignores empty input; execute-input accepts it.
  fuzzel --dmenu --prompt-only='' --placeholder="$3" \
    --override=key-bindings.execute=none \
    --override='key-bindings.execute-input=Return KP_Enter Control+y' \
    --mesg="$(menu_hint "$1" "$2")" < /dev/null
}
