# Design: Wallpaper Rotation Toggle (omarchy-nix)

## Technical Approach

Add a boolean option `omarchy.rotate_on_start` (default `true`) that gates whether `omarchy-theme-bg-next` runs on Hyprland session start. The option is declared as a sibling to `omarchy.theme` (not nested) to avoid breaking existing configs. The `swaybg.nix` module uses `lib.optional` to conditionally include the rotation command in `exec-once`.

## Architecture Decisions

### Decision: Option placement — sibling to `theme`, not nested

**Choice**: `omarchy.rotate_on_start` as a top-level bool in `omarchyOptions`  
**Alternatives considered**: Nest under `omarchy.theme.rotate_on_start` (requires converting `theme` from enum to submodule)  
**Rationale**: Nesting breaks all existing configs that set `omarchy.theme = "tokyo-night"`. Sibling placement is additive, requires no migration, and matches the proposal's preferred path (B).

### Decision: Conditional inclusion mechanism — `lib.optional`

**Choice**: `lib.optional config.omarchy.rotate_on_start "omarchy-theme-bg-next"`  
**Alternatives considered**: `lib.mkIf` (requires wrapping entire attrset), `lib.optionals` (overkill for single item)  
**Rationale**: `lib.optional` is idiomatic for single-element conditional lists. Returns `["omarchy-theme-bg-next"]` when true, `[]` when false. Hyprland's `exec-once` accepts both forms without error.

## Data Flow

```
User config (hosts/t14/home/omarchy.nix)
  │
  │  omarchy.rotate_on_start = false
  ▼
omarchy-nix config.nix (option declaration)
  │
  │  lib.mkOption { type = bool; default = true; }
  ▼
modules/home-manager/swaybg.nix (consumption)
  │
  │  lib.optional config.omarchy.rotate_on_start "omarchy-theme-bg-next"
  ▼
wayland.windowManager.hyprland.settings.exec-once
  │
  │  [] or ["omarchy-theme-bg-next"]
  ▼
Hyprland session start (exec-once dispatcher)
  │
  └─→ (if present) omarchy-theme-bg-next advances wallpaper
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `config.nix` (omarchy-nix) | Modify | Add `rotate_on_start` bool option after `theme` (line ~45) |
| `modules/home-manager/swaybg.nix` (omarchy-nix) | Modify | Replace unconditional list with `lib.optional` gated on `config.omarchy.rotate_on_start` |
| `hosts/t14/home/omarchy.nix` (nixos-hosts) | Modify (optional) | Add `omarchy.rotate_on_start = false;` |
| `flake.lock` (nixos-hosts) | Modified | Bump `omarchy-nix` input after upstream merge |

## Interfaces / Contracts

### Option declaration (config.nix)

```nix
rotate_on_start = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = "Advance wallpaper to next image on every Hyprland session start";
};
```

**Position**: After `theme` option (line 44), before `primary_font` (line 45).

### Option consumption (swaybg.nix)

```nix
wayland.windowManager.hyprland.settings.exec-once =
  lib.optional config.omarchy.rotate_on_start "omarchy-theme-bg-next";
```

**Before**:
```nix
wayland.windowManager.hyprland.settings.exec-once = [
  "omarchy-theme-bg-next"
];
```

**After**:
```nix
wayland.windowManager.hyprland.settings.exec-once =
  lib.optional config.omarchy.rotate_on_start "omarchy-theme-bg-next";
```

### Module import chain verification

1. `config.nix` declares `omarchyOptions` → exposed as `config.omarchy.*`
2. `modules/home-manager/default.nix` imports `swaybg.nix` (line 48)
3. `swaybg.nix` receives `{ config, pkgs, lib, ... }` (line 2)
4. `config.omarchy.rotate_on_start` is accessible ✓

## Flake.lock Bump Strategy

After the omarchy-nix PR merges to `main`:

```bash
# In nixos-hosts repo
nix flake lock --update-input omarchy-nix
nix flake check --no-build
```

This updates `flake.lock` to point to the merged commit. The `--update-input` flag only bumps the specified input, leaving others unchanged.

## t14 Host Config (Optional)

In `hosts/t14/home/omarchy.nix`, add after line 115 (after `omarchy.fonts.kitty`):

```nix
# Disable automatic wallpaper rotation on session start.
# User prefers static wallpaper (manually selected via Super+Ctrl+Space).
omarchy.rotate_on_start = false;
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Eval | Option declaration | `nix flake check --no-build` on omarchy-nix |
| Eval | Conditional inclusion | `nix flake check --no-build` on nixos-hosts after lock bump |
| Manual | `rotate_on_start = false` | Set in t14 config, relogin, confirm wallpaper unchanged |
| Manual | `rotate_on_start = true` (or unset) | Remove override or set `true`, relogin, confirm wallpaper advances |
| Regression | Other hosts unaffected | rog/thinkcentre default to `true` — verify no behavior change |

## Migration / Rollout

No migration required. Default `true` preserves existing behavior. Users opt out explicitly by setting `omarchy.rotate_on_start = false`.

## Open Questions

None.
