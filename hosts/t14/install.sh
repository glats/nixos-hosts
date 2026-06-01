#!/usr/bin/env bash
# T14 NixOS Install Script — Run from live ISO
set -euo pipefail

DIE() { echo "[ERROR] $*" >&2; exit 1; }
INFO() { echo "[INFO] $*"; }

DISK="${1:-}"
[[ -n "$DISK" ]] || DIE "Usage: $0 /dev/nvme0n1"
[[ -e "$DISK" ]]   || DIE "Disk $DISK not found"

# ------------------------------------------------------------------
# 1. Partitioning
# ------------------------------------------------------------------
INFO "Partitioning $DISK ..."

# Wipe old signatures
wipefs -af "$DISK"

# GPT: 512M ESP + resto root
parted "$DISK" -- mklabel gpt
parted "$DISK" -- mkpart ESP fat32 1MB 512MB
parted "$DISK" -- set 1 esp on
parted "$DISK" -- mkpart root xfs 512MB 100%

ESP="${DISK}p1"
ROOT="${DISK}p2"

# Format
mkfs.fat -F 32 -n boot "$ESP"
mkfs.xfs -L nixos "$ROOT"

# ------------------------------------------------------------------
# 2. Mount
# ------------------------------------------------------------------
INFO "Mounting filesystems ..."
mount "$ROOT" /mnt
mkdir -p /mnt/boot
mount "$ESP" /mnt/boot

# ------------------------------------------------------------------
# 3. Clone flake repo (or reuse local copy)
# ------------------------------------------------------------------
INFO "Fetching nixos-hosts flake ..."
if [[ -d /home/nixos/nixos-hosts ]]; then
  cp -r /home/nixos/nixos-hosts /mnt/nixos-hosts
else
  git clone https://github.com/glats/nixos-hosts /mnt/nixos-hosts || DIE "git clone failed"
fi

# ------------------------------------------------------------------
# 4. Generate real hardware config
# ------------------------------------------------------------------
INFO "Generating hardware-configuration.nix ..."
nixos-generate-config --root /mnt
# Move generated hardware-config into our host directory
mv /mnt/etc/nixos/hardware-configuration.nix /mnt/nixos-hosts/hosts/t14/hardware-configuration.nix

# ------------------------------------------------------------------
# 5. Install
# ------------------------------------------------------------------
INFO "Running nixos-install ..."
nixos-install --flake /mnt/nixos-hosts#t14 --no-root-passwd

# ------------------------------------------------------------------
# 6. Passwords
# ------------------------------------------------------------------
INFO "Set passwords:"
nixos-enter --root /mnt -c 'passwd glats'
nixos-enter --root /mnt -c 'passwd root'

# ------------------------------------------------------------------
# 7. Done
# ------------------------------------------------------------------
INFO "Install complete. Reboot when ready:"
echo "  umount -R /mnt && reboot"
