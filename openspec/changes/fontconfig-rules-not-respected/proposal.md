# Proposal: Fontconfig Rules Not Respected

## Intent

Fontconfig rules (rejectfonts, redirects, strong aliases, emoji fallbacks) defined in `modules/desktop/fonts.nix` `localConf` are never loaded. The NixOS XSLT drops `local.conf` from the generated `/etc/fonts/fonts.conf`, so fontconfig ignores ALL user-defined rules. Fix by writing them directly into conf.d, which IS included.

## Scope

### In Scope
- Write all current `localConf` XML to `/etc/fonts/conf.d/51-nixos-custom.conf` via `environment.etc`
- Remove dead `localConf` block from `modules/desktop/fonts.nix`
- Fix "Source Sans Pro" -> "Source Sans 3" in `hosts/t14/home/hypr/hyprlock.nix`
- Apply to all 3 Linux hosts (rog, thinkcentre, t14)
- Preserve working `defaultFonts` aliases and font packages unchanged

### Out of Scope
- Browser-bundled font behavior (Brave/Chromium use their own fontconfig)
- Upstream nixpkgs XSLT fix (tracked as follow-up, not this change)
- GTK theme font overrides in `home-linux/theme.nix` (unaffected)

## Capabilities

### New Capabilities
- `system-fontconfig`: System-wide fontconfig rules (rejectfonts, aliases, redirects, emoji fallbacks) loaded from conf.d, surviving NixOS rebuilds

### Modified Capabilities
None. Bug fix: config existed but was never loaded.

## Approach

**Primary**: Replace `localConf = "..."` with `environment.etc."fonts/conf.d/51-nixos-custom.conf"` containing identical XML. Priority 51 runs before defaultFonts (52) and fontconfig's 60-latin.conf. Uses existing `environment.etc` pattern already present in `modules/hardware/nvidia.nix`. One file changed, ~30 lines replaced.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/desktop/fonts.nix` | Modified | Replace `localConf` with `environment.etc` block; keep rest unchanged |
| `hosts/t14/home/hypr/hyprlock.nix` | Modified | Line 54: "Source Sans Pro" -> "Source Sans 3" |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Brave/Chromium still show Noto/Roboto | Med | Browser fontconfig is independent — not fixable here; verify separately |
| Hyprlock break after font rename | Low | "Source Sans 3" is same font, updated family name; verify with `fc-list` |
| Priority conflict with existing conf.d | Low | Priority 51 is deliberate — before defaultFonts (52), after rendering (10) |

## Rollback Plan

Revert `modules/desktop/fonts.nix` and `hosts/t14/home/hypr/hyprlock.nix` in git, rebuild. No state migration needed.

## Dependencies

None.

## Success Criteria

- [ ] `nix flake check --no-build` passes for all Linux hosts
- [ ] `fc-match sans-serif` returns "Source Sans 3" as first choice after rebuild
- [ ] `fc-list` confirms Liberation, DejaVu, Arimo rejected (not in results)
- [ ] `fc-match Arial` resolves to sans-serif family (redirect active)
- [ ] Hyprlock renders "Source Sans 3" without fallback on t14
