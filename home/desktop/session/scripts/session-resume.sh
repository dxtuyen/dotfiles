#!/usr/bin/env bash
set -euo pipefail

# Disarm the old idle deadline before refreshing it. Do not wait on a service
# whose systemctl suspend call may itself be returning from this wake event.
systemctl --user --no-block stop idle-suspend.timer idle-suspend.service
timeout --kill-after=1s 2s "$HOME/.local/bin/countdown-engine" sleep-resume || true

# Give unattended wake fresh idle/display periods; keep inhibited sessions stopped.
systemctl --user --no-block try-restart swayidle.service locked-display.service
swaymsg 'output * power on'
