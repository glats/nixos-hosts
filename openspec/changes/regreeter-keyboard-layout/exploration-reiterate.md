## Exploration (Reiterate): regreeter-keyboard-layout

### Problem

The waybar-based keyboard layout indicator at the t14 greeter is **invisible**. The waybar config uses `layer: "bottom"` which renders the bar **below** xdg-shell windows. ReGreet (a GTK4 app launched via greetd) runs as an xdg-shell window and covers the entire `bottom` layer, hiding the 24px bar completely.

User sees: login form with no waybar bar at all. The indicator exists but is rendered behind ReGreet.

### Root Cause — wlroots Layer-Shell z-ordering

The **wlr-layer-shell-unstable-v1** protocol defines 4 layers:

```
overlay (3)     ← above everything
top (2)         ← above xdg-shell
xdg-shell        ← ReGreet sits here
bottom (1)      ← below xdg-shell ← WHERE WAYBAR IS
background (0)  ← bottom-most
```

Confirmed from the official protocol spec (wayland.app/protocols/wlr-layer-shell-unstable-v1): "Traditional shell surfaces will typically be rendered between the bottom and top layers."

`layer = "bottom"` → waybar renders BELOW ReGreet → invisible. This is by protocol design, not a compositor bug.

### ReGreet Native Capabilities — NOTHING USABLE

**ReGreet has ZERO built-in keyboard layout display capability:**

- Sample TOML (`regreet.sample.toml`): only `[widget.clock]`, `[appearance]`, `[GTK]`, `[background]`, `[commands]`, `[env]`. No keyboard/layout widget.
- README explicitly: "For configuring other essential features, such as the keyboard layout/mapping... please check out the configuration options for the wayland compositor."
- No plugin system. No custom widget API.
- `extraCss` is static GTK CSS — CSS `::after` pseudo-elements can show static text only, no dynamic runtime values (layout name).
- ReGreet is Rust/Relm4 — forking to add a layout widget is Very High effort, disproportionate to showing two letters.
- `programs.regreet.settings` (NixOS option): TOML value, no layout-specific sub-options.

### Options Investigated

#### 1. Fix waybar layer: `bottom` → `top` (RECOMMENDED)

Change one line in waybar JSON config: `layer = "bottom"` → `layer = "top"`.

Also recommend changing `position = "bottom"` → `position = "top"` for better visibility (status bar conventionally at top).

**How it works technically**: With `layer = "top"`, waybar renders above xdg-shell windows (above ReGreet). With no `mode` set in config, `layer` is honored by waybar (waybar's `mode` option overrides `layer` only when explicitly set). Default `exclusive = true` creates a 24px exclusive zone — Hyprland reserves that space, pushing ReGreet's form slightly down. No overlap possible. Default `passthrough = false` absorbs clicks on the 24px strip; since the login form is centered ~400-660px Y on a 1080p screen, this is irrelevant.

Key waybar config options from official wiki:
- `layer`: `top` = "displayed in front of windows"
- `mode`: NOT set → `layer` is honored. Setting `mode` would override `layer`.
- `exclusive`: default `true` → creates exclusive zone, pushing xdg-shell windows away from the bar edge
- `passthrough`: default `false` → clicks on bar are NOT passed through. Irrelevant for our non-interactive label bar.

**Pros**:
- One-line fix (change `"bottom"` to `"top"`)
- waybar is already in closure, configured, and scripted
- `top` layer is the standard, well-tested layer for panels/bars
- `exclusive: true` ensures zero visual overlap with ReGreet
- No new dependencies, no new processes
- Keyboard interactivity is `none` by default — won't steal focus from ReGreet password field

**Cons**:
- ReGreet's login form appears 24px higher (centered in 1056px vs 1080px). Imperceptible.
- If the user session waybar is at the bottom, greeter waybar at the top creates an inconsistency (minor)

**Effort**: Trivial — literally changing two words in JSON (omarchy-nix/modules/nixos/system.nix line 40-41)

**Implementation**:
```diff
- layer = "bottom";
- position = "bottom";
+ layer = "top";
+ position = "top";
```

#### 2. waybar `layer: "overlay"` + `exclusive: false`

Overlay layer is above everything including other layer-shell surfaces. With `exclusive: false`, waybar doesn't claim space, ReGreet fills full screen, bar floats on top. Clicks pass through (keyboard interactivity: none).

**Pros**: No geometry changes for ReGreet. Bar floats above.
**Cons**: Overlay layer surfaces can interact with exclusive zones from bottom-layer surfaces (Hyprland issue #4162 documented this). Slightly less tested path. Bar background covers ReGreet's background image at top 24px.
**Effort**: Very Low — 3-line config change (layer + exclusive + passthrough)

#### 3. Hyprland window rule: `windowrule = move 0 24, .*` + layer `top`

Move ReGreet window down 24px via Hyprland window rule, place waybar at top with `layer = "top"`.

**Pros**: Allows waybar at top without exclusive zone.
**Cons**: window rule affects all windows in greeter session. ReGreet class/title may change between versions. Fragile regex. The exclusive zone approach is cleaner.
**Effort**: Low

#### 4. `hyprctl notify` on Alt+Shift toggle

Replace XKB `grp:alt_shift_toggle` with custom Hyprland keybind that switches layout AND shows a temporary notification toast via `hyprctl notify`. The notification shows "ES" or "LATAM" for a few seconds.

`hyprctl notify -1 3000 "rgb(ff1ea3)" "ES"` — works in the greeter Hyprland session (pure compositor feature, no notification daemon needed).

**Pros**: Works without any overlay/bar at all. Built into Hyprland.
**Cons**: Shows only brief notification, not persistent indicator. Requires replacing XKB-level toggle with compositor-level keybind (`bind = ALT, Shift_L, exec, ...`). Two-step toggle (need to read current layout, compute target, dispatch switch). Brittle — if the notification is missed, user doesn't know layout. Does not meet the persistent-display requirement.
**Effort**: Medium — need to wrap toggle in script

#### 5. GTK overlay window (yad/zenity)

Launch a small GTK window showing the layout, positioned via Hyprland window rules.

**Pros**: Works without waybar dependency.
**Cons**: GTK portals in greeter session cause dbus timeout deadlocks (`GTK_USE_PORTAL=0` needed). yad is GTK3, may conflict with GTK4 (ReGreet). Polling loop in shell script is fragile. May steal focus. Over-engineered for two letters.
**Effort**: Medium-High

#### 6. Patch ReGreet source

Fork ReGreet, add GTK widget reading compositor layout state.

**Pros**: Most integrated solution.
**Cons**: Rust/GTK4 development. Maintaining fork. Disproportionate to value.
**Effort**: Very High — impractical

#### 7. Do nothing

Layout toggle (Alt+Shift) works, just no visual feedback. Two layouts means pressing once always toggles.

**Pros**: Zero effort.
**Cons**: Fails explicit user requirement. User cannot confirm layout before typing password.

### Recommendation

**Approach 1: Fix layer to `top` + position to `top`**

This is a trivial fix — literally changing two words in the waybar JSON config. It addresses the root cause (wrong z-order) directly. All existing infrastructure (polling script, CSS, Hyprland config generation, startup delay, `GTK_USE_PORTAL=0`) remains unchanged. No new dependencies or processes.

The `top` layer is the correct layer per the wlroots protocol for a panel/bar that should be "in front of windows". With `exclusive: true` (default), Hyprland reserves 24px, ensuring zero visual overlap between the bar and ReGreet. With keyboard interactivity `none` (default for waybar), the bar doesn't steal focus from ReGreet's password field.

**Files to change**:
| Repo | File | Line(s) | Change |
|------|------|---------|--------|
| omarchy-nix | `modules/nixos/system.nix` | 40-41 | `"bottom"` → `"top"` (both layer and position) |

That's it. One file, two words. Single-repo change (omarchy-nix). nixos-hosts needs no changes — it just consumes the updated omarchy-nix version.

### Why Not Overlay Layer?

`layer: "overlay"` would also work, but:
1. Overlay is intended for notifications/OSDs, not persistent panels
2. `exclusive: false` means no geometry reservation — ReGreet fills full screen, bar floats on top, covering background
3. With `exclusive: false`, waybar's background (rgba(30,30,46,0.9)) covers the top 24px of ReGreet's background image
4. Less tested path than `top` for persistent panels
5. `top` with `exclusive: true` is the standard, well-tested panel configuration

### Implementation Sketch

**omarchy-nix** (`modules/nixos/system.nix`, lines 40-41):
```diff
  waybarGreeterConfig = pkgs.writeText "waybar-greeter-config" (
    builtins.toJSON {
-     layer = "bottom";
-     position = "bottom";
+     layer = "top";
+     position = "top";
      height = 24;
```

Then bump the omarchy-nix flake input in nixos-hosts `flake.nix` to include the updated commit.

Everything else (the polling script, CSS, env vars, exec-once, startup delay, `environment.etc` entries) stays exactly as-is.

### Risks

- **Waybar mode override**: waybar's `mode` option overrides `layer` when explicitly set. Current config does NOT set `mode`, so `layer` is honored. No risk.
- **Keyboard interactivity**: waybar defaults to `none` — won't steal keyboard focus. ReGreet (xdg-shell) gets normal focus. No risk.
- **Exclusive zone edge cases**: On multi-monitor setups, exclusive zone applies per-monitor. The greeter Hyprland config already handles monitor selection — waybar on the greeter monitor only. No risk.
- **Click passthrough**: 24px strip at top of screen absorbs clicks (but only on the bar area). ReGreet's login form is centered and well below. No practical impact.
- **Non-t14 hosts unaffected**: This is an omarchy-nix change, but `layoutIndicator` is gated on both `greeter.type == "regreet"` AND `layoutIndicator.enable`. Non-t14 hosts don't enable it. No risk.

### Verification Plan

1. `nix flake check --no-build` on omarchy-nix (passes)
2. Rebuild t14: waybar bar visible at top of login screen showing "ES" or "LATAM"
3. Press Alt+Shift: label updates within 1-2s
4. Type password: ReGreet form works, no focus steal
5. Verify non-t14 hosts: `nix flake check --no-build` for rog, thinkcentre, mact2 (all pass)
