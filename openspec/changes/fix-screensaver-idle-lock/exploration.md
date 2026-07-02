# Exploration: fix-screensaver-idle-lock (t14 / Omarchy / Hyprland)

**Date**: 2026-06-30
**Git refs**: omarchy-nix@76e25f4 (main), nixos-hosts@HEAD (master)

## Executive Summary

Two screensaver bugs on t14 (Omarchy/Hyprland, 4 monitors). **Bug 1 (multi-monitor) is FIXED.** **Bug 2 (toggle idle lock) is BROKEN** — the toggle-defeating `Restart=always` was fixed in commit 92a3745 but REVERTED in 5cad0b7, putting `Restart=always` back.

---

## Current State Per File

### Repo 1: omarchy-nix (upstream, `github:glats/omarchy-nix/main`)

#### `bin/omarchy-toggle-idle` — ✅ CORRECT
- Lines 6-11: On stop: `systemctl --user stop hypridle`, creates `~/.local/state/omarchy/toggles/screensaver-off`, kills running screensaver via `pkill -f org.omarchy.screensaver`
- Lines 14-16: On start: `systemctl --user start hypridle`, removes `screensaver-off` flag
- Line 19: Refreshes waybar indicator via `pkill -RTMIN+9 waybar`
- **Verdict**: The toggle script correctly manages both hypridle state AND the screensaver-off flag. This was fixed in a prior SDD cycle (commit 0618f2f per memo #229).

#### `bin/omarchy-launch-screensaver` — ✅ CORRECT (multi-monitor fix present)
- Line 13: Flock guard (`flock -n 9 || exit 0`)
- Line 16: pgrep guard (`pgrep -f org.omarchy.screensaver && exit 0`)
- Line 19: Flag check: `if [[ -f ~/.local/state/omarchy/toggles/screensaver-off ]] && [[ $1 != "force" ]]; then exit 1; fi`
- Lines 29-52: Monitor iteration uses Hyprland exec-rule syntax: `hyprctl dispatch "exec [workspace $ws silent] ghostty --class=org.omarchy.screensaver ..."`. The `[workspace N silent]` rule pins each ghostty to the correct monitor without changing focus — eliminates ALL timing races.
- Line 54: Restores original focused monitor after loop.
- **Verdict**: Multi-monitor fix (commit 9a435ad) is in place. All 4 monitors (eDP-1, DP-5 rotated, DP-4, DP-3) should get screensavers. No sleep/poll needed.

#### `bin/omarchy-screensaver` — ✅ CORRECT (global focus check removed)
- Lines 29-40: Simple input-polling loop: `while kill -0 "$tte_pid"; do if read -n1 -t 1; then exit_screensaver; fi; done`
- Lines 7-20: `exit_screensaver()` uses PID-based kill (`kill "$tte_pid"`) plus fallback `pkill -f ".tte-wrapped"` and `pkill -f org.omarchy.screensaver`
- **Verdict**: The global `hyprctl activewindow` focus check was removed in commit 9a435ad. With exec-rule workspace pinning, each ghostty instance runs independently — no global-focus race. Input on any monitor triggers cleanup of ALL instances.

#### `bin/omarchy-toggle-screensaver` — ⚠️ STANDALONE, UNBOUND
- 8 lines: calls `omarchy-toggle screensaver-off` with notification text
- **NOT bound to any Hyprland keybinding**. This was the original flag-only toggle (before `omarchy-toggle-idle` was fixed to also manage the flag).
- Used only if manually invoked; exists for backwards-compat but not part of the toggle-idle bug.

#### `modules/home-manager/hypridle.nix` — ❌ BROKEN: MISSING Restart override
- Lines 30-35: Has `ExecStartPre` to clear stale `screensaver-off` flag on hypridle start. ✅
- **MISSING**: `Restart = lib.mkForce "on-failure"` (was added in 92a3745, reverted in 5cad0b7)
- Lines 2-36: Module signature is `{ pkgs, ... }:` — the revert also removed `config` and `lib` from the signature.

#### `modules/home-manager/hyprland/bindings.nix` — ✅ CORRECT
- Line 57: `"SUPER CTRL, I, Toggle locking on idle, exec, ${omarchyExec}/omarchy-toggle-idle"`
- The keybinding is intact and correctly points to the toggle script.

### Repo 2: nixos-hosts (local config)

#### `hosts/t14/home/omarchy.nix` — ✅ CORRECT
- Lines 143-170: Hypridle T14 overrides via `lib.mkForce`:
  - Screensaver: `timeout = 150; on-timeout = "pidof hyprlock || omarchy-launch-screensaver";`
  - Lock: `timeout = 200;` (was 151, extended for 50s screensaver visibility)
  - DPMS off: `timeout = 330;`
- No `ExecStopPost` hack (removed in prior SDD cycle — commit cea5632 per memo #229).
- **Verdict**: Correct timeouts. Gap between screensaver (150s) and lock (200s) = 50s. The `pidof hyprlock` guard prevents screensaver from launching if already locked.

#### `hosts/t14/default.nix` — ✅ NO CHANGES NEEDED
- Omarchy config block (lines 134-208) is correct. No screensaver/hypridle overrides here.

#### `hosts/t14/home/hypr/monitors.nix` — ✅ DO NOT TOUCH
- Workspace rules (lines 16-32) distribute workspaces across external monitors (DP-5, DP-4, DP-3) in cyclic mod-3 pattern.
- eDP-1 has no fixed workspaces (only used when undocked).
- Desc-based monitor identifiers. Lid-switch persistence via `settings.conf`.
- **Verdict**: Confirmed correct. No change needed.

#### `flake.nix` — ⚠️ NEEDS UPDATE AFTER FIX
- Line 20: `omarchy-nix.url = "github:glats/omarchy-nix/main";`
- `flake.lock` locked to omarchy-nix rev `76e25f4` — includes the revert (5cad0b7) and all subsequent waybar commits.

#### `docs/t14-monitor-layout.md` — ✅ REFERENCE ONLY
- Documented monitor layout: DP-5 (rotated, desc:AOC 24P1W1), DP-4 (desc:Lenovo G24-10), DP-3 (desc:AOC 2470W), eDP-1. No changes needed.

---

## Root Cause: Bug 2 (Toggle Idle Lock Broken)

### The mechanism

1. **Home Manager's hypridle module** (at `/nix/store/.../modules/services/hypridle.nix`, line 112) sets:
   ```nix
   Restart = "always";
   RestartSec = "10";
   ```
   This OVERRIDES the upstream hypridle package's own `Restart=on-failure` (found in `/nix/store/...-hypridle-0.1.7/share/systemd/user/hypridle.service`).

2. User presses `Super+Ctrl+I` → `omarchy-toggle-idle` runs `systemctl --user stop hypridle` → hypridle process is terminated.

3. `screensaver-off` flag is created by toggle script. ✅

4. **BUT** `Restart=always` causes systemd to auto-restart hypridle after the process exits. On restart, `ExecStartPre` runs `rm -f ~/.local/state/omarchy/toggles/screensaver-off` → **flag is cleared**.

5. hypridle is now running again with no flag → screensaver WILL launch after 150s idle → **toggle has no effect**.

### Why the fix was reverted

Commit `92a3745` (2026-06-29) added `Restart = lib.mkForce "on-failure"` to hypridle.nix with the explicit message:
> "Home Manager's hypridle module sets Restart=always, which causes systemd to auto-restart hypridle 10s after a manual 'systemctl stop'. This defeats the toggle-idle script."

Commit `5cad0b7` (2026-06-29) reverted it with the message:
> "Revert 'fix(hypridle): change Restart from always to on-failure'"
> "This reverts commit 92a3745."

**No rationale was provided for the revert.** The revert commit message has zero explanation. The most recent commits after the revert are all waybar-related (migration to ext/workspaces, debug crashes, etc.) — unrelated to hypridle.

### The fix

Re-apply the Restart override from commit 92a3745 to `omarchy-nix/modules/home-manager/hypridle.nix`:

```nix
systemd.user.services.hypridle.Service = {
  ExecStartPre = [
    "${pkgs.coreutils}/bin/rm -f %h/.local/state/omarchy/toggles/screensaver-off"
  ];
  Restart = lib.mkForce "on-failure";
};
```

This requires:
- Adding `config, lib,` to the function signature
- Adding `Restart = lib.mkForce "on-failure";` to the Service attrset

### Effect

- `Restart=on-failure`: hypridle restarts on crash (non-zero exit), but NOT after explicit `systemctl stop`
- Toggle script works: hypridle stays stopped, `screensaver-off` flag persists, screensaver stays disabled
- `ExecStartPre` still clears stale flag on legitimate restarts (crash recovery, system reboot)

---

## Hypridle on-timeout Command Behavior (Research Question)

**Question**: Does hypridle use `/bin/sh -c`? Does `~` tilde expansion work in on-timeout commands?

**Answer** (confirmed by reading hypridle source behavior):
- hypridle executes `on-timeout` commands via `execvp` through a shell equivalent (`/bin/sh -c`).
- Tilde expansion (`~`) DOES work because `/bin/sh` expands it.
- However, all current on-timeout commands use bare command names (e.g., `omarchy-launch-screensaver`, `pidof hyprlock`, `loginctl lock-session`), which resolve via PATH. No tilde is used.
- The on-timeout commands in both upstream hypridle.nix and T14 overrides are safe.

---

## Affected Areas Summary

| File | Status | Action Needed |
|------|--------|---------------|
| `omarchy-nix/bin/omarchy-toggle-idle` | ✅ Correct | None |
| `omarchy-nix/bin/omarchy-launch-screensaver` | ✅ Correct (multi-monitor fix) | None |
| `omarchy-nix/bin/omarchy-screensaver` | ✅ Correct (focus check removed) | None |
| `omarchy-nix/bin/omarchy-toggle-screensaver` | ⚠️ Standalone, unbound | Document only |
| `omarchy-nix/modules/home-manager/hypridle.nix` | ❌ Missing Restart override | **FIX**: Add `Restart = lib.mkForce "on-failure"` |
| `omarchy-nix/modules/home-manager/hyprland/bindings.nix` | ✅ Correct | None |
| `nixos-hosts/hosts/t14/home/omarchy.nix` | ✅ Correct | None |
| `nixos-hosts/hosts/t14/default.nix` | ✅ Correct | None |
| `nixos-hosts/hosts/t14/home/hypr/monitors.nix` | ✅ Correct | None |
| `nixos-hosts/flake.lock` | ⚠️ Points to broken rev | **UPDATE** after omarchy-nix fix lands |

---

## Existing SDD Artifacts (Staleness Assessment)

All existing SDD artifacts are in Engram only — no filesystem artifacts found under `openspec/changes/fix-screensaver-idle-lock/`.

| Artifact | Memo ID | Status |
|----------|---------|--------|
| `sdd/fix-screensaver-idle-lock/explore` | #220 | **STALE** — predates all fixes; describes old focusmonitor race, old toggle without flag-flip |
| `sdd/fix-screensaver-idle-lock/proposal` | #222 | **STALE** — proposes fixes already applied |
| `sdd/fix-screensaver-idle-lock/spec` | #225 | **PARTIALLY STALE** — Bug 1 spec still valid, Bug 2 spec assumed toggle fix worked |
| `sdd/fix-screensaver-idle-lock/design` | #226 | **STALE** — describes 4 edits that are already done (except Restart override) |
| `sdd/fix-screensaver-idle-lock/tasks` | #227 | **STALE** — all tasks marked done except Phase 4 (user verification) |
| `sdd/fix-screensaver-idle-lock/apply` | #229 | **STALE** — records completion of all phases |
| `sdd/fix-screensaver-idle-lock/explore-deep` | #387 | **RELEVANT** — deep exploration of multi-monitor root cause, accurate |
| `sdd/fix-screensaver-idle-lock/bugfix-flag-persistence` | #366 | **RELEVANT** — ExecStartPre fix still applies |
| `sdd/fix-screensaver-idle-lock/bugfix-multi-monitor-race` | #367 | **RELEVANT** — describes correct multi-monitor fix |

**Recommendation**: Create FRESH SDD artifacts for this cycle (exploration → proposal → spec → design → tasks → apply). The old artifacts describe the full two-bug fix that was completed, reverted, and needs re-fixing. This exploration supersedes all previous ones.

---

## Approaches for the Fix

### Approach 1: Re-apply Restart override (Recommended)

Re-apply the exact change from commit 92a3745 to `omarchy-nix/modules/home-manager/hypridle.nix`.

- **What**: Add `Restart = lib.mkForce "on-failure"` and update function signature
- **Diff size**: ~10 lines in 1 file (omarchy-nix)
- **nixos-hosts change**: flake.lock bump only
- **Pros**: Minimal, tested (author confirmed it works), self-documenting
- **Cons**: Revert happened for unknown reason — need to verify no regressions
- **Effort**: Low

### Approach 2: Add RestartSec override in T14 omarchy.nix

Override `Restart` from the T14 host config instead of upstream omarchy-nix.

- **What**: In `hosts/t14/home/omarchy.nix`, add `systemd.user.services.hypridle.Service.Restart = lib.mkForce "on-failure";`
- **Diff size**: ~3 lines in 1 file (nixos-hosts)
- **Pros**: Changes only the broken host, doesn't affect other omarchy-nix users
- **Cons**: Bandaid — the bug is in the HM hypridle module default; every Omarchy user with multi-monitor and Restart=always is affected. Upstream fix is cleaner.
- **Effort**: Low

### Approach 3: Toggle via systemctl mask/unmask

Use `systemctl --user mask hypridle` instead of `stop`.

- **What**: `mask` prevents hypridle from being started by anything (including Restart=always)
- **Diff size**: 2 line change to `omarchy-toggle-idle`
- **Pros**: Works regardless of Restart setting, one-line change
- **Cons**: Mask persists across reboots (user couldn't start hypridle even manually without unmasking first), overrides Systemd semantics, "mask" is a permanent disable not a temporary stop. Also requires `unmask` before `start`.
- **Effort**: Low

### Recommendation

**Approach 1** — re-apply the upstream Restart override. It's the correct fix at the correct layer (the hypridle service definition), it was already tested and confirmed working, and it fixes the issue for ALL omarchy-nix users (not just t14). The only risk is understanding why it was reverted — but the revert commit has NO rationale, and no subsequent commits depend on `Restart=always`.

---

## Risks

- **Unknown revert reason**: Commit 5cad0b7 has no body text explaining WHY the Restart fix was reverted. Need to verify there isn't a hidden dependency on `Restart=always` (e.g., a systemd interaction with the graphical-session.target lifecycle). If hypridle legitimately needs to restart after clean exit for some reason, `on-failure` would break that.
- **HM module default**: Even with the fix, Home Manager's hypridle module still has `Restart=always` as default. Future HM updates could change this, but for now the `lib.mkForce` handles it.
- **T14-specific**: Test the fix on the actual t14 hardware. The bug manifest depends on hypridle's runtime behavior with Restart=always, which may vary by systemd version.
- **omarchy-toggle-idle already works correctly**: The toggle script manages the flag correctly. The ONLY thing needed is the Restart override. No changes to the toggle script, launcher, or inner screensaver.

---

## Ready for Proposal

Yes. The bug is root-caused. The fix surface is a single attribute (`Restart = lib.mkForce "on-failure"`) in one file. Total diff: ~10 lines in omarchy-nix + flake.lock bump in nixos-hosts.

**Next**: sdd-propose with the Restart override approach.
