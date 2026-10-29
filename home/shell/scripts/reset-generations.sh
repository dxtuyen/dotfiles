#!/usr/bin/env bash
# reset-generations.sh — clean old NixOS generations + RENUMBER the profile back to 1.
#
# WHY IT'S NEEDED: every `nixos-rebuild switch` adds one generation
# (/nix/var/nix/profiles/system-<N>-link). Nix assigns the next number as
# **largest remaining number + 1**, so deleting generations alone does NOT
# lower the number — to get back to 1 the remaining link must be renamed.
#
# The script does 4 things:
#   1. Build the requested configuration before deleting any generations, then
#      delete every generation except the current, running one.
#   2. Rename the remaining `system-<N>-link` to `system-1-link` and point the
#      `system` symlink at it => the next rebuild becomes generation 2, then 3, 4...
#   3. `nixos-rebuild switch` to create generation 2 and rewrite the boot entry. The
#      systemd-boot builder DELETES ALL `nixos*` entries in /boot/loader/entries then
#      rewrites them from the current generation list => old entries clean themselves
#      up, no manual deletion needed.
#   4. `nix-collect-garbage` — reclaim unreachable store paths while keeping
#      generation 1 as a rollback target for the new generation 2.
#
# Older generations are permanently deleted. The previous configuration remains
# as generation 1 until removed by normal retention or an explicit cleanup.
#
# 2 mandatory safety checks, enforced by the script:
#   • /boot must be mounted — otherwise step 3 dies at "Failed to install
#     bootloader" (this actually happened when /etc/fstab held another machine's UUID).
#   • Never leave 0 generations — the systemd-boot builder refuses to run and
#     exits 1 when the generation list is empty.
#
# Usage:  sudo bash home/shell/scripts/reset-generations.sh [flake-dir] [host]
#         defaults: flake-dir = repository root inferred from this script, host = laptop

set -euo pipefail

FLAKE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
HOST="${2:-laptop}"
PROFILE=/nix/var/nix/profiles/system
GEN_DIR=/nix/var/nix/profiles

if [ "$(id -u)" -ne 0 ]; then
  echo "Must run with sudo (touches /nix/var/nix/profiles and /boot)." >&2
  exit 1
fi
if [ ! -f "$FLAKE/flake.nix" ]; then
  echo "Cannot find $FLAKE/flake.nix — pass the flake path: sudo bash $0 /path/to/flake" >&2
  exit 1
fi
if ! mountpoint -q /boot; then
  echo "ERROR: /boot not mounted => rebuild will die at 'Failed to install bootloader'." >&2
  echo "     Check with: lsblk -o NAME,UUID   then  mount /dev/disk/by-uuid/<ESP-UUID> /boot" >&2
  exit 1
fi

echo "== 0. Current state =="
nix-env -p "$PROFILE" --list-generations
CUR_LINK="$(readlink "$PROFILE")"                      # e.g. system-18-link
CUR_NUM="${CUR_LINK#system-}"; CUR_NUM="${CUR_NUM%-link}"
CUR_STORE="$(readlink -f "$PROFILE")"
if [ "$CUR_STORE" != "$(readlink -f /run/current-system)" ]; then
  echo "ERROR: the selected system profile differs from the running system. Switch to it or roll back before resetting generations." >&2
  exit 1
fi
echo "   in use: generation $CUR_NUM → $CUR_STORE"
echo "   flake: $FLAKE#${HOST} · /boot: mounted · disk usage:"; df -h /nix | tail -1

echo
echo "== 1. Build first, then delete old generations (keep the running one) =="
nix build --no-link "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel"
nix-env -p "$PROFILE" --delete-generations old

echo
echo "== 2. Renumber to generation 1 =="
if [ "$CUR_NUM" = "1" ]; then
  echo "   already generation 1, nothing to rename."
else
  [ -e "$GEN_DIR/system-1-link" ] && { echo "ERROR: system-1-link already exists." >&2; exit 1; }
  mv "$GEN_DIR/system-$CUR_NUM-link" "$GEN_DIR/system-1-link"
  ln -sfn system-1-link "$PROFILE"
  echo "   system-$CUR_NUM-link → system-1-link (target unchanged: $CUR_STORE)"
fi
nix-env -p "$PROFILE" --list-generations

echo
echo "== 3. Rebuild (create generation 2 + rewrite boot entries) =="
nixos-rebuild switch --flake "$FLAKE#$HOST"

echo
echo "== 4. Clean the store =="
nix-collect-garbage

echo
echo "== Done =="
nix-env -p "$PROFILE" --list-generations
echo "Entries in /boot:"; ls -1 /boot/loader/entries/
df -h /nix | tail -1
