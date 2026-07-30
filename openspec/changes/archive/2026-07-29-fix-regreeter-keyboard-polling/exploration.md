# Exploration: fix-regreeter-keyboard-polling

## Current State

The t14 greeter layout indicator uses two shell scripts, both defined in `omarchy-nix/modules/nixos/system.nix` (commit `45d2607`):

1. **`greetdKbNotify`** — shows initial `hyprctl notify` with layout at greeter startup
2. **`greetdKbMonitor`** — background polling script that checks every 1s and notifies on layout change

Both scripts use the SAME jq selector to get the active keymap:

```bash
hyprctl devices -j | jq -r '.keyboards[0].active_keymap // empty'
```

**The selector `.keyboards[0]` is the root cause of the bug.**

## Root Cause Analysis

`hyprctl devices -j` returns ALL devices reporting as keyboards, INCLUDING ACPI pseudo-devices. On the t14, the `.keyboards` array contains (confirmed via live diagnostic):

| Index | Device name | Type | active_keymap changes? |
|-------|-----------|------|----------------------|
| 0 | `video-bus` | ACPI pseudo-device | **No** (stays "Spanish") |
| 1 | `power-button` | ACPI button | No |
| 2 | `power-button-1` | ACPI button (duplicate) | No |
| 3 | `sleep-button` | ACPI button | No |
| 4 | `at-translated-set-2-keyboard` | **Physical keyboard** | **Yes** |
| 5 | `thinkpad-extra-buttons` | Platform buttons | No |
| 6 | `hl-virtual-keyboard-fcitx5` | fcitx5 virtual (user session only) | N/A in greeter |

**Behavior in greeter session:**

- `.keyboards[0]` = `video-bus` → always reports "Spanish" → initial notification works (coincidentally)
- When Alt+Shift toggles layout on the physical keyboard, `at-translated-set-2-keyboard` changes to "Spanish (Latin American)" but `video-bus` stays "Spanish"
- `greetdKbMonitor` watches `video-bus` which never changes → no notification update
- fcitx5 (and its `hl-virtual-keyboard-fcitx5` with `main: true`) is NOT running in greeter session

**Contrast with user session:**

The user-session script `hosts/t14/home/scripts/kb-layout.sh` uses `main: yes` from `hyprctl devices` (text output) to find the real keyboard. This WORKS in the user session because fcitx5 creates `hl-virtual-keyboard-fcitx5` with `main: true`. In the greeter session, no device has `main: true`, so the `main`-based approach would select nothing.

## Affected Areas

| File | Area | Nature |
|------|------|--------|
| `omarchy-nix/modules/nixos/system.nix` lines 43-44 | `greetdKbNotify` jq selector | `.keyboards[0]` → must change |
| `omarchy-nix/modules/nixos/system.nix` lines 54-55 | `greetdKbMonitor` jq selector | `.keyboards[0]` → must change |

**NOT affected:**

- `hosts/t14/default.nix` — only has `layoutIndicator.enable = true`, no selector logic
- `hosts/t14/home/scripts/kb-layout.sh` — user-session script uses `main: yes`, works correctly, no changes needed
- Layout label mapping (`*Spanish*` → "ES", `*Latin*` → "LATAM") — correct, no changes needed
- Any non-t14 host — feature is t14-only

## Approaches

### Approach A: Exclude non-physical devices via jq denylist (RECOMMENDED)

Replace `.keyboards[0]` with a jq filter that excludes known ACPI pseudo-devices and virtual keyboards, then selects the first remaining device:

```bash
hyprctl devices -j | jq -r '[.keyboards[] |
  select(.name | test("video-bus|power-button|sleep-button|thinkpad-extra|hl-virtual-keyboard") | not)] |
  .[0].active_keymap // empty'
```

This removes devices whose names indicate they are NOT real physical keyboards:
- `video-bus` — ACPI video bridge (never changes layout)
- `power-button` / `power-button-1` — ACPI power buttons
- `sleep-button` — ACPI sleep button
- `thinkpad-extra-buttons` — platform-specific media/Fn buttons
- `hl-virtual-keyboard-*` — input-method virtual keyboards (fcitx5, ibus)

Anything left should be a physical keyboard.

**Pros:**
- Works on any hardware, not just t14 (USB keyboards, PS/2 keyboards, etc.)
- Robust across different Linux kernel versions (ACPI device names are stable)
- No hardcoded device name — adapts to the host's actual hardware
- Filters out both the t14-specific ACPI devices AND input-method virtual keyboards

**Cons:**
- Denylist requires maintenance if new ACPI keyboard devices appear in future kernels
- Regex in jq is slightly more complex than a simple index

**Effort:** Trivial — change two jq selectors (identical in both scripts). Same line twice.

### Approach B: Hardcode device name

Replace `.keyboards[0]` with a selector matching the exact physical keyboard name:

```bash
hyprctl devices -j | jq -r '.keyboards[] | select(.name == "at-translated-set-2-keyboard") | .active_keymap // empty'
```

**Pros:** Exact match, no ambiguity, works on the t14.

**Cons:** Tied to one specific laptop model. Would break on:
- A different laptop with a different internal keyboard name
- A desktop with a USB keyboard (different device name)
- Systems that rename the AT keyboard device

**Effort:** Trivial

### Approach C: Use `.main` selector with empty fallback

Try `select(.main)` first, fall back to some heuristic:

```bash
hyprctl devices -j | jq -r '(.keyboards[] | select(.main) | .active_keymap) // (.keyboards[4].active_keymap) // empty'
```

**Pros:** Would work in user session (fcitx5 marks main).

**Cons:** In greeter session, NO keyboard has `main: true` (fcitx5 not running) → fallback is still index-based fragile. No better than [0].

**Effort:** Low but pointless — doesn't solve the greeter problem.

### Approach D: Query via `hyprctl switchxkblayout` read

Hyprland has `hyprctl switchxkblayout <device> <command>` but no read/query subcommand. There is no Hyprland-native API to read current layout.

**Pros:** None — API doesn't exist.

**Cons:** Not possible.

**Effort:** N/A — not feasible.

## Recommendation

**Approach A: jq denylist filter.**

This is the correct fix because:
1. It addresses the root cause (`.keyboards[0]` is wrong) by selecting the right device
2. It's hardware-agnostic — works on any machine with any physical keyboard
3. It's conservative — only excludes devices KNOWN to not be real keyboards
4. The denylist terms (ACPI device names, input-method virtual keyboard prefix) are stable Linux conventions, not kernel-version-specific
5. It's a one-line-per-script change (two identical edits)
6. The same fix can be copy-pasted into both `greetdKbNotify` and `greetdKbMonitor` — both have the identical jq selector

**Alternative considered but rejected:** Hardcoding `at-translated-set-2-keyboard` would work today but breaks on hardware changes. The denylist approach is only slightly more complex while being vastly more portable.

## Implementation Sketch

In `omarchy-nix/modules/nixos/system.nix`, change BOTH instances of:

```nix
# Current (broken)
| ${pkgs.jq}/bin/jq -r '.keyboards[0].active_keymap // empty'
```

to:

```nix
# Fixed
| ${pkgs.jq}/bin/jq -r '[.keyboards[] | select(.name | test("video-bus|power-button|sleep-button|thinkpad-extra|hl-virtual-keyboard") | not)] | .[0].active_keymap // empty'
```

Two identical edits: one in `greetdKbNotify`, one in `greetdKbMonitor`. No other changes needed.

**Verification:**
1. Initial notification: on greeter startup, `greetdKbNotify` should show "ES" (selects the physical keyboard's active_keymap)
2. Toggle: press Alt+Shift → `at-translated-set-2-keyboard` changes to "Spanish (Latin American)" → monitor picks it up → notification shows "LATAM"
3. Non-t14 hosts: `nix flake check --no-build` — no impact (feature gated behind `layoutIndicator.enable`)

## Risks

- **New ACPI keyboard devices**: Future Linux kernels might introduce new ACPI keyboard-like devices with names NOT in the denylist. If such a device appears before the real keyboard in the array, the selector would pick the wrong one. **Mitigation**: The denylist covers known ACPI device name patterns; unknown devices are assumed to be keyboards (allowlist-by-default approach). If a new device appears, the fix is adding one string to the denylist regex.
- **Multi-keyboard setups**: If two physical keyboards are connected (e.g., laptop internal + USB external), the filter returns the FIRST physical keyboard's layout. Both keyboards share the same XKB layout group (Hyprland applies layouts globally), so any real keyboard's active_keymap should match. **Mitigation**: Layout is per-session, not per-device — the first result is correct.
- **Regex escape**: The pipe `|` inside the jq regex is an alternation operator, not a special character that needs escaping in this context — it's inside a jq string passed to `test()`. **No risk.**
