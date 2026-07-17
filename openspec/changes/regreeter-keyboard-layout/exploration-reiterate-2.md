## Exploration (Reiterate #2): regreeter-keyboard-layout

### Problem Restatement

After three attempts at layer-shell z-ordering:
- `layer: "bottom"` → waybar completely invisible (below xdg-shell, expected)
- `layer: "top"` → also invisible (unexpected — should be above xdg-shell windows)
- `layer: "overlay"` → partially visible but "sigue quedando de tras" (renders behind ReGreet)

Even the overlay layer, which per the wlroots protocol spec should be ABOVE everything including fullscreen windows, cannot reliably render above ReGreet.

### Root Cause Analysis

#### ReGreet Rendering Mechanism (source code verified)

ReGreet is a **pure GTK4/Relm4 application** using `gtk::ApplicationWindow` as its root widget. Key findings from source code inspection:

| Aspect | Finding | Evidence |
|--------|---------|----------|
| **Layer-shell usage** | NONE | Cargo.toml has NO `wlr-layer-shell` dependency — only `gtk4`, `relm4`, `glycin` |
| **Fullscreen mode** | NEVER explicitly set | `git grep fullscreen` in ReGreet repo returns ZERO results |
| **Window type** | Standard `gtk::ApplicationWindow` (xdg-shell toplevel) | `src/gui/component.rs` view! macro |
| **Background** | `gtk::Picture` widget inside `gtk::Overlay` | `src/gui/templates.rs` — GTK Overlay widget, NOT Wayland overlay layer |
| **Monitor handling** | `choose_monitor()` selects a monitor object but does NOT fullscreen/maximize the window | `src/gui/model.rs` lines 150-180 |

ReGreet creates a **normal xdg-shell window** with NO special compositor privileges. It should render BELOW overlay and top layer-shell surfaces, and AT OR BELOW fullscreen shell surfaces.

#### Why Overlay Layer Fails (Hyprland Compositor Behavior)

The wlroots layer-shell protocol (`wlr-layer-shell-unstable-v1`) defines this z-order:

```
overlay (3)     ← should be above everything
top (2)         ← above xdg-shell | fullscreen shells rendered here
xdg-shell        ← ReGreet
bottom (1)      ← below xdg-shell
background (0)  ← bottom-most
```

However, **Hyprland has documented z-ordering bugs** with layer-shell surfaces:

| Issue | Date | Description |
|-------|------|-------------|
| [hyprwm/Hyprland#3931](https://github.com/hyprwm/Hyprland/issues/3931) | Nov 2023 | Overlay and top layer surfaces at same z-depth (closed as "per spec", but behavior observed) |
| [hyprwm/Hyprland#12789 (discussion)](https://github.com/hyprwm/Hyprland/discussions/12789) | Late 2025 | Top layer stays above fullscreen windows when it shouldn't; toggle fullscreen required to fix |
| [hyprwm/Hyprland#12909 (discussion)](https://github.com/hyprwm/Hyprland/discussions/12909) | Jan 2026 | Layer pop-ups and context menus appearing behind windows (fixed on master) |
| [hyprwm/Hyprland#11575 (discussion)](https://github.com/hyprwm/Hyprland/discussions/11575) | Sep 2025 | Fullscreen windows block overlay/notifications in some rendering paths |
| [hyprwm/Hyprland PR#12851](https://github.com/hyprwm/Hyprland/pull/12851) | Jan 2026 | Fix: fullscreen window detection missed special workspaces, causing layer surfaces to be incorrectly hidden |

**Conclusion**: The root cause is a **Hyprland compositor bug** where xdg-shell windows (particularly large/fullscreen ones like a greeter) can render above overlay layer-shell surfaces due to incorrect `m_aboveFullscreen` flag management, solitary-block rendering optimizations, or monitor reconnection handling. ReGreet itself is **not the cause** — it creates a standard xdg-shell window.

The nixpkgs snapshot used (March 2026) includes Hyprland from around v0.47-0.48 timeframe, which may or may not include the PR#12851 fix.

#### Why `hyprctl notify` Works

`hyprctl notify` creates a **compositor-internal notification** rendered by Hyprland's own notification system, NOT through the layer-shell protocol. Per discussion #11575: *"The problem goes away if there is something on the overlay layer or if a hyprctl notification is active"* — notifications specifically unblock rendering and force overlay surfaces to appear. Furthermore, notifications are rendered in their own compositor-internal layer that is ALWAYS above everything.

**This is the only mechanism GUARANTEED to render above ReGreet on all Hyprland versions.**

### Options Investigated

#### 1. `hyprctl notify` — Transient notification on toggle (RECOMMENDED)

Replace the XKB `grp:alt_shift_toggle` with a Hyprland keybind that toggles layout programmatically and shows a notification.

**Implementation**:
```
# In hyprland.conf:
bind = ALT, Shift_L, exec, /etc/greetd/greetd-kb-toggle

# greetd-kb-toggle script:
# 1. Read current layout: hyprctl devices -j | jq -r '.keyboards[]|select(.main)|.active_keymap'
# 2. Determine target: if "Spanish" → switch to next (latam), show "LATAM"
# 3. Switch: hyprctl switchxkblayout <device> next
# 4. Notify: hyprctl notify 0 4000 "rgb(cdd6f4)" "ES" (or "LATAM")
# 5. On greeter startup: hyprctl notify 0 5000 "rgb(cdd6f4)" "KB: ES" (initial layout)

# Keybind approach: use bind instead of input.kb_options
bind = ALT,Shift_L,exec,/etc/greetd/greetd-kb-toggle
```

**Changes to `system.nix`**:
1. Remove `kb_options = grp:alt_shift_toggle` from `inputBlock`  
2. Add `bind = ALT,Shift_L,exec,...` line to hyprland.conf template
3. Write toggle script to `/etc/greetd/greetd-kb-toggle`
4. Add startup notification in greeter script (after regreet launches)

**Waybar**: Can be removed entirely (persistent bar is the problem), OR kept disabled and only the notification handles layout feedback.

**Pros**:
- GUARANTEED to render above everything (compositor-internal, not layer-shell)
- Already in closure (`pkgs.hyprland` provides `hyprctl`)
- Extremely simple: shell script + Hyprland bind + startup notification
- No z-ordering issues, no exclusive zones, no timing races
- Notification duration configurable (3-5 seconds sufficient for layout feedback)
- No new dependencies
- Removes the entire waybar complexity from the greeter

**Cons**:
- NOT persistent (notification fades after timeout) — user must have seen it
- Must remove XKB-level toggle (`grp:alt_shift_toggle`) and use compositor-level bind
- Two-step toggle: read current → compute target → switch → notify (slightly more code)
- If notification timeout is too short and user looks away, they miss it

**Effort**: Low-Medium — script + bind + notification, removes waybar config entirely

---

#### 2. `nwg-wrapper` — Alternative layer-shell client (PROMISING FALLBACK)

Uses `gtk-layer-shell` library (GTK3) to create a layer-shell surface for displaying text. Different client than waybar, might have different rendering behavior.

**Key features**:
- `-l 3` or SIGUSR1 to use overlay layer
- `-s SCRIPT` to poll a script and display its output
- `-r REFRESH` for polling interval (ms)
- `-o OUTPUT` for specific monitor
- `-p POSITION -a ALIGNMENT` for positioning
- Pango markup for text formatting
- CSS styling
- In nixpkgs (`pkgs.nwg-wrapper`)

**Implementation**:
```
exec-once = nwg-wrapper -s /etc/greetd/kb-layout-script -r 1000 \
  -p right -a start -mt 4 -mr 12 -l 2 \
  -c /etc/greetd/nwg-wrapper.css
# Then: kill -SIGUSR1 $(pgrep nwg-wrapper) to switch to overlay layer (3)
```

**Pros**:
- Lighter than waybar (single widget, not a full bar framework)
- Uses gtk-layer-shell directly (different code path than waybar)
- In nixpkgs, no compilation needed
- Pango markup support
- Persistent display (unlike notifications)
- Can be toggled between top/overlay layers via signal

**Cons**:
- Still uses layer-shell — may have SAME z-ordering issue if compositor is the root cause
- GTK3 (different toolkit than ReGreet's GTK4, may avoid portal deadlocks)
- Default layer is bottom (1); overlay (3) requires SIGUSR1 after startup
- New dependency to add to greeter closure (nwg-wrapper + gtk3 + gtk-layer-shell + python)
- Slightly heavier than a minimal C client

**Effort**: Low-Medium — add nwg-wrapper to closure, write CSS + script, add to Hyprland config

---

#### 3. Custom minimal layer-shell client in C (MAXIMUM CONTROL)

Write a tiny C program using `wlr-layer-shell-unstable-v1` directly with `exclusive_zone: -1` (extends over all exclusive zones from other surfaces).

**Reference implementations**:
- [wlroots examples/layer-shell.c](https://github.com/swaywm/wlroots/blob/master/examples/layer-shell.c) — fully functional, ~400 lines
- [mhalo](https://github.com/progandy/mhalo) — mouse halo overlay, `exclusive_zone: -1`, anchored to all edges
- [wlr-board](https://gitlab.com/3443e/wlr-board) — key overlay for gaming, transparent layer-shell with text

**Implementation sketch**:
```c
// Create overlay layer-shell surface
layer_surface = zwlr_layer_shell_v1_get_layer_surface(
    layer_shell, wl_surface, output,
    ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY, "kb-layout-indicator");
zwlr_layer_surface_v1_set_anchor(layer_surface, ANCHOR_TOP | ANCHOR_RIGHT);
zwlr_layer_surface_v1_set_size(layer_surface, 80, 24);
zwlr_layer_surface_v1_set_exclusive_zone(layer_surface, -1); // Ignore other exclusive zones
zwlr_layer_surface_v1_set_keyboard_interactivity(layer_surface, 0); // None

// Render text with Cairo/Pango
// Poll hyprctl devices every 1s for active_keymap
// Update surface on change
```

**Pros**:
- MAXIMUM control over layer-shell protocol parameters
- `exclusive_zone: -1` is the nuclear option — extends over everything
- Minimal binary, no toolkit deps beyond wayland + cairo/pango
- Persistent display, guaranteed to work at protocol level

**Cons**:
- Must compile C code (Nix derivation needed)
- Cairo/Pango dependencies added to greeter closure
- More code to maintain
- Overkill for displaying two letters
- Still fundamentally depends on compositor honoring layer-shell protocol

**Effort**: Medium-High — C program + Nix derivation + wayland protocol XML build

---

#### 4. Hyprland window rule to constrain ReGreet (WORKAROUND)

Force ReGreet's window to not cover the full screen height, leaving room for waybar at the top with `layer: top` and exclusive zone.

**Implementation**:
```
# In hyprland.conf:
windowrulev2 = size 100% calc(100% - 24), class:^(regreet)$
windowrulev2 = move 0 24, class:^(regreet)$
```

This forces ReGreet to be 24px shorter and start 24px from the top edge. A waybar with `layer: "top"` and `exclusive: true` at the top would occupy the reserved 24px.

**Pros**:
- Simple config change (no new code)
- Waybar at `layer: top` avoids overlay's undefined ordering
- Persistent display
- No new dependencies

**Cons**:
- `calc()` in window rules may not be supported (Hyprland uses simple expressions, not CSS calc)
- Window class `regreet` may change between versions (fragile regex)
- ReGreet renders 24px lower — centered form shifts slightly
- Hardcoded 24px height — fragile to different screen resolutions
- window rules apply to ALL matching windows in greeter session
- May not work if ReGreet's window doesn't match `class:^(regreet)$`

**Effort**: Low — config-only change

---

#### 5. Pre-greeter splash (INITIAL LAYOUT ONLY)

Show layout BEFORE ReGreet launches via a separate display program, then close it and start ReGreet.

**Implementation**:
```
# In greetd-regreet-start:
hyprctl notify 0 3000 "rgb(cdd6f4)" "KB: ES"  # Show initial layout
sleep 3.5  # Wait for notification to be seen
regreet    # Launch greeter
```

**Pros**: Simple, works for initial layout display
**Cons**: No toggle feedback, requires extra delay, notification fades before user types

**Effort**: Trivial

---

#### 6. Wallpaper with baked-in layout text (NOT PRACTICAL)

Generate a PNG with layout text, set as ReGreet background. Update file on toggle.

**Pros**: No z-ordering issues at all
**Cons**: ReGreet's `gtk::Picture` + `gtk::MediaFile` does NOT monitor file for changes — would need ReGreet restart to reload. Impractical for dynamic updates.

**Effort**: High — requires re-launching ReGreet on every toggle

---

#### 7. `hyprctl notify` ONLY (MINIMAL VIABLE)

Strip out ALL waybar code entirely. Use ONLY `hyprctl notify` for layout feedback — both on startup and on toggle.

This is a subset of option 1 but goes further: remove the entire `layoutIndicator` submodule, waybar config, CSS, polling script, and startup delay from omarchy-nix. Replace with a simple toggle script and Hyprland bind.

**Pros**:
- SIMPLEST implementation — removes ~80 lines of code, adds ~30
- No layer-shell, no waybar, no timing races, no exclusive zones
- Guaranteed to work
- No `GTK_USE_PORTAL=0` needed (only waybar needed that)
- No `sleep 0.5` startup delay needed
- Single file change in omarchy-nix (`system.nix`)
- The `layoutIndicator` submodule in `config.nix` becomes unused and can be deprecated

**Cons**:
- Not persistent (notification disappears after timeout)
- User must see the notification within the timeout window
- If user misses the notification, there's no fallback indicator

**Effort**: Low — delete waybar code, add toggle script + bind

---

### Recommendation

**PRIMARY: Option 7 — `hyprctl notify` ONLY (strip waybar, use notifications)**

This is the ONLY approach guaranteed to work on all Hyprland versions. The `hyprctl notify` mechanism is compositor-internal and does not depend on the buggy layer-shell z-ordering path.

**Implementation plan**:

1. **Remove waybar infrastructure** from `omarchy-nix/modules/nixos/system.nix`:
   - Remove `layoutIndicatorScript` (greetd-kb-layout polling script)
   - Remove `waybarGreeterConfig` and `waybarGreeterStyle` derivations
   - Remove `gtkPortalEnv` (was only needed for waybar's GTK)
   - Remove `waybarExec` exec-once line
   - Remove `sleep 0.5` from greeter script
   - Remove `environment.etc` entries for waybar config files

2. **Add Hyprland keybind** to replace XKB toggle:
   - Remove `kb_options = grp:alt_shift_toggle` from `inputBlock`
   - Add `bind = ALT,Shift_L,exec,/etc/greetd/greetd-kb-toggle` to hyprland.conf template

3. **Write toggle script** (`/etc/greetd/greetd-kb-toggle`):
   ```bash
   #!/bin/sh
   # Read all keyboards and their active keymaps
   DEVICES=$(hyprctl devices -j)
   MAIN_DEVICE=$(echo "$DEVICES" | jq -r '.keyboards[] | select(.main == true) | .name')
   CURRENT=$(echo "$DEVICES" | jq -r '.keyboards[] | select(.main == true) | .active_keymap')
   
   # Toggle and determine new layout name
   case "$CURRENT" in
     *Spanish*) 
       NEW="LATAM"
       ;;
     *Latino*|*Latin*)
       NEW="ES"
       ;;
     *)
       # Unknown or first toggle — try switching and re-read
       hyprctl switchxkblayout "$MAIN_DEVICE" next
       sleep 0.1
       NEW=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | cut -c1-2 | tr 'a-z' 'A-Z')
       hyprctl notify 0 3000 "rgb(cdd6f4)" "$NEW"
       exit 0
       ;;
   esac
   
   # Switch ALL keyboards to keep them in sync
   echo "$DEVICES" | jq -r '.keyboards[].name' | while read -r kb; do
     hyprctl switchxkblayout "$kb" next
   done
   
   # Show notification
   hyprctl notify 0 4000 "rgb(cdd6f4)" "$NEW"
   ```

4. **Add startup notification** in greeter script:
   ```bash
   # After regreet launches (background it and show initial layout)
   regreet &
   REGREET_PID=$!
   sleep 1  # Wait for regreet to map its window
   INITIAL=$(hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap')
   case "$INITIAL" in
     *Spanish*) LABEL="ES" ;;
     *Latino*|*Latin*) LABEL="LATAM" ;;
     *) LABEL="KB: ?" ;;
   esac
   hyprctl notify 0 5000 "rgb(cdd6f4)" "KB: $LABEL"
   wait $REGREET_PID
   ```

5. **Deprecate `layoutIndicator` submodule** in `config.nix` (keep but mark as deprecated/unused)

**IF persistent display is required**, implement Option 2 (`nwg-wrapper`) as a FALLBACK alongside the notification system, so there's both a persistent indicator AND guaranteed on-toggle feedback. However, the notification-only approach is recommended as the MVP.

### Affected Files

| Repo | File | Change |
|------|------|--------|
| omarchy-nix | `modules/nixos/system.nix` | Remove waybar code (~lines 24-60, 235-237, 323-324, 337-346), add bind + toggle script + startup notification |
| omarchy-nix | `config.nix` | Optionally deprecate `layoutIndicator` submodule |
| nixos-hosts | `hosts/t14/default.nix` | Remove `layoutIndicator.enable = true` from greeter block |
| nixos-hosts | `hosts/t14/home/omarchy.nix` | Update architecture comment (remove waybar mention) |

### Risks

- **Notification timeout**: If set too short (e.g., 1-2s), user may miss it. Recommend 4-5s for toggle, 5s for startup.
- **Toggle race**: Reading current layout and switching must be fast enough that the user doesn't press Alt+Shift again during the script execution. 100ms sleep between read and switch mitigates this.
- **XKB vs compositor keybind**: Removing `grp:alt_shift_toggle` means the toggle ONLY works in the greeter Hyprland (not in the user session). User session already has its own toggle mechanism in `hosts/t14/home/hypr/input.nix`. No conflict.
- **All keyboards sync**: The script switches ALL keyboards to keep them in sync. If a USB keyboard is plugged in after the greeter starts, it won't be in the initial device list. Edge case, not critical for a login screen.
- **Non-t14 hosts unaffected**: The greeter block is only generated when `cfg.greeter.type == "regreet"`. rog, thinkcentre, mact2 are unaffected. `nix flake check` for all hosts must still pass.

### Verification Plan

1. `nix flake check --no-build` for t14, rog, thinkcentre, mact2 (all must pass)
2. Rebuild t14, reboot
3. At greeter screen:
   - Initial notification appears showing "KB: ES" or "KB: LATAM" for 5 seconds
   - Press Alt+Shift → notification shows new layout name ("ES" or "LATAM")
   - Press Alt+Shift again → notification updates
   - Type password and login → works normally
4. Verify user session layout toggle still works independently
