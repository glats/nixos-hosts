# Proposal: t14 Waybar Keyboard Layout Indicator

## Intent

The t14 host has working keyboard layout toggle scripts (`kb-toggle.sh`, `kb-layout.sh`) and Alt+Shift binding to cycle between `es` and `latam` layouts, but there is no visual indicator in waybar showing the current layout. Users cannot tell which layout is active without opening a terminal and running `hyprctl keyboard-layout`. Adding a waybar widget closes this feedback loop and enables click-to-toggle from the bar.

## Scope

### In Scope
- Add `custom/language` module to waybar config in `omarchy-nix`
- Wire click-to-toggle via existing `kb-toggle.sh`
- Bump `omarchy-nix` flake pin in `nixos` repo after upstream merge

### Out of Scope
- Layout indicator on other hosts (rog, thinkcentre, mact2)
- Per-window layout tracking or layout-aware keybinding hints
- Native `hyprland/language` module migration (deferred — needs IPC field verification)

## Capabilities

### New Capabilities
- `waybar-keyboard-layout`: Waybar module displaying current XKB layout name with click-to-toggle

### Modified Capabilities
None

## Approach

Use waybar's `custom/language` module (shell-exec pattern) rather than the native `hyprland/language` module. Rationale: the `custom/*` pattern is already used by 5 other modules in this config (`custom/iwd-wifi`, `custom/voxtype`, `custom/idle-indicator`, etc.), the scripts are proven, and it avoids uncertainty about the native module's JSON field names for non-standard layout identifiers like `latam`.

**Change 1 — omarchy-nix repo** (`config/waybar/config`):
- Add `"custom/language"` to `modules-right` array (before `"cpu"`)
- Add module config block: `exec` calls `kb-layout.sh`, `on-click` calls `kb-toggle.sh`, `interval: 5`, `tooltip: true`

**Change 2 — nixos repo** (`flake.nix`):
- Bump `omarchy-nix` input pin to the merged commit

No other files change. The HM `home.file` in `waybar.nix:10-13` already deploys the entire `config/waybar/` directory recursively.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix:config/waybar/config` | Modified | Add module entry + config block (~8 lines) |
| `nixos:flake.nix` | Modified | Bump omarchy-nix input pin (1 line) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `kb-layout.sh` output format mismatch with waybar `custom` module `return-type` | Low | Script outputs plain text ("es"/"latam"); default `return-type` is `"text"` which renders `exec` stdout directly — no JSON wrapping needed |
| `latam` layout name renders oddly in waybar font | Low | Test visually; can add `format-es`/`format-latam` mapping if using native module later |
| Waybar doesn't reload after config change | Low | `reload_style_on_change: true` is set; HM activation triggers waybar restart |

## Rollback Plan

1. Revert the `config/waybar/config` change in omarchy-nix (remove module entry + block)
2. Revert flake pin bump in `flake.nix`
3. Run `nixos-build` — waybar redeploys without the module

Both changes are independent and reversible in either order.

## Dependencies

- omarchy-nix upstream PR must merge before flake pin bump
- `kb-layout.sh` and `kb-toggle.sh` must be deployed on t14 (already done)

## Success Criteria

- [ ] Waybar shows current layout label ("es" or "latam") in the right module group
- [ ] Clicking the widget toggles between es ↔ latam
- [ ] Layout label updates within 5 seconds of toggle
- [ ] `nix flake check --no-build` passes on nixos repo
