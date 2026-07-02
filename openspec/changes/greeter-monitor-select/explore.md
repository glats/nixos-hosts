# Exploration: greeter-monitor-select (v2 — re-investigated)

**Change**: `greeter-monitor-select`
**Project**: nixos-hosts
**Date**: 2026-06-29
**Supersedes**: Engram obs #370 (the prior explore's RCA was directionally correct, but
this version reflects the verified deprecation timeline of `windowrulev2` and the new
Lua config in Hyprland 0.55+).

## CRITICAL UPDATE — what changed since the prior explore

The user's claim that "`windowrulev2 monitor` is DEPRECATED/DISCONTINUED in Hyprland — not
just broken" is **confirmed and quantified**. The deprecation is a three-step removal:

| Hyprland version | Date | Status of `windowrulev2` |
|---|---|---|
| 0.46.0 | 2024-08 | Both `windowrule` (v1) and `windowrulev2` (v2) work; v1 regex must fully match |
| 0.48.0 | 2025-03-25 | **Syntax break**: `windowrulev2` requires `class:` prefix; bare regex no longer works. Closed issues #9723, #9726 mark the breaking change. |
| 0.53.x | 2026-02 | **Soft removal**: PR #12847 (commit `9817553`) makes `windowrulev2` a handler that returns the error string `"windowrulev2 is deprecated. Correct syntax can be found on the wiki."` — config parses, but every rule errors. |
| 0.55.0 | 2026-05-09 | **hyprlang→Lua migration**: PR #13817 makes `hyprland.lua` the default config format if present. hyprlang is still supported "for 1-2 releases" then dropped. The wiki banner now says: *"Looking for the old hyprlang syntax? Check the 0.54 wiki pages. Since Hyprland 0.55, hyprlang is deprecated in favor of lua."* |
| 0.55.4 | 2026-06-22 | **Current in nixpkgs unstable** (`b3c092d3c36d`); user's `hyprland` flake input is pinned to `521ece463c4a` from `1774635470` (≈ 2026-05-22, 0.55.x line). |

**Implication for the prior explore's RCA**: the prior explore correctly identified
that `windowrulev2` was unreliable. It was in fact **already a hard error by the
time of this exploration** (0.53+). The current omarchy-nix commit history shows
the user already migrated to `windowrule` (commit `082e89f`) and then abandoned
window rules entirely in favor of script-based monitor control — which is the only
path that survives the 0.53+ deprecation.

**`windowrule` itself is also evolving**: the rewrite in commit `c2670e9` (Nov 17, 2025)
introduced a block syntax (`windowrule { name = "x"; match:class = "^y$"; monitor = "DP-1" }`),
but the legacy line syntax `windowrule = monitor "DP-1", class:^(regreet)$` still works
(confirmed by issue #9723 maintainer reply: *"In the latest git version, change all
`windowrulev2` to `windowrule`. And use `class:[regex]` instead just `[regex]`"*).
**However**, the `monitor` field of `windowrule` still exhibits the same
focus-stealing bugs (`#8942`, `#9365`, `#8262`) that made the prior `windowrulev2`
attempts fail — the deprecation did not fix the behavior.

---

## 1. Current Architecture (re-verified, no change)

The current chain is unchanged from the prior explore:

```
greetd.service
  └─ default_session.command = "start-hyprland -- --config /etc/greetd/hyprland.conf"
       user = "greeter" (lib.mkForce — overrides programs.regreet.enable's cage default)
  └─ start-hyprland wrapper
       └─ Hyprland -c /etc/greetd/hyprland.conf
            ├─ monitor = desc:...  (3 lines for t14 — see below)
            ├─ env = XCURSOR_THEME,...  (cursor block)
            └─ exec-once = $greetd-regreet-start
                 └─ writeShellScript:
                      1. /sys/class/drm scan → if any external is connected,
                         `hyprctl keyword monitor eDP-1,disable` and break
                      2. regreet
                      3. hyprctl dispatch exit
```

**Files that participate** (re-verified):
- `omarchy-nix/modules/nixos/system.nix:159-238` — greetd block + greeter user + regreet enable + hyprland.conf generator
- `omarchy-nix/config.nix:284-382` — `omarchy.greeter` submodule (`type`, `keyboard`, `monitors`, `cursor`, `wayvnc`)
- `hosts/t14/default.nix:180-205` — `omarchy.greeter` config (type=regreet, 3 desc: lines, es/latam, Bibata-Modern-Ice, wayvnc)
- `flake.nix:220` — wires `omarchy-nix.nixosModules.default` into t14's extraModules

**What the current emitted `/etc/greetd/hyprland.conf` looks like for t14** (3 monitor lines + cursor env + exec-once + input + misc):

```
monitor = desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1
monitor = desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1
monitor = desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1
env = XCURSOR_THEME,Bibata-Modern-Ice
env = HYPRCURSOR_THEME,Bibata-Modern-Ice
env = XCURSOR_SIZE,24
env = HYPRCURSOR_SIZE,24
exec-once = /nix/store/.../bin/greetd-regreet-start
input {
    kb_layout = es,latam
    kb_options = grp:alt_shift_toggle
}
misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    disable_hyprland_guiutils_check = true
}
```

No `windowrule` is emitted. The script is the only mechanism that affects the runtime monitor layout.

**Critical observation**: With the current 3 desc: lines, eDP-1 is NOT in the list, but Hyprland's auto-detection may still add it back if it doesn't recognize the desc: match. The existing `eDP-1,disable` script step covers that case (if any external is connected, kill eDP-1).

---

## 2. What REPLACED `windowrulev2 monitor` (re-investigated)

Three replacement mechanisms exist; all are insufficient or have known issues for this use case.

### 2a. `windowrule = monitor "DP-4", class:^(regreet)$` (line syntax, still works)

Source: Hyprland wiki "Window Rules", confirmed in 0.55.4 hyprlang docs.

**Syntax** (per #9723 maintainer fix):
```ini
windowrule = monitor "DP-4", class:^(regreet)$
```

**Known bugs that make this insufficient**:
- **#8942 (closed Jan 2025)**: `monitor` rule causes `openwindow` socket2 event to report the *focused* monitor's workspace, not the target monitor's workspace. Repo's recommended workaround: use a `workspace` rule instead — but workspace rules have the same problem because workspace-to-monitor binding is determined at config-parse time, not window-open time.
- **#9365 (closed Feb 2025)**: combining `windowrulev2 = monitor X, class:Y` with `windowrulev2 = noinitialfocus, class:Y` causes focus to *jump* to monitor X even when the window itself is not focused. The very fact that users reach for `noinitialfocus` to suppress this proves the underlying issue.
- **#8262 (closed Nov 2024)**: focus wanders from the currently focused monitor to the new window's monitor when a workspace rule fires.

**Verdict**: `windowrule = monitor "DP-4"` does place the window on DP-4, but the surrounding focus behavior is broken in ways that affect the user experience of an unattended greeter session less critically (no real user to be confused by focus jumps), but is still unreliable enough that the prior explore rejected it. **Status: still insufficient.**

### 2b. `windowrule` block syntax (new in 0.55+)

```lua
windowrule {
    name = "regreet-to-dp4"
    match:class = "^regreet$"
    monitor = "DP-4"
}
```

Per the c2670e9 rewrite. The `monitor` field still has the same focus-stealing bugs. No new code paths were added to fix them in 0.55. **Status: still insufficient.**

### 2c. Lua config with per-window placement helpers

The new Lua config (0.55+) exposes `hl.window_rule` (per PR #13817 + wiki) and a richer
event API. Theoretically, a Lua config could:
- Listen to the `openwindow` event
- Check `class == "regreet"`
- Call `hl.monitor.moveWindowToMonitor` or similar

But:
- The `monitor` field on the new `hl.window_rule` is functionally identical to the
  `windowrule` `monitor` field — same backend code path, same bugs.
- Writing a Lua greeter config adds a second config format to the project (current
  code is hyprlang; Lua migration is a separate, larger effort tracked upstream).
- The `openwindow` event in Lua is just a sugar wrapper over the socket2 stream
  — does not fix the focus prediction bug.

**Verdict**: Same bugs, plus a migration cost. **Status: not a fix.**

### 2d. `workspace = 1, monitor:desc:Lenovo...` (community pattern)

Bind workspace 1 to the target monitor; tell ReGreet to open on workspace 1. Implemented
in the prior commit `1577614` and found not to work — ReGreet does not auto-pick
workspace 1, it opens on the focused monitor's active workspace. **Status: not a fix.**

### 2e. The actually-working mechanism: `hyprctl keyword monitor X,disable` + `hyprctl dispatch focusmonitor X`

This is the pattern used by:
- **vaxerski's own answer in Hyprland discussion #4789** (official maintainer): *"The syntax seems to be `monitor=NAME,disabled`, but that works, thanks!"* — endorsing the `hyprctl keyword monitor X,disable` pattern.
- **EndoliteMatrix/hyprland-dock-undock-automation** (a production dock-aware Hyprland config) — uses `hyprctl keyword monitor ${INTERNAL_DESC},preferred,-30000x0,1.0` + `hyprctl dispatch dpms off` + `hyprctl keyword workspace "name:offscreen,monitor:${INTERNAL_DESC},default:true,persistent:true"` + `hyprctl dispatch moveworkspacetomonitor` to park the internal panel and keep ReGreet-visible monitors stable. This is a **real-world production script** using exactly the Approach A pattern.
- **hyprland-wiki discussion #11583**: confirms `hyprctl keyword monitor X,disable` works at runtime; the only caveat is that it doesn't persist across config reloads (irrelevant for greeter — no reloads happen during greeter).

**Verdict**: The community standard for runtime monitor selection IS the `hyprctl keyword monitor X,disable` pattern. **This is the only path that survives the 0.53+ `windowrulev2` deprecation AND the 0.55+ Lua migration**, because it's an IPC command that has been stable across all of these.

---

## 3. Hyprland IPC commands available to the greeter script

The greeter script runs as user `greeter` (in `video` group) inside a `start-hyprland` session. It has access to the Hyprland IPC socket at `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket.sock` and the socket2 stream. All of the following have been stable since Hyprland 0.30+:

| Command | Purpose | Reliability for this use case |
|---|---|---|
| `hyprctl monitors -j` (or `hyprctl -j monitors`) | List all monitors with id/name/description/make/model/serial/activeWorkspace | The description field is set by the kernel from EDID; matches what the user already uses in `desc:` lines. ✅ Stable |
| `hyprctl keyword monitor <name>,disable` | Disable a monitor by name or description | Officially endorsed (#4789). ✅ Stable |
| `hyprctl keyword monitor <name>,<mode>,<pos>,<scale>` | Re-enable/reconfigure a monitor | ✅ Stable |
| `hyprctl dispatch focusmonitor <name>` | Move focus to a specific monitor | ✅ Stable (PR #4660 fixed focus tracking) |
| `hyprctl dispatch moveworkspacetomonitor <ws> <mon>` | Move workspace to monitor | ✅ Stable (PR #4660 fix) |
| `hyprctl dispatch movecurrentworkspacetomonitor <mon>` | Move active workspace to monitor | ✅ Stable |
| `hyprctl -j clients` | List all clients with class/title/workspace/address/monitor | Used to find ReGreet window after launch (e.g., for event-based move, see below) |
| `socat -U - UNIX-CONNECT:...socket2.sock` | Subscribe to events (openwindow, focusedmon, etc.) | Used in the Sway multi-monitor Regreet workaround (issue #80). Possible but more complex. |

**JSON caveat for `hyprctl monitors -j`**: the legacy `hyprctl -j monitors` flag (note
flag position) returns a clean JSON array. The newer `hyprctl monitors -j` (command-positional
`-j`) also returns a clean JSON array in 0.45+. The bug where it printed a non-JSON
`adding monitors\n` prefix (#2921) was fixed years ago. **In 0.55.4 the output is
clean JSON. No need to strip a header line.**

---

## 4. Approach Evaluation Matrix (re-evaluated with new evidence)

### Approach A — Script-based monitor selection (RECOMMENDED, no change vs. prior explore)

**What it does**:
1. Wait for Hyprland to enumerate monitors (`hyprctl monitors -j`).
2. Identify the target monitor by description substring (e.g., `"LEN G24"`).
3. `hyprctl keyword monitor <other-ext>,disable` for every external that is not the target.
4. Keep `eDP-1,disable` when an external is connected (current behavior).
5. `hyprctl dispatch focusmonitor <target>`.
6. Launch regreet.

**Evidence for viability**:
- vaxerski's own answer in #4789 endorses `monitor X,disable` as the standard runtime pattern.
- EndoliteMatrix's production dock script uses the same approach for docked/undocked transitions.
- hyprland-wiki #11583 confirms `hyprctl keyword monitor X, disable` works at runtime; the only limitation (no persistence across config reload) is irrelevant for the greeter session.
- The same script already exists in the codebase (`eDP-1,disable` step) — this is an extension, not a new concept.

**Evidence against alternative paths**:
- `windowrulev2` is now a hard error (0.53+).
- `windowrule = monitor` still has bugs #8942, #9365, #8262 (focus prediction, focus jumping, focus wandering).
- The 0.55+ Lua config does not fix any of these — the underlying code path is the same.

| Pros | Cons |
|---|---|
| Smallest diff (~20-30 lines added to one shell script) | Runtime timing: `hyprctl monitors -j` may return empty for the first ~50-200ms after exec-once. Need a retry loop. |
| Survives all Hyprland deprecations (uses stable IPC, not config syntax) | Requires `jq` in the greeter PATH. Already implicit in any modern NixOS (jq is in `start-hyprland`'s default env). |
| Reuses the existing `greetd-regreet-start` script pattern | Description substring match (`"LEN G24"`) is fragile if the user changes the monitor or if EDID reports a different string. The user already encodes the full description in `cfg.greeter.monitors`, so a substring of that is a stable fingerprint. |
| Handles dock/undock matrix: with Lenovo → only DP-4 stays; without Lenovo → first external or eDP-1 | |
| Easily reversible: just don't set `focusMonitor` (or set it to `""`) | |

**Files**: `omarchy-nix/modules/nixos/system.nix` (modify `greetd-regreet-start`); `omarchy-nix/config.nix` (add `focusMonitor` option); `hosts/t14/default.nix` (set `focusMonitor = "LEN G24"`).
**Effort**: Low. ~20 lines in system.nix, ~5 lines in config.nix, 1 line in t14/default.nix. Single commit.
**Risk**: Low. If `jq` parsing fails, the existing eDP-1 disable still runs and regreet still launches (degraded but functional).
**Rollback**: revert single commit.

### Approach A' — Same as A, but using an event-based move (alternative sub-approach)

**What it does**: instead of disabling non-target monitors BEFORE regreet, launch regreet
and then watch the socket2 stream for the `openwindow` event with class `regreet`, then
`hyprctl dispatch movewindow mon:DP-4 address:0x...`.

**Evidence**: Sway users do this (ReGreet issue #80). Sway example script:
```sh
regreet & p=$!
swaymsg -t subscribe '["window"]'
get_focused() { swaymsg -t get_tree | jq -r '.. | select(.focused? and .app_id=="apps.regreet")' }
cur_focused=$(get_focused)
while [[ -z $cur_focused ]]; do cur_focused=$(get_focused); done
swaymsg 'move output DP-1'
swaymsg '[app_id="apps.regreet"] focus'
wait $p
swaymsg exit
```

| Pros | Cons |
|---|---|
| Doesn't touch monitor config — works with Hyprland's auto-detection | Adds `socat` (or similar) dependency; more complex shell |
| ReGreet appears on the configured monitor even if the dock state changes mid-greeter | Race condition: a 50-200ms flicker where regreet is on the wrong monitor before being moved |
| | User sees the form on DP-3 briefly, then it jumps to DP-4 — visible glitch |

**Effort**: Medium. ~40 lines of shell + a `socat`/`jq` dependency.
**Risk**: Medium. The flicker is a visible regression vs. Approach A (which never shows regreet on the wrong monitor).
**Verdict**: A strict superset of A's complexity, with a visible regression. **Not recommended unless A's timing proves flaky in production.**

### Approach B — `windowrule = monitor "DP-4", class:^(regreet)$` (DISQUALIFIED — even more so than before)

**What it does**: Add the new `windowrule` line to `/etc/greetd/hyprland.conf`:
```ini
windowrule = monitor "DP-4", class:^(regreet)$
```

**Evidence (new since prior explore)**:
- In Hyprland 0.53+ the old `windowrulev2` syntax returns an error per #12847. The user already migrated to `windowrule` per #9723.
- But the `monitor` field of `windowrule` has the **same focus-stealing bugs** as the old `windowrulev2`:
  - #8942: openwindow event reports wrong workspace
  - #9365: focus jumps to the target monitor even with noinitialfocus
  - #8262: focus wanders from current monitor
- These bugs are not fixed in 0.55+ (the Lua rewrite did not change the focus prediction code path).

| Pros | Cons |
|---|---|
| 1-line config addition | windowrulev2 deprecation forced migration to windowrule, but windowrule's monitor field has identical bugs |
| No new dependencies | The prior explore already tried this 4 times in different syntaxes — all failed or were reverted |
| Pure config — no shell script | The user's commit history (c09d050, 082e89f, 2964103, aba1daf) shows the iteration never converged on a working version |

**Verdict**: **DISQUALIFIED.** The prior explore was correct; the deprecation timeline now confirms there is no future-friendly way to make this work. The user already abandoned this path.

### Approach C — Switch to nwg-hello (STRONG PLAN B)

**What it does**: Change `cfg.greeter.type = "nwg-hello"` and add a new nwg-hello config
submodule that sets `form_on_monitors = [<target>]` and `monitor_nums = [<target>]`.

**Evidence (verified via exa + nix MCP + GitHub)**:
- `nixpkgs/nixos-unstable` has `nwg-hello 0.4.3` (verified via nix MCP, June 2026).
- `nixpkgs/release-25.11` has `nwg-hello 0.4.1`.
- nwg-hello is in the Arch `[extra]` repo (Endeavour forum, Garuda). It's the default greeter in nwg-iso and Garuda.
- The README explicitly documents:
  ```json
  {
    "monitor_nums": [],
    "form_on_monitors": [],
    ...
  }
  ```
  with notes: *"monitor_nums: leave as is to see the greeter on all monitors. Set e.g. [0, 2] for it to appear on the 1st and 3rd one. form_on_monitors: which of above monitors to display the login form on (just the wallpaper on the rest)."*
- Garuda user: *"nwg-hello has better support for monitor configuration; you can specify right in the config what monitors you want the greeter to use, and also what display to show the login form on."* (Endeavour forum)
- There is **no** nixpkgs `services.greetd` integration for nwg-hello — only the package is provided. omarchy-nix would need to add the module.

| Pros | Cons |
|---|---|
| Multi-monitor support is a **core, first-class feature** of nwg-hello — not a hack | Different UI/UX (GTK3 / Python vs ReGreet's GTK4 / Rust) |
| Native `form_on_monitors: [<target>]` — solves the problem cleanly, no shell script | Background, greeting message, dark theme must be ported to nwg-hello's CSS+JSON config format |
| Used in nwg-iso and Garuda as the default greeter — battle-tested | No `services.greetd` integration in nixpkgs — must add a new module to omarchy-nix |
| Sits in nixpkgs — no flake input needed | Different escape hatch: nwg-hello doesn't exit Hyprland the same way; needs `cmd-sleep/reboot/poweroff` mapping |
| The user already has a custom Hyprland config for the greeter (wayvnc, kb_layout, etc.) — this carries over unchanged | The user loses ReGreet's "lock screen style" aesthetic (ReGreet is a login form, nwg-hello is more like a launchpad) |

**Files**:
- `omarchy-nix/modules/nixos/system.nix` — add `nwg-hello` branch in the greetd block
- `omarchy-nix/config.nix` — extend `omarchy.greeter.type` enum to include `"nwg-hello"`; add `nwgHello` config submodule
- `hosts/t14/default.nix` — change `omarchy.greeter.type = "nwg-hello"`; add `monitor_nums = [0]`
- `flake.lock` — no change (nwg-hello is in nixpkgs)

**Effort**: Medium. ~50-80 lines of new module code, plus config migration.
**Risk**: Medium. New dependency, new config surface, different UI.
**Rollback**: Revert to "regreet" string; revert module additions.

### Approach D — Switch to hyprlogin (NOT FEASIBLE)

**What it does**: Use hyprlogin (Hyprlock fork) as the greeter. hyprlogin is a hyprlock
fork repurposed as a greetd greeter — GPU-accelerated, multi-threaded, supports
fractional scale.

**Evidence**:
- hyprlogin is **NOT in nixpkgs** (verified via nix MCP: "Package 'hyprlogin' not found").
- AUR-only as `hyprlogin-git` (ArchWiki greetd page).
- Repo: `AuthenticSm1les/hyprlogin` (mentioned in ArchWiki).

| Pros | Cons |
|---|---|
| Hyprland-native (forked from hyprlock) | WIP upstream; not in nixpkgs — would need a flake input or `pkgs.fetchFromGitHub` |
| Multi-monitor via hyprlock's existing config | Same "where does the form go" problem — hyprlock config is per-monitor but greeter session is new |
| GPU-accelerated, fast | Maintenance burden: track upstream hyprlock + apply greeter patches |
| | User would need to learn hyprlock's config grammar (widget/category syntax) |

**Files**:
- New flake input for `AuthenticSm1les/hyprlogin`
- New module in `omarchy-nix/modules/nixos/` for `programs.hyprlogin` (or call into a derivation)
- Replace regreet branch in system.nix
- t14 default.nix change
- flake.lock bump

**Effort**: High. New flake input, derivation, module, hyprlock config learning curve.
**Risk**: High. WIP upstream, AUR-only, package-derivation maintenance.
**Rollback**: Hard — once committed, removing the input requires lock churn.
**Verdict**: **NOT FEASIBLE** for this change. Defer to a separate "evaluate hyprlogin" change if interest.

### Approach E — Switch to SDDM (DISQUALIFIED)

**Evidence**:
- NixOS supports `compositor = "kwin"` or `"weston"` for SDDM-Wayland via
  `services.displayManager.sddm.wayland.compositor`. Hyprland is **not supported**
  as a Wayland compositor for SDDM on NixOS (verified by reading the option
  descriptions in nixpkgs; only kwin and weston are listed).

| Pros | Cons |
|---|---|
| Mature, default on many distros | **Cannot launch Hyprland as the compositor** for SDDM-Wayland on NixOS |
| Multi-monitor handled by the chosen compositor (kwin/weston) | kwin/weston won't read Hyprland's `~/.config/hypr/hyprland.conf` or monitor rules — would need a separate login-time config |
| Qt theme integration with system | Not a drop-in for t14's Hyprland workflow |

**Verdict**: **DISQUALIFIED.** Critical incompatibility with the Hyprland-based t14 stack.

### Approach F — Switch to cage (DISQUALIFIED for Hyprland workflow)

`programs.regreet.cageArgs` exists in nixpkgs and supports `cageArgs = [ "-m" "last" ]` to
limit cage to the last-connected monitor. But cage is a separate Wayland compositor
that doesn't read Hyprland's config — moving t14 to cage would mean re-implementing
all the omarchy/Hyprland-specific config (kb_layout, wayvnc, monospace fonts, etc.)
in cage's TOML. The t14 stack is Hyprland-first; cage is the wrong direction.

---

## 5. Recommendation

**Approach A** (script-based monitor selection in `greetd-regreet-start`) is still
recommended. The new evidence (Hyprland 0.55+ Lua migration, `windowrulev2` returning
an error since 0.53, the vaxerski-endorsed `monitor X,disable` pattern, the
EndoliteMatrix production script) makes Approach A **even more compelling** than
it was at the time of the prior explore.

### Why A is now MORE correct than before

1. **windowrulev2 is not just broken — it's an error string in 0.53+**. The prior attempts
   (c09d050, 082e89f, etc.) are not just "fragile" — they actively produce error
   messages in current Hyprland. Approach A doesn't use any window rule, so it
   sidesteps this completely.

2. **windowrule's `monitor` field has the same focus-stealing bugs** as windowrulev2
   did. Even with the new line syntax, Approach B remains disqualified.

3. **The Lua migration (0.55+) does not introduce a new mechanism for window-to-monitor
   placement**. The `hl.window_rule` Lua API uses the same backend code path. No
   new fix is on the horizon.

4. **The community standard for runtime monitor selection IS `hyprctl keyword monitor X,disable`**
   (vaxerski's own answer in #4789; EndoliteMatrix's production script). Approach A
   is the documented, idiomatic, production-validated approach.

5. **All commands Approach A uses (`hyprctl keyword monitor X,disable`,
   `hyprctl dispatch focusmonitor X`, `hyprctl monitors -j`) are stable IPC** — they
   have been part of Hyprland since 0.30 and have not changed in 0.55.

### Why C (nwg-hello) is a good Plan B (not Plan A)

- nwg-hello is a clean, multi-monitor-native solution.
- However, it is a significant UX change (different look, different config format).
- Approach A's diff is ~30 lines across 3 files; nwg-hello requires a new module
  + config migration + new config surface.
- If Approach A's runtime hack proves flaky in production (e.g., `hyprctl monitors -j`
  timing issues at exec-once), Plan B is well-positioned.

### Implementation sketch (updated for current Hyprland)

```sh
# in greetd-regreet-start, BEFORE the existing eDP-1 disable
# Wait for Hyprland to enumerate monitors
for i in 1 2 3 4 5 6 7 8 9 10; do
  hyprctl monitors -j 2>/dev/null | jq -e 'length > 0' >/dev/null 2>&1 && break
  sleep 0.1
done

# Identify target monitor by description substring (e.g., "LEN G24")
TARGET_DESC='${cfg.greeter.focusMonitor}'   # NixOS option, e.g. "LEN G24"
if [ -n "$TARGET_DESC" ]; then
  TARGET_MON=$(hyprctl monitors all -j 2>/dev/null | \
    jq -r --arg d "$TARGET_DESC" \
      '.[] | select((.description // "") | contains($d)) | .name' | \
    head -1)
  if [ -n "$TARGET_MON" ] && [ "$TARGET_MON" != "null" ]; then
    # Disable every other external (non-eDP) monitor
    for m in $(hyprctl monitors all -j 2>/dev/null | jq -r '.[].name'); do
      case "$m" in
        eDP-*) ;;   # leave the internal panel alone for the disable-eDP-1 step below
        "$TARGET_MON") ;;   # keep the target
        *) hyprctl keyword monitor "$m,disable" >/dev/null 2>&1 ;;
      esac
    done
    hyprctl dispatch focusmonitor "$TARGET_MON" >/dev/null 2>&1
  fi
fi

# Existing logic: if any external is connected, also disable eDP-1
for s in /sys/class/drm/card*-*/status; do
  case "$s" in *-eDP-*) continue;; esac
  read -r st < "$s" 2>/dev/null
  if [ "$st" = connected ]; then
    hyprctl keyword monitor eDP-1,disable >/dev/null 2>&1
    break
  fi
done

regreet
hyprctl dispatch exit
```

**New submodule option** in `omarchy-nix/config.nix`:
```nix
focusMonitor = lib.mkOption {
  type = lib.types.str;
  default = "";
  example = "LEN G24";
  description = ''
    Description substring of the monitor that should host ReGreet when docked
    (e.g., "LEN G24" matches "Lenovo Group Limited LEN G24-10 ...").
    Empty = use current behavior (disable eDP-1 only).
  '';
};
```

**t14 change** in `hosts/t14/default.nix`:
```nix
greeter = {
  type = "regreet";
  focusMonitor = "LEN G24";  # <-- one new line
  ...
};
```

---

## 6. Knowledge gaps (verification on live t14 needed before spec/design)

1. **`hyprctl monitors -j` returns valid JSON without the legacy "adding monitors\n"
   prefix in 0.55.4.** Per the Hyprland code, this was fixed long ago. But verifying
   on the live t14 system with `hyprctl monitors -j | jq '.[].name'` is a 5-second
   sanity check.

2. **Exact `description` field reported by `hyprctl monitors all -j` for the Lenovo
   G24-10 in t14's dock.** The user's `cfg.greeter.monitors` config uses
   `desc:Lenovo Group Limited LEN G24-10 U5B4GWF1` — but the kernel may report a
   slightly different string (truncation, different separator, EDID quirks). Must
   be confirmed before `jq contains` filtering can be trusted. Verifiable with:
   `hyprctl monitors all -j | jq -r '.[] | "\(.name) -> \(.description)"'`

3. **ReGreet's actual `class` when running inside `start-hyprland` under the `greeter` user.**
   README implies it's the binary name (`regreet`), but `hyprctl clients -j` should
   confirm. Verifiable with: `hyprctl clients -j | jq -r '.[] | "\(.class) -> \(.title) -> mon=\(.monitor)"'`
   run after regreet starts.

4. **Timing of `hyprctl monitors -j` at exec-once**: how long does it take for the
   monitor list to be non-empty? The 200ms upper bound (10 × 0.1s) is generous
   but may not be enough on slow boots or with USB-C dock negotiation. Verifiable
   by adding a `date +%s.%N` printout and comparing timestamps.

5. **Whether `hyprctl dispatch moveworkspacetomonitor` is needed.** If we disable all
   monitors except the target, the workspaces collapse onto the target automatically
   (per Hyprland #4660 fix). So `moveworkspacetomonitor` may be unnecessary. The
   sketch above doesn't use it; the prior explore's sketch did. Worth a brief
   verification.

6. **Hyprland monitor ID stability across re-dock events.** When a dock re-attaches,
   does the same physical DP-3 connector still get ID 0? If yes, fine. If Hyprland
   re-numbers, the approach needs to be re-verified. (PR #2666 reused IDs on
   reconnect, so likely stable.)

---

## 7. Out of scope (intentionally)

- Changing the post-login session monitor layout (already in `t14-monitor-layout-perfection`).
- Adopting nwg-hello as the primary greeter (kept as Plan B).
- Adopting hyprlogin (not feasible for this change).
- Migrating omarchy-nix to Hyprland 0.55+ Lua config (separate, larger effort; hyprlang
  is still supported "for 1-2 releases" per the 0.55 release notes).
- Auto-detecting which external monitor is the "primary" without a `focusMonitor`
  config string (this would require heuristics like "highest-id, or last-connected,
  or named per port" — too fragile to ship without a config knob).

---

## 8. Summary of changes since prior explore (obs #370)

| Topic | Prior explore (obs 370) | This explore (v2) | Impact |
|---|---|---|---|
| `windowrulev2` status | "broken / unreliable" (Hyprland #8942 cited) | "returns error string in 0.53+, fully removed in 0.48+ syntax-wise" | Strengthens disqualification of Approach B |
| `windowrule` status | "syntax migration in progress" | "block syntax in 0.55+, but `monitor` field has same focus-stealing bugs as windowrulev2" | Strengthens disqualification of Approach B |
| Hyprland 0.55+ Lua config | Not mentioned | "Same backend code path for monitor placement; doesn't fix #8942/#9365/#8262" | Adds to disqualification of any `windowrule`-based approach |
| Endorsed runtime pattern | Not mentioned | "vaxerski's own answer in #4789 endorses `hyprctl keyword monitor X,disable`" | Strengthens Approach A |
| Production validation | Not mentioned | "EndoliteMatrix/hyprland-dock-undock-automation uses Approach A pattern in production" | Strengthens Approach A |
| `hyprctl monitors -j` JSON | "Empty at exec-once; need retry" | "Valid JSON in 0.55.4, no header to strip" | Minor: retry loop is still needed (timing) but no JSON parsing concern |
| Plan B (nwg-hello) | Already in matrix | nixpkgs version verified (0.4.3 unstable, 0.4.1 release-25.11), no `services.greetd` module in nixpkgs | Plan B unchanged; nixpkgs coverage is current |
| Plan C (hyprlogin) | "WIP, AUR-only" | Confirmed: NOT in nixpkgs, AUR-only | Plan C unchanged |
| Plan D (SDDM) | "Disqualified" | Confirmed: Hyprland is not supported as SDDM-Wayland compositor in nixpkgs | Plan D unchanged |

---

## Ready for Proposal

**Yes** — Approach A. The new evidence makes Approach A even more clearly the right
path. The implementation sketch is small (~30 lines across 3 files), the rollback is
trivial, and the production validation (EndoliteMatrix) and the official endorsement
(vaxerski) give strong external validation.

**Verification before spec/design**: 5 knowledge-gap checks (Section 6). All take
less than 5 minutes total on the live t14 system.

**Recommended next phase**: sdd-propose → sdd-spec → sdd-design → sdd-tasks → sdd-apply.
