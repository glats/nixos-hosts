# Exploration: t14-hyprctl-reload-causes-resets-on-workspace-switch

> **Change**: `t14-hyprctl-reload-causes-resets-on-workspace-switch` (t14 / Omarchy / Hyprland)
> **Repo**: `/home/glats/.nixos`
> **Date**: 2026-06-30 (second pass — waybar-crash hypothesis)
> **SDD mode**: hybrid (Engram + filesystem)
> **Predecessor work**: prior explore at `sdd/t14-hyprctl-reload-causes-resets-on-workspace-switch/explore`
> (Engram #439), session log `session-ses_0e9e.md`

## Goal

Eliminate Hyprland resets on the T14. The user confirmed in this second pass that
**waybar is actually crashing and restarting** ("waybar disappears and reappears"),
not just flickering. This changes the diagnostic significantly: the root cause may be
**waybar segfaulting on Hyprland 0.55 IPC events**, not just `hyprctl reload` churn.

## New Critical Signal (from user)

> "when the reset happens, waybar disappears and reappears — it's actually restarting
> (crashing), not just a surface flicker."

This rules out "just an animation/surface flicker" and points to a **real process
restart**. Combined with the waybar GitHub issues found in this pass, the most likely
cause is **waybar's `hyprland/workspaces` module segfaulting on Hyprland 0.55** when
certain IPC events fire (workspace destruction, monitor changes, or
`monitoradded>>`/`monitorremoved>>` events).

## Current State

### Waybar configuration (full picture, first time investigated)

| Item | Value | Source |
|---|---|---|
| Package | `waybar 0.15.0` (nixpkgs `0.2511.909248`, pinned in `flake.lock`) | `nixos_nix info waybar` |
| Launch | `exec-once = [ "pkill -x waybar; uwsm-app -- waybar" ]` (Hyprland autostart) | `omarchy-nix/modules/home-manager/hyprland/autostart.nix:14` |
| Process wrapper | `uwsm-app` runs as `systemd-run --user --scope` (transient scope unit) | `uwsm/main.py: app()` function calls `systemd-run --user --scope` |
| Restart policy | **None** — transient scope units default to `Restart=no`. If waybar crashes, it does NOT auto-restart. | systemd transient scope semantics |
| Config source | Static file via `omarchy-nix/config/waybar/config` (200 lines JSON) | `omarchy-nix/modules/home-manager/waybar.nix:10-14` |
| Style | `omarchy-nix/config/waybar/style.css` (100 lines) | same |
| Config deployed to | `~/.config/waybar/config` (managed by `home.file."waybar/"`) | `home-manager-files` symlinks |
| Theme | Symlinked to `$HOME/.config/omarchy/current/theme/waybar.css` | `waybar.nix:17` |
| Font | `Source Sans 3 Semibold` (overridden in `t14/home/omarchy.nix:106`) | same |

### Waybar modules in use (`omarchy-nix/config/waybar/config`)

| Module | Source | Why it matters |
|---|---|---|
| `hyprland/workspaces` (modules-left) | built-in | **THE PRIMARY CRASH SUSPECT** — known SIGSEGV with Hyprland 0.55 |
| `custom/omarchy` (modules-left) | inline | static icon, no IPC |
| `clock` (center) | built-in | safe |
| `custom/update` (center) | inline | runs `omarchy-update-available` every 6h |
| `custom/voxtype` (center) | inline | runs `omarchy-voxtype-status` (JSON, on event) |
| `custom/screenrecording-indicator` | inline | polls `pgrep gpu-screen-recorder` |
| `custom/idle-indicator` | inline | polls `pgrep hypridle` |
| `custom/notification-silencing-indicator` | inline | polls `makoctl mode` |
| `group/tray-expander` (right) | built-in | hosts `tray` |
| `tray` | built-in | standard tray |
| `bluetooth`, `network`, `custom/iwd-wifi` | mixed | network: waybar built-in; iwd-wifi: runs `iwctl station wlan0 show` (potentially slow script) |
| `pulseaudio` | built-in | safe |
| `custom/language` | inline | runs `kb-layout.sh` every 2s |
| `cpu`, `battery` | built-in | safe |

### Waybar `hyprland/workspaces` config details (THE CRITICAL MODULE)

```jsonc
"hyprland/workspaces": {
  "on-click": "activate",
  "format": "{icon}",
  "format-icons": { "default": "..." /* 20 letters */ },
  "persistent-workspaces": {
    "1": [], "2": [], "3": [], "4": [], "5": []
  }
}
```

No `window-rewrite` (issue #4451 freeze bug), no `move-to-monitor`, no special
workspaces. This is the **minimal/safe config** for the module. The known
SIGSEGV issues (#4361, #4357) still apply even with this minimal config because
the crash is in the IPC handler / GTK layer, not the format string.

### Waybar launch chain (mechanism for "disappears and reappears")

1. Hyprland `exec-once` runs at startup:
   `pkill -x waybar; uwsm-app -- waybar`
2. `uwsm-app` calls `systemd-run --user --scope` to launch waybar as a transient scope unit.
3. If waybar segfaults → scope unit exits with failure → scope is gone.
4. **No auto-restart** on transient scope units by default.
5. So if waybar crashes, it stays gone... unless something else restarts it.

**The mystery**: the user sees waybar "reappear" after it disappears. If systemd
scope units don't auto-restart, what is restarting it? Candidates:

- `omarchy-toggle-waybar` script (uses `pkill -f "waybar" || uwsm-app -- waybar`)
  — but the user would notice a manual toggle.
- A Hyprland event handler that re-runs exec-once. `hyprctl reload` does NOT
  re-run exec-once (exec-once runs once per Hyprland instance), but if Hyprland
  itself is fully restarting (not just reload), exec-once would re-run.
- The systemd `graphical-session.target` watch that uwsm uses — but again, uwsm
  would not auto-restart a scope.

**Hypothesis**: when waybar segfaults, Hyprland's surface for waybar is also
destroyed, and the visual "reappear" is Hyprland re-creating the layer-shell
surface. OR, the `omarchy-toggle-waybar` pattern is being triggered by some
Hyprland event (e.g., Super+Shift+Space binding via `omarchy-toggle-waybar`).

This is a **DIAGNOSTIC QUESTION** to ask the user: "after the reset, does
`ps aux | grep waybar` show the SAME PID or a NEW PID? If same PID = layer-shell
re-render only; if new PID = waybar actually restarted."

### Waybar crash mechanism — strong evidence from upstream

Web search confirmed waybar has **known SIGSEGV crashes with Hyprland 0.55**:

| Issue | Title | Status | Relevance |
|---|---|---|---|
| [#4361](https://github.com/Alexays/Waybar/issues/4361) | "Sometimes, waybar crashes when reconnecting a docking station (with 2 monitors) in Hyprland" | **Confirmed in v0.15.0 (Apr 2026)** | DIRECT MATCH — dock/undock cycle crashes waybar. User has 3 externals + eDP-1 (4 monitors) |
| [#4357](https://github.com/Alexays/Waybar/issues/4357) | "Waybar crashed with log 'terminated by signal SIGSEGV'" | Aug 2025 | Comment: "Removing hyprland workspaces appears to have fixed it" |
| [#5008](https://github.com/Alexays/Waybar/issues/5008) | "hyprland/workspaces: old-style workspace dispatch fails on Hyprland Lua dispatcher builds" | Apr 2026 | Old-style `dispatch workspace` calls don't work with Hyprland 0.55. Fix in PR #5103, not yet released |
| [#5035](https://github.com/Alexays/Waybar/issues/5035) | "Hyprland (lua) 0.55v workspace buttons not working" | May 2026 | Same root cause: Hyprland 0.55 dispatcher syntax change. Waybar 0.15.0 still affected |
| #4451 | "hyprland/workspaces and hyprland/window become frozen" | Open | `window-rewrite` freeze — NOT in user's config, not relevant |
| [#2945](https://github.com/Alexays/Waybar/issues/2945) | "Persistent workspace disappear after being active" | Open | When persistent workspace is destroyed by Hyprland, waybar doesn't re-add it |

**PR #5103** in waybar fixes the Lua dispatcher issue. Not yet in v0.15.0 release.
Requires building from source or waiting for next release.

### IPC event flow on the t14

1. User presses Super+1/2/3 → `hyprland.conf` line 305-307: `bindd = SUPER, code:10, Switch to workspace 1, workspace, 1`
2. Hyprland dispatches workspace change → emits IPC event `workspace>>N`
3. waybar's `hyprland/workspaces` module subscribes to `socket2` and receives the event
4. waybar updates the UI (active workspace highlight)
5. **If the workspace being switched to has a hybrid/invalid rule** (the dual binding):
   - Hyprland may emit `workspacev2>>id,name,monitor` with `monitor = ""` (empty because the merged monitor is "AOC" which doesn't exist when undocked)
   - waybar receives this and tries to query workspace info from Hyprland's workspace object
   - If the workspace is destroyed (per `hyprctl dispatch workspace 2` returning "Previous workspace doesn't exist" in the session log), waybar's IPC handler may segfault
6. This explains why the user sees waybar disappear and reappear

### Workspace rule merge behavior (from prior pass — still relevant)

Hyprland 0.55's `mergeLeft` (PR #14217, April 2026, `CWorkspaceRule::mergeLeft`)
creates hybrid rules when two `workspace = N, monitor:X` rules conflict:

| Source | Workspace 1 binding |
|---|---|
| `mkWorkspaceRules` (unconditional) | `1, monitor:desc:AOC 24P1W1 OTNQ4HA000101, default:true, persistent:false` |
| `extraConfig` (when lid open) | `1, monitor:eDP-1, default:true, persistent:true` |
| **Merged result** (empirically observed in `session-ses_0e9e.md`) | `monitor: AOC 24P1W1, default:true, persistent:true` |

When the user is **docked + lid open**, both AOC externals and eDP-1 exist, so
the hybrid monitor "AOC 24P1W1" is valid. But when the user is **docked + lid
closed** (or undocked), the AOC monitor doesn't exist or the user wants workspace
1 on eDP-1 — switching to workspace 1 creates an inconsistent state.

The merged rule's `monitor: AOC` may not match the actual focus → Hyprland
emits a `destroyworkspace>>` event when the workspace fails to find its monitor →
waybar's `hyprland/workspaces` module tries to handle the destroyed workspace
event and segfaults.

### Affected areas (full)

| File | Line(s) | What it does | Why it matters |
|---|---|---|---|
| `omarchy-nix/config/waybar/config` | 19-53 | `hyprland/workspaces` module config | **The module that crashes**. Has `persistent-workspaces: 1-5`. |
| `omarchy-nix/modules/home-manager/waybar.nix` | 1-31 | waybar home-manager module | Deploys config to `~/.config/waybar/`, sets theme symlink |
| `omarchy-nix/modules/home-manager/hyprland/autostart.nix` | 14 | `pkill -x waybar; uwsm-app -- waybar` | exec-once. If Hyprland restarts, waybar restarts. If waybar crashes mid-session, nothing restarts it. |
| `omarchy-nix/modules/home-manager/hyprland/autostart.nix` | 24 | `pkill -SIGUSR2 waybar` | Theme switch. Not a kill, just signal. |
| `omarchy-nix/bin/omarchy-toggle-waybar` | 6-11 | `pkill -f waybar \|\| uwsm-app -- waybar` | Manual toggle. If the user accidentally hits Super+Shift+Space, this restarts waybar. **Could be the "reappear" mechanism**. |
| `omarchy-nix/bin/omarchy-hyprland-monitor-watch` | 9-11 | `monitoradded>>` → `hyprctl reload` | On dock, causes a reload. Reload may emit config-changed events that waybar's IPC handler stumbles on. **This is a reload source we can remove**. |
| `omarchy-nix/modules/home-manager/theme-switcher.nix` | 71 | `${pkgs.hyprland}/bin/hyprctl reload` | On theme switch, reloads Hyprland. Could cause waybar crash if a theme change happens during a workspace switch. |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | 47 | `hyprctl reload` | On every 2s snapshot diff, reloads. Reload may cause waybar to crash. **This is a reload source we can remove**. |
| `hosts/t14/home/hypr/monitors.nix` | 16-30, 56-58 | dual-binding workspace rules | The cause of inconsistent workspace state. **This is the workspace binding problem we can fix**. |

### Diagnostic instrumentation plan

If the fix attempt doesn't fully resolve, the user can capture waybar's stderr
to confirm the crash hypothesis:

1. **Waybar stderr capture** — wrap `exec-once` to redirect waybar stderr to a file:
   ```nix
   # In autostart.nix, change:
   "pkill -x waybar; uwsm-app -- waybar"
   # To:
   "pkill -x waybar; uwsm-app -- bash -c 'exec waybar 2>>$HOME/.cache/waybar-stderr.log'"
   ```
   This captures segfault messages. Then `tail -f ~/.cache/waybar-stderr.log`
   while switching workspaces. If waybar is crashing, the log will show
   `Gdk-Message: Error flushing display: Invalid argument` followed by SIGSEGV.

2. **Hyprland trace logging** — `HYPRLAND_TRACE=1` env var on Hyprland launch
   gives verbose IPC logs. Combined with the waybar stderr, you can correlate
   which IPC event kills waybar.

3. **Waybar PID monitoring** — `watch -n 0.2 'pgrep waybar'` to see if the PID
   actually changes on reset. If yes = real restart = waybar crashed. If no =
   just layer-shell surface recreation = not a crash.

4. **Hyprland IPC event monitoring** — `socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`
   in a separate terminal to see ALL events as they fire. If you see
   `destroyworkspace>>N` immediately before waybar crashes, you've found it.

5. **Waybar core dump** — `ulimit -c unlimited; echo '/tmp/core.%e.%p' > /proc/sys/kernel/core_pattern`
   then run waybar directly (not via uwsm-app) in a terminal. On crash, core
   dump at `/tmp/core.waybar.PID` → `gdb waybar /tmp/core.waybar.PID` for
   backtrace. Confirms the exact crash site (likely in `src/modules/hyprland/workspace.cpp`).

### Approaches

| # | Approach | Description | Fixes reload? | Fixes dual binding? | Fixes waybar crash? | Risk |
|---|---|---|---|---|---|---|
| 1 | Remove `hyprctl reload` from validator `apply()` | 1-line change to `monitor-lid-validator.sh:47`. Eliminates one reload source. | ✓ (one source) | ✗ | Maybe (reduces monitor events that trigger IPC crash) | Low (prior session confirmed: insufficient on its own) |
| 2 | Approach 1 + filter workspaces 1-3 from `mkWorkspaceRules` | 1-line change to `monitors.nix` workspace lists. Eliminates dual binding. | ✓ (one source) | ✓ | Maybe (eliminates inconsistent workspace state) | Low (prior session: empirically tested with reload, was inconclusive) |
| 3 | Approach 2 + remove `monitoradded>>` reload from `omarchy-hyprland-monitor-watch` | Cross-repo change. Eliminates ALL known reload sources. | ✓ (all sources) | ✓ | Maybe | Low (user-owned repo) |
| 4 | Approach 3 + add waybar stderr capture wrapper | 1-line change to `autostart.nix:14`. Captures crash logs. | ✓ | ✓ | Diagnostic only | Very low |
| 5 | Approach 3 + switch waybar to `ext/workspaces` module | Replace `hyprland/workspaces` with `ext/workspaces` in waybar config. Uses wlr protocol instead of hyprland IPC. | ✓ | ✓ | **Probably ✓** (sidesteps the buggy Hyprland IPC path entirely) | Medium (loses special-workspace support, but user doesn't use special workspaces) |
| 6 | Approach 3 + add waybar systemd-managed service with `Restart=on-failure` | Replace exec-once with a home-manager `systemd.user.services.waybar` that has `Restart=always`. Restarts waybar quickly when it crashes. | ✓ | ✓ | Partially (reduces visible reset duration, but doesn't prevent crash) | Low (logs go to journal, easier to diagnose) |
| 7 | Approach 3 + rebuild waybar from git (PR #5103) | Override nixpkgs waybar with a `pkgs.waybar.override` or build from source. Includes the Hyprland 0.55 Lua dispatcher fix. | ✓ | ✓ | **Probably ✓** (the actual upstream fix) | Medium (build complexity, version drift) |
| 8 | Approach 3 + disable waybar's `hyprland/workspaces` module entirely (use static icons) | Comment out the module in waybar config. Loses workspace indicator. | ✓ | ✓ | ✓ (no module = no crash) | High (degraded UX) |

### Recommendation

**Approach 3 + Approach 4 (one combined change with diagnostics enabled).**

**Reasoning**:

1. The two confirmed reload sources (validator + omarchy monitor-watch) are real
   contributors to monitor IPC events that may crash waybar's `hyprland/workspaces`
   module. Removing them reduces the trigger surface.
2. The dual-binding workspace conflict is real and produces inconsistent workspace
   state that may trigger workspace-destroyed IPC events, which is a known
   waybar crash pattern (issue #2945).
3. With these three changes (Approach 3), we eliminate the two identified
   reload sources AND the dual binding. If waybar still crashes, the cause is
   pure waybar/Hyprland 0.55 incompatibility and we need approach 5, 6, or 7.
4. The waybar stderr capture (Approach 4) is one extra line in autostart.nix
   that costs nothing and gives the user a tool to confirm/refute the crash
   hypothesis if resets persist.

**What we are NOT recommending** (and why):
- Approach 5 (switch to `ext/workspaces`): works but degrades waybar's
  workspace handling (loses per-monitor workspace detection, no special
  workspace support). Defer to fallback if Approach 3+4 doesn't fix.
- Approach 6 (systemd Restart=always): makes crashes invisible but doesn't
  fix them. The user wants the root cause fixed, not a band-aid.
- Approach 7 (rebuild from git): best long-term but adds nixpkgs overlay
  complexity. Defer to fallback.
- Approach 8 (disable module): unacceptable UX regression.

**Concrete change set**:

1. `hosts/t14/home/scripts/monitor-lid-validator.sh`: remove `hyprctl reload`
   from `apply()` (re-apply commit `ec366fb`).
2. `hosts/t14/home/hypr/monitors.nix`: add `builtins.filter (w: w > 3)` to the
   `mkWorkspaceRules` workspace lists.
3. `omarchy-nix/bin/omarchy-hyprland-monitor-watch`: remove
   `monitoradded>>` → `hyprctl reload` branch. Replace with a no-op (the
   `omarchy-hyprland-monitor-internal recover` pattern from the
   `monitorremoved>>` branch is more appropriate for `monitoradded>>` too).
4. `omarchy-nix/modules/home-manager/hyprland/autostart.nix:14`: change
   `pkill -x waybar; uwsm-app -- waybar` to
   `pkill -x waybar; uwsm-app -- bash -c 'exec waybar 2>>$HOME/.cache/waybar-stderr.log'`
   so waybar's stderr (including any segfault messages) is captured.

**Optional follow-up** (if resets persist after above):
- Approach 5: switch to `ext/workspaces` in waybar config
- Approach 7: rebuild waybar with PR #5103 (or pin nixpkgs to a waybar version
  that includes the fix when released)

### Critical diagnostic questions for the user

Before applying the fix, the user should run these commands to confirm the
hypothesis (low cost, high information):

```bash
# 1. Watch waybar's PID — if it changes, waybar actually restarted
watch -n 0.2 'pgrep -a waybar'

# 2. Capture waybar stderr going forward
echo "" > ~/.cache/waybar-stderr.log
# (then in another terminal, switch workspaces and watch for crashes)
tail -f ~/.cache/waybar-stderr.log

# 3. Watch all Hyprland IPC events
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock
```

**Two-minute test**: If the user can run the watch commands and reproduce the
reset, we can definitively say "waybar's PID changes on reset" (crash confirmed)
or "waybar's PID stays the same" (surface recreation only). This data point is
invaluable for the next phase.

### Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Waybar crash is triggered by something OTHER than reloads/dual-binding (e.g., `omarchy-hyprland-workspace-layout-toggle` Super+L, or some other event) | Medium | Diagnostic instrumentation (Approach 4) will reveal. If crash log shows crash is not IPC-related, escalate to Approach 5/7. |
| The user finds the `ext/workspaces` workaround insufficient and we end up doing Approach 7 anyway | Medium | Approach 7 is a follow-up if Approach 3+4 doesn't fully resolve. The infrastructure (capture, filter) is reusable. |
| Removing the `monitoradded>>` reload breaks other omarchy features that depend on the reload (e.g., theme refresh) | Low | The reload was only added recently (commit `a8fbfca` in user's owned repo). The theme refresh is on a separate event. Monitor layout is handled by the polling daemon. |
| The user doesn't want a second `~/.cache/waybar-stderr.log` file | Low | The log rotates by simple append; user can `rm` it. Or we can use `truncate -s 0` at startup. |
| Resets persist because waybar has a second, unrelated bug in `custom/iwd-wifi` or `custom/language` script (exec interval 2s) | Low | Those scripts are simple and well-tested. But if waybar stderr shows non-IPC crash, investigate those. |

## Ready for Proposal

**Yes** — Approach 3 + Approach 4 is a well-scoped, low-risk fix that:
- Eliminates the two confirmed reload sources
- Fixes the dual-binding workspace conflict
- Adds waybar stderr capture for diagnostic continuity
- Has a clear fallback (Approach 5 or 7) if crashes persist

The orchestrator should communicate to the user that:
- The "waybar disappears and reappears" pattern is consistent with a known
  waybar SIGSEGV bug (issue #4361, #4357) on `hyprland/workspaces` with
  Hyprland 0.55.
- The two reload sources and the dual binding are confirmed contributors.
- Applying the fix gives the user a waybar stderr log that will definitively
  confirm the crash on the next reproduction.
- If the fix is insufficient, the fallback (switch to `ext/workspaces` or
  rebuild waybar from git) is ready.

The orchestrator should also recommend that the user runs the diagnostic
commands (PID watch + stderr capture) BEFORE applying the fix, to gather the
"waybar PID changes on reset" evidence. This is 30 seconds of work and
provides certainty for the next phase.

## Next Steps

- `sdd-propose` with the four-change scope (Approach 3+4)
- If user wants diagnostic first: stay in explore, ask user to run diagnostic
  commands, then come back with confirmed data.

## Relevant Files

- `hosts/t14/home/scripts/monitor-lid-validator.sh:47` — `hyprctl reload` in `apply()`
- `hosts/t14/home/hypr/monitors.nix:16-30, 56-58` — dual binding
- `omarchy-nix/bin/omarchy-hyprland-monitor-watch:9-11` — `monitoradded>>` reload
- `omarchy-nix/modules/home-manager/hyprland/autostart.nix:14` — waybar exec-once
- `omarchy-nix/config/waybar/config:19-53` — `hyprland/workspaces` module (crash suspect)
- `omarchy-nix/modules/home-manager/waybar.nix:1-31` — waybar home-manager module
- `omarchy-nix/bin/omarchy-toggle-waybar:6-11` — possible "reappear" mechanism
- `openspec/changes/t14-hyprctl-reload-causes-resets-on-workspace-switch/proposal.md`
  (existing) — needs update to add stderr capture + waybar-crash context
- `session-ses_0e9e.md:1180-1310, 2300-2400` — prior waybar investigation notes
- Web: GitHub issues #4361, #4357, #5008, #5035, PR #5103, #4451, #2945
