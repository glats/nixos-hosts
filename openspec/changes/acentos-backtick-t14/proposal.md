# Proposal: Restore fcitx5 IME and fix compose:caps on t14

## Intent

fcitx5 was deleted from t14 in commit `f8f7d51` under the false assumption that omarchy-nix provides it. It does not — `omarchy-nix/modules/packages.nix` has zero fcitx references, and the autostart line in `autostart.nix:9` is commented out. The deletion left t14 with no input method backend.

Additionally, `compose:caps` in both `hosts/t14/home/hypr/input.nix` and `hosts/t14/default.nix:178` remaps CAPS LOCK to Compose with no backend consuming it, breaking dead-key and backtick input. This option is a trap inherited from omarchy-nix's upstream default.

## Scope

### In Scope
- Restore `hosts/t14/home/fcitx5.nix` (env vars + xdg.configFile from commit `84f88a8`)
- Install fcitx5 packages (`fcitx5`, `fcitx5-gtk`, `fcitx5-configtool`) — omarchy does NOT provide them
- Wire fcitx5 autostart (systemd user service or Hyprland exec-once)
- Remove `,compose:caps` from `hosts/t14/home/hypr/input.nix:11`
- Remove `,compose:caps` from `hosts/t14/default.nix:178` (ReGreet greeter)
- Keep `es,latam` layouts with `grp:alt_shift_toggle`

### Out of Scope
- Changing omarchy-nix upstream defaults (separate PR to `glats/omarchy-nix`)
- Adding `.XCompose` or custom compose tables
- Modifying other hosts (rog, thinkcentre unaffected)

## Capabilities

### New Capabilities
- `fcitx5-ime-t14`: fcitx5 input method deployment for t14 — packages, env vars, user config, autostart

### Modified Capabilities
None — no existing specs in `openspec/specs/` are affected.

## Approach

**Option C — Full restore + cleanup** (user-selected):

1. Recreate `hosts/t14/home/fcitx5.nix` from deleted version (commit `84f88a8`): session variables (`GTK_IM_MODULE`, `QT_IM_MODULE`, `XMODIFIERS`) + `xdg.configFile` for `fcitx5/profile` (es/latam/us layouts) and `fcitx5/config`
2. Add fcitx5 packages to `hosts/t14/home/omarchy.nix` `home.packages` (or within `fcitx5.nix` itself)
3. Add fcitx5 autostart — prefer `systemd.user.services.fcitx5` over Hyprland exec-once for reliability
4. Strip `,compose:caps` from both `input.nix` (Hyprland) and `default.nix` (ReGreet) — CAPS LOCK returns to normal behavior
5. Import restored `fcitx5.nix` in `hosts/t14/home/default.nix`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/home/fcitx5.nix` | New (restored) | Env vars + xdg.configFile for fcitx5 profile/config |
| `hosts/t14/home/omarchy.nix` | Modified | Add fcitx5 packages to `home.packages` |
| `hosts/t14/home/default.nix` | Modified | Import restored `fcitx5.nix` |
| `hosts/t14/home/hypr/input.nix` | Modified | Remove `,compose:caps` from `kb_options` |
| `hosts/t14/default.nix` | Modified | Remove `,compose:caps` from greeter `keyboard.options` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| fcitx5 + compose:caps collision — both fight over CAPS LOCK | High | Remove `compose:caps` from both Hyprland and ReGreet before enabling fcitx5 |
| Greeter keyboard mismatch — ReGreet still has compose:caps while session doesn't | Med | Fix both in same commit; verify greeter shows correct layout toggle |
| omarchy-nix upstream re-introduces compose:caps on next flake update | Med | Track upstream `input.nix` default; consider local `mkForce` without compose:caps as guard |
| fcitx5 package missing from closure | Low | Explicit `home.packages` declaration — not relying on omarchy |

## Rollback Plan

Revert the commit: `git revert <sha>`. This restores the pre-change state (no fcitx5, compose:caps present). If only partial issues, remove the `fcitx5.nix` import from `home/default.nix` and rebuild.

## Dependencies

- None external — fcitx5 is in nixpkgs, no custom overlays needed
- omarchy-nix upstream fix is recommended but NOT a prerequisite

## Success Criteria

- [ ] Dead keys (backtick `` ` ``, acute accent `´`) produce characters in terminal and GUI apps
- [ ] CAPS LOCK functions as normal Caps Lock (not remapped to dead Compose)
- [ ] fcitx5 tray icon appears in waybar after login
- [ ] `es` / `latam` layouts toggle with Alt+Shift
- [ ] ReGreet greeter keyboard matches session (no compose:caps)
- [ ] `nix flake check --no-build` passes
