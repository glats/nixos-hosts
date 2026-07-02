# Exploration: t14 Migration to NVMe

**Change:** t14-migrate-to-nvme
**Date:** 2026-06-26
**Phase:** Explore

## Current State

Host **t14** (ThinkPad T14 AMD Gen 4) is installed on `/dev/sda` using **btrfs** with subvolumes, boots via **systemd-boot** with plymouth + Zen kernel.

### Current Hardware Config (`hosts/t14/hardware-configuration.nix`)

| Mount | Device | FS Type | Notes |
|-------|--------|---------|-------|
| `/` | UUID `d4506bf4-...` | btrfs | Root subvolume |
| `/home` | Same UUID | btrfs | subvol=home |
| `/nix` | Same UUID | btrfs | subvol=nix |
| `/boot` | UUID `35BB-2D84` | vfat | ESP |
| swap | UUID `2d3bf74b-...` | swap | Swap partition |

### Bootloader: systemd-boot
- Set via `modules/features/boot.nix`, enabled with `boot-settings.enable = true`
- `boot.loader.efi.canTouchEfiVariables = true`
- Zen kernel, AMD microcode, plymouth

### Other Hosts Use UUIDs (not /dev/sdX)
Both `rog` and `thinkcentre` reference disks by `/dev/disk/by-uuid/...` — never raw paths. Both use XFS.

### Flake Structure
- `lib/mkHost.nix` builds hosts from `hosts/${hostname}/` + sops-nix + home-manager
- t14 adds: `omarchy-nix` (Hyprland desktop) + `nixos-hardware.lenovo-thinkpad-t14-amd-gen4`
- No host-specific secrets (unlike rog which has `secrets/host/rog/`)

### Secrets & SSH Key
- sops-nix uses `/etc/ssh/ssh_host_ed25519_key` for decryption
- On fresh install: SSH key is regenerated → all secrets fail unless re-encrypted
- **Critical**: must preserve old SSH key or update `.sops.yaml` with new key

### Symlink Pattern
- Repo expected at `/etc/nixos` for rebuilds
- `~/.nixos` used for user convenience (shell aliases, `nh` helper)
- `nixos-build` script auto-detects path

## Recommended Approach
1. Boot from NixOS USB
2. Partition NVMe: ESP (vfat, ~512MB) + root (XFS) + optional swap
3. Format: `mkfs.xfs /dev/nvme0n1p2`, `mkfs.fat -F 32 /dev/nvme0n1p1`
4. Mount → `nixos-generate-config --root /mnt` gets correct UUIDs
5. Clone repo, replace hardware config, `nixos-install --flake /mnt/etc/nixos#t14`
6. Preserve or re-encrypt SSH host key for sops

## Risks
| Risk | Mitigation |
|------|------------|
| btrfs→XFS (no subvolumes) | Host has no btrfs-specific settings — safe |
| SSH host key lost | Copy from old system OR re-encrypt secrets |
| Boot order | Set NVMe first in BIOS/UEFI |
| NVMe in initrd | Already present (`boot.initrd.availableKernelModules`) |
