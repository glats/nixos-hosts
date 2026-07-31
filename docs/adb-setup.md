# ADB (Android Debug Bridge) — Setup Reference

## What was configured

- **Package**: `android-tools` (v35.0.2, free — Apache 2.0 + MIT)
- **Purpose**: `adb` and `fastboot` available for all Linux and macOS hosts

## Linux hosts

### t14 (Hyprland, local session)

Only needs the package. systemd 258+ built-in uaccess rules in
`70-uaccess.rules` match ADB interfaces automatically. The user has a
local seat session (`Remote=no` in loginctl), so uaccess ACLs are
applied.

**No udev rules needed.** No group needed.

**File**: `linux/system/base/profiles/dev.nix` (shared dev tools profile)

### rog, thinkcentre (XRDP, remote session)

systemd uaccess does **not** work for remote sessions — logind creates
them without a seat (`Remote=yes`). udev rules with explicit
`GROUP`/`MODE` ownership are required instead.

**Module**: `linux/system/hardware/adb.nix`

What it does:
- Creates udev rules in `99-local.rules` (via `services.udev.extraRules`)
- `GROUP="adbusers"`, `MODE="0660"` for Google VID (`18d1`) and Linux
  Foundation gadget VID:PID (`1d6b:0104`)
- GROUP/MODE works at any udev priority — only `TAG+="uaccess"` needs
  priority <73

The `adbusers` group is defined in `linux/system/base/users.nix`
(unconditionally, so `extraGroups` never fails on hosts that don't
import the module). The user `glats` is added to it there too.

**Files**:
- `linux/system/base/users.nix` — `users.groups.adbusers` + `extraGroups = [ "adbusers" ]`
- `linux/system/hardware/adb.nix` — udev rules (imported per-host)
- `hosts/rog/default.nix` — imports `adb.nix`
- `hosts/thinkcentre/default.nix` — imports `adb.nix`

## macOS (mact2)

macOS doesn't use udev. USB permissions are handled by the OS
(on-first-connect prompt). Just the package in `home.packages`.

**File**: `darwin/home/packages.nix`

**No udev, no groups, no extra config.**

## Adding ADB to a new Linux host

1. Is the user going to access this host via remote desktop (XRDP, SSH)?
   - **Yes**: import `../../linux/system/hardware/adb.nix` in the host's `default.nix`
   - **No** (local session): systemd uaccess handles it — no extra import needed

2. The package (`android-tools`) is already in the shared dev profile
   imported by all Linux hosts — nothing to add.

3. Ensure the user is in the `adbusers` group. Already set in
   `linux/system/base/users.nix` for user `glats`. For additional users,
   add `"adbusers"` to their `extraGroups`.

## Adding ADB to a new macOS host

1. Ensure `android-tools` is in `home.packages` (already in
   `darwin/home/packages.nix`).

2. No udev, no groups — macOS handles USB permissions natively.

## Troubleshooting

- **"Access denied (insufficient permissions)" on Linux**: Check
  `loginctl show-session` — if `Remote=yes`, the host needs the
  `adb.nix` module imported. If `Remote=no`, check systemd version
  (`systemctl --version` — must be ≥258).
- **Device not listed by `adb devices`**: Check `lsusb` for the device
  VID:PID. If not `18d1` or `1d6b:0104`, add the vendor ID to
  `adb.nix`.
- **"adbusers group does not exist"**: Ensure
  `linux/system/base/users.nix` is imported (it is for all Linux hosts).
