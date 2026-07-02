# SDD Session Prompt — fix-screensaver-idle-lock

**For**: Next SDD session (do NOT execute in this session)
**Save to**: Engram `sdd/fix-screensaver-idle-lock/preflight` + openspec `openspec/changes/fix-screensaver-idle-lock/`
**Predecessor**: This session (partially successful — multi-monitor fix works, toggle still broken)

---

## SDD Session Preflight

### Change: fix-screensaver-idle-lock

The T14 (Omarchy/Hyprland, 4 monitors: eDP-1 + 3 externals on dock) has two bugs:

1. **Multi-monitor screensaver** (FIXED ✅): screensaver only appeared on eDP-1. Root cause: `hyprctl dispatch exec` is fire-and-forget — the Wayland surface maps asynchronously, after the script has moved focus to the next monitor. **Fix applied**: use Hyprland's exec-rule syntax `dispatch "exec [workspace N silent] ghostty..."` which pins the window to workspace N without relying on focus timing. Works on all 4 monitors. DO NOT BREAK THIS.

2. **Toggle idle lock (Super+Ctrl+I)** (BROKEN ❌): the shortcut should prevent screensaver AND lock from activating, but both still fire. Root cause identified but fix was WRONG.

### Execution Mode
- **guided** (auto-chain phases, pause before apply)

### Artifact Store
- **hybrid** (Engram + openspec)

### Delivery
- **no-pr** (commit directly to main/master on both repos; user does `nixos-rebuild switch`)

### Review Budget
- **standard** (nix flake check, format-nix, bash -n)

---

## ⚠️ CRITICAL: REVALIDAR TODO — NO ASUMIR NADA

**Toda la información en este documento es meramente informativa.** Refleja lo observado e intentado en esta sesión, pero PUEDE estar desactualizada. La sesión SDD DEBE leer los archivos reales antes de implementar.

---

## REPOSITORY CONTEXT

- **nixos-hosts** (`github.com/glats/nixos-hosts`): `/home/glats/.nixos`. T14 is `hosts/t14/`. Branch: `master`.
- **omarchy-nix** (`github.com/glats/omarchy-nix`): `/home/glats/repos/omarchy-nix`. User OWNS this repo (full push access). Branch: `main`.
- **Auth**: Use `~/.git-credentials` for git push.
- **Patterns**: `nixos-build` for switching, `format-nix` for formatting, `nix flake check --no-build` for validation, `bash -n` for shell scripts.

---

## WHAT WAS FIXED (KEEP THESE — DO NOT REVERT)

### Fix A — Multi-monitor screensaver: exec-rule workspace pinning
**Commit**: `9a435ad` (omarchy-nix) + `97a4b90` (nixos-hosts flake bump)
**File**: `omarchy-nix/bin/omarchy-launch-screensaver`
**What**: Replaced `hyprctl dispatch exec -- ghostty` with `hyprctl dispatch "exec [workspace N silent] ghostty"`. The `[workspace N silent]` rule pins the window to workspace N without changing focus. Works on all 4 monitors, no sleep needed. Also removed `c` moves and all timing-based hacks.
**Status**: ✅ Confirmed working on all 4 monitors.

### Fix B — Inner screensaver: removed global focus check
**Commit**: `9a435ad` (omarchy-nix)
**File**: `omarchy-nix/bin/omarchy-screensaver`
**What**: Removed `screensaver_in_focus()` function and its usage in the exit condition. With 4 terminals only one can be globally active, so the other 3 immediately exited and pkilled all instances. Now exit only on keypress (read -n1).
**Status**: ✅ Works with multi-monitor.

### Fix C — Toggle flag management
**Commit**: `0618f2f` (omarchy-nix)
**File**: `omarchy-nix/bin/omarchy-toggle-idle`
**What**: Added `touch screensaver-off` on stop branch and `rm -f screensaver-off` on start branch, plus `pkill org.omarchy.screensaver` on stop.
**Status**: ⚠️ Partially correct — flag management logic is sound but doesn't address the real toggle problem.

---

## WHAT WAS TRIED AND FAILED (DO NOT REPEAT)

### Attempt 1-5 — Various timing-based multi-monitor fixes
**Commits**: `ce9b27c`, `31aecd7`, `230a34e`, `6ba3c89`, `b0f4b3f`
**What**: sleep 0.3s, poll-for-map, sleep 2s, workspace dispatch, workspace + movecursor — all assumed the bug was a timing race in the focus loop.
**Why failed**: The real problem was `dispatch exec` async surface creation, not timing. All these approaches still relied on focus/cursor being correct when the surface mapped, which was never guaranteed.

### Attempt 6 — Change hypridle Restart=always to on-failure
**Commit**: `92a3745` (omarchy-nix) — **REVERTED in `5cad0b7`**
**What**: Changed systemd unit from `Restart=always` to `Restart=on-failure` so manual `systemctl stop` wouldn't auto-restart.
**Why failed**: This broke something else ("estaba funcionando bien y ahora no funciona"). The Restart=always is there for a reason — hypridle is critical infrastructure that should always be running.

### Attempt 7 — ExecStartPre to clear stale flag on hypridle start
**Commit**: `651a2c1` (omarchy-nix)
**What**: Added `rm -f screensaver-off` as ExecStartPre.
**Why incomplete**: Combined with Restart=always, this clears the flag every time systemd restarts hypridle (including after a manual toggle stop → auto-restart 10s later). Defeats the toggle.

---

## ROOT CAUSE OF BUG 2 (TOGGLE NOT WORKING)

### The Problem
`omarchy-toggle-idle` does `systemctl --user stop hypridle` to disable idle. But hypridle's systemd unit has `Restart=always; RestartSec=10`. Systemd restarts hypridle 10 seconds after the stop. The ExecStartPre then clears the `screensaver-off` flag. The toggle has no lasting effect.

### The Correct Approach
**Stop trying to stop hypridle.** Instead, keep hypridle running and use a **flag-based gate** in the on-timeout commands:

```
Toggle script manages:  ~/.local/state/omarchy/toggles/idle-off

When idle is TOGGLED OFF (disabled):
  → create idle-off flag
  → kill any running screensaver (pkill org.omarchy.screensaver)

When idle is TOGGLED ON (enabled):
  → remove idle-off flag

hypridle on-timeout commands check the flag:
  screensaver: "[ -f ~/.local/state/omarchy/toggles/idle-off ] || (pidof hyprlock || omarchy-launch-screensaver)"
  lock:        "[ -f ~/.local/state/omarchy/toggles/idle-off ] || loginctl lock-session"
  dpms off:    "[ -f ~/.local/state/omarchy/toggles/idle-off ] || hyprctl dispatch dpms off"
```

This way:
1. hypridle stays running (Restart=always is fine — no conflict)
2. Flag blocks all on-timeout actions when present
3. On reboot, ExecStartPre can clear the flag (fresh start each boot)
4. No race between toggle stop and auto-restart

---

## CURRENT STATE (AS OF SESSION END)

### omarchy-nix (branch main, HEAD: 5cad0b7)
```
5cad0b7 Revert "fix(hypridle): change Restart from always to on-failure"
92a3745 fix(hypridle): change Restart from always to on-failure  [REVERTED]
9a435ad fix(screensaver): use exec-rule workspace pinning for multi-monitor
b0f4b3f fix(screensaver): move cursor to each monitor  [SUPERSEDED by 9a435ad]
6ba3c89 fix(screensaver): use workspace dispatch  [SUPERSEDED]
230a34e fix(screensaver): replace fragile poll-for-map...  [SUPERSEDED]
31aecd7 fix(screensaver): wait for window map...  [SUPERSEDED]
651a2c1 fix(hypridle): correct bracket structure...  [SUPERSEDED]
516bd6f fix(hypridle): clear stale screensaver-off flag...  [PARTIALLY RELEVANT]
ce9b27c fix(screensaver): settle focus...  [SUPERSEDED]
0618f2f fix(idle): flip screensaver-off flag and kill running screensaver
```

### nixos-hosts (branch master, HEAD: a1b9a93)
```
a1b9a93 chore(flake): bump omarchy-nix for hypridle Restart=on-failure fix
97a4b90 chore(flake): bump omarchy-nix for exec-rule workspace pinning fix
2304581 chore(flake): bump omarchy-nix for movecursor-based screensaver fix
50b1222 chore(flake): bump omarchy-nix for workspace-based screensaver fix
f7f6d5c chore(flake): bump omarchy-nix for screensaver focus-race fix
3d0200b chore(flake): bump omarchy-nix for hypridle ExecStartPre fix
cea5632 fix(t14): drop screensaver ExecStopPost now handled by omarchy-toggle-idle
```

### Current flag state (on this machine, NOT t14):
- `~/.local/state/omarchy/toggles/screensaver-off` — was deleted (stale from testing)
- `~/.local/state/omarchy/toggles/idle-off` — does not exist (not yet created)

### What currently works:
- ✅ Multi-monitor screensaver (exec-rule workspace pinning)
- ✅ Inner screensaver doesn't self-destruct (removed global focus check)
- ❌ Toggle (Super+Ctrl+I) doesn't prevent lock — root cause identified but fix not implemented

---

## FEATURES TO PRESERVE

### T14 hypridle timeouts (in hosts/t14/home/omarchy.nix)
```nix
listener = [
  { timeout = 150; on-timeout = "pidof hyprlock || omarchy-launch-screensaver"; }
  { timeout = 200; on-timeout = "loginctl lock-session"; }
  { timeout = 330; on-timeout = "hyprctl dispatch dpms off"; on-resume = "..."; }
];
```
The 150→200 gap gives 50s of screensaver visibility before lock. PRESERVE THIS.

### omarchy-nix hypridle defaults (modules/home-manager/hypridle.nix)
```nix
listener = [
  { timeout = 150; on-timeout = "pidof hyprlock || omarchy-launch-screensaver"; }
  { timeout = 151; on-timeout = "loginctl lock-session"; }
  { timeout = 330; on-timeout = "hyprctl dispatch dpms off"; ... }
];
```
The T14 overrides these with `lib.mkForce`. The flag check should be added to BOTH the upstream defaults AND the T14 override.

### Monitor layout (DO NOT TOUCH)
See `docs/t14-monitor-layout.md`. 3 external monitors + eDP-1. DP-5 is rotated portrait. Workspace distribution mod-3. Dead-zone fix (y=420).

### Other preserved settings (DO NOT TOUCH)
- `omarchy-toggle-idle` keybinding: `SUPER CTRL, I` in `omarchy-nix/modules/home-manager/hyprland/bindings.nix`
- `waybar` idle indicator (pkill -RTMIN+9 waybar in toggle script)
- `ignore_dbus_inhibit = false` — allows apps to inhibit idle
- `inhibit_sleep = 3` — wait 3s before sleep after lock

---

## EXPLORATION PHASE REQUIREMENTS (if needed)

If the flag-based approach described above needs validation, the explore phase should:

1. **Verify hypridle's shell execution**: hypridle runs on-timeout via `/bin/sh -c`. Does `[ -f ~/... ]` work in this context? Test with a simple flag check first.
2. **Check flag path expansion**: Does `~` expand correctly in hypridle's shell? If not, use `$HOME`.
3. **Consider notification on toggle**: Currently the toggle notifies "Stop locking computer when idle" / "Now locking computer". With flag approach, no service is started/stopped — just flag management. The notification text may need updating.
4. **Consider also killing running screensaver in toggle-off**: When user toggles idle off, any currently-running screensaver should be killed. Already implemented (pkill), keep it.

---

## IMPLEMENTATION PLAN (for apply phase)

### Files to modify:

| File | Repo | Action |
|------|------|--------|
| `bin/omarchy-toggle-idle` | omarchy-nix | Replace systemctl stop/start with flag management + screensaver kill |
| `modules/home-manager/hypridle.nix` | omarchy-nix | Add `[ -f idle-off ] ||` prefix to all 3 on-timeout commands. Remove ExecStartPre for screensaver-off (redundant with flag check). |
| `hosts/t14/home/omarchy.nix` | nixos-hosts | Add `[ -f idle-off ] ||` prefix to all 3 on-timeout commands in the t14 override. |
| `flake.lock` | nixos-hosts | Bump omarchy-nix input after upstream commits. |

### omarchy-toggle-idle changes (pseudocode):
```bash
if [[ -f ~/.local/state/omarchy/toggles/idle-off ]]; then
  # Currently OFF → turn ON (enable idle)
  rm -f ~/.local/state/omarchy/toggles/idle-off
  notify-send -u low "Now locking computer when idle"
else
  # Currently ON → turn OFF (disable idle)
  mkdir -p ~/.local/state/omarchy/toggles
  touch ~/.local/state/omarchy/toggles/idle-off
  pkill -f org.omarchy.screensaver 2>/dev/null || true
  notify-send -u low "Stop locking computer when idle"
fi
pkill -RTMIN+9 waybar
```

### hypridle on-timeout changes:
```
Before: on-timeout = "pidof hyprlock || omarchy-launch-screensaver"
After:  on-timeout = "[ -f $HOME/.local/state/omarchy/toggles/idle-off ] || pidof hyprlock || omarchy-launch-screensaver"

Before: on-timeout = "loginctl lock-session"
After:  on-timeout = "[ -f $HOME/.local/state/omarchy/toggles/idle-off ] || loginctl lock-session"

Before: on-timeout = "hyprctl dispatch dpms off"
After:  on-timeout = "[ -f $HOME/.local/state/omarchy/toggles/idle-off ] || hyprctl dispatch dpms off"
```

### Cleanup:
- Remove `ExecStartPre` for `screensaver-off` from hypridle module (no longer needed — the flag check in on-timeout handles reboots: on reboot, flag doesn't exist, so all timeouts fire normally).
- Remove `touch screensaver-off` / `rm -f screensaver-off` from toggle script (replaced by `idle-off` flag).
- Keep `pkill -f org.omarchy.screensaver` in toggle-off (kills running screensaver immediately).
- Keep the `screensaver-off` check in `omarchy-launch-screensaver` (it's a separate toggle for screensaver-only disable, used by `omarchy-toggle-screensaver`).

Wait — there are TWO separate toggles:
1. `omarchy-toggle-idle` (Super+Ctrl+I) — should disable ALL idle actions (screensaver + lock + dpms)
2. `omarchy-toggle-screensaver` — should disable ONLY the screensaver (lock still fires)

For #1: use `$HOME/.local/state/omarchy/toggles/idle-off` flag
For #2: use `$HOME/.local/state/omarchy/toggles/screensaver-off` flag (already exists, already checked in `omarchy-launch-screensaver`)

The `idle-off` flag blocks ALL on-timeout commands. The `screensaver-off` flag blocks only the screensaver launch (checked in `omarchy-launch-screensaver`). These are independent.

**IMPORTANT**: The screensaver-off flag does NOT need to be checked in hypridle on-timeout. It's checked inside `omarchy-launch-screensaver` (line 19). For toggle-idle, we use idle-off which blocks everything at the hypridle level.

---

## KNOWN ISSUES FROM THIS SESSION

### Issue 1 — systemctl was wrong mechanism
Stopping hypridle to disable idle breaks because Restart=always restarts it. **Do not use systemctl for toggle.**

### Issue 2 — ExecStartPre clears flag on every restart
With Restart=always, ExecStartPre runs every 10 seconds after a toggle stop. **Do not rely on ExecStartPre for toggle flags.**

### Issue 3 — Multiple flag files create confusion
We have `screensaver-off` (screensaver-only toggle) and need `idle-off` (full idle toggle). These are SEPARATE toggles with SEPARATE flags. Don't merge them.

---

## RELEVANT CONTEXT FILES (READ THESE)

- `omarchy-nix/bin/omarchy-toggle-idle` (19 lines) — current toggle script
- `omarchy-nix/bin/omarchy-launch-screensaver` (54 lines) — multi-monitor screensaver launcher (FIXED)
- `omarchy-nix/bin/omarchy-screensaver` (40 lines) — inner screensaver (FIXED)
- `omarchy-nix/bin/omarchy-toggle-screensaver` — separate screensaver-only toggle (leave alone)
- `omarchy-nix/modules/home-manager/hypridle.nix` (42 lines) — upstream hypridle defaults
- `hosts/t14/home/omarchy.nix` (lines 144-170) — T14 hypridle overrides
- `hosts/t14/default.nix` — T14 host entry
- `hosts/t14/home/hypr/monitors.nix` — workspace rules, DO NOT TOUCH
- `docs/t14-monitor-layout.md` — monitor layout reference
- `omarchy-nix/modules/home-manager/hyprland/bindings.nix` — keybinding: SUPER CTRL, I
- `omarchy-nix/default/hypr/apps/system.conf` — window rules (fullscreen on, float on for screensaver)
- `openspec/changes/fix-screensaver-idle-lock/exploration.md` — initial exploration
- `openspec/changes/fix-screensaver-idle-lock/upstream-comparison.md` — upstream basecamp/omarchy comparison
- `openspec/changes/fix-screensaver-idle-lock/deep-exploration.md` — deep exploration that found exec-rule fix
- `openspec/changes/fix-screensaver-idle-lock/specs/` — delta specs
- `openspec/changes/fix-screensaver-idle-lock/design.md` — design doc
- `openspec/changes/fix-screensaver-idle-lock/proposal.md` — proposal doc
- Engram: `sdd/fix-screensaver-idle-lock/explore` — all exploration artifacts
- Engram: `sdd/fix-screensaver-idle-lock/bugfix-flag-persistence` — stale flag bugfix
- Engram: `sdd/fix-screensaver-idle-lock/bugfix-multi-monitor-race` — multi-monitor race
- Engram: session summary for this session (contains full timeline of changes)
