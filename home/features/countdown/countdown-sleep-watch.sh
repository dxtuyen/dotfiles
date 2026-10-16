#!/usr/bin/env bash
# Watcher: pause on sleep / continue on wake (listens to logind PrepareForSleep).
# END_TIME is wall-clock so REMAINING must be preserved, or the timer jumps.
set -u
set -o pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" \
    >> "$STATE_DIR/countdown-sleep-watch.log"
}

log "watcher started (watching PrepareForSleep on the system bus)"

pending=0
dbus-monitor --system \
  "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep',sender='org.freedesktop.login1'" 2>/dev/null |
while IFS= read -r line; do
  case "$line" in
    *"member=PrepareForSleep"*)
      pending=1
      ;;
    *"boolean true"*)
      if [ "${pending:-0}" -eq 1 ]; then
        pending=0
        log "machine going to sleep -> sleep-pause"
        "$HOME/.local/bin/countdown-engine" sleep-pause \
          >> "$STATE_DIR/countdown-sleep-watch.log" 2>&1
      fi
      ;;
    *"boolean false"*)
      if [ "${pending:-0}" -eq 1 ]; then
        pending=0
        log "machine woke up -> sleep-resume"
        "$HOME/.local/bin/countdown-engine" sleep-resume \
          >> "$STATE_DIR/countdown-sleep-watch.log" 2>&1
      fi
      ;;
  esac
done
