# Design: T14 Hyprland Workspace Initialization

## Technical Approach

Add declarative workspace rules with `default:true` and `persistent:true` flags to ensure workspaces are created on the correct monitors at session start and remain visible in Waybar. The existing `monitor-lid-validator.sh` daemon will trigger `hyprctl reload` after monitor layout changes to handle Hyprland's startup race condition (issue #5464).

## Architecture Decisions

### Decision: Use `lib.imap1` for Index-Based Default Flag

**Choice**: Refactor `mkWorkspaceRules` to use `lib.imap1` to detect the first workspace per monitor and append `default:true` only to that workspace. All workspaces get `persistent:true`.

**Alternatives considered**: 
- Hardcode default workspace per monitor (rejected: less maintainable, duplicates logic)
- Use `lib.mapAttrsToList` with separate default list (rejected: more complex, harder to follow)

**Rationale**: `lib.imap1` provides 1-based index, making it trivial to check `idx == 1` for the default workspace. Keeps the cyclic distribution logic intact while adding flags declaratively.

### Decision: eDP-1 Rules Inside ENABLE_LAPTOP Conditional

**Choice**: Add workspace rules for eDP-1 (workspaces 1, 2, 3) inside the existing `# hyprlang if ENABLE_LAPTOP` block in `extraConfig`, using the same pattern but without `monitor:desc:` prefix (eDP-1 is a direct name, not a descriptor).

**Alternatives considered**:
- Add eDP-1 rules unconditionally (rejected: conflicts with external monitor rules when docked)
- Generate eDP-1 rules via `mkWorkspaceRules` (rejected: eDP-1 is conditional, not part of the static distribution)

**Rationale**: eDP-1 is only active when `ENABLE_LAPTOP` is true. Placing rules inside the conditional ensures they only apply when the laptop panel is enabled, avoiding conflicts with external monitor assignments.

### Decision: Daemon Reload After Apply

**Choice**: Add `hyprctl reload` at the very end of the `apply()` function in `monitor-lid-validator.sh`, after all `hyprctl keyword monitor` calls complete.

**Alternatives considered**:
- Reload before monitor changes (rejected: reload would use stale monitor state)
- Reload only on dock events (rejected: lid toggle also needs reload for workspace re-assignment)

**Rationale**: `hyprctl reload` re-evaluates all workspace rules against the current monitor state. Placing it at the end ensures monitor layout is fully applied before workspace rules are re-checked, mitigating Hyprland issue #5464 where `default:true` may not take effect on first config parse.

## Data Flow

```
Hyprland Session Start
    ↓
Config Parse (monitors.nix)
    ↓
Workspace Rules Generated:
  - workspace = 1, monitor:desc:AOC..., default:true, persistent:true
  - workspace = 2, monitor:desc:Lenovo..., default:true, persistent:true
  - workspace = 3, monitor:desc:AOC2470W..., default:true, persistent:true
  - [all other workspaces: persistent:true only]
    ↓
[If ENABLE_LAPTOP]
  - workspace = 1, monitor:eDP-1, default:true, persistent:true
  - workspace = 2, monitor:eDP-1, persistent:true
  - workspace = 3, monitor:eDP-1, persistent:true
    ↓
monitor-lid-validator.sh Startup
    ↓
apply() → detect lid state → persist + move monitors
    ↓
hyprctl reload (re-evaluates workspace rules)
    ↓
Workspaces created on correct monitors

Dock/Undock Event (socket2)
    ↓
sleep 0.5 → apply() → hyprctl reload
    ↓
Workspace rules re-applied to new monitor layout
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `hosts/t14/home/hypr/monitors.nix` | Modify | Refactor `mkWorkspaceRules` to use `lib.imap1` and emit `default:true, persistent:true` flags. Add eDP-1 workspace rules inside `ENABLE_LAPTOP` conditional. |
| `hosts/t14/home/scripts/monitor-lid-validator.sh` | Modify | Add `hyprctl reload` at the end of `apply()` function. |

## Interfaces / Contracts

### Workspace Rule Format

```nix
# Before (current):
"${toString w}, monitor:desc:${monitor}"

# After (refactored):
"${toString w}, monitor:desc:${monitor}, default:${lib.boolToString (idx == 1)}, persistent:true"
```

### eDP-1 Rules (inside ENABLE_LAPTOP conditional)

```hyprlang
# hyprlang if ENABLE_LAPTOP
workspace = 1, monitor:eDP-1, default:true, persistent:true
workspace = 2, monitor:eDP-1, persistent:true
workspace = 3, monitor:eDP-1, persistent:true
# ... existing monitor rules ...
# hyprlang endif
```

### Daemon Reload

```bash
apply() {
  LID_STATE=$(grep -o 'open\|closed' /proc/acpi/button/lid/LID*/state 2>/dev/null || echo "open")
  case "$LID_STATE" in
    closed) persist 0; move_to_y0 ;;
    *)      persist 1; move_to_y420 ;;
  esac
  hyprctl reload  # ← NEW: re-evaluate workspace rules after monitor changes
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Manual | Docked startup | Connect dock, restart Hyprland, verify workspaces 1/2/3 appear on correct monitors via `hyprctl workspaces` |
| Manual | Undocked startup | Disconnect dock, restart Hyprland, verify workspace 1 appears on eDP-1 |
| Manual | Persistent workspaces | Close all windows on workspace 2, verify it remains visible in Waybar |
| Manual | Dock event | Start undocked, connect dock, verify workspaces re-assign to external monitors |
| Manual | Lid toggle | Docked with lid open, close lid, verify eDP-1 disables and workspaces stay on externals |

## Migration / Rollout

No migration required. Changes are declarative and take effect on next Hyprland session start or `hyprctl reload`.

## Edge Case: Hyprland Issue #5464

**Problem**: `default:true` may not take effect on first config parse if monitors are not yet fully initialized.

**Mitigation**: `monitor-lid-validator.sh` calls `hyprctl reload` at the end of every `apply()` invocation. This forces Hyprland to re-evaluate workspace rules against the current monitor state, ensuring `default:true` assignments are applied correctly.

**Race condition**: The daemon waits `sleep 0.5` after `monitoradded`/`monitorremoved` events before calling `apply()`, giving Hyprland time to settle the monitor layout before reloading workspace rules.

## Out of Scope

- **Waybar configuration**: No changes to Waybar. Persistent workspaces are managed entirely via Hyprland's `persistent:true` flag. Waybar's `persistent-workspaces` config is not needed because Hyprland now reports persistent workspaces via IPC.
