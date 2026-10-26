#!/usr/bin/env bash
# Usage: countdown-engine {start|add|pause|resume|toggle|reset|status|inhibit|inhibit-state|...|daemon}
# Old names: `study` -> `pomodoro` -> back to `countdown` (matches key $mod+c).

STATE_DIR="${XDG_RUNTIME_DIR:-$HOME/.local/state}"
STATE_FILE="$STATE_DIR/countdown-state"
LOCK_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/countdown-state.lock"
FLOCK="@flock@"
SLEEP_MARKER="$STATE_DIR/countdown-sleep-paused"
MANUAL_FLAG="$STATE_DIR/inhibit-manual"
HISTORY_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/countdown-history.log"
LEGACY_HISTORY_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro-history.log"
mkdir -p "$STATE_DIR" "$(dirname "$LOCK_FILE")" "$(dirname "$HISTORY_FILE")"
exec 9>>"$LOCK_FILE"

# Serialize state transitions shared by Waybar, the menu and the timer daemon.
state_lock() {
  "$FLOCK" -x 9 || {
    echo "countdown-engine: cannot acquire state lock" >&2
    exit 1
  }
}

state_unlock() {
  "$FLOCK" -u 9 || {
    echo "countdown-engine: cannot release state lock" >&2
    exit 1
  }
}

# Migrate legacy files only when needed, under the state lock. This
# keeps concurrent Waybar/menu invocations from choosing or appending
# migration files at the same time, without locking routine status polls.
if [ -f "$STATE_DIR/pomodoro-state" ] ||
   [ -f "$STATE_DIR/study-state" ] ||
   [ -f "$STATE_DIR/pomodoro-sleep-paused" ] ||
   [ -f "$LEGACY_HISTORY_FILE" ]; then
  state_lock

  if [ -f "$STATE_DIR/pomodoro-state" ] || [ -f "$STATE_DIR/study-state" ]; then
    # GNU stat's %y includes sub-second precision. The fixed timestamp
    # format sorts lexically; exact ties keep the canonical file first.
    newest_state=""
    newest_mtime=""
    for f in "$STATE_FILE" "$STATE_DIR/pomodoro-state" "$STATE_DIR/study-state"; do
      [ -f "$f" ] || continue
      mt=$(stat -c %y "$f" 2>/dev/null) || continue
      if [ -z "$newest_mtime" ] || [[ "$mt" > "$newest_mtime" ]]; then
        newest_mtime=$mt
        newest_state=$f
      fi
    done

    if [ "$newest_state" = "$STATE_FILE" ]; then
      rm -f -- "$STATE_DIR/pomodoro-state" "$STATE_DIR/study-state"
    elif [ -n "$newest_state" ] && mv -f -- "$newest_state" "$STATE_FILE"; then
      rm -f -- "$STATE_DIR/pomodoro-state" "$STATE_DIR/study-state"
    else
      echo "countdown-engine: state migration failed; keeping legacy state files" >&2
    fi
  fi

  if [ -f "$STATE_DIR/pomodoro-sleep-paused" ]; then
    if [ ! -e "$SLEEP_MARKER" ]; then
      mv -f -- "$STATE_DIR/pomodoro-sleep-paused" "$SLEEP_MARKER" ||
        echo "countdown-engine: could not migrate sleep marker" >&2
    else
      rm -f -- "$STATE_DIR/pomodoro-sleep-paused"
    fi
  fi

  if [ -f "$LEGACY_HISTORY_FILE" ]; then
    if [ -f "$HISTORY_FILE" ]; then
      if cat "$LEGACY_HISTORY_FILE" >> "$HISTORY_FILE"; then
        rm -f -- "$LEGACY_HISTORY_FILE"
      fi
    else
      mv -f -- "$LEGACY_HISTORY_FILE" "$HISTORY_FILE"
    fi
  fi

  state_unlock
fi

read_state() {
  if [ -f "$STATE_FILE" ]; then
    . "$STATE_FILE"
  else
    DURATION=""
    RUNNING="false"
    END_TIME=""
    REMAINING=""
  fi
}

# Anti-idle from 2 sources: running session (automatic) + manual press.
# Any source present → stop swayidle. Called inside write_state so it only
# runs on state transitions, never in a 1-second loop.
sync_idle_inhibit() {
  if { [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; } || [ -f "$MANUAL_FLAG" ]; then
    systemctl --user stop swayidle 2>/dev/null || true
  else
    systemctl --user start swayidle 2>/dev/null || true
  fi
}

write_state() {
  local tmp
  # Same-directory rename keeps readers from seeing a partially written state.
  tmp=$(mktemp "$STATE_FILE.XXXXXX") || return 1
  if ! printf 'DURATION="%s"\nRUNNING="%s"\nEND_TIME="%s"\nREMAINING="%s"\n' \
    "$DURATION" "$RUNNING" "$END_TIME" "$REMAINING" > "$tmp"; then
    rm -f -- "$tmp"
    return 1
  fi
  if ! mv -f -- "$tmp" "$STATE_FILE"; then
    rm -f -- "$tmp"
    return 1
  fi
  sync_idle_inhibit
}

get_remaining() {
  if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
    now=$(date +%s)
    remaining=$((END_TIME - now))
    [ "$remaining" -lt 0 ] && remaining=0
  elif [ -n "$REMAINING" ]; then
    remaining="$REMAINING"
  else
    remaining=0
  fi
  echo "$remaining"
}

# Seconds studied (clamped to [0, DURATION*60]).
get_elapsed() {
  if [ -z "$DURATION" ]; then
    echo 0
  elif [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
    e=$((DURATION * 60 - (END_TIME - $(date +%s))))
    [ "$e" -gt $((DURATION * 60)) ] && e=$((DURATION * 60))
    [ "$e" -lt 0 ] && e=0
    echo "$e"
  elif [ -n "$REMAINING" ]; then
    e=$((DURATION * 60 - REMAINING))
    [ "$e" -lt 0 ] && e=0
    echo "$e"
  else
    echo $((DURATION * 60))
  fi
}

format_time() {
  local secs=$1
  printf "%02d:%02d" $((secs / 60)) $((secs % 60))
}

play_sound() {
  paplay /run/current-system/sw/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true
}

log_history() {
  # $1 = session label, $2 = number of minutes
  printf '%s | %s | %s min\n' "$(date '+%Y-%m-%d %H:%M')" "$1" "$2" >> "$HISTORY_FILE"
}

# Log history if the session is replaced/reset after >= 1 minute studied.
maybe_log_current() {
  elapsed=$(get_elapsed)
  if [ "$elapsed" -ge 60 ]; then
    log_history "$1 (interrupted)" "$((elapsed / 60))"
  fi
}

notify_waybar() {
  # Signal 8 = countdown time, 10 = play/pause control, 7 = idle inhibition.
  pkill -RTMIN+8 waybar 2>/dev/null || true
  pkill -RTMIN+10 waybar 2>/dev/null || true
  pkill -RTMIN+7 waybar 2>/dev/null || true
}

notify_clock() {
  # Refresh only the countdown time every second.
  pkill -RTMIN+8 waybar 2>/dev/null || true
}

daemon_loop() {
  while true; do
    # Atomic rename makes this snapshot safe without locking every second.
    read_state
    if [ "$RUNNING" != "true" ] || [ -z "$END_TIME" ]; then
      exit 0
    fi
    now=$(date +%s)
    remaining=$((END_TIME - now))
    if [ "$remaining" -le 0 ]; then
      state_lock
      read_state
      finished_duration=""
      finalize_if_expired || {
        state_unlock
        exit 1
      }
      still_running="$RUNNING"
      still_has_end_time="$END_TIME"
      state_unlock
      if [ -n "$finished_duration" ]; then
        play_sound
        notify-send -a countdown -i "chronometer" -t 10000 -u critical \
          "Focus" "Focus session finished! $finished_duration min 🍅"
        log_history "countdown" "$finished_duration"
        notify_waybar
        exit 0
      fi
      if [ "$still_running" != "true" ] || [ -z "$still_has_end_time" ]; then
        exit 0
      fi
    fi
    # Refresh only the clock each second.
    notify_clock
    sleep 1
  done
}

# Always replace the old daemon with a new one (avoids the pause -> stuck-timer race).
# The first switch left daemons with old names (pomodoro/study) -> kill those too.
ensure_daemon() {
  pkill -f "countdown-engine daemon" 2>/dev/null || true
  pkill -f "pomodoro-engine daemon" 2>/dev/null || true
  pkill -f "study daemon" 2>/dev/null || true
  nohup "$HOME/.local/bin/countdown-engine" daemon 9>&- >/dev/null 2>&1 &
}

# Clear the "sleep auto-pause" marker when the user acts manually.
clear_sleep_marker() {
  rm -f "$SLEEP_MARKER" 2>/dev/null || true
}

# Must be called under state_lock; only one caller can finalize a session.
finalize_if_expired() {
  if [ "$RUNNING" != "true" ] || [ -z "$END_TIME" ]; then
    return 0
  fi
  now=$(date +%s)
  [ "$END_TIME" -gt "$now" ] && return 0

  finished_duration="$DURATION"
  DURATION=""
  RUNNING="false"
  END_TIME=""
  REMAINING=""
  write_state || return 1
  # Do not pkill here: this function can run inside the daemon itself.
  # Killing it before the caller unlocks/notifies leaves Waybar stuck at 1s.
}

case "${1:-status}" in
  start)
    minutes="${2:-}"
    # Integer 1-480 (presets set in the rofi menu).
    if ! [[ "$minutes" =~ ^[1-9][0-9]*$ ]] || [ "$minutes" -lt 1 ] || [ "$minutes" -gt 480 ]; then
      echo "Usage: countdown-engine start <1-480>" >&2
      exit 1
    fi
    state_lock
    read_state
    maybe_log_current "countdown"
    clear_sleep_marker
    now=$(date +%s)
    DURATION="$minutes"
    RUNNING="true"
    END_TIME=$((now + minutes * 60))
    REMAINING=""
    write_state || exit 1
    ensure_daemon
    state_unlock
    notify_waybar
    notify-send -a countdown -i "chronometer" -t 3000 \
      "Focus" "Focus session of $minutes min started 🍅"
    ;;

  add)
    minutes="${2:-}"
    if ! [[ "$minutes" =~ ^[1-9][0-9]*$ ]] || [ "$minutes" -lt 1 ] || [ "$minutes" -gt 480 ]; then
      echo "Usage: countdown-engine add <1-480>" >&2
      exit 1
    fi
    # Finalize first if the session elapsed while its menu was open.
    "$0" status >/dev/null
    state_lock
    read_state
    if [ -z "$DURATION" ]; then
      state_unlock
      notify-send -a countdown -i "dialog-error" -t 4000 \
        "Focus" "No session to add time to."
      exit 1
    fi
    new_duration=$((DURATION + minutes))
    if [ "$new_duration" -gt 480 ]; then
      state_unlock
      notify-send -a countdown -i "dialog-error" -t 4000 \
        "Focus" "Maximum total is 480 min (currently $DURATION min)."
      exit 1
    fi
    remaining=$(get_remaining)
    if [ "$remaining" -le 0 ]; then
      state_unlock
      "$0" status >/dev/null
      exit 1
    fi
    clear_sleep_marker
    DURATION="$new_duration"
    if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
      END_TIME=$((END_TIME + minutes * 60))
    else
      REMAINING=$((remaining + minutes * 60))
    fi
    write_state || exit 1
    if [ "$RUNNING" = "true" ]; then
      ensure_daemon
    fi
    state_unlock
    notify_waybar
    notify-send -a countdown -i "chronometer" -t 3000 \
      "Focus" "Added $minutes min · session total $DURATION min"
    ;;

  pause)
    state_lock
    read_state
    if [ "$RUNNING" = "true" ]; then
      now=$(date +%s)
      REMAINING=$((END_TIME - now))
      [ "$REMAINING" -lt 0 ] && REMAINING=0
      RUNNING="false"
      END_TIME=""
      write_state || exit 1
      # Kill the daemon immediately (don't wait for it to exit on its own).
      pkill -f "countdown-engine daemon" 2>/dev/null || true
      state_unlock
      notify_waybar
      notify-send -a countdown -i "chronometer" -t 2000 "Focus" "Paused ⏸"
    else
      state_unlock
    fi
    ;;

  resume)
    state_lock
    read_state
    clear_sleep_marker
    if [ "$RUNNING" != "true" ] && [ -n "$REMAINING" ] && [ "$REMAINING" -gt 0 ]; then
      now=$(date +%s)
      END_TIME=$((now + REMAINING))
      RUNNING="true"
      write_state || exit 1
      ensure_daemon
      state_unlock
      notify_waybar
      notify-send -a countdown -i "chronometer" -t 2000 "Focus" "Resumed ▶"
    else
      state_unlock
    fi
    ;;

  toggle)
    state_lock
    read_state
    clear_sleep_marker
    if [ "$RUNNING" = "true" ]; then
      now=$(date +%s)
      REMAINING=$((END_TIME - now))
      [ "$REMAINING" -lt 0 ] && REMAINING=0
      RUNNING="false"
      END_TIME=""
      write_state || exit 1
      # Kill the daemon immediately (don't wait for it to exit on its own).
      pkill -f "countdown-engine daemon" 2>/dev/null || true
      state_unlock
      notify_waybar
      notify-send -a countdown -i "chronometer" -t 2000 "Focus" "Paused ⏸"
    elif [ -n "$REMAINING" ] && [ "$REMAINING" -gt 0 ]; then
      now=$(date +%s)
      END_TIME=$((now + REMAINING))
      RUNNING="true"
      write_state || exit 1
      ensure_daemon
      state_unlock
      notify_waybar
      notify-send -a countdown -i "chronometer" -t 2000 "Focus" "Resumed ▶"
    else
      state_unlock
    fi
    ;;

  reset)
    state_lock
    read_state
    maybe_log_current "countdown"
    clear_sleep_marker
    DURATION=""
    RUNNING="false"
    END_TIME=""
    REMAINING=""
    write_state || exit 1
    pkill -f "countdown-engine daemon" 2>/dev/null || true
    state_unlock
    notify_waybar
    ;;

  daemon)
    daemon_loop
    ;;

  status)
    read_state
    finished_duration=""
    # Lock only on expiry or daemon recovery; routine Waybar polls are lock-free.
    if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
      if [ "$((END_TIME - $(date +%s)))" -le 0 ] || ! pgrep -f "countdown-engine daemon" >/dev/null 2>&1; then
        state_lock
        read_state
        if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
          finalize_if_expired || {
            state_unlock
            exit 1
          }
          if [ -z "$finished_duration" ] && ! pgrep -f "countdown-engine daemon" >/dev/null 2>&1; then
            ensure_daemon
            sync_idle_inhibit
          fi
        fi
        state_unlock
      fi
    fi
    # Refresh from the latest complete snapshot after any locked transition.
    read_state
    remaining=$(get_remaining)
    if [ -z "$DURATION" ]; then
      text="⏱"
      class="idle"
      tooltip="🍅 Foculocks — no session"
    else
      if [ "$RUNNING" = "true" ]; then
        s_icon="▶"
        s_label="Running"
        class="running"
      else
        s_icon="⏸"
        s_label="Paused"
        class="paused"
      fi
      text="🍅 $(format_time "$remaining") $s_icon"
      tooltip="Focus $DURATION min\\n$s_label · $(format_time "$remaining")"
    fi
    if [ -n "$finished_duration" ]; then
      play_sound
      notify-send -a countdown -i "chronometer" -t 10000 -u critical \
        "Focus" "Focus session finished! $finished_duration min 🍅"
      log_history "countdown" "$finished_duration"
      notify_waybar
    fi
    printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' \
      "$text" "$class" "$tooltip"
    ;;

  control-click)
    "$0" status >/dev/null
    read_state
    if [ -z "$DURATION" ]; then
      exec "$HOME/.local/bin/countdown"
    fi
    exec "$0" toggle
    ;;

  status-control)
    # Reuse status recovery/expiry handling, then show the action for the state.
    "$0" status >/dev/null
    read_state
    if [ -z "$DURATION" ]; then
      text=""
      class="idle"
      tooltip="Start a Countdown session"
    elif [ "$RUNNING" = "true" ]; then
      text=""
      class="running"
      tooltip="Pause Countdown"
    else
      text=""
      class="paused"
      tooltip="Resume Countdown"
    fi
    printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' \
      "$text" "$class" "$tooltip"
    ;;

  status-time)
    # Refresh the visible time every second; state transitions are recovered by status.
    "$0" status >/dev/null
    read_state
    remaining=$(get_remaining)
    if [ -z "$DURATION" ]; then
      text=""
      class="idle"
      tooltip=""
    elif [ "$RUNNING" = "true" ]; then
      text="$(format_time "$remaining")"
      class="running"
      tooltip="Running · $(format_time "$remaining") remaining"
    else
      text="$(format_time "$remaining")"
      class="paused"
      tooltip="Paused · $(format_time "$remaining") remaining"
    fi
    printf '{"text": "%s", "class": "%s", "tooltip": "%s"}\n' \
      "$text" "$class" "$tooltip"
    ;;

  inhibit-state)
    # Fast read-only snapshot for menus; state transitions stay in countdown-engine commands.
    read_state
    printf -v now '%(%s)T' -1
    manual_json=false
    [ -f "$MANUAL_FLAG" ] && manual_json=true
    if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ] && [ "$END_TIME" -gt "$now" ]; then
      inhibit_class="running"
    elif [ "$manual_json" = true ]; then
      inhibit_class="manual"
    else
      inhibit_class="idle"
    fi
    printf '%s %s\n' "$inhibit_class" "$manual_json"
    ;;

  inhibit)
    # JSON state for Waybar and options.
    "$0" status >/dev/null 2>&1
    read_state
    manual_json=false
    [ -f "$MANUAL_FLAG" ] && manual_json=true
    if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
      printf '{"text": "%s", "class": "%s", "tooltip": "%s", "manual": %s}\n' \
        "$(printf '\xef\x81\xae')" "running" \
        "Focus is active — idle is inhibited automatically\\nClick to pause the session; manual changes apply after Focus ends" "$manual_json"
    elif [ -f "$MANUAL_FLAG" ]; then
      printf '{"text": "%s", "class": "%s", "tooltip": "%s", "manual": true}\n' \
        "$(printf '\xef\x81\xae')" "manual" \
        "Manual idle inhibition is ON\\nClick to turn it off"
    else
      printf '{"text": "%s", "class": "%s", "tooltip": "%s", "manual": false}\n' \
        "$(printf '\xef\x81\xb0')" "idle" \
        "Idle inhibition is OFF\\nClick to turn it on or start a Focus session"
    fi
    ;;

  inhibit-toggle)
    # Toggle manual idle inhibition. Focus keeps its automatic inhibition.
    state_lock
    read_state
    if [ -f "$MANUAL_FLAG" ]; then
      rm -f "$MANUAL_FLAG"
      toggle_msg="Off"
    else
      : > "$MANUAL_FLAG"
      toggle_msg="On"
    fi
    sync_idle_inhibit
    state_unlock
    notify_waybar
    if [ "$RUNNING" = "true" ] && [ "$toggle_msg" = "Off" ]; then
      notify-send -a countdown -i "dialog-information" -t 3000 \
        "Idle inhibition" "Focus is active — automatic inhibition stays on until the session ends"
    else
      notify-send -a countdown -i "dialog-information" -t 2000 \
        "Idle inhibition" "$toggle_msg — screen locking, display sleep, and suspend behavior updated"
    fi
    ;;

  sleep-pause)
    # Machine sleeping: pause the session, keep REMAINING so sleep time is not deducted.
    state_lock
    read_state
    sleep_paused=0
    if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
      now=$(date +%s)
      REMAINING=$((END_TIME - now))
      [ "$REMAINING" -lt 0 ] && REMAINING=0
      RUNNING="false"
      END_TIME=""
      touch "$SLEEP_MARKER"
      write_state || exit 1
      pkill -f "countdown-engine daemon" 2>/dev/null || true
      sleep_paused=1
    elif [ -n "$DURATION" ]; then
      # Already paused (lock-pause ran first) -> still set the marker so
      # sleep-resume knows the machine just woke and can tell the user to unlock.
      touch "$SLEEP_MARKER"
    fi
    state_unlock
    if [ "$sleep_paused" -eq 1 ]; then
      notify_waybar
    fi
    ;;

  sleep-resume)
    # Machine woke: do NOT auto-resume — the session STAYS paused, the user
    # presses ▶ to continue (same after unlocking). Remaining behavior:
    # expired during sleep -> finalize; no marker -> just sync anti-idle.
    state_lock
    read_state
    woken_paused=0
    finished_duration=""
    if [ -f "$SLEEP_MARKER" ]; then
      rm -f "$SLEEP_MARKER" 2>/dev/null || true
      if [ "$RUNNING" != "true" ] && [ -n "$REMAINING" ] && [ "$REMAINING" -gt 0 ]; then
        # REMAINING was preserved by sleep-pause -> keep it, just notify.
        woken_paused=1
      elif [ -n "$DURATION" ] && [ "$REMAINING" = "0" ]; then
        finished_duration="$DURATION"
        DURATION=""
        RUNNING="false"
        END_TIME=""
        REMAINING=""
        write_state || exit 1
        pkill -f "countdown-engine daemon" 2>/dev/null || true
      fi
      sync_idle_inhibit
    else
      sync_idle_inhibit
    fi
    state_unlock
    if [ "$woken_paused" -eq 1 ]; then
      notify-send -a countdown -i "chronometer" -t 5000 \
        "Focus" "Just woke up — unlock, session is PAUSED ⏸ (press ▶ to continue)"
    elif [ -n "$finished_duration" ]; then
      play_sound
      notify-send -a countdown -i "chronometer" -t 10000 -u critical \
        "Focus" "Focus session finished while the machine slept! $finished_duration min 🍅"
      log_history "countdown" "$finished_duration"
    fi
    notify_waybar
    ;;

  lock-pause)
    # Screen locked (manually via $mod+Escape, 300s timeout, or before-sleep)
    # -> pause the session, keep REMAINING. Unlocking does NOT auto-resume — press ▶.
    state_lock
    read_state
    lock_paused=0
    if [ "$RUNNING" = "true" ] && [ -n "$END_TIME" ]; then
      now=$(date +%s)
      REMAINING=$((END_TIME - now))
      [ "$REMAINING" -lt 0 ] && REMAINING=0
      RUNNING="false"
      END_TIME=""
      write_state || exit 1
      pkill -f "countdown-engine daemon" 2>/dev/null || true
      lock_paused=1
    fi
    state_unlock
    if [ "$lock_paused" -eq 1 ]; then
      notify_waybar
      notify-send -a countdown -i "chronometer" -t 3000 \
        "Focus" "Screen locked — session paused ⏸ (unlock, then press ▶)"
    fi
    ;;

  *)
    echo "Usage: countdown-engine {start <1-480>|add <1-480>|pause|resume|toggle|reset|status|inhibit|inhibit-state|inhibit-toggle|lock-pause|sleep-pause|sleep-resume|daemon}" >&2
    exit 1
    ;;
esac
