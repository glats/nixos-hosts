# Proposal: Wallpaper Rotation Toggle (omarchy-nix upstream)

## Intent

`omarchy-theme-bg-next` is unconditionally injected into Hyprland's `exec-once` at `modules/home-manager/swaybg.nix:16`. Every session start advances the wallpaper, with no way to opt out. Users who prefer a static wallpaper (or who select one manually via `Super+Ctrl+Space`) lose their choice on next login. This change adds a boolean toggle so rotation is controllable while preserving the current behavior as the default.

## Scope

### In Scope
- New `omarchy.theme.rotate_on_start` option in `config.nix` (`types.bool`, default `true`)
- Conditional inclusion of `omarchy-theme-bg-next` in `swaybg.nix` via `lib.mkIf`
- PR to `github.com/glats/omarchy-nix` (upstream — user has push access)
- `flake.lock` bump in `nixos-hosts` after merge
- Optional: set `omarchy.theme.rotate_on_start = false` on t14

### Out of Scope
- Time-based / interval rotation (systemd timer)
- Changes to `omarchy-theme-bg-next` script itself
- Changes to the manual wallpaper picker (`Super+Ctrl+Space` / `omarchy-theme-bg-set`)
- Any host other than t14 (for the optional per-host override)

## Capabilities

### New Capabilities
- `wallpaper-rotation-toggle`: Boolean option controlling whether `omarchy-theme-bg-next` runs on Hyprland session start. Default `true` preserves backward compatibility.

### Modified Capabilities
None (pure additive option; existing behavior unchanged when option is unset).

## Approach

1. **Declare option** in `config.nix` inside `omarchyOptions`:
   ```nix
   theme = {
     rotate_on_start = lib.mkOption {
       type = lib.types.bool;
       default = true;
       description = "Advance wallpaper to next image on every Hyprland session start";
     };
   };
   ```
   Note: `theme` is currently a flat `lib.types.enum` at the top level of `omarchyOptions`. Two paths:
   - **(A) Nest under new submodule**: Convert `omarchy.theme` from enum to submodule with `name` + `rotate_on_start`. Breaks all existing configs that set `omarchy.theme = "tokyo-night"`. **Rejected.**
   - **(B) Sibling option**: Add `omarchy.rotate_on_start` as a standalone bool alongside `omarchy.theme`. No migration needed. **Preferred.**

2. **Gate exec-once** in `modules/home-manager/swaybg.nix`:
   ```nix
   wayland.windowManager.hyprland.settings.exec-once =
     lib.optional config.omarchy.rotate_on_start "omarchy-theme-bg-next";
   ```

3. **Per-host override** (optional, in `hosts/t14/home/omarchy.nix`):
   ```nix
   omarchy.rotate_on_start = false;
   ```

4. **Bump flake.lock** in nixos-hosts after upstream merge.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `config.nix` | Modified | Add `rotate_on_start` bool option (sibling to `theme`) |
| `modules/home-manager/swaybg.nix` | Modified | Replace unconditional list with `lib.optional` gated on new option |
| `hosts/t14/home/omarchy.nix` (nixos-hosts) | Modified (optional) | Set `omarchy.rotate_on_start = false` |
| `flake.lock` (nixos-hosts) | Modified | Bump `omarchy-nix` input to new rev after merge |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Option name collision with future upstream option | Low | Use `rotate_on_start` (specific) rather than generic `rotation` |
| `exec-once` ordering breaks if list becomes empty | Low | `autostart.nix:10` always loads `swaybg -i current/background`; empty rotation list just means no advance |
| Users miss the toggle and think rotation broke | Low | Default is `true` — existing behavior preserved; opt-out is explicit |
| Flake.lock bump causes eval regression on t14 | Low | Run `nix flake check --no-build` before `nixos-build switch` |

## Rollback Plan

Set `omarchy.rotate_on_start = true` (or remove the override). One-line revert in host config. Upstream revert: revert the single commit in omarchy-nix.

## Dependencies

- omarchy-nix PR merged to `main`
- `flake.lock` rev bump in nixos-hosts points to merged commit

## Success Criteria

- [ ] `nix flake check --no-build` passes on omarchy-nix
- [ ] PR merged to `glats/omarchy-nix:main`
- [ ] `nix flake check --no-build` passes on nixos-hosts after lock bump
- [ ] t14 with `rotate_on_start = false`: wallpaper persists across Hyprland restart
- [ ] t14 with `rotate_on_start = true` (or unset): wallpaper advances as before
- [ ] Other hosts (rog, thinkcentre) unaffected — default `true` preserves current behavior
