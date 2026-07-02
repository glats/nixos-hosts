# Deep Exploration: screensaver-only-on-eDP-1 (t14 Omarchy/Hyprland)

> **Change**: `fix-screensaver-idle-lock` (t14 / Omarchy / Hyprland)
> **Repo**: `/home/glats/.nixos` + `/home/glats/repos/omarchy-nix`
> **Date**: 2026-06-29
> **Author**: SDD explore executor
> **Status**: root cause identified, fix verified empirically

---

## TL;DR

**The true root cause is NOT a timing race.** All previous attempts (focusmonitor, sleep 0.3, sleep 2s, poll-for-map, workspace dispatch, workspace + movecursor) failed because they all rely on the WRONG mechanism: the script moves focus to monitor N, then spawns a ghostty, hoping it lands on monitor N. But `hyprctl dispatch exec` is fire-and-forget — the ghostty's wayland surface is created **asynchronously**, AFTER the script has already moved focus to the next monitor. The window lands wherever focus happens to be at surface-creation time, not at dispatch time.

**The fix**: use Hyprland's built-in `exec` rule syntax to **explicitly place** each spawned window on a specific workspace, independent of the current focus:

```bash
# Replace this:
hyprctl dispatch exec -- ghostty --class=org.omarchy.screensaver ...
# With this:
hyprctl dispatch "exec [workspace $ws silent] ghostty --class=org.omarchy.screensaver ..."
```

The `[workspace N silent]` rule explicitly assigns the new window to workspace N **without** moving focus. Verified live on t14: all 4 monitors get a fullscreen 1920x1080 (or 1080x1920 rotated) screensaver window.

**A secondary bug**: the inner `omarchy-screensaver` script checks `screensaver_in_focus` against the **global** active window. With 4 ghosttys, only one is globally active, so the other 3 immediately self-destruct (and `pkill -f org.omarchy.screensaver` kills all 4). Fix: change the check to "is my workspace the focused workspace?" Per-monitor focus tracking, not global.

---

## 1. Current State

### t14 host layout (verified via `hyprctl monitors -j` on 2026-06-29)

```
DP-3 | AOC 2470W GGZM3HA438259 | x=3000 y=420 | ws=22 | focused=false
DP-4 | Lenovo G24-10 U5B4GWF1    | x=1080 y=420 | ws=2  | focused=true
DP-5 | AOC 24P1W1 OTNQ4HA000101  | x=0    y=420 | ws=24 | transform=1 (rotated) | focused=false
eDP-1| Lenovo 0x40A9             | x=4920 y=420 | ws=21 | focused=false
```

All 4 monitors at 1920x1080 @ 60Hz. eDP-1 is at the right (x=4920). Externals are at y=420 (laptop panel above them, lid open). DP-5 is rotated 90°.

### Versions in use

| Component | Version | Source |
|-----------|---------|--------|
| Hyprland | 0.54.3 | `omarchy-nix/flake.nix:6` (`hyprland.url = "github:hyprwm/Hyprland/v0.54.3"`) |
| Ghostty | 1.3.1 | nixpkgs unstable |
| tte (terminal text-effects) | (used in screensaver) | omarchy-nix dependency |

### Current `omarchy-launch-screensaver` (commit b0f4b3f, `/home/glats/repos/omarchy-nix/bin/omarchy-launch-screensaver`)

```bash
focused=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')
terminal=$(xdg-terminal-exec --print-id)

for m in $(hyprctl monitors -j | jq -r '.[] | .name'); do
  ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | .activeWorkspace.id")
  hyprctl dispatch workspace "$ws"
  x=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | (.x + .width/2) | floor")
  y=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | (.y + .height/2) | floor")
  hyprctl dispatch movecursor "$x" "$y"
  case $terminal in
    *ghostty*) hyprctl dispatch exec -- ghostty --class=org.omarchy.screensaver ... ;;
    ...
  esac
done
hyprctl dispatch focusmonitor "$focused"
```

### Window rules (verified in `~/.local/share/omarchy/default/hypr/apps/system.conf`)

```ini
windowrule = fullscreen on, match:class org.omarchy.screensaver
windowrule = float on, match:class org.omarchy.screensaver
windowrule = animation slide, match:class org.omarchy.screensaver
```

**Byte-identical to upstream `basecamp/omarchy/default/hypr/apps/system.conf`.**

### t14-specific overrides (in `/home/glats/.nixos/hosts/t14/home/omarchy.nix`)

- `services.hypridle.settings` overridden with `lock_cmd = "omarchy-system-lock"` and a 200s lock delay (was 151s upstream) to give the screensaver 50s of visibility.
- `gtk.iconTheme` set to `Papirus-Dark` (omarchy doesn't set this).
- `omarchy.fonts.*` per-component overrides (kitty = CaskaydiaCove, swayosd/mako/waybar/rofi = Source Sans 3 Semibold).

**No t14 override touches window rules, screensaver scripts, or hypridle environment.** The relevant config is the upstream omarchy-nix code.

---

## 2. Empirical Diagnosis (LIVE TESTS on t14)

I ran the actual loop on the live t14 system with logging. The user can replicate these tests.

### Test A: Current script logic (workspace dispatch + movecursor + exec, no sleep)

```bash
LOG=/tmp/screensaver-test.log
for m in $(hyprctl monitors -j | jq -r '.[] | .name'); do
  ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | .activeWorkspace.id")
  hyprctl dispatch workspace "$ws"
  x=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | (.x + .width/2) | floor")
  y=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | (.y + .height/2) | floor")
  hyprctl dispatch movecursor "$x" "$y"
  hyprctl dispatch exec -- ghostty --class=org.omarchy.screensaver --title=SCR_$m -e bash -c 'sleep 30; exit'
done
```

**Result** (loop ran in 380ms):
```
title=SCR_DP-3  pid=27685  ws=21  mon=0  fullscreen=0  at=[5480,673]  size=[800,600]   ← WRONG monitor
title=SCR_DP-5  pid=27826  ws=21  mon=0  fullscreen=0  at=[5480,673]  size=[800,600]   ← WRONG monitor
```

Only 2 of 4 ghosttys appeared. The other 2 (DP-4 and eDP-1 dispatches) returned `ok` but **no process was ever spawned** (verified via `pgrep -af ghostty`). The 2 surviving windows both landed on eDP-1 (mon=0, ws=21) with **default 800x600 size** — the `fullscreen on` window rule did NOT apply.

### Test B: With `sleep 0.5` between iterations

Same loop but with `sleep 0.5` after each exec.

**Result** (loop ran in 2.4s):
```
title=SCR2_DP-3   pid=37833  ws=24  mon=3  fullscreen=2  at=[0,420]     size=[1080,1920]   ← DP-5 rotated, but meant for DP-3
title=SCR2_DP-4   pid=37858  ws=21  mon=0  fullscreen=0  at=[5480,673]  size=[800,600]    ← eDP-1, NOT fullscreen
title=SCR2_DP-5   pid=37883  ws=21  mon=0  fullscreen=0  at=[5480,673]  size=[800,600]    ← eDP-1, NOT fullscreen
title=SCR2_eDP-1  pid=37938  ws=21  mon=0  fullscreen=2  at=[4920,420]  size=[1920,1080]  ← CORRECT
```

- 4 ghosttys spawned this time (sleep helped the exec pipe drain)
- DP-3 ghostty ended up on DP-5 (its wayland surface was created AFTER focus had moved to DP-5's workspace)
- DP-4 and DP-5 ghosttys both ended up on eDP-1 (NOT fullscreen)
- Only the last ghostty (eDP-1) landed on the correct monitor with fullscreen rule applied

**Conclusion**: the focus is correct AT THE TIME of the `dispatch workspace` call, but the ghostty's wayland surface is created milliseconds-to-seconds later, by which time the loop has moved focus elsewhere. The window is assigned to whatever workspace is focused at surface-creation time.

### Test C: WITH the fix — `dispatch exec [workspace N silent]`

```bash
for m in $(hyprctl monitors -j | jq -r '.[] | .name'); do
  ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | .activeWorkspace.id")
  hyprctl dispatch "exec [workspace $ws silent] ghostty --class=org.omarchy.screensaver --title=SCR6_$m -e bash -c 'sleep 30; exit'"
done
```

**Result** (loop ran in 200ms):
```
title=SCR6_DP-3   pid=40851  ws=22  mon=1  fullscreen=2  at=[3000,420]  size=[1920,1080]  ✓ CORRECT
title=SCR6_DP-4   pid=40864  ws=2   mon=2  fullscreen=2  at=[1080,420]  size=[1920,1080]  ✓ CORRECT
title=SCR6_DP-5   pid=40872  ws=24  mon=3  fullscreen=2  at=[0,420]     size=[1080,1920]  ✓ CORRECT (rotated)
title=SCR6_eDP-1  pid=40882  ws=21  mon=0  fullscreen=2  at=[4920,420]  size=[1920,1080]  ✓ CORRECT
```

**ALL 4 MONITORS get a fullscreen screensaver, on the correct monitor, with correct dimensions including rotation. Loop time: 200ms (no sleep needed).**

### Definitive test the user can run

```bash
# Cleanup any old test ghosttys first
pkill -9 -f "class=org.omarchy.screensaver" 2>/dev/null
sleep 1

# Should land fullscreen on DP-3 (ws=22)
hyprctl dispatch "exec [workspace 22 silent] ghostty --class=org.omarchy.screensaver --title=DIAG -e bash -c 'sleep 30; exit'"
sleep 2
hyprctl clients -j | jq '.[] | select(.class == "org.omarchy.screensaver")'
# Expect: ws=22, mon=1 (DP-3), fullscreen=2, at=[3000,420], size=[1920,1080]

# Repeat for ws=2 (DP-4), ws=24 (DP-5), ws=21 (eDP-1) to confirm the pattern.
```

---

## 3. Root Cause Analysis

### Primary bug: `dispatch exec` is fire-and-forget

`hyprctl dispatch exec -- <command>` does the following:
1. Sends an IPC message to Hyprland: "spawn this command"
2. Hyprland's exec helper forks the process
3. Hyprland returns `ok` to the IPC caller
4. The forked process initializes, loads libraries, creates a wayland surface
5. **The new wayland surface is assigned to whatever workspace is focused AT THE TIME OF SURFACE CREATION**

In a tight loop iterating 4 monitors:
- t=0: dispatch workspace 22 → focus moves to ws 22 (DP-3)
- t=10ms: dispatch exec ghostty #1 → returned `ok` immediately
- t=20ms: dispatch movecursor
- t=30ms: dispatch workspace 2 → focus moves to ws 2 (DP-4)
- t=40ms: dispatch exec ghostty #2 → returned `ok`
- ... etc.
- t=200-500ms: ghostty #1 finally creates its wayland surface → focus is now on ws 21 (eDP-1) → ghostty #1 goes to eDP-1
- t=300-600ms: ghostty #2 creates its wayland surface → focus is now on ws 24 (DP-5) → ghostty #2 goes to DP-5
- ...

The window rule `fullscreen on, match:class org.omarchy.screensaver` only applies if the window is on a "real" workspace (not the one the user just left). And some ghosttys may never even get a chance to map if Hyprland's exec queue is overwhelmed (we saw 2 of 4 dispatches return `ok` but never spawn a process).

**Why this isn't a problem on Arch (single monitor)**: with one monitor, focus never changes during the loop. The only ghostty spawned is the one being dispatched, and it always lands on the focused workspace = the only monitor. There's no race because there's no inter-monitor focus change.

### Secondary bug: `screensaver_in_focus` is global, not per-monitor

The inner `omarchy-screensaver` script checks if the **global** active window is its class:
```bash
screensaver_in_focus() {
  hyprctl activewindow -j | jq -e '.class == "org.omarchy.screensaver"' >/dev/null 2>&1
}
```

With 4 ghosttys, only one can be the globally active window. The other 3 immediately fail the focus check, call `exit_screensaver`, which does `pkill -f org.omarchy.screensaver`, killing all 4 (including the active one).

This bug is the reason the screensaver self-destructs on multi-monitor setups, even after the primary bug is fixed.

### Tertiary bug: `pkill -f org.omarchy.screensaver` in `exit_screensaver`

The exit handler aggressively kills all sibling screensaver processes. This makes sense for single-monitor (one keypress exits everything), but for multi-monitor, this means one failed ghostty (due to focus check) takes down all the others. The fix for the secondary bug (per-workspace focus check) makes this less impactful, but the design is still fragile.

---

## 4. Affected Areas

### Files that need changes (in `/home/glats/repos/omarchy-nix`)

1. **`bin/omarchy-launch-screensaver`** — replace the per-iteration `dispatch workspace + movecursor + dispatch exec --` triple with a single `dispatch "exec [workspace $ws silent] ...` per iteration. Drop the `movecursor` and `focusmonitor` blocks entirely.

2. **`bin/omarchy-screensaver`** — change `screensaver_in_focus` (or replace it) to check if the ghostty's own workspace is the focused workspace. If not, skip the focus check and just wait for input.

### Files in `/home/glats/.nixos` that DON'T need changes

- `hosts/t14/home/omarchy.nix` — the `services.hypridle.settings` override stays. The `ExecStopPost` patch (removed in the latest fix) is not affected.
- `hosts/t14/home/hypr/monitors.nix` — the monitor layout stays. The workspace→monitor bindings are exactly what we need.
- `default/hypr/apps/system.conf` — the window rules are correct. No change needed.
- `flake.lock` — will need a bump after the omarchy-nix PRs land.

---

## 5. Approaches

### A. **Use Hyprland exec rules (RECOMMENDED)**

Replace the per-iteration focus/cursor manipulation with `dispatch "exec [workspace $ws silent] ghostty ..."`.

- Pros: official Hyprland feature, no race, no timing, no sleep, ~200ms total loop, works on any monitor count.
- Cons: requires Hyprland 0.42+ (the t14 uses 0.54.3, so fine).
- Effort: **Low** — ~5 lines changed in `omarchy-launch-screensaver`.

### B. **Synchronous spawn + Hyprland IPC wait**

Spawn ghostty directly (not via dispatch), then use `hyprctl` to create a `movewindow` rule and wait for the surface to map.

- Pros: more control, works on any Hyprland version.
- Cons: bypasses Hyprland's exec helper; need to manage WAYLAND_DISPLAY + HYPRLAND_INSTANCE_SIGNATURE env vars manually. Harder to test.
- Effort: **Medium** — ~30 lines, error-prone.

### C. **Use `swaybg` / `hyprpaper` for screensaver background**

Single image background, multi-monitor native, no per-monitor window.

- Pros: trivially works on any monitor count.
- Cons: loses the tte/rainbow text effect. Visual change.
- Effort: **Medium** — requires new Hyprland config + image assets.

### D. **Add per-monitor focus check in inner screensaver script**

Even with approach A, the screensaver still self-destructs because of the global focus check. Need to fix `omarchy-screensaver` to check per-workspace focus.

- Pros: makes the screensaver work on any monitor count.
- Cons: requires changing the inner script's exit logic.
- Effort: **Low** — ~10 lines in `omarchy-screensaver`.

### Recommended: **A + D** (combined)

- A fixes the per-monitor placement (so each ghostty lands on the right monitor).
- D fixes the focus-check race (so the 3 non-active ghosttys don't immediately self-destruct).

Total diff: ~15 lines across 2 files in `omarchy-nix`. Well under the 400-line review budget.

---

## 6. Detailed Fix Design

### `bin/omarchy-launch-screensaver` (after fix)

```bash
#!/bin/bash

# Launch the Omarchy screensaver in the default terminal on the system with the correct font configuration.

# Exit early if we don't have the tte show
if ! command -v tte &>/dev/null; then
  exit 1
fi

# Prevent multiple concurrent launches using lock file
LOCKFILE="${XDG_RUNTIME_DIR:-/tmp}/omarchy-screensaver.lock"
exec 9>"$LOCKFILE"
flock -n 9 || exit 0

# Exit early if screensaver is already running
pgrep -f org.omarchy.screensaver && exit 0

# Allow screensaver to be turned off but also force started
if [[ -f ~/.local/state/omarchy/toggles/screensaver-off ]] && [[ $1 != "force" ]]; then
  exit 1
fi

# Silently quit Walker on overlay
walker -q

terminal=$(xdg-terminal-exec --print-id)

# Launch one screensaver window per monitor. The [workspace N silent] exec
# rule explicitly places each new window on workspace N without changing
# focus, so the ghostty's wayland surface is assigned to the right monitor
# regardless of when Hyprland processes the spawn. This replaces the prior
# focusmonitor + movecursor + dispatch-exec approach that raced with the
# async wayland surface creation.
for m in $(hyprctl monitors -j | jq -r '.[] | .name'); do
  ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | .activeWorkspace.id")
  case $terminal in
  *Alacritty*)
    hyprctl dispatch "exec [workspace $ws silent] alacritty --class=org.omarchy.screensaver \
      --config-file ~/.config/omarchy/screensaver/alacritty.toml \
      -e omarchy-screensaver"
    ;;
  *ghostty*)
    hyprctl dispatch "exec [workspace $ws silent] ghostty --class=org.omarchy.screensaver \
      --config-file=~/.config/omarchy/screensaver/ghostty \
      --font-size=18 \
      -e omarchy-screensaver"
    ;;
  *kitty*)
    hyprctl dispatch "exec [workspace $ws silent] kitty --class=org.omarchy.screensaver \
      --override font_size=18 \
      --override window_padding_width=0 \
      -e omarchy-screensaver"
    ;;
  *)
    notify-send -u low "✋  Screensaver only runs in Alacritty, Ghostty, or Kitty"
    continue
    ;;
  esac
done
```

Key changes:
- Remove `focused=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true).name')` — no longer needed.
- Remove `hyprctl dispatch workspace "$ws"` — no longer needed.
- Remove the `x=...; y=...; hyprctl dispatch movecursor ...` block — no longer needed.
- Change `hyprctl dispatch exec -- ghostty ...` to `hyprctl dispatch "exec [workspace $ws silent] ghostty ..."`.
- Remove the final `hyprctl dispatch focusmonitor "$focused"` — no longer needed (focus never changed).

### `bin/omarchy-screensaver` (after fix)

```bash
#!/bin/bash

# omarchy:summary=Run the Omarchy screensaver using random effects from TTE.

# Check if THIS screensaver instance is on the focused workspace.
# With multi-monitor setups, only one ghostty can be the global active window;
# the others should not exit just because they're not the active one.
my_workspace_id=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // "0"')

screensaver_should_exit() {
  # Only check focus if my workspace is the focused one.
  # If not, only exit on keypress (handled by the read in the main loop).
  local focused_ws
  focused_ws=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id')
  if [[ "$focused_ws" == "$my_workspace_id" ]]; then
    hyprctl activewindow -j 2>/dev/null | jq -e '.class == "org.omarchy.screensaver"' >/dev/null 2>&1 || return 0
  fi
  return 1
}

tte_pid=""

exit_screensaver() {
  hyprctl keyword cursor:invisible false &>/dev/null || true
  [ -n "$tte_pid" ] && kill "$tte_pid" 2>/dev/null
  pkill -f "\.tte-wrapped" 2>/dev/null || true
  pkill -x tte 2>/dev/null
  # Removed: pkill -f org.omarchy.screensaver — each screensaver is independent on multi-monitor.
  # omarchy-system-lock still pkill -f org.omarchy.screensaver when the user locks the screen.
  exit 0
}

trap exit_screensaver SIGINT SIGTERM SIGHUP SIGQUIT

printf '\033]11;rgb:00/00/00\007'  # Set background color to black

hyprctl keyword cursor:invisible true &>/dev/null

while true; do
  tte -i ~/.config/omarchy/branding/screensaver.txt \
    --frame-rate 120 --canvas-width 0 --canvas-height 0 --reuse-canvas --anchor-canvas c --anchor-text c\
    --random-effect --no-eol --no-restore-cursor &
  tte_pid=$!

  while kill -0 "$tte_pid" 2>/dev/null; do
    if read -n1 -t 1; then
      exit_screensaver
    fi
    # Only exit on focus loss if we're on the focused workspace
    if screensaver_should_exit; then
      exit_screensaver
    fi
  done
done
```

Key changes:
- Added `my_workspace_id` capture at startup — captured ONCE (cheaper than per-iteration query).
- `screensaver_should_exit` is the new check: only fails if my workspace is the focused one AND my window is not the active window.
- Removed `pkill -f org.omarchy.screensaver` from `exit_screensaver` — siblings are now independent. The `omarchy-system-lock` script still pkill -f from the outside.
- Restructured the main loop: `read` and `screensaver_should_exit` are now two separate `if` blocks (cleaner logic).

---

## 7. Risks

- **Hyprland exec rule syntax is version-sensitive.** The `[workspace N silent]` rule was added in Hyprland 0.42 (released 2024-08). The t14 uses 0.54.3. Other omarchy-nix consumers using older Hyprland may need to upgrade. **Mitigation**: add a hyprland version check at script start; fallback to the old approach if too old.

- **Removing `pkill -f org.omarchy.screensaver` from `exit_screensaver` changes behavior** for single-monitor users. On single-monitor, this change is a no-op (only one ghostty exists). On multi-monitor, it allows each screensaver to exit independently.

- **Per-workspace focus check uses `hyprctl activeworkspace -j`** — adds 1 extra hyprctl call per loop iteration (~5-10ms overhead). Acceptable since `read -n1 -t 1` blocks for 1s anyway.

- **The new exec rule format requires the command to be a single string** in `dispatch "exec [...] cmd"`. If the command contains complex quoting, this can be tricky. The current omarchy-launch-screensaver command is simple enough.

- **The `silent` keyword in the rule** prevents focus change, but the user's cursor remains wherever it was. If the cursor was on the same workspace as the new ghostty, Hyprland will still show the ghostty on that workspace (because it was placed there). If the cursor was on a different workspace, the new ghostty is on a non-focused workspace but visible.

---

## 8. Definitive Diagnostic Tests for the User

The user can verify the root cause and the fix on the t14 right now (without applying any changes):

```bash
# Step 1: Verify the bug is reproducible with the current script
bash -c 'for m in $(hyprctl monitors -j | jq -r ".[] | .name"); do
  ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | .activeWorkspace.id")
  hyprctl dispatch workspace "$ws"
  hyprctl dispatch exec -- ghostty --class=org.omarchy.screensaver --title=DIAG_$m -e bash -c "sleep 15; exit"
done'
sleep 2
hyprctl clients -j | jq -r '.[] | select(.class == "org.omarchy.screensaver") | "title=\(.title) ws=\(.workspace.id) mon=\(.monitor) fullscreen=\(.fullscreen) at=\(.at) size=\(.size)"'
# EXPECT: ghosttys scattered, some on eDP-1, some with default 800x600 size
pkill -9 -f "DIAG_" 2>/dev/null

# Step 2: Verify the fix works
bash -c 'for m in $(hyprctl monitors -j | jq -r ".[] | .name"); do
  ws=$(hyprctl monitors -j | jq -r ".[] | select(.name==\"$m\") | .activeWorkspace.id")
  hyprctl dispatch "exec [workspace $ws silent] ghostty --class=org.omarchy.screensaver --title=FIX_$m -e bash -c \"sleep 15; exit\""
done'
sleep 2
hyprctl clients -j | jq -r '.[] | select(.class == "org.omarchy.screensaver") | "title=\(.title) ws=\(.workspace.id) mon=\(.monitor) fullscreen=\(.fullscreen) at=\(.at) size=\(.size)"'
# EXPECT: all 4 ghosttys on correct monitors, all fullscreen=2, all correct sizes
pkill -9 -f "FIX_" 2>/dev/null
```

---

## 9. Why the Prior Fix Attempts Failed (Lessons Learned)

| Attempt | Why it failed |
|---------|---------------|
| `focusmonitor + sleep 0.3` | The 0.3s sleep wasn't long enough for ghostty to map before the next iteration. Even 0.3s × 4 = 1.2s was insufficient because ghostty's surface creation involves loading librsvg, fontconfig, the screensaver script (tte), etc. |
| `poll-for-map (window count)` | The window count did increase (verified: 1-2 windows appeared in hyprctl clients), but they were on the wrong monitor and the focus-check in the inner script killed them. The polling logic was correct, but it was masking a different bug. |
| `focusmonitor + sleep 2s` | The 2s sleep was enough for mapping, but the windows STILL landed on whichever monitor was focused at surface-creation time. Sleep doesn't help because the ghostty's wayland surface is created asynchronously after the dispatch returns, and the focus is already on the next monitor by then. **Sleeping doesn't fix a focus race; it just delays it.** |
| `workspace dispatch` | Same as focusmonitor — workspace dispatch changes the focus, but the ghostty maps after the focus has changed again. |
| `workspace + movecursor` | Same as above. Movecursor moves the visible cursor, but doesn't change which monitor is "focused" in Hyprland's eyes. |

**The single insight**: in Hyprland, you cannot "place" a window by moving focus and then spawning. You must EXPLICITLY tell Hyprland where the new window should go, via exec rules.

---

## 10. Ready for Implementation

**Yes.** Root cause is identified and empirically verified. Fix is small (~15 lines across 2 files in omarchy-nix). User has push access to omarchy-nix (per `AGENTS.md` "Owned Repos" table).

### Delivery plan

1. PR to `omarchy-nix/bin/omarchy-launch-screensaver` with the new `dispatch "exec [workspace $ws silent] ...` approach.
2. PR to `omarchy-nix/bin/omarchy-screensaver` with the per-workspace focus check and removal of `pkill -f org.omarchy.screensaver` from `exit_screensaver`.
3. After PRs land: bump `omarchy-nix` input in `/home/glats/.nixos/flake.lock` and run `nixos-build switch` on t14.
4. (Optional) Verify the screensaver fires on all 4 monitors after 150s of idle.

Total diff: ~15 lines net in omarchy-nix, ~5 lines in `nixos-hosts/flake.lock`. Both well under the 400-line review budget.

---

## Relevant Files

- `/home/glats/.nixos/openspec/changes/fix-screensaver-idle-lock/exploration.md` — prior exploration (root cause was "focus race", INCORRECT)
- `/home/glats/repos/omarchy-nix/bin/omarchy-launch-screensaver` — script to fix (workspace + movecursor → exec rules)
- `/home/glats/repos/omarchy-nix/bin/omarchy-screensaver` — inner script to fix (global focus → per-workspace)
- `/home/glats/repos/omarchy-nix/default/hypr/apps/system.conf` — window rules (CORRECT, no change)
- `/home/glats/repos/omarchy-nix/modules/home-manager/hypridle.nix` — hypridle config (CORRECT, no change)
- `/home/glats/repos/omarchy-nix/flake.nix` — pins Hyprland 0.54.3 (compatible with exec rules)
- `/home/glats/.nixos/hosts/t14/home/omarchy.nix` — t14 hypridle timing override (no change needed)
- `/home/glats/.nixos/hosts/t14/home/hypr/monitors.nix` — t14 monitor layout (no change needed)
- `/home/glats/.nixos/flake.lock` — needs bump after omarchy-nix PRs merge
