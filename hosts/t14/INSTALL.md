# T14 NixOS Install Guide

Quick reference for installing NixOS on the ThinkPad T14 from the live ISO.

## Boot the ISO

1. Flash ISO to USB: `sudo dd if=t14-nixos.iso of=/dev/sdX bs=4M status=progress`
2. Boot T14 from USB (F12 for boot menu)
3. Login: `nixos` / `nixos`

## Quick Install (automated script)

```bash
sudo /etc/nixos/t14-install.sh /dev/nvme0n1
```

This partitions, formats, clones the repo, generates hardware config, installs, and prompts for passwords.

## Manual Install Step-by-Step

### 1. Partition

```bash
DISK=/dev/nvme0n1
sudo wipefs -af "$DISK"
sudo parted "$DISK" -- mklabel gpt
sudo parted "$DISK" -- mkpart ESP fat32 1MB 512MB
sudo parted "$DISK" -- set 1 esp on
sudo parted "$DISK" -- mkpart root xfs 512MB 100%
```

### 2. Format

```bash
sudo mkfs.fat -F 32 -n boot "${DISK}p1"
sudo mkfs.xfs -L nixos "${DISK}p2"
```

### 3. Mount

```bash
sudo mount "${DISK}p2" /mnt
sudo mkdir -p /mnt/boot
sudo mount "${DISK}p1" /mnt/boot
```

### 4. Get flake repo

```bash
# Option A: clone from GitHub
sudo git clone https://github.com/glats/nixos-hosts /mnt/nixos-hosts

# Option B: copy from USB/local
sudo cp -r /home/nixos/nixos-hosts /mnt/nixos-hosts
```

### 5. Generate hardware config

```bash
sudo nixos-generate-config --root /mnt
sudo mv /mnt/etc/nixos/hardware-configuration.nix \
       /mnt/nixos-hosts/hosts/t14/hardware-configuration.nix
```

### 6. Install

```bash
sudo nixos-install --flake /mnt/nixos-hosts#t14 --no-root-passwd
```

### 7. Set passwords

```bash
sudo nixos-enter --root /mnt -c 'passwd glats'
sudo nixos-enter --root /mnt -c 'passwd root'
```

### 8. Reboot

```bash
sudo umount -R /mnt
sudo reboot
```

## Post-Install (after first boot)

1. Login as `glats`
2. SDDM → UWSM → Hyprland should start automatically
3. OpenCode available via `opencode` in terminal
4. To rebuild: `nixos-build switch` (alias pre-configured)

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No WiFi | `nmtui` or `nmcli` |
| Wrong keyboard | `loadkeys es` |
| Install fails | Re-run `nixos-install` after fixing config |
| Hyprland black screen | Check monitor name in `hypr/monitors.nix`, rebuild |

## Layout

- ESP → `/boot` (FAT32, 512MB)
- Root → `/` (XFS, resto del disco)
- Swap → `zram` (en RAM, ya configurado en host config)

## Notes

- No LUKS (plano, como rog y thinkcentre)
- No btrfs (XFS según preferencia)
- systemd-boot como bootloader UEFI
- `hardware-configuration.nix` se regenera en target, no editar a mano
