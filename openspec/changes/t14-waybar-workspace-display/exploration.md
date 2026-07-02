# Exploration: t14-waybar-workspace-display

## Problem

After HDM migration, waybar shows too many workspaces (1,2,3,4,5,6,7,8,21) and lost the focus indicator. Before migration, it only showed ~6 workspaces and indicated which one had focus.

## Current State

Waybar on T14 uses `ext/workspaces` module (migrated from `hyprland/workspaces` in prior SDD `t14-workspace-switch-resets` to fix IPC crashes). The config at `omarchy-nix/config/waybar/config` has:

```json
"ext/workspaces": {
    "format": "{icon}",
    "format-icons": { "1": "1", ... "20": "20" },
    "on-click": "activate",
    "all-outputs": true
}
```

Two problems:
1. **Too many workspaces**: `all-outputs: true` shows workspaces from ALL 4 monitors. In docked state: 9 total (8 persistent across 3 externals + workspace 21 on eDP-1). User expected ~6.
2. **Missing focus indicator**: CSS at `~/.config/waybar/style.css` only has `#workspaces button.empty { opacity: 0.5 }`. No `.active`, `.visible`, or `.urgent` styling.

## Research: Ext/Workspaces Module

From the [official waybar wiki](https://github.com/Alexays/Waybar/wiki/Module:-Workspaces):

| Config Option | Default | Effect |
|---|---|---|
| `all-outputs` | `false` | `true` = show all monitors' workspaces; `false` = only bar's assigned output |
| `active-only` | `false` | If `true`, only active or urgent workspaces shown |
| `persistent-workspaces` | empty | **Does NOT work with `ext/workspaces`** (confirmed by source code) |
| `format-icons` | — | Can use `"active"`, `"urgent"`, `"default"` for state-based icons |
| `sort-by-number` | `false` | Numeric sort for workspace names |

CSS classes applied by `ext/workspaces`:
- `#workspaces button.active` — focused/active workspace
- `#workspaces button.visible` — visible on some output
- `#workspaces button.urgent` — urgent flag
- `#workspaces button.empty` — exists, no windows
- `#workspaces button.hidden` — hidden workspace
- `#workspaces button.persistent` — persistent workspace

## Current Hyprland Workspace State (Docked)

```
21: eDP-1  (active)
3:  DP-3  (active), 6: DP-3
2:  DP-4  (active), 5: DP-4, 8: DP-4
1:  DP-5  (active), 4: DP-5, 7: DP-5
```

4 monitors, 9 unique workspaces. `monitors.conf` (HDM-generated) assigns persistent workspaces 1-18 to external monitors only — **no persistent workspaces on eDP-1**.

## Root Causes

1. `all-outputs: true` shows all monitors' workspaces instead of only eDP-1
2. `persistent-workspaces` is unsupported in `ext/workspaces` (confirmed via waybar C++ source: only implemented for `sway/workspaces` and `hyprland/workspaces`)
3. HDM docked profile has no persistent workspace rules for eDP-1 (pre-existing design gap)
4. No CSS styling for `.active`, `.visible` classes

## Approaches

### 1. `all-outputs: false` + CSS focus indicator (RECOMMENDED)
- Change `"all-outputs"` from `true` to `false` in waybar config
- Add `#workspaces button.active { /* highlight */ }` and `.empty`/`.visible` CSS
- Pros: Minimal change (2 files), correct for undocked state, fixes both issues
- Cons: Docked eDP-1 may show too few workspaces (only 21) until HDM adds persistent rules
- Effort: **Low**

### 2. `active-only: true` + CSS
- Show only active workspaces (4 docked, ~1 undocked)
- Pros: Always minimal display
- Cons: Too few workspaces; no workspace preview
- Effort: Low

### 3. Switch back to `hyprland/workspaces`
- If the IPC crash was fixed upstream
- Pros: `persistent-workspaces` works, familiar behavior
- Cons: Risk of crash regression; Lua dispatcher incompatibility (#5008); nixpkgs waybar may lag
- Effort: Medium

### 4. Hybrid: waybar fix + HDM eDP-1 rules
- Fix waybar config AND add persistent workspace rules for eDP-1 in HDM docked profile
- Pros: Complete fix for all states
- Cons: Touches HDM (separate change scope); more complex
- Effort: Medium

### 5. State-based `format-icons`
- Use `"active": "●"`, `"default": "○"` in format-icons for visual differentiation
- Pros: No CSS changes needed
- Cons: Less flexible than CSS; doesn't fix workspace count
- Effort: Low

## Recommendation

**Approach 1: `all-outputs: false` + CSS focus indicator**

Rationale:
- `all-outputs: false` restores pre-migration behavior (show only eDP-1 workspaces)
- CSS `.active` class styling provides the missing focus indicator
- 2-file change in omarchy-nix only (waybar config + style.css)
- No risk of crash regression (stays on stable `ext/workspaces`)
- Missing eDP-1 persistent workspaces in docked state is an HDM concern (pre-existing, separate)

## Affected Files

| File | Change |
|------|--------|
| `omarchy-nix/config/waybar/config` | `all-outputs: true` → `false`; optionally remove redundant `format-icons` 1-20 |
| `~/.config/waybar/style.css` (from `omarchy-nix/config/waybar/style.css`) | Add `#workspaces button.active` and `#workspaces button.visible` CSS rules |

## Risks

- **Docked eDP-1 workspace scarcity**: With `all-outputs: false`, eDP-1 may only show 1 workspace in docked mode. Mitigation: HDM profile should include persistent workspaces for eDP-1 even when docked (separate SDD change).
- **`persistent-workspaces` confusion**: Wiki is contradictory; source code confirms unsupported. Do not attempt to use it.

## Next Phase

Ready for **sdd-propose**.
