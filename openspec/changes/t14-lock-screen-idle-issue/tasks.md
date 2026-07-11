# Tasks: Reliable Idle Toggle for T14 Lock Screen

## Session Context

- **Change**: t14-lock-screen-idle-issue
- **Branch**: fix/idle-toggle-reliable (nixos-hosts)
- **Delivery Strategy**: single-pr
- **Repos Affected**: omarchy-nix (4 files), nixos-hosts (1 file)
- **Execution Mode**: auto

## Prerequisites

### Workspace

| Repo | Path | Branch |
|------|------|--------|
| omarchy-nix | /home/glats/repos/omarchy-nix/ | main |
| nixos-hosts | /home/glats/.nixos/ | fix/idle-toggle-reliable |

### Verification Commands

```bash
# omarchy-nix: just check syntax (no Nix build needed for scripts)
shellcheck bin/omarchy-system-wake bin/omarchy-system-lock bin/omarchy-toggle-idle

# nixos-hosts: verify flake evaluates
nix flake check --no-build

# nixos-hosts: build t14 config specifically
nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link
```

---

## Task 1: omarchy-nix — Create `bin/omarchy-system-wake`

| Field | Value |
|-------|-------|
| **Repo** | omarchy-nix |
| **File** | `bin/omarchy-system-wake` |
| **Action** | CREATE |
| **Dependencies** | None |
| **Verification** | Script is executable, idempotent, in bin/ dir for auto-discovery |

### Specification

New script to restore display and keyboard after system wake (lock resume or sleep resume). Called by hypridle lock listener `on-resume`.

Commands:
- `brightnessctl -r` — restore saved brightness
- `hyprctl dispatch dpms on` — turn on displays

### Implementation Notes

- No arguments, no env vars, no flags
- Idempotent — safe to call repeatedly
- The `executableBinDir` in `modules/home-manager/default.nix` copies `../../bin` recursively, so this file is auto-discovered. No Nix changes needed.
- Must be executable (`chmod +x`)
- Include `omarchy:summary` annotation in comment

### Acceptance

- [ ] Script exists at `bin/omarchy-system-wake`
- [ ] Has executable bit
- [ ] Has `#!/bin/bash` shebang
- [ ] Runs `brightnessctl -r` then `hyprctl dispatch dpms on`
- [ ] Returns exit code 0
- [ ] Shellcheck passes

---

## Task 2: omarchy-nix — Add `OMARCHY_LOCK_ONLY` guard to `bin/omarchy-system-lock`

| Field | Value |
|-------|-------|
| **Repo** | omarchy-nix |
| **File** | `bin/omarchy-system-lock` |
| **Action** | MODIFY |
| **Dependencies** | None |
| **Verification** | Script works with and without env var |

### Specification

Add support for `OMARCHY_LOCK_ONLY` environment variable. When set to `true`, the script locks the session (hyprlock, keyboard reset, 1password lock) but does NOT modify display power or keyboard backlight state.

### Ambiguity Resolution

**Design says**: "run hyprlock directly and exit" (skip everything else)
**Spec says**: "SHALL lock the session (hyprlock, keyboard reset, 1password lock) but MUST NOT modify display power or keyboard backlight state"

**Resolution**: Follow the spec. The current script already has no display-side effects, so `OMARCHY_LOCK_ONLY=true` executes the same code path. The guard is structural for future-proofing — if display management is added later, the `OMARCHY_LOCK_ONLY` path will skip it. Implement as a no-op check at the top that passes through to the same code.

### Current Code

```bash
#!/bin/bash
# omarchy:summary=Lock the screen
...
pidof hyprlock || hyprlock &
hyprctl switchxkblayout all 0 > /dev/null 2>&1
if pgrep -x "1password" >/dev/null; then
  1password --lock &
fi
pkill -f org.omarchy.screensaver
```

### Implementation

Add after the shebang + summary comments:

```bash
if [[ -n $OMARCHY_LOCK_ONLY ]]; then
  pidof hyprlock || hyprlock &
  hyprctl switchxkblayout all 0 > /dev/null 2>&1
  if pgrep -x "1password" >/dev/null; then
    1password --lock &
  fi
  exit 0
fi
```

This preserves all current behaviors in the lock-only path. When display management is added later, the `exit 0` naturally excludes it.

### Acceptance

- [ ] `OMARCHY_LOCK_ONLY=true omarchy-system-lock` locks screen (hyprlock, keyboard reset, 1pass)
- [ ] `omarchy-system-lock` (no env var) behaves identically to current code
- [ ] Shellcheck passes

---

## Task 3: omarchy-nix — Rewrite `bin/omarchy-toggle-idle` to flag-based toggle

| Field | Value |
|-------|-------|
| **Repo** | omarchy-nix |
| **File** | `bin/omarchy-toggle-idle` |
| **Action** | MODIFY |
| **Dependencies** | None |
| **Verification** | Toggle creates/removes `idle-off` flag, no systemctl calls |

### Specification

Replace systemctl-based toggle (stop/start hypridle) with flag-based toggle using `idle-off` flag. The flag is checked by hypridle listeners via `omarchy-toggle-enabled`.

### Current Flow

```
systemctl --user is-active hypridle
  -> active:  stop hypridle, create screensaver-off, kill screensaver, notify
  -> inactive: start hypridle, rm screensaver-off, notify
pkill -RTMIN+9 waybar
```

### Target Flow

```
[[ -f ~/.local/state/omarchy/toggles/idle-off ]]
  -> exists:    rm flag, notify "Now locking", refresh waybar
  -> absent:    create flag, kill screensaver, notify "Stop locking", refresh waybar
```

### Implementation

Use the existing `omarchy-toggle` helper for the flag toggle + notification, then add the extra behavior:

```bash
#!/bin/bash

# omarchy:summary=Toggle hypridle idle locking

if [[ -f "$HOME/.local/state/omarchy/toggles/idle-off" ]]; then
  rm "$HOME/.local/state/omarchy/toggles/idle-off"
  notify-send -u low "(omarchy)  Now locking computer when idle"
else
  mkdir -p "$HOME/.local/state/omarchy/toggles"
  touch "$HOME/.local/state/omarchy/toggles/idle-off"
  pkill -f org.omarchy.screensaver 2>/dev/null || true
  notify-send -u low "(omarchy)  Stop locking computer when idle"
fi

pkill -RTMIN+9 waybar
```

**Changes from current**:
- No `systemctl --user is-active / stop / start / Restart` interaction
- Uses `idle-off` flag instead of `screensaver-off` + hypridle process
- Screensaver kill moved to the "disable idle" (create flag) branch
- Waybar refresh retained

### Acceptance

- [ ] First invocation: creates `~/.local/state/omarchy/toggles/idle-off`, shows notification
- [ ] Second invocation: removes flag, shows "Now locking" notification
- [ ] No systemctl calls anywhere in script
- [ ] Waybar refreshed on every toggle
- [ ] Screensaver killed when idle-off is enabled
- [ ] Shellcheck passes

---

## Task 4: omarchy-nix — Modify `modules/home-manager/hypridle.nix`

| Field | Value |
|-------|-------|
| **Repo** | omarchy-nix |
| **File** | `modules/home-manager/hypridle.nix` |
| **Action** | MODIFY |
| **Dependencies** | Task 1 (omarchy-system-wake), Task 2 (OMARCHY_LOCK_ONLY) |
| **Verification** | `nix flake check --no-build` passes |

### Specification

Six changes to the hypridle Nix module:

#### 4a: Wrap all 3 listener `on-timeout` commands with flag guard

Each `on-timeout` in listener array gets wrapped:

```
on-timeout = "! omarchy-toggle-enabled idle-off && <cmd>";
```

This includes:
- Screensaver listener (150s): `! omarchy-toggle-enabled idle-off && pidof hyprlock || omarchy-launch-screensaver`
- Lock listener (151s): `! omarchy-toggle-enabled idle-off && omarchy-system-lock`
- DPMS listener (330s): `! omarchy-toggle-enabled idle-off && hyprctl dispatch dpms off`

#### 4b: Fix lock `on-timeout` — use `omarchy-system-lock` instead of `loginctl lock-session`

This ensures 1password locking and keyboard reset happen on idle lock, matching manual and sleep lock paths.

#### 4c: Add `on-resume` to lock listener

```
on-resume = "omarchy-system-wake";
```

Calls `omarchy-system-wake` (created in Task 1) to restore brightness + DPMS after unlock.

#### 4d: Fix `before_sleep_cmd` — use `OMARCHY_LOCK_ONLY=true omarchy-system-lock` instead of `loginctl lock-session`

This ensures the sleep path also does 1password locking and keyboard reset, but uses `OMARCHY_LOCK_ONLY` (Task 2) to skip any future display-side effects.

#### 4e: Keep `ExecStartPre` — clear `screensaver-off` only

No change needed here. Already clears `screensaver-off` only. `idle-off` is NOT cleared. Confirmed correct.

#### 4f: Remove `Restart = lib.mkForce "on-failure"`

This override existed so `systemctl --user stop hypridle` would not auto-restart. With flag-based toggle, daemon is never manually stopped, so this is unnecessary. Remove the line.

### Current State

```nix
{ pkgs, lib, ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "omarchy-system-lock";
        before_sleep_cmd = "loginctl lock-session";           # 4d: FIX
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        inhibit_sleep = 3;
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "pidof hyprlock || omarchy-launch-screensaver";  # 4a: WRAP
        }
        {
          timeout = 151;
          on-timeout = "loginctl lock-session";                        # 4a: WRAP, 4b: FIX
                                                                         # 4c: ADD on-resume
        }
        {
          timeout = 330;
          on-timeout = "hyprctl dispatch dpms off";                    # 4a: WRAP
          on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
        }
      ];
    };
  };

  systemd.user.services.hypridle.Service.ExecStartPre = [
    "${pkgs.coreutils}/bin/rm -f %h/.local/state/omarchy/toggles/screensaver-off"
  ];

  systemd.user.services.hypridle.Service.Restart = lib.mkForce "on-failure";  # 4f: REMOVE
}
```

### Target State

```nix
{ pkgs, lib, ... }:
{
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "omarchy-system-lock";
        before_sleep_cmd = "OMARCHY_LOCK_ONLY=true omarchy-system-lock";   # FIXED
        after_sleep_cmd = "hyprctl dispatch dpms on";
        ignore_dbus_inhibit = false;
        inhibit_sleep = 3;
      };
      listener = [
        {
          timeout = 150;
          on-timeout = "! omarchy-toggle-enabled idle-off && pidof hyprlock || omarchy-launch-screensaver";  # WRAPPED
        }
        {
          timeout = 151;
          on-timeout = "! omarchy-toggle-enabled idle-off && omarchy-system-lock";   # WRAPPED + FIXED
          on-resume = "omarchy-system-wake";                                          # ADDED
        }
        {
          timeout = 330;
          on-timeout = "! omarchy-toggle-enabled idle-off && hyprctl dispatch dpms off";  # WRAPPED
          on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
        }
      ];
    };
  };

  systemd.user.services.hypridle.Service.ExecStartPre = [
    "${pkgs.coreutils}/bin/rm -f %h/.local/state/omarchy/toggles/screensaver-off"
  ];
  # Restart=on-failure removed — flag-based toggle never manually stops the daemon.
}
```

### Acceptance

- [ ] All 3 listener `on-timeout` commands wrapped with `! omarchy-toggle-enabled idle-off &&`
- [ ] Lock listener `on-timeout` uses `omarchy-system-lock` (not `loginctl lock-session`)
- [ ] Lock listener has `on-resume = "omarchy-system-wake"`
- [ ] `before_sleep_cmd` uses `OMARCHY_LOCK_ONLY=true omarchy-system-lock`
- [ ] `ExecStartPre` clears only `screensaver-off` (not `idle-off`)
- [ ] `Restart = on-failure` removed
- [ ] `nix flake check --no-build` passes on omarchy-nix

---

## Task 5: nixos-hosts — Simplify `hosts/t14/home/omarchy.nix`

| Field | Value |
|-------|-------|
| **Repo** | nixos-hosts |
| **File** | `hosts/t14/home/omarchy.nix` |
| **Action** | MODIFY |
| **Dependencies** | Task 4 (upstream hypridle.nix fixed — but can be done independently for file content, then flake.lock updated) |
| **Verification** | `nix flake check --no-build` passes, `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link` |

### Specification

Remove the `services.hypridle.settings = lib.mkForce { ... }` block (lines 171-198 in current file).

### Current Code Block to Remove

```nix
  # Override hypridle timings from upstream omarchy-nix.
  # Upstream sets lock at 151s (1s after screensaver at 150s), which means
  # the lock kills the screensaver before the user can see it.
  # We increase the lock delay to 200s so the screensaver has 50s of visibility.
  services.hypridle.settings = lib.mkForce {
    general = {
      lock_cmd = "omarchy-system-lock";
      before_sleep_cmd = "loginctl lock-session";
      after_sleep_cmd = "hyprctl dispatch dpms on";
      ignore_dbus_inhibit = false;
      inhibit_sleep = 3;
    };
    listener = [
      {
        timeout = 150;
        on-timeout = "pidof hyprlock || omarchy-launch-screensaver";
      }
      {
        timeout = 200; # Was 151 — increased to 200 to give screensaver 50s to show
        on-timeout = "loginctl lock-session";
      }
      {
        timeout = 330;
        on-timeout = "hyprctl dispatch dpms off";
        on-resume = "hyprctl dispatch dpms on && brightnessctl -r";
      }
    ];
  };
```

### Rationale

The upstream omarchy-nix now uses flag-based disarm (`idle-off` flag). When the flag is present, NO listener fires at all — screensaver, lock, and DPMS are all suppressed. The 200s lock timeout override was a workaround for the old behavior where lock killed the screensaver immediately. With the flag mechanism, the lock listener at 151s causes no visual issue when idle-off is active (all listeners are suppressed), and when idle-off is inactive, the lock happens at 151s which is fine.

### Implementation

- Remove block (lines 171-198 inclusive)
- Post-removal, the upstream `hypridle.nix` from omarchy-nix takes effect with its default 151s lock timeout, flag guards, `omarchy-system-lock`, and `omarchy-system-wake`.
- After removing, update flake.lock to point to the new omarchy-nix commit (the one with Tasks 1-4).

### Acceptance

- [ ] `services.hypridle.settings` block removed from t14 omarchy.nix
- [ ] No other hypridle-related overrides remain in file
- [ ] `nix flake check --no-build` passes for t14
- [ ] `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link` succeeds

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines (omarchy-nix) | ~44 (12 new + 32 modified) |
| Estimated changed lines (nixos-hosts) | ~28 (removed block, negative delta) |
| 400-line budget risk | **Low** (total delta ~44 net new) |
| Chained PRs recommended | **No** — well under 400 lines across both repos |
| Decision needed before apply | **Two-repo coordination**: omarchy-nix changes must be committed and pushed before nixos-hosts flake.lock can be updated |

## Cross-Cutting Concerns

| Concern | Impact | Mitigation |
|---------|--------|------------|
| Two-repo coordination | Omarchy-nix changes must ship before nixos-hosts can consume them | Do omarchy-nix first (commit + push), then update nixos-hosts flake.lock |
| OMARCHY_LOCK_ONLY ambiguity | Design says "hyprlock only"; spec says "all current behaviors" | Resolved at task level: spec interpretation wins. Lock-only path preserves all current behaviors (hyprlock, keyboard, 1password). |
| Prior commits on branch | nixos-hosts `fix/idle-toggle-reliable` has 5 prior commits | Verify they don't conflict before removing hypridle block |
| Script auto-discovery | New `omarchy-system-wake` needs no Nix packaging changes | Confirmed: `executableBinDir` in `default.nix` copies `../../bin` recursively |
| flake.lock update | nixos-hosts must update lock after omarchy-nix push | Use `nix flake lock --update-input omarchy-nix` or manual hash update |
