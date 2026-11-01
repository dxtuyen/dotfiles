#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  "") action=lock-pause ;;
  --sleep) action=sleep-pause ;;
  *) echo "Usage: lock-screen [--sleep]" >&2; exit 2 ;;
esac

# Concurrent callers join the same job. A failed lock must propagate to the caller.
systemctl --user start swaylock.service

# Pausing also clears manual idle inhibition after the lock is confirmed.
# A stalled timer must never delay locking or hold up system sleep indefinitely.
timeout --kill-after=1s 2s "$HOME/.local/bin/countdown-engine" "$action" || true
