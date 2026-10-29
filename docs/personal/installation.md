# Personal installation runbook

Manual installation notes for the author's laptop, with optional QEMU/KVM preparation at the end. This runbook uses the repository's `laptop` target and `doxuantuyen` account. It is kept outside the main documentation navigation for personal reference.

The physical-machine procedure replaces the target disk with an unencrypted GPT layout. It does not cover dual boot or preserving existing partitions. **Partitioning and formatting destroy data on the selected disk.** Complete the backup and disk-identification steps first.

Run each command in order and continue only after it succeeds. Steps 1–10 run in the same root shell inside the installer. Step 11 runs as the installed user after reboot. For practice, complete [VM preparation](#optional-qemukvm-preparation) first, then follow the same installation steps inside the guest.

## Installation profile

| Setting | Physical laptop | Practice VM |
| --- | --- | --- |
| Boot mode | UEFI | UEFI through OVMF |
| Architecture | `x86_64-linux` | `x86_64-linux` |
| Target disk | `/dev/nvme0n1`; verify before use | `/dev/vda`; verify inside the guest |
| Partition 1 | EFI, 1 GiB, FAT32 | EFI, 1 GiB, FAT32 |
| Partition 2 | Swap, 10 GiB for the current approximately 8 GiB RAM laptop | Swap, 4 GiB for the helper's 3 GiB guest RAM |
| Partition 3 | Root, remaining space, ext4 | Root, remaining space, ext4 |
| Labels | `boot`, `swap`, `nixos` | `boot`, `swap`, `nixos` |
| Flake target / hostname | `laptop` | `laptop`, local to the guest |
| User / checkout | `doxuantuyen` / `~/dotfiles` | `doxuantuyen` / `~/dotfiles` inside the guest |

The swap label must match `boot.resumeDevice = "/dev/disk/by-label/swap"` in the laptop module. Reassess disk swap capacity if the laptop's RAM changes; zram is not the persistent hibernation destination.

## 1. Prepare the installer and backups

Before booting the installer:

1. Back up documents, Anki collections, database exports, SSH keys, application state, and any uncommitted repository changes to another device or service.
2. Check that the backup can be read. Keep a copy of this runbook accessible from another device.
3. Connect the laptop to AC power and arrange internet access.
4. Download a NixOS minimal `x86_64-linux` ISO from the [official download page](https://nixos.org/download/), verify it using the published checksum, and write the image to a USB drive with an image-writing tool. Writing the USB also replaces its contents.
5. Boot the USB entry marked UEFI. If firmware rejects the installer, review Secure Boot settings; this repository does not configure Secure Boot.

For a VM, use the virtual ISO and disk prepared at the end of this document instead of a USB drive.

## 2. Open a root shell and connect to the network

At the installer console:

```bash
sudo -i
```

Confirm that the installer booted in UEFI mode:

```bash
ls /sys/firmware/efi/efivars
```

The directory must exist. If it does not, reboot and select the UEFI boot entry before continuing.

Wired networking normally obtains an address automatically. For Wi-Fi, open NetworkManager's text interface:

```bash
nmtui
```

Choose **Activate a connection**, select the network, enter its password, and return to the shell. Check the address, route, and HTTPS connectivity:

```bash
ip -brief address
ip route
curl -I https://cache.nixos.org
```

Do not continue until HTTPS works. An incorrect system clock can cause certificate errors; inspect it with `timedatectl` if needed. The installer networking procedure follows the [NixOS installation manual](https://nixos.org/manual/nixos/stable/#sec-installation-manual).

## 3. Identify and select the target disk

List disks with their sizes, models, filesystems, and mount points:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,TYPE,FSTYPE,LABEL,MOUNTPOINTS
```

Identify the internal laptop disk by its model and size. Distinguish it from the installer USB and backup drives. Disconnect unnecessary external storage before partitioning.

For the current physical laptop, set:

```bash
INSTALL_DISK=/dev/nvme0n1
EFI_PARTITION=/dev/nvme0n1p1
SWAP_PARTITION=/dev/nvme0n1p2
ROOT_PARTITION=/dev/nvme0n1p3
```

**Inside the practice VM, use this block instead:**

```bash
INSTALL_DISK=/dev/vda
EFI_PARTITION=/dev/vda1
SWAP_PARTITION=/dev/vda2
ROOT_PARTITION=/dev/vda3
```

Confirm the selected disk again:

```bash
lsblk -o NAME,PATH,SIZE,MODEL,TYPE,FSTYPE,LABEL,MOUNTPOINTS "$INSTALL_DISK"
```

The selected disk must be the installation target, with no partitions mounted or active as swap. If it is in use, stop and unmount only its identified partitions or disable its active swap before proceeding. Do not unmount the installer or backup storage.

These variables exist only in this shell. If you open a new root shell, set and verify them again before using later commands.

## 4. Create the GPT partition layout

Create a new GPT table on the verified target, then open the partition editor. This replaces any previous partition table:

```bash
parted "$INSTALL_DISK" -- mklabel gpt
cfdisk "$INSTALL_DISK"
```

In `cfdisk`:

1. Confirm that the header says **gpt** and that the disk consists of free space. If the GPT creation command failed or the old layout remains, stop and resolve it first.
2. Create partition 1 at the beginning of the free space with size **1G**. Set its type to **EFI System**.
3. Create partition 2 with size **10G** on the physical laptop, or **4G** in the practice VM. Set its type to **Linux swap**.
4. Create partition 3 using the remaining free space. Set its type to **Linux filesystem**.
5. Verify partition numbers, sizes, and types against the installation profile. Select **Write**, type `yes`, and select **Quit**.

Confirm that the kernel sees exactly the expected layout:

```bash
lsblk -o NAME,PATH,SIZE,TYPE,PARTTYPENAME "$INSTALL_DISK"
```

The order must be **EFI → swap → root**. If it differs, fix the partition layout or update the variables before formatting. Do not assume device numbering from another installation guide.

## 5. Format, mount, and enable swap

Format the three verified partitions:

```bash
mkfs.fat -F 32 -n boot "$EFI_PARTITION"
mkswap -L swap "$SWAP_PARTITION"
mkfs.ext4 -L nixos "$ROOT_PARTITION"
```

Mount root first, then EFI, and enable disk swap:

```bash
mount "$ROOT_PARTITION" /mnt
mount --mkdir -o umask=0077 "$EFI_PARTITION" /mnt/boot
swapon "$SWAP_PARTITION"
```

Verify all three results:

```bash
findmnt /mnt
findmnt /mnt/boot
swapon --show
lsblk -f "$INSTALL_DISK"
```

`/mnt` must be the ext4 root partition, `/mnt/boot` must be the FAT32 EFI partition, and disk swap must be active with the label `swap`.

## 6. Generate the hardware configuration and obtain the repository

Generate hardware settings from this installation environment:

```bash
nixos-generate-config --root /mnt
cat /mnt/etc/nixos/hardware-configuration.nix
```

Check that `/` and `/boot` use the UUIDs shown by `lsblk -f`, and that `swapDevices` identifies the new disk swap. Guest and laptop hardware files are different; use the file generated on the target being installed.

Clone through HTTPS so that no GitHub SSH key is needed in the installer. The temporary Nix shell supplies Git even when the ISO does not include it:

```bash
nix-shell -p git --run 'git clone https://github.com/dxtuyen/dotfiles.git /tmp/dotfiles'
cp /mnt/etc/nixos/hardware-configuration.nix \
  /tmp/dotfiles/hosts/laptop/hardware-configuration.nix
cd /tmp/dotfiles
```

The generated `/mnt/etc/nixos/configuration.nix` is not the flake entry point. The next steps install `.#laptop` from this checkout.

## 7. Review the target configuration

Inspect the relevant files before building:

| File | Verify |
| --- | --- |
| `flake.nix` | `x86_64-linux`, target `laptop`, and user `doxuantuyen` |
| `hosts/laptop/default.nix` | Hostname, imports, and integrated Home Manager user |
| `hosts/laptop/hardware-configuration.nix` | Newly generated mounts, UUIDs, disk swap, and hardware modules |
| `modules/nixos/core.nix` | UEFI bootloader, account, network, timezone, and `nh` checkout path |
| `modules/nixos/laptop.nix` | Intel graphics, resume label, sleep mode, battery thresholds, and lid handling |

For the current laptop, retain the intended laptop settings. On different physical hardware, adapt them before installation. Do not increase either `stateVersion` merely because a newer ISO is being used.

**For the practice VM only**, edit the temporary guest checkout with `nano`:

1. In `modules/nixos/core.nix`, change `boot.loader.efi.canTouchEfiVariables = true;` to `false;`. The helper does not provide a persistent writable OVMF variables drive; the installed system can use the fallback EFI loader.
2. In `modules/nixos/laptop.nix`, change `boot.initrd.kernelModules = [ "i915" ];` to `boot.initrd.kernelModules = [ ];`.
3. In the same file, remove `"mem_sleep_default=deep"` from `boot.kernelParams`, leaving an empty list if there are no other entries. The generated guest hardware file supplies the appropriate virtual device modules.

Keep these VM edits inside the guest checkout. VM practice covers installation and desktop use; it does not verify physical battery, lid, or hibernation behavior.

## 8. Install NixOS, then set the user password

From `/tmp/dotfiles`, install the selected flake:

```bash
nixos-install --flake .#laptop
```

Wait for installation to complete successfully. Set the root password when prompted. If a download or build fails, fix the reported problem and rerun the same command; do not repartition or format again.

**After installation succeeds**, set the normal user's password:

```bash
nixos-enter --root /mnt -c 'passwd doxuantuyen'
```

Enter the password twice. The user exists only after installation creates the account. This order follows the [NixOS installation procedure](https://nixos.org/manual/nixos/stable/#sec-installation-installing).

## 9. Preserve the exact checkout used for installation

Copy the checkout, including the generated hardware file and any reviewed changes, into the installed user's home:

```bash
mkdir -p /mnt/home/doxuantuyen
cp -a /tmp/dotfiles /mnt/home/doxuantuyen/dotfiles
nixos-enter --root /mnt -c \
  'chown -R doxuantuyen:users /home/doxuantuyen/dotfiles'
```

Confirm that the copied hardware file matches the installation checkout:

```bash
cmp /tmp/dotfiles/hosts/laptop/hardware-configuration.nix \
  /mnt/home/doxuantuyen/dotfiles/hosts/laptop/hardware-configuration.nix
```

No output and exit status 0 indicate a match. Keeping this checkout avoids accidentally restoring the repository's previous hardware UUIDs through a fresh clone after reboot. If the destination already exists after a retried step, inspect it before copying again; do not create a nested checkout.

## 10. Check the boot files and reboot

Check the installed boot files and mounted EFI partition:

```bash
findmnt /mnt/boot
ls /mnt/boot/EFI
ls /mnt/boot/loader/entries
```

For the VM, also confirm that the fallback loader exists:

```bash
ls /mnt/boot/EFI/BOOT/BOOTX64.EFI
```

Once installation, both passwords, the saved checkout, and boot files are confirmed:

```bash
sync
reboot
```

On the laptop, remove the USB drive as the machine restarts and boot the internal drive. In the VM, close the QEMU window after reboot and start `vm-nixos` from the host to boot without the ISO.

## 11. Verify the installed system

Log in as `doxuantuyen` at tuigreet. In Sway, open Foot with `Super+Enter`.

If Wi-Fi is not connected, run `nmtui` again; the installer connection was not copied into the new system.

```bash
hostname
findmnt /
findmnt /boot
lsblk -f
swapon --show
systemctl --failed
systemctl --user --failed
```

Expected results: hostname `laptop`, the correct root and EFI partitions, active disk swap, and no unexplained failed services. zram may appear alongside disk swap. Check the desktop services:

```bash
systemctl --user status sway-session.target
systemctl --user status waybar swayidle session-lock fcitx5-daemon
```

Review and validate the preserved checkout before the first rebuild:

```bash
cd ~/dotfiles
git status --short
git diff -- hosts/laptop/hardware-configuration.nix modules/nixos/
nix fmt
nix flake check --no-build
nix build .#checks.x86_64-linux.workflows --no-link --print-build-logs
sudo nixos-rebuild switch --flake .#laptop
```

Hardware and VM-specific edits may appear as local modifications; review them before committing or pulling. Keep a VM's generated hardware and overrides separate from the laptop checkout.

### Check physical sleep and hibernation

On the physical laptop, inspect the available sleep modes and resume argument:

```bash
cat /sys/power/mem_sleep
cat /proc/cmdline
readlink -f /dev/disk/by-label/swap
swapon --show
```

`[deep]` indicates the selected deep-sleep mode. Verify that the `resume=` kernel argument identifies the disk swap device. If deep sleep is unavailable, adjust the laptop module and rebuild before testing.

Save work, then test suspend and wake:

```bash
systemctl suspend
```

After confirming that wake and screen locking work, save work again and test hibernation:

```bash
systemctl hibernate
```

Power the laptop back on and confirm that the session resumes. If resume fails, inspect `journalctl -b` and `journalctl -b -1`, the swap capacity, and the resume device before repeating the test.

### Restore SSH access and personal data

Restore the existing SSH key from the backup, or generate a new key only if needed:

```bash
ssh-keygen -t ed25519 -C 'doxuantuyen-laptop'
```

Do not overwrite an existing key. If a new key was created, add its public key to GitHub:

```bash
cat ~/.ssh/id_ed25519.pub
ssh-add ~/.ssh/id_ed25519
ssh -T git@github.com
```

On first connection, compare the host fingerprint with [GitHub's published fingerprints](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints). Successful authentication reports your username and says shell access is unavailable. GitHub returns exit status 1 for this test even on success, as described in its [SSH connection guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection). Once authentication works, update the preserved checkout's remote:

```bash
cd ~/dotfiles
git remote set-url origin git@github.com:dxtuyen/dotfiles.git
git config core.hooksPath .githooks
```

Restore documents, collections, database backups, and required credentials separately. Keep private keys, passwords, and API keys outside Git. See the [maintenance notes](../README.md#maintenance) for later updates and recovery.

## Optional QEMU/KVM preparation

Complete this section **on the host**, then run steps 1–11 **inside the guest**. The repository's `vm-nixos` helper boots a virtual disk and never needs a physical disk passed through.

### A. Verify host prerequisites

The configured host provides QEMU/KVM, OVMF, `qemu-img`, and `vm-nixos`. The helper uses KVM acceleration, the host CPU model, 3 GiB guest RAM, VirtIO storage/networking, and a GTK display.

```bash
command -v vm-nixos qemu-img
id -nG
ls -l /dev/kvm
test -r /dev/kvm && test -w /dev/kvm && echo 'KVM access is available'
```

The account must have access to `/dev/kvm`, normally through the `kvm` group. If group membership was just changed by a rebuild, log out and back in. Enable CPU virtualization in firmware if KVM is unavailable.

Allow enough free host RAM for the 3 GiB guest and enough disk space for the installed desktop and downloaded packages. A 60 GiB sparse virtual disk gives more headroom than the older 30 GiB practice image; its file grows as data is written.

### B. Download the ISO and create the virtual disk

Use a dedicated practice directory so an earlier VM remains intact:

```bash
VM_PRACTICE_DIR="$HOME/VMs/nixos-practice"
mkdir -p "$VM_PRACTICE_DIR/iso" "$VM_PRACTICE_DIR/disk"
ISO_RELEASE_URL="$(curl --fail --silent --show-error --location --head \
  --output /dev/null --write-out '%{url_effective}' \
  https://channels.nixos.org/nixos-unstable/latest-nixos-minimal-x86_64-linux.iso)"
curl --fail --location "$ISO_RELEASE_URL" \
  --output "$VM_PRACTICE_DIR/iso/nixos-minimal.iso"
curl --fail --location "$ISO_RELEASE_URL.sha256" \
  --output "$VM_PRACTICE_DIR/iso/nixos-minimal.iso.sha256"
```

The resolved release URL keeps the ISO and checksum on the same release even if the channel advances during download. Verify the renamed local ISO against that checksum:

```bash
read -r ISO_SHA256 ISO_ORIGINAL_NAME < "$VM_PRACTICE_DIR/iso/nixos-minimal.iso.sha256"
printf '%s  %s\n' "$ISO_SHA256" "$VM_PRACTICE_DIR/iso/nixos-minimal.iso" \
  | sha256sum --check
```

Continue only when the check reports `OK`. Keep only the intended ISO in this directory; the helper selects the first `*.iso` in sorted order.

Create the virtual disk only if the path is unused:

```bash
if [ -e "$VM_PRACTICE_DIR/disk/training.qcow2" ]; then
  echo 'Practice disk already exists; keep it or choose a new directory.'
else
  qemu-img create -f qcow2 "$VM_PRACTICE_DIR/disk/training.qcow2" 60G
fi
```

### C. Boot the guest and use the installation procedure

```bash
VM_DIR="$VM_PRACTICE_DIR" vm-nixos iso
```

Inside the installer, start at step 2. At step 3, select the `/dev/vda` variables. At step 4, use **1 GiB EFI → 4 GiB swap → remaining root**. At step 7, make the VM-only firmware and hardware edits in the guest's temporary checkout.

The guest uses the same account and hostname as the laptop, but its filesystem, generated hardware file, passwords, and checkout are independent. Do not run the guest partitioning commands in a host terminal.

### D. Boot the installed VM later

Close the installer QEMU instance before opening the virtual disk again. From a host shell:

```bash
VM_PRACTICE_DIR="$HOME/VMs/nixos-practice"
VM_DIR="$VM_PRACTICE_DIR" vm-nixos
```

The default mode boots from disk without attaching the ISO. If UEFI opens a boot manager instead, select the disk's `EFI/BOOT/BOOTX64.EFI` loader. Shut down the guest normally before closing its window or reusing its disk.

For another clean practice run, choose a new practice directory and create a new disk. Keep the existing disk if its installed system is still useful.

### E. Troubleshoot installation problems

| Symptom | Check |
| --- | --- |
| KVM permission denied | Verify group membership and `/dev/kvm` access on the host, then start a fresh login session. |
| ISO or disk not found | Set `VM_DIR` for every helper invocation; confirm `iso/*.iso` and `disk/training.qcow2` exist below it. |
| No `/dev/vda` in the installer | Inspect `lsblk` inside the guest; verify the helper attached a VirtIO disk. |
| EFI variable write failure during installation | Confirm the VM checkout sets `boot.loader.efi.canTouchEfiVariables = false`, then rerun installation. |
| Boot returns to the installer | Close QEMU and restart the helper in disk mode. |
| Installed system does not boot | Verify root/EFI mounts, the generated hardware file, and fallback EFI loader; boot the ISO to inspect or repair. |
| Installation runs out of memory or disk | Confirm disk swap is active; increase the virtual disk or guest resources before retrying. |

For a repair, boot the ISO, open a root shell, and identify the existing partitions. Set the correct variables from step 3, then run only the mount and `swapon` commands from step 5. **Do not repeat partitioning or formatting.** The preserved checkout is available through the mounted root:

```bash
cd /mnt/home/doxuantuyen/dotfiles
```

Correct the configuration there and rerun `nixos-install --flake .#laptop`. If the checkout was never saved, clone a fresh temporary copy as in step 6 and recover the correct hardware file before installing.
