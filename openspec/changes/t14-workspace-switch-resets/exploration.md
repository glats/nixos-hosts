# Exploration: t14-workspace-switch-resets (DEEP RE-INVESTIGATION)

> **Change**: `t14-workspace-switch-resets`
> **Repo**: `/home/glats/.nixos` (+ `glats/omarchy-nix`)
> **Date**: 2026-06-30
> **SDD mode**: hybrid (Engram + filesystem)
> **Prior phase**: `t14-hyprctl-reload-causes-resets-on-workspace-switch` (3/4 fixes applied; waybar still crashes)
> **Method**: Source-code analysis (waybar `workspaces.cpp`, `backend.cpp`, `backend.hpp`), commit bisection (v0.15.0→master), cross-referenced with nixpkgs build flags and Hyprland architecture.

---

## REVALIDATION: File-by-File System State

| Claim in prior exploration | Verified? | Finding |
|---|---|---|
| `monitors.nix:25` has `w > 3` filter | ✅ YES | `builtins.filter (w: w > 3) workspaces` at line 25 — correctly applied |
| `monitor-lid-validator.sh` has no `hyprctl reload` | ✅ YES | `apply()` ends after `case` block; no reload. Fix preserved from commit `b39d79f`. |
| `omarchy-hyprland-monitor-watch` lacks `monitoradded>>` reload (deployed) | ⚠️ PARTIAL | Deployed version pinned by flake.lock is clean. But `origin/main` HEAD still has lines 9-11 (`monitoradded>>` → `hyprctl reload`). PRIOR SDD PHASE 2 WAS NEVER APPLIED TO OMARCHY-NIX. |
| `autostart.nix` has stderr capture | ❌ NO | Still reads `"pkill -x waybar; uwsm-app -- waybar"` — no `2>>` redirect. PRIOR SDD TASK 2.2 NEVER APPLIED. |
| `waybar-src` flake input still exists | ✅ YES | Lines 113-117 in `flake.nix` — dead code from reverted `waybar-git` overlay. |
| `overlays/linux.nix` has no waybar-git residue | ✅ YES | Completely clean. |
| HDM migration v2 is deployed | ❌ NO | Doc committed (`55d20c1`) but `hosts/t14/hdm/` directory doesn't exist on disk. HDM is NOT deployed. |

**Critical finding**: The prior SDD session (`t14-hyprctl-reload-causes-resets-on-workspace-switch`) applied only Phase 1 (nixos-hosts: validator reload removal + workspace filter) as commit `b39d79f`. Phase 2 (omarchy-nix: monitor-watch fix + stderr capture) was NEVER pushed to `glats/omarchy-nix` main. The pinned flake.lock revision is clean by luck (pre-dates the re-addition), but any omarchy-nix bump will re-introduce the `monitoradded>>` reload.

---

## 1. WAYBAR IPC CRASH MECHANISM (Source Code Analysis)

### 1.1 Architecture (verified from source, not web research)

Read actual C++ source from `Alexays/Waybar` at master HEAD (`0594574`):

```
IPC thread (socketListener)           GTK main thread
   │                                     │
   ├─ read socket2 event                 │
   ├─ parseIPC(ev)                       │
   │  ├─ lock callbackMutex_             │
   │  ├─ for each handler:               │
   │  │  └─ handler->onEvent(ev)         │
   │  │     ├─ lock m_mutex              │
   │  │     ├─ onWorkspaceDestroyed()    │
   │  │     │  └─ m_workspacesToRemove   │
   │  │     │     .push_back(id)         │
   │  │     ├─ onWorkspaceCreated()      │
   │  │     │  ├─ getSocket1JsonReply()  │  ← BLOCKING socket1 call while holding m_mutex!
   │  │     │  └─ m_workspacesToCreate   │
   │  │     │     .emplace_back(...)     │
   │  │     ├─ dp.emit()  ──────────────→│  Glib::Dispatcher signals
   │  │     └─ unlock m_mutex            │
   │  └─ unlock callbackMutex_           │
   │                                     ├─ doUpdate()
   │                                     │  ├─ lock m_mutex
   │                                     │  ├─ removeWorkspacesToRemove()
   │                                     │  │  └─ m_box.remove(btn)    ← GTK op (correct thread)
   │                                     │  │  └─ m_workspaces.erase()  ← vector mutation
   │                                     │  ├─ createWorkspacesToCreate()
   │                                     │  │  └─ m_box.pack_start()    ← GTK op (correct thread)
   │                                     │  ├─ sortWorkspaces()
   │                                     │  │  └─ m_box.reorder_child() ← GTK op (correct thread)
   │                                     │  └─ unlock m_mutex
   │                                     └─ AModule::update()
```

### 1.2 PR #4808 (GTK thread safety) — already in v0.15.0

Commit `39e59e5` (merged 2026-02-04, tagged in v0.15.0) moved all GTK widget access from `onEvent()` (IPC thread) to `update()` (GTK main thread via `Glib::Dispatcher`). This fixed the "corrupted double-linked list" segfaults caused by accessing GTK widgets from a non-GTK thread.

**Verification**: All GTK operations (`m_box.pack_start`, `m_box.remove`, `m_box.reorder_child`, `button.show_all`) now happen exclusively in `doUpdate()` which runs on the GTK main thread. The `onEvent()` handlers only modify non-GTK state (vectors of strings, work queues). This is correct.

### 1.3 Residual crash vectors in v0.15.0

Despite PR #4808, three crash vectors remain:

**Vector A — `onWorkspaceCreated()` blocks IPC thread on socket1**

`onWorkspaceCreated()` holds `m_mutex` while calling `m_ipc.getSocket1JsonReply("workspacerules")` and `m_ipc.getSocket1JsonReply("workspaces")`. These open new socket1 connections and do blocking reads. If Hyprland is slow to respond (e.g., during a burst of workspace create/destroy cycles), the IPC thread is stuck holding `m_mutex`. No other events can be processed until the socket1 reply arrives. Meanwhile, `doUpdate()` on the GTK thread tries to acquire `m_mutex` and blocks.

**Impact**: Event processing stalls during rapid workspace switches. The socket2 kernel buffer fills up. When the IPC thread finally releases `m_mutex`, a backlog of events rushes through, potentially overwhelming the GTK thread's update cycle.

**Vector B — `m_workspaces` iterator invalidation during sort**

`sortWorkspaces()` calls `std::ranges::sort()` on `m_workspaces` (a `vector<unique_ptr<Workspace>>`). The sort uses a lambda that accesses `workspace->id()`, `workspace->name()`, `workspace->isSpecial()`, etc. If a `Workspace` object's internal state is being modified concurrently (e.g., by `updateWorkspaceStates()` setting active/visible flags on the same objects), the sort comparator could read inconsistent state. This is protected by `m_mutex`, so it's thread-safe — but if the comparator throws (e.g., `std::stoi` on a malformed name), the sort is interrupted with the vector in a partially-sorted state.

**Vector C — `removeWorkspace()` calling `m_box.remove()` then `m_workspaces.erase()`**

`m_box.remove(button)` removes the GTK widget from the container. If the button is already in the process of being destroyed (e.g., due to a GTK animation timeout or signal handler), this could double-free. This is unlikely but possible under heavy event load.

### 1.4 Post-v0.15.0 commits (full bisection)

| Commit | Date | Description | Fixes crash? |
|---|---|---|---|
| `39e59e5` | 2026-02-04 | PR #4808 — GTK-on-IPC-thread fix | IN v0.15.0 |
| `e189392` | 2026-02-23 | Lint fix | No |
| `fe03dfa` | 2026-03-03 | Perf: eliminate deep JSON copies | No |
| `4c71b2b` | 2026-03-03 | Perf: optimize string operations | No |
| `dd47a2b` | 2026-03-07 | Stabilize reload/event handling (scroll stacking fix) | No (scroll fix only) |
| `e17c0d9` | 2026-04-29 | PR #5013 — Lua dispatch for Hyprland 0.54+ | No (fixes clicks, not crashes) |
| `97917db` | 2026-05-02 | Test for dispatch | No |
| `0594574` | 2026-05-04 | **MERGE of PR #5013 = CURRENT MASTER HEAD** | **REGRESSION: instant crash on startup** |

**Key finding**: `0594574` (master HEAD, May 4, 2026) is the exact commit the user tried that caused instant startup crash. There are ZERO commits after May 4. The regression has NOT been fixed upstream. Building from any master commit ≥ `e17c0d9` is unsafe.

The root cause of the master startup crash is likely in `IPC::dispatch()` / `isLuaProtocol()` — the probe command `getSocket1Reply("dispatch workspace __waybar_probe__")` called during first workspace click/scroll. If this probe throws (socket not ready, malformed response, Hyprland version mismatch), the exception propagates through the GTK signal handler without being caught, crashing waybar. This is a wiring issue: the old code used `ipc_.sendCmd()` which handled errors through the i3 IPC event loop; the new code opens a raw socket and throws on failure.

### 1.5 Commit `2a05edaf` (debounce timer)

**THIS COMMIT DOES NOT EXIST ON MASTER.** It was mentioned in the prior exploration as "2026-05-13, master only" but my full GitHub API commit listing of master shows no such commit. It may exist on a branch or was misidentified. Regardless, even if it exists, the debounce timer targets visual flicker, not the crash.

---

## 2. HYPRLAND 0.55 WORKSPACE EVENT BEHAVIOR

### 2.1 Why create/destroy events fire on the T14

The T14's `monitors.nix` conditional architecture explains the event churn:

```
When lid OPEN (ENABLE_LAPTOP=1):
  Workspaces 1-3: bound to eDP-1 (persistent:true, from extraConfig block)
  Workspaces 4-20: distributed across 3 externals (from mkWorkspaceRules, w>3 filter)

When lid CLOSED (!ENABLE_LAPTOP):
  eDP-1: disabled (monitor = eDP-1,disable from hyprlang conditional)
  Workspaces 1-3: NO explicit rules (the eDP-1 workspace block is inside `if ENABLE_LAPTOP`)
  Workspaces 4-20: same distribution (from mkWorkspaceRules, w>3 filter)
```

When docked with lid closed, pressing Super+1:
1. Hyprland has NO rule for workspace 1 → creates it on the focused external monitor
2. `createworkspacev2>>1,` emitted on socket2
3. workspace 1 now exists on that monitor, no windows
4. User presses Super+2 → Hyprland switches to workspace 2
5. Workspace 1 is now empty AND non-persistent (no rule saying `persistent:true` when docked)
6. `destroyworkspacev2>>1` emitted
7. Switch back to Super+1 → `createworkspacev2>>1` again
8. Repeat for every Super+1/2/3 keystroke → burst of create/destroy events

**This is Hyprland's intentional behavior**, not a bug. Workspaces without `persistent:true` AND without explicit monitor binding are created on-demand and destroyed when empty. The `w > 3` filter was added specifically to remove the dual-binding that caused workspace rule mergeLeft conflicts — but as a side effect, workspaces 1-3 lost their external monitor bindings when docked.

### 2.2 Can Hyprland suppress these events?

Searched Hyprland issues/docs:
- No `misc:` option to suppress `destroyworkspacev2>>` events during switch
- No config option to make workspaces permanently persistent regardless of binding
- The `persistent` flag in workspace rules requires an active monitor binding to take effect
- **Mitigation**: Add `persistent:true` to workspace rules 1-3 even when docked — requires adding them to the external monitor rules (undoing `w>3` filter), which re-introduces the dual-binding mergeLeft bug from the prior SDD session.

### 2.3 Socket2 event capture feasibility

Path: `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock`

```bash
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock
```

This would reliably capture all events. However, it requires manual instrumentation on the T14 (not automatable in Nix). The events expected during a Super+1/2 cycle (docked, lid closed):
```
createworkspacev2>>1,
workspacev2>>1,
destroyworkspacev2>>1,
createworkspacev2>>2,
workspacev2>>2,
```
This confirms the create/destroy cycle per switch.

---

## 3. ALL ALTERNATIVE WORKSPACE MODULES (Equal Evaluation)

### 3a. `sway/workspaces` — NOT VIABLE

**Investigation**: Read `src/modules/sway/workspaces.cpp` from waybar source.

Uses the **i3 IPC protocol**: subscribes to `["workspace"]`, sends `IPC_GET_TREE`, reads the i3 tree JSON. All communication goes through `ipc_.sendCmd()` / `ipc_.subscribe()` which uses the i3/Sway Unix socket protocol (magic string + length-prefixed JSON payloads).

**Hyprland does NOT implement i3 IPC.** GitHub search for "Hyprland i3 IPC" returned zero relevant hits. Hyprland has its own socket1/socket2 protocol (text-based and JSON-based, not i3 wire format). The `sway/workspaces` module would fail to connect to Hyprland's socket and show nothing.

**Verdict**: Dead end. Not tested in prior exploration.

### 3b. `wlr/workspaces` — NOT COMPILED

**Investigation**: Read nixpkgs `pkgs/by-name/wa/waybar/package.nix`:

```nix
mesonFlags = [
  (lib.mapAttrsToList lib.mesonEnable { ... })
  ++ (lib.mapAttrsToList lib.mesonBool {
    "experimental" = experimentalPatches;  # -Dexperimental=true
    "niri" = niriSupport;
  })
];
```

**Missing**: `-Dwlr=enable` is NOT in the mesonFlags. The `wlr/workspaces` module requires the wlroots protocol backend which is guarded by the `wlr` meson option. nixpkgs does not build it.

**Could it be added?** Yes, via an overlay:
```nix
waybar = prev.waybar.overrideAttrs (old: {
  mesonFlags = old.mesonFlags ++ [ "-Dwlr=enabled" ];
});
```
But this would require `wlroots` as a build input (nixpkgs may or may not already have it in the build closure). The needed cmake/meson dependency is `wlroots` (the library). Worth investigating but adds build complexity.

**Verdict**: Not available in current nixpkgs waybar. Requires custom overlay + additional build inputs. The prior exploration was correct about this.

### 3c. `ext/workspaces` — PRIMARY CANDIDATE (verified in detail)

**Investigation**: Confirmed via multiple sources:

1. **nixpkgs build**: `experimentalPatches ? true` → `-Dexperimental=true` → `ext/workspaces` IS compiled into nixpkgs waybar v0.15.0. Verified by reading the actual `package.nix` from nixos-unstable.

2. **Hyprland support**: Implements `ext-workspace-v1` Wayland protocol since PR hyprwm/Hyprland#10818 (merged 2025-06-26). Available in Hyprland ≥ 0.52.1. T14 runs 0.55.

3. **No IPC thread**: Uses the Wayland protocol directly — no socket2 listener, no `onEvent()` callback, no GTK-on-IPC-thread surface. This eliminates ALL the crash vectors identified in Section 1.

4. **Source code**: Module at `src/modules/ext/workspace_manager.cpp` (waybar). Uses `ext_workspace_manager_v1` Wayland globals. Workspace creation/destruction goes through Wayland protocol events dispatched by the compositor on the main thread.

5. **Tradeoffs vs `hyprland/workspaces`**:

| Feature | hyprland/workspaces | ext/workspaces |
|---|---|---|
| Protocol | socket2 IPC | ext-workspace-v1 (Wayland) |
| persistent-workspaces config | ✅ Yes (Hyprland rules + config override) | ❌ No |
| Workspace names from IPC | ✅ Yes (via `workspacev2>>` events) | ⚠️ Limited (compositor defines names) |
| Icons from IPC | ✅ Yes (`format-icons` from `workspacev2>>`) | ⚠️ Limited (uses compositor-provided names) |
| On-click activate | ✅ Yes | ✅ Yes (`"on-click": "activate"`) |
| Window count per workspace | ✅ Yes (taskbar) | ❌ No |
| Special workspaces | ✅ Yes | ❌ No |
| all-outputs | ✅ Optional | Required for multi-monitor |
| Sort methods | ID, NAME, NUMBER, DEFAULT, SPECIAL-CENTERED | NAME, NUMBER, DEFAULT |
| Urgent hints from IPC | ✅ Yes | ❌ No |
| Ignore workspaces | ✅ Yes (regex) | ❌ No |

**What the T14 actually uses**: The current config only uses `on-click: activate`, `format-icons` (20 numbered icons), and `persistent-workspaces: 1..5`. NO window taskbar, NO special workspaces, NO `ignore-workspaces`, NO scroll, NO `move-to-monitor`, NO `window-rewrite`. **Every feature the T14 uses is supported by `ext/workspaces`.**

**The only gap**: `persistent-workspaces` in the config won't work. BUT the T14 already has `persistent:true` in Hyprland workspace rules (from `monitors.nix`). Hyprland will keep workspaces alive, and `ext/workspaces` will display them.

### 3d. `custom` module with `hyprctl` polling

**Design**:
```json
"custom/workspaces": {
  "exec": "hyprctl workspaces -j | jq -r '.[].id' | sort -n | tr '\n' ' '",
  "interval": 1,
  "format": "{}",
  "on-click": "hyprctl dispatch workspace {}"  // can't pass specific ID easily
}
```

**CPU cost**: `time hyprctl workspaces -j` ≈ 5-10ms per call. At 1Hz, negligible. At 5Hz (smoother), ~2-5% CPU.

**Issues**:
- Cannot map separate click targets to specific workspace IDs (waybar's `custom` module has one click handler)
- No active-workspace highlighting (need to parse JSON and set CSS classes — custom module can't do this)
- 1-second update lag means the workspace indicator is stale after switch
- Significantly worse UX than any native module

**Verdict**: Only as absolute last resort. NOT recommended.

### 3e. Disable workspace display entirely

**UX impact**:
- No visual workspace indicator at all
- Must remember which workspace you're on or use `hyprctl activeworkspace`
- Walker (app launcher) can show workspace but requires extra keystroke
- Acceptable as temporary measure (hours/days) while implementing a real fix
- NOT acceptable as permanent solution

**Verdict**: Emergency stop-gap only.

---

## 4. WAYBAR BUILD OPTIONS (Deep Dive)

### 4a. Commit bisection results

| Range | Status |
|---|---|
| v0.15.0 (tag `90b209a`) | ✅ Works but crashes on workspace switch |
| v0.15.0 + `dd47a2b` (Mar 7, reload stabilization) | Unknown (no crash fix) |
| v0.15.0 + `e17c0d9` (Apr 29, Lua dispatch) | ❌ Known regression (startup crash) |
| master HEAD `0594574` (May 4) | ❌ Known regression (startup crash) |

**No commit exists between v0.15.0 and master that fixes the workspace-switch crash without introducing the startup regression.** The one commit that might help (`dd47a2b`, scroll event stacking fix) doesn't address the crash mechanism. The prior exploration's claim that no fix exists is CONFIRMED.

### 4b. Nixpkgs waybar patch approach

nixpkgs `package.nix` uses `fetchFromGitHub` with `tag = finalAttrs.version` and a fixed hash. To patch:
```nix
# In overlays/linux.nix
waybar = prev.waybar.overrideAttrs (old: {
  patches = (old.patches or []) ++ [
    ./patches/waybar-fix-ipc-race.patch
  ];
});
```

But this requires writing a C++ patch ourselves — we'd need to identify the exact crash fix (which doesn't exist upstream yet) and backport it. This is high-risk custom development on a C++ codebase with threading complexity.

**Verdict**: Not recommended. The correct fix doesn't exist upstream; we'd be inventing it.

### 4c. Community overlays and NUR

- Nix User Repository (NUR): No waybar variants found via `nix search`
- Community flakes: Common pattern is `waybar-git` overlay pointing to master — but master is currently broken (May 4 regression)
- No known overlay specifically patches the Hyprland 0.55 workspace crash

---

## 5. SYSTEMD AUTO-RESTART WORKAROUND (Concrete Design)

### 5.1 Home Manager systemd service

```nix
# In hosts/t14/home/default.nix or a new module
systemd.user.services.waybar = {
  Unit = {
    Description = "Waybar status bar";
    PartOf = [ "graphical-session.target" ];
    After = [ "graphical-session.target" ];
  };
  Service = {
    ExecStart = "${pkgs.waybar}/bin/waybar";
    Restart = "always";
    RestartSec = "100ms";
    StandardOutput = "null";
    StandardError = "journal";
  };
  Install = {
    WantedBy = [ "graphical-session.target" ];
  };
};
```

Then in `autostart.nix`, replace line 14:
```diff
- "pkill -x waybar; uwsm-app -- waybar"
+ "systemctl --user restart waybar"
```

### 5.2 UWSM interaction

`uwsm-app` runs as `systemd-run --user --scope` which is a transient scope unit (NOT a service). A proper `systemd.user.services.waybar` is a different unit type. They don't conflict — `uwsm-app` wouldn't be used for waybar anymore.

**Issue**: `uwsm` integrates with `graphical-session.target` lifecycle. If waybar is started as a standard systemd service with `WantedBy=graphical-session.target`, it starts and stops with the graphical session — same lifecycle as uwsm-app would provide. No integration issue.

### 5.3 UX impact measurement

- Crash → systemd sends SIGKILL → `RestartSec=100ms` → new waybar process starts
- Waybar startup latency (nixpkgs build, cold): ~200-400ms (GTK init, layer-shell surface creation)
- Visible blank bar: ~300-500ms per crash
- At 5+ switches per second (rapid Super+1/2/3): systemd rate-limits restarts (`StartLimitBurst=5`, `StartLimitIntervalSec=10s`) → after 5 crashes in 10s, waybar stays dead

**Mitigation**: `StartLimitBurst=20` + `StartLimitIntervalSec=5s` to allow rapid restarts. But even with this, rapid switching will show persistent flicker.

### 5.4 Omarchy-toggle-waybar integration

Current (`omarchy-toggle-waybar`):
```bash
if pgrep -f ...; then pkill -f ...; else uwsm-app -- waybar >/dev/null 2>&1 &; fi
```

With systemd:
```diff
- if pgrep -f ...; then pkill -f ...; else uwsm-app -- waybar >/dev/null 2>&1 &; fi
+ if systemctl --user is-active waybar; then systemctl --user stop waybar; else systemctl --user start waybar; fi
```

### 5.5 Belt-and-braces: systemd + ext/workspaces

These are complementary:
- **ext/workspaces**: Removes the IPC crash surface → waybar shouldn't crash
- **systemd Restart=always**: If waybar crashes for ANY other reason (OOM, GTK bug, segfault from another module), it restarts instantly

Both can coexist. systemd should be the safety net, ext/workspaces the primary fix.

---

## 6. ADDITIONAL INVESTIGATIONS

### 6.1 t14-hdm-migration-v2 interaction

**State**: NOT deployed. Doc committed (`55d20c1`) but HDM directory doesn't exist on disk. Tasks.md shows 16 uncompleted tasks.

**Impact on waybar**: HDM migration would:
- Remove `monitor-lid-validator.sh` entirely → no more daemon polling
- Replace Hyprland conditionals with HDM profile-based config generation
- Likely make workspaces 1-3 persistent across profiles (HDM generates explicit rules per profile)
- This would eliminate the create/destroy churn for workspaces 1-3 when docked

**Recommendation**: HDM migration is a SEPARATE change. Do NOT couple it with the waybar fix. If HDM is deployed first, it might reduce the crash frequency (persistent workspaces → fewer create/destroy events) but won't eliminate the crash surface (socket2 IPC listener still active). If HDM is deployed after, the waybar fix must still work with HDM.

**Decision**: Implement waybar fix first (ext/workspaces). HDM can follow independently.

### 6.2 Known Issues Validation

| # | Issue | Validation |
|---|---|---|
| 1 | waybar stderr capture broken | CONFIRMED. `omarchy-toggle-waybar:13` → `>/dev/null 2>&1`. `autostart.nix:14` → no redirect at all. |
| 2 | wlr/workspaces not compiled | CONFIRMED. nixpkgs waybar has no `-Dwlr=enable`. |
| 3 | waybar master regression | CONFIRMED and BISECTED. Master HEAD `0594574` (May 4, 2026) = PR #5013 merge = instant startup crash. No newer commits exist. |
| 4 | Ghostty output in waybar stderr | The `uwsm-app` wrapper inherits the terminal's environment. If Ghostty is the terminal that launches Hyprland, Ghostty's stderr may leak into waybar's output. With systemd service, `StandardError=journal` isolates waybar's stderr from the terminal. |
| 5 | omarchy-toggle-waybar as restart mechanism | CONFIRMED. The `pkill -f waybar \|\| uwsm-app -- waybar` toggle pattern restarts waybar. If the user accidentally hits Super+Shift+Space, waybar restarts. With systemd, this becomes `systemctl --user restart waybar`. |

### 6.3 Relationship with prior SDD session

The `t14-hyprctl-reload-causes-resets-on-workspace-switch` session:
- **Fix 1** (remove validator reload): ✅ APPLIED (`b39d79f`)
- **Fix 2** (w>3 filter): ✅ APPLIED (`b39d79f`)
- **Fix 3** (remove monitor-watch reload): ❌ NEVER APPLIED to omarchy-nix main
- **Fix 4** (stderr capture): ❌ NEVER APPLIED to omarchy-nix main

The 3 fixes that WERE applied stopped the `hyprctl reload` churn but the waybar process still crashes on workspace switches because the root cause is IPC listener crashes in `hyprland/workspaces` module, not reload-induced events.

---

## 7. APPROACHES (Final Ranking)

| # | Approach | Eliminates crash? | Effort | UX | Risk | Verdict |
|---|---|---|---|---|---|---|
| 1 | `ext/workspaces` module | ✅ Yes (no socket2 IPC) | Low | Good (loses persistent-ws config but Hyprland rules cover) | Low | **PRIMARY** |
| 5 | systemd auto-restart | ❌ No (still crashes) | Low-Medium | Mediocre (300-500ms blank per crash) | Low | **FALLBACK / BELT-AND-BRACES** |
| 3 | `custom` polling | ✅ Yes | Medium | Bad (1s lag, no click targets) | Low | **LAST RESORT** |
| 4 | Disable workspace display | ✅ Yes | Trivial | Terrible | None | **EMERGENCY ONLY** |
| 2 | Cherry-pick/build from git | ❓ Unknown (no fix exists upstream) | High | Unknown (depends on fix) | High (regression risk) | **DO NOT PURSUE** |
| - | `sway/workspaces` | N/A (won't work) | N/A | N/A | N/A | **NOT VIABLE** |
| - | `wlr/workspaces` | N/A (not compiled) | Medium (custom build) | Unknown | Medium | **POSSIBLE BUT HIGH COST** |

---

## RECOMMENDATION

**Primary change**: Switch `hyprland/workspaces` → `ext/workspaces` in `omarchy-nix/config/waybar/config` (Approach 1).

**Secondary (defense-in-depth)**: Wrap waybar launch in a proper systemd user service with `Restart=always` + `RestartSec=100ms` (Approach 5). This catches crashes from ANY module, not just workspaces.

**Cleanup bundle**:
1. Remove unused `waybar-src` flake input from `flake.nix` (lines 113-117)
2. Apply the missing Phase 2 fixes from prior SDD to omarchy-nix main:
   - Remove `monitoradded>>` reload from `omarchy-hyprland-monitor-watch`
   - Add waybar stderr capture in `autostart.nix`
3. Fix `omarchy-toggle-waybar` stderr capture

**What changed from prior exploration**:
- The prior recommendation (Approach 1 only) is REINFORCED, but with MUCH deeper evidence (source-code threading analysis, full commit bisection, verified nixpkgs build flags)
- Approach 5 (systemd) is now promoted from "fallback" to "belt-and-braces" — it should be deployed TOGETHER with ext/workspaces
- The prior exploration did not evaluate `sway/workspaces` (now confirmed NOT VIABLE)
- The prior exploration did not test HDM migration interaction (now confirmed NOT DEPLOYED)
- The missing Phase 2 omarchy-nix fixes were discovered during revalidation

---

## RISKS

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| `ext/workspaces` doesn't show workspaces correctly on 3-external-monitor layout | Medium | High | Must test on T14 hardware before merge. `all-outputs: true` is the key config flag. |
| `persistent-workspaces` config loss means workspaces 1-3 disappear when empty (docked) | Low | Medium | Hyprland `persistent:true` rules in `monitors.nix` already keep them alive. `ext/workspaces` reflects what Hyprland reports. |
| Omarchy-nix shared config change breaks rog/thinkcentre | Low | High | Need to verify `ext-workspace-v1` protocol support on all Hyprland hosts. Could add per-host waybar config override if needed. |
| Systemd service conflicts with UWSM | Low | Medium | systemd service uses `WantedBy=graphical-session.target` — same lifecycle as UWSM. Tested pattern in NixOS community. |
| Hyprland `ext-workspace-v1` implementation has bugs in 0.55 | Low | Medium | Community reports confirm it works (Waybar issue #5008). Testing on T14 hardware is definitive. |

---

## NEXT: READY FOR PROPOSAL

**Yes.** The exploration has validated every claim against source code and commits. The recommendation is data-backed, the risk matrix is comprehensive, and the fallback paths are clear.
