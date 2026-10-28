#!/usr/bin/env bash
# Countdown menu: enter a duration to start, or manage the active session.
set -u

ENGINE="$HOME/.local/bin/countdown-engine"
# Read legacy state and engines during migration.
for candidate in "$HOME/.local/bin/pomodoro-engine" "$HOME/.local/bin/study"; do
  if [ ! -x "$ENGINE" ] && [ -x "$candidate" ]; then
    ENGINE="$candidate"
  fi
done
STATE_DIR="${XDG_RUNTIME_DIR:-$HOME/.local/state}"

format_time() {
  local secs=$1
  printf "%02d:%02d" $((secs / 60)) $((secs % 60))
}

ask_minutes() {
  local prompt="${1:-Countdown — minutes (1–480)}"
  local minutes
  minutes=$(rofi -dmenu -p "$prompt" \
    -mesg "Enter minutes (1–480) · Enter to start · Esc to cancel" \
    -theme-str 'window { width: 28%; } mainbox { padding: 14px; spacing: 10px; } listview { enabled: false; } entry { placeholder: "Enter minutes…"; }')
  if [ -z "$minutes" ]; then
    exit 0
  fi
  if ! [[ "$minutes" =~ ^[1-9][0-9]*$ ]] || [ "$minutes" -lt 1 ] || [ "$minutes" -gt 480 ]; then
    notify-send -a countdown -i "dialog-error" -t 4000 \
      "Countdown" "Invalid minutes: $minutes (need 1–480)"
    exit 1
  fi
  echo "$minutes"
}

ask_task() {
  rofi -dmenu -p "Countdown — task (optional)" \
    -mesg "Enter a task name · Enter to continue · Esc to skip" \
    -theme-str 'window { width: 36%; } mainbox { padding: 14px; spacing: 10px; } listview { enabled: false; } entry { placeholder: "What are you focusing on?"; }'
}

# Finalize or recover the timer before building the menu.
"$ENGINE" status >/dev/null

DURATION=""
RUNNING="false"
END_TIME=""
REMAINING=""
# Prefer the current state file, then check legacy paths.
MENU_STATE="$STATE_DIR/countdown-state"
if [ ! -f "$MENU_STATE" ]; then
  for legacy in "$STATE_DIR/pomodoro-state" "$STATE_DIR/study-state"; do
    if [ -f "$legacy" ]; then
      MENU_STATE="$legacy"
      break
    fi
  done
fi
if [ -f "$MENU_STATE" ]; then
  # shellcheck disable=SC1090
  . "$MENU_STATE"
fi

if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
  r=$((END_TIME - $(date +%s)))
  [ "$r" -lt 0 ] && r=0
elif [ -n "$REMAINING" ]; then
  r="$REMAINING"
else
  r=0
fi

# When idle, open the duration input directly. Enter starts the countdown.
if [ -z "$DURATION" ]; then
  m=$(ask_minutes) || exit $?
  [ -n "$m" ] || exit 0
  task=$(ask_task)
  exec "$ENGINE" start "$m" "$task"
fi

if [ "$RUNNING" = "true" ]; then
  ITEMS=("⏸ Pause")
else
  ITEMS=("▶ Resume")
fi
ITEMS+=("↺ Reset")
ITEMS+=("＋ Add minutes...")

choice=$(printf '%s\n' "${ITEMS[@]}" | rofi -dmenu -i -p "Countdown · $(format_time "$r")")

case "$choice" in
  "⏸ "*) exec "$ENGINE" toggle ;;
  "▶ "*) exec "$ENGINE" toggle ;;
  "↺ Reset") exec "$ENGINE" reset ;;
  "＋ Add minutes...")
    m=$(ask_minutes "Countdown — add minutes (1–480)") || exit $?
    [ -n "$m" ] || exit 0
    exec "$ENGINE" add "$m"
    ;;
esac
