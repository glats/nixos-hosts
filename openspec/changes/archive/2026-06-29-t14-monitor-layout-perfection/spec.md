# Spec: t14-monitor-layout-perfection

> **Change**: `t14-monitor-layout-perfection`
> **Scope**: Two repositories — omarchy-nix (generic) + nixos-hosts (T14-specific)
> **Date**: 2026-06-29 (v4 — final, reflects all implementation iterations)
> **Supersedes**: v3 (initial 5-capability spec), v2, v1

---

## CAP-CONDITIONAL: Parse-time Conditional Layout (nixos-hosts, T14-specific)

The Hyprland config MUST use `# hyprlang if` conditionals to select the correct monitor layout at parse time, driven by the `$ENABLE_LAPTOP` variable from `settings.conf`.

| Req | Requirement |
|-----|-------------|
| REQ-COND-1 | `extraConfig` MUST contain `source = <path>/settings.conf` to read `$ENABLE_LAPTOP` at parse time |
| REQ-COND-2 | When `$ENABLE_LAPTOP = 1` → eDP-1 MUST be enabled at `preferred, 4920x420, 1` and 3 externals MUST be at y=420 |
| REQ-COND-3 | When `$ENABLE_LAPTOP =` (empty) → eDP-1 MUST be disabled (`monitor = eDP-1, disable`) and 3 externals MUST be at y=0 |
| REQ-COND-4 | The disabled value MUST be empty (`$ENABLE_LAPTOP =`), NOT `0`, because hyprlang treats any non-empty value as truthy |
| REQ-COND-5 | Workspace rules for the 3 externals (mod-3 distribution) MUST be identical in both conditional branches |
| REQ-COND-6 | When ENABLE_LAPTOP and eDP-1 is on, workspaces 1-3 MUST bind to eDP-1 for undocked usage |

#### Scenario: Boot docked, lid closed
- GIVEN `$ENABLE_LAPTOP =` (empty) in settings.conf
- AND lid is closed
- WHEN Hyprland starts and parses hyprland.conf
- THEN eDP-1 is disabled
- AND AOC 24P1W1 at `0x0`, Lenovo at `1080x0`, AOC 2470W at `3000x0`
- AND no dead zone exists

#### Scenario: Boot undocked, lid open
- GIVEN `$ENABLE_LAPTOP = 1` in settings.conf
- WHEN Hyprland starts
- THEN eDP-1 is active at `preferred, 4920x420, 1`
- AND workspaces 1-3 bind to eDP-1

---

## CAP-LIDSWITCH: Single-owner Lid-Switch Runtime Control (T14-specific + omarchy generic)

Lid switch events MUST be handled by exactly one writer. Omarchy's default lid-switch `bindl` MUST be disabled so T14's `bindl` is the sole owner of `settings.conf`.

| Req | Requirement |
|-----|-------------|
| REQ-LID-1 | `omarchy.hyprland.lidSwitch.enable = false` MUST be set in t14 host config |
| REQ-LID-2 | T14's bindl MUST be the ONLY writer to `settings.conf` |
| REQ-LID-3 | No race condition SHALL exist between two `bindl` handlers on the same lid event |
| REQ-LID-4 | The bindl regex MUST match `Lid Switch` case-insensitively: `.*[Ll]id.*` |
| REQ-LID-5 | On lid close, the bindl MUST: set `$ENABLE_LAPTOP =` in settings.conf, disable eDP-1 via `hyprctl keyword`, AND reposition all 3 externals to y=0 |
| REQ-LID-6 | On lid open, the bindl MUST: set `$ENABLE_LAPTOP = 1` in settings.conf, enable eDP-1 via `hyprctl keyword`, AND reposition all 3 externals to y=420 |

#### Scenario: Lid close without race
- GIVEN `omarchy.hyprland.lidSwitch.enable = false`
- WHEN lid closes
- THEN only T14's `bindl` fires
- AND eDP-1 is disabled and externals move to y=0
- AND no `hyprctl reload` from omarchy's `bindl` interferes

#### Scenario: Lid open restores layout
- GIVEN lid was closed, `$ENABLE_LAPTOP =` empty
- WHEN lid opens
- THEN T14's `bindl` writes `$ENABLE_LAPTOP = 1` to settings.conf
- AND eDP-1 re-enables at correct position
- AND externals move to y=420

---

## CAP-DAEMON: Boot-time Validator Daemon (nixos-hosts, T14-specific)

A systemd daemon MUST run after `graphical-session.target`, apply the correct layout based on lid state, persist the setting, and monitor for changes.

| Req | Requirement |
|-----|-------------|
| REQ-DAEMON-1 | A systemd user service `monitor-lid-validator.service` MUST exist with `Type=simple`, `After=graphical-session.target` |
| REQ-DAEMON-2 | The service MUST auto-detect `HYPRLAND_INSTANCE_SIGNATURE` if not set in environment |
| REQ-DAEMON-3 | The service MUST restart on failure (`Restart=on-failure`, `RestartSec=5`) |
| REQ-DAEMON-4 | The service MUST provide `PATH` including `~/.local/bin` and `/run/current-system/sw/bin` |
| REQ-DAEMON-5 | The service MUST provide `XDG_RUNTIME_DIR=%t` |
| REQ-DAEMON-6 | On start, the daemon MUST read lid state from `/proc/acpi/button/lid/LID*/state`, apply correct layout via `hyprctl keyword`, persist to settings.conf, and call `hyprctl reload` |
| REQ-DAEMON-7 | The daemon MUST poll `hyprctl monitors -j` every 2 seconds and re-apply layout if monitor list changes |
| REQ-DAEMON-8 | The daemon MUST always apply on each trigger (idempotent), not skip based on cached state |

#### Scenario: Boot with stale settings.conf
- GIVEN settings.conf has `$ENABLE_LAPTOP = 1` from last session
- AND lid is currently closed (lid was closed after last session)
- WHEN the daemon starts
- THEN it reads lid state ("closed") and applies y=0 layout
- AND settings.conf is updated to `$ENABLE_LAPTOP =` empty

#### Scenario: Dock plugged mid-session
- GIVEN daemon is running with polling loop
- WHEN external monitors are connected
- THEN daemon detects monitor change on next poll (within 2s)
- AND re-applies layout based on current lid state

#### Scenario: systemd service restarts after crash
- GIVEN daemon crashes (e.g., OOM)
- WHEN systemd restarts it with `Restart=on-failure`
- THEN daemon re-applies layout based on current lid state

---

## CAP-SETTINGS: Writable settings.conf (nixos-hosts, T14-specific)

The `settings.conf` file MUST be writable at runtime so the bindl and daemon can update `$ENABLE_LAPTOP`.

| Req | Requirement |
|-----|-------------|
| REQ-SET-1 | `settings.conf` MUST NOT be a Nix store symlink (read-only) |
| REQ-SET-2 | `home.activation.seedHyprSettings` MUST create the file if it doesn't exist, using shell `printf` |
| REQ-SET-3 | The file content MUST be `$ENABLE_LAPTOP = 1\n` (new file) or preserve existing content (upgrade) |

#### Scenario: First activation
- GIVEN settings.conf does not exist
- WHEN `home-manager switch` runs
- THEN `home.activation.seedHyprSettings` creates `~/.config/hypr/settings.conf`
- AND content is `$ENABLE_LAPTOP = 1\n`
- AND the file is a regular file (not a symlink)

#### Scenario: bindl writes to settings.conf
- GIVEN settings.conf is a regular writable file
- WHEN lid-switch bindl runs `printf '$ENABLE_LAPTOP =\n' > $HOME/.config/hypr/settings.conf`
- THEN the file content is updated
- AND the write succeeds (no silent failure)

---

## CAP-HOTPLUG: Monitor Hotplug Recovery (omarchy-nix, generic + T14 daemon)

Monitor addition/removal at runtime MUST be detected and trigger layout correction.

| Req | Requirement |
|-----|-------------|
| REQ-HOTPLUG-1 | On `monitoradded>>` or `monitoraddedv2>>` socket2 event, `omarchy-hyprland-monitor-watch` MUST execute `hyprctl reload` |
| REQ-HOTPLUG-2 | T14 daemon polling loop MUST detect monitor changes within 2 seconds |
| REQ-HOTPLUG-3 | On detected change, the daemon MUST re-apply the correct layout for the current lid state |
| REQ-HOTPLUG-4 | The two layers (omarchy reload + daemon apply) are independent and idempotent |

#### Scenario: Dock connected mid-session
- GIVEN laptop is undocked, daemon is polling
- WHEN dock with 3 externals is connected
- THEN `omarchy-hyprland-monitor-watch` fires `hyprctl reload` via monitoradded handler
- AND daemon detects monitor change within 2s
- AND daemon re-applies layout for current lid state

#### Scenario: Undock mid-session
- GIVEN laptop is docked, daemon is polling
- WHEN dock is disconnected
- THEN daemon detects monitor removal within 2s
- AND daemon applies correct layout for current lid state (eDP-1 enabled if lid open)

---

## CAP-DRM: Boot-time DRM Probe Synchronization (nixos-hosts, T14-specific)

| Req | Requirement |
|-----|-------------|
| REQ-DRM-1 | A systemd drop-in `udev-settle.conf` MUST add `ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10` to the `wayland-wm@hyprland.desktop.service` unit |
| REQ-DRM-2 | The `-` prefix MUST make the directive non-fatal — Hyprland SHALL start even if `udevadm settle` fails |
| REQ-DRM-3 | The drop-in MUST be instance-scoped to `hyprland.desktop` only |

#### Scenario: Cold boot with externals
- GIVEN `udevadm settle` ExecStartPre is active
- WHEN system boots
- THEN `udevadm settle` runs before Hyprland and blocks until DRM devices are probed
- AND the daemon's lid-state reading is reliable (DRM devices exist)

#### Scenario: udevadm settle not available
- GIVEN `udevadm` is missing or broken
- WHEN systemd processes ExecStartPre
- THEN the `-` prefix causes the directive to fail non-fatally
- AND Hyprland starts normally (degraded — daemon still corrects on poll)

---

## CAP-STANDALONE: Standalone Validator Script (nixos-hosts, T14-specific)

The monitor layout logic MUST live in a standalone script for maintainability.

| Req | Requirement |
|-----|-------------|
| REQ-STAND-1 | The script MUST be at `~/.local/bin/monitor-lid-validator.sh`, deployed via `home.file` |
| REQ-STAND-2 | The script MUST support `--daemon` (apply+loop), `--apply-once` (apply and exit), and no-args (apply and exit) modes |
| REQ-STAND-3 | The script MUST auto-detect `HYPRLAND_INSTANCE_SIGNATURE` |

#### Scenario: Script mode dispatch
- GIVEN script is at `~/.local/bin/monitor-lid-validator.sh`
- WHEN called with `--daemon` → applies once and enters 2s polling loop
- WHEN called with `--apply-once` → applies once and exits
- WHEN called with no args → applies once and exits

---

## Out of Scope (confirmed)

- Greeter monitor layout (separate system)
- split-monitor-workspaces or hyprmoncfg
- Other hosts (rog, thinkcentre, mact2)
- Comprehensive toggle-source fix in omarchy-nix (separate upstream PR)
- Mirror toggle (not used on T14)

## Verification Strategy (as performed)

| Layer | Method | Covers |
|-------|--------|--------|
| Build (omarchy-nix) | `nix flake check --no-build` | CAP-HOTPLUG, CAP-LIDSWITCH |
| Build (nixos-hosts) | `nix flake check --no-build` | All CAPs |
| Format | `format-nix` | Code style |
| Config grep | Conditionals exist, no omarchy bindl | CAP-CONDITIONAL, CAP-LIDSWITCH |
| File check | settings.conf is regular file, not symlink | CAP-SETTINGS |
| File check | Service file exists with correct config | CAP-DAEMON |
| File check | Drop-in exists with correct content | CAP-DRM |
| Manual | All scenarios verified on t14 hardware | All CAPs |
