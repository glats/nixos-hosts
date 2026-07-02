# Proposal: Omarchy Arch-to-NixOS Drift

## Intent

Close gaps between the old Arch Linux omarchy setup and NixOS omarchy-nix. Three bugs/gaps were identified: a broken Nautilus dark-mode fix (portal file installed to the wrong store path), missing omarchy-hook features (`.d/` directory support, graceful error handling), and unwired `theme-set`/`post-boot` hooks.

## Scope

### In Scope
- Fix Nautilus dark mode — move gtk.portal from `home.packages` to `xdg.portal.extraPortals`
- Fix `omarchy-hook` — add `.d/` directory iteration and graceful error handling
- Wire `theme-set` hook call in `theme-switcher.nix`
- Create `omarchy-weather-status` command + `omarchy-post-boot` systemd user service

### Out of Scope
- Wallpaper management (local-only, user-declared)
- Fcitx5 input method (removed deliberately in `f8f7d51`)
- Ghostty, Hyprlock, Hypridle, Starship config
- Arch-specific hooks (`post-update`, `battery-low` — already handled)

## Capabilities

### New Capabilities
- `nautilus-dark-mode`: Nautilus renders dark mode via correct portal profile path
- `omarchy-hook-dir-support`: `omarchy-hook` iterates `.d/` dirs and skips `.sample` files
- `omarchy-theme-set-hook`: `theme-switcher` calls `omarchy-hook theme-set` after rebuild
- `omarchy-weather-status`: CLI weather command + post-boot systemd user service

### Modified Capabilities
- None — no existing specs in this repo

## Approach

Fix each gap independently:
1. **Nautilus**: Move `runCommand` from `home-manager.users.glats.home.packages` → `xdg.portal.extraPortals` in `hosts/t14/default.nix` (~5 lines)
2. **omarchy-hook**: Edit `bin/omarchy-hook` — add `for d in "$HOOK_DIR.d/"*.hook` loop, `.sample` skip, replace `set -e` with per-command `||` handlers
3. **theme-set**: Add `omarchy-hook theme-set "$THEME_NAME"` line after `nixos-rebuild` in theme-switcher script
4. **Weather**: Create `bin/omarchy-weather-status` (curl wttr.in), create systemd user service and timer in `modules/features/services/`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/default.nix` | Modified | Move gtk.portal to `extraPortals` |
| `bin/omarchy-hook` | Modified | Add `.d/` support, graceful errors |
| `modules/features/services/theme-switcher.nix` | Modified | Wire `theme-set` hook |
| `bin/omarchy-weather-status` | New | Lightweight weather CLI |
| `modules/features/services/omarchy-post-boot.nix` | New | Systemd user service + timer |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Nautilus fix breaks other portal behavior | Low | Localized change, testable with `nixos-rebuild test` |
| omarchy-hook changes break existing hooks | Low | Keep backward compat, add `.d/` as fallback |
| Weather script depends on external API | Medium | Handle curl failures gracefully, cache results |

## Rollback Plan

- **Per-file**: `git checkout <file>` + `nixos-rebuild switch` for Nix files
- **New files**: `git rm` + revert imports
- **Full rollback**: `git checkout . && nixos-rebuild switch`

## Dependencies

None — all changes self-contained within the repo.

## Success Criteria

- [ ] Nautilus renders dark mode on t14 after rebuild
- [ ] `omarchy-hook` iterates `.d/` dirs and skips `.sample`
- [ ] `theme-switcher` triggers `theme-set` hook after rebuild
- [ ] `omarchy-weather-status` returns weather on CLI
- [ ] `systemctl --user status omarchy-post-boot` shows active
- [ ] `nix flake check --no-build` and `format-nix` pass
