{ pkgs, ... }:

{
  home.file = {
    ".local/bin/vm-nixos" = {
      executable = true;
      text = ''
        #! /usr/bin/env bash
        # Boot the NixOS training VM from disk (default) or an ISO.
        set -euo pipefail

        DIR="''${VM_DIR:-$HOME/VMs}"
        DISK="$DIR/disk/training.qcow2"
        ISO="$(find "$DIR/iso" -maxdepth 1 -name '*.iso' 2>/dev/null | sort | head -1 || true)"

        MODE="''${1:-disk}"
        case "$MODE" in
          iso|install) MODE=iso ;;
          disk|boot)   MODE=disk ;;
          *) echo "Usage: vm-nixos [iso|disk]" >&2; exit 1 ;;
        esac

        [ -f "$DISK" ] || {
          echo "Disk not found: $DISK" >&2
          echo "Create it with: qemu-img create -f qcow2 \"$DISK\" 30G" >&2
          exit 1
        }
        if [ "$MODE" = iso ] && [ -z "$ISO" ]; then
          echo "No ISO found in $DIR/iso; add a NixOS installer ISO to that directory." >&2
          exit 1
        fi

        # Resolve the pinned UEFI firmware at build time.
        OVMF_CODE="${pkgs.OVMF.firmware}"

        ARGS=(
          -machine q35,accel=kvm
          -cpu host
          -m 3G
          -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
          -drive "file=$DISK,if=virtio,format=qcow2"
          -nic user,model=virtio
          -display gtk
        )
        if [ "$MODE" = iso ]; then
          ARGS+=(-boot d -cdrom "$ISO")
        else
          ARGS+=(-boot c)
        fi

        exec ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 "''${ARGS[@]}"
      '';
    };
  };
}
