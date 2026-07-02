# Proposal: Rename btop theme to `glats` across all NixOS hosts

## Intent

Users looking for the "glats" btop theme see only `nix-colors.theme` on disk, making the glats palette appear missing even though it is correctly deployed. Rename the theme file and its `color_theme` reference so the on-disk name matches user expectations.

## Scope

### In Scope
- Rename theme file `nix-colors.theme` → `glats.theme` in `home-linux/btop-theme.nix`
- Update `color_theme` value in `home-linux/btop-file.nix` (rog, thinkcentre)
- Update `color_theme` value in `home-linux/btop-settings.nix` (t14)

### Out of Scope
- Visual parity between rog/thinkcentre and t14 (#1269 drift — separate change)
- Resolving the t14 dual-writer (omarchy-nix `btop.nix` also writes `glats.theme`); after rename both writers converge on the same path with identical content, so no functional conflict exists
- Darwin `home-darwin/btop.nix` — not in scope (Linux-only module set)

## Capabilities

### New Capabilities
None — pure config rename, no new behavior.

### Modified Capabilities
None — no spec-level behavior changes.

## Approach

**Single rename across three files.** The glats palette is already byte-identical across all three hosts; only the file name and the `color_theme` string differ from user expectations.

1. `home-linux/btop-theme.nix`: change `home.file."~/.config/btop/themes/nix-colors.theme"` → `home.file."~/.config/btop/themes/glats.theme"`
2. `home-linux/btop-file.nix`: change `color_theme = "nix-colors"` → `color_theme = "glats"`
3. `home-linux/btop-settings.nix`: change `lib.mkForce "nix-colors"` → `lib.mkForce "glats"`

Update inline comments that reference `nix-colors` to match.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/btop-theme.nix` | Modified | Theme file path renamed |
| `home-linux/btop-file.nix` | Modified | `color_theme` string updated (rog/thinkcentre) |
| `home-linux/btop-settings.nix` | Modified | `color_theme` string updated (t14) |

Estimated delta: ~10 lines across 3 files.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| t14 dual-writer: omarchy-nix and `btop-theme.nix` both produce `glats.theme` | Low | Content is byte-identical today; add a comment in `btop-theme.nix` noting the convergence so future palette drift is visible |
| User has a manually edited `nix-colors.theme` on a host | Low | Home Manager `home.file` overwrites on switch; document in commit message |
| No visual change — users may not notice the fix | Info | Success criterion is disk-level, not visual |

## Rollback Plan

Revert the three-file rename (single `git revert` of the apply commit). Because `home.file` is declarative, the previous generation's `nix-colors.theme` + `color_theme = "nix-colors"` is already in the Nix store and can be re-activated by rolling back to the prior generation (`nixos-rebuild switch --rollback` on the affected host).

## Dependencies

None.

## Success Criteria

- [ ] `ls ~/.config/btop/themes/` shows `glats.theme` on rog, thinkcentre, and t14 after `nixos-rebuild switch`
- [ ] `grep color_theme ~/.config/btop/btop.conf` returns `glats` on all three hosts
- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` passes (no new formatting regressions)
- [ ] No `nix-colors.theme` file remains on any host
