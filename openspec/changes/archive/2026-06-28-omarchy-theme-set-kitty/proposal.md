# Proposal: omarchy-theme-set-kitty

## Intent

`omarchy-theme-set` generates per-theme `kitty.conf` files and places a live symlink at `~/.config/omarchy/current/theme/kitty.conf`. omarchy-nix's kitty module emits `include = "~/.config/omarchy/current/theme/kitty.conf"` via `lib.mkDefault`. However, `home-linux/kitty.nix` wraps `programs.kitty.settings` in `lib.mkForce`, which **drops the `include` directive entirely on t14**. Result: kitty on t14 ignores `omarchy-theme-set` recoloring — the palette stays frozen at whatever nix-colors evaluated to at build time.

Ghostty has the identical problem (`home-linux/ghostty.nix` also uses `lib.mkForce`), but is out of scope for this change (see Open Questions).

## Scope

### In Scope
- Restore omarchy-nix's `include` directive on t14 so `omarchy-theme-set` recolors kitty at runtime
- Switch `lib.mkForce` → `lib.mkDefault` on `programs.kitty.settings` in `home-linux/kitty.nix`
- Resolve merge semantics for opacity, keybindings, and padding that omarchy-nix also defines

### Out of Scope
- Ghostty runtime recoloring (same root cause, separate change)
- Changes to omarchy-nix upstream
- rog / thinkcentre kitty config (no omarchy-nix imported — unaffected)

## Capabilities

### New Capabilities
_None_

### Modified Capabilities
- `kitty-consolidation`: The spec currently requires `lib.mkForce` on `programs.kitty.settings`. This change relaxes that to `lib.mkDefault` on t14, allowing omarchy-nix's `include` to merge in. rog/thinkcentre remain byte-identical (no omarchy-nix竞争).

## Approach

**Approach A (recommended):** Change `lib.mkForce` → `lib.mkDefault` on `programs.kitty.settings` in `home-linux/kitty.nix`.

- **t14**: omarchy-nix is imported first (`inputs.omarchy-nix.homeManagerModules.default`), then `home-linux/kitty.nix` via `./default.nix`. With `mkDefault` on both sides, later definitions win per-key. The `include` directive from omarchy-nix survives; nixos-hosts's color definitions, padding, and user preferences also survive (they are either unique keys or higher-priority `mkDefault` from the later import).
- **rog / thinkcentre**: No omarchy-nix imported → `mkDefault` is the effective priority, same behavior as today.

**Trade-off vs Approach B** (xdg.configFile override on t14 only): Approach A is a one-line change with no host-conditional logic. Approach B preserves byte-identical config but adds t14-specific plumbing.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/kitty.nix` | Modified | `lib.mkForce` → `lib.mkDefault` on `settings` (line 29) |
| `openspec/specs/kitty-consolidation/spec.md` | Modified | Relax mkForce requirement to mkDefault; document merge semantics |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| omarchy-nix's `background_opacity = "0.95"` merges back, overriding nixos-hosts's `0.6` | Medium | Verify eval output; if it does, add explicit `background_opacity = lib.mkForce "0.6"` or accept omarchy's value |
| omarchy-nix keybindings merge back, conflicting with `kitty_mod+f10` | Low | Keybindings are per-key merge; no conflict expected |
| rog/thinkcentre behavior changes | None | They don't import omarchy-nix — `mkDefault` has no competitor |

## Rollback Plan

Revert `lib.mkDefault` → `lib.mkForce` in `home-linux/kitty.nix` line 29. Single-line revert, no other files affected.

## Dependencies

- omarchy-nix's `modules/home-manager/kitty.nix` must emit `include` via `lib.mkDefault` (already the case — no upstream change needed)

## Success Criteria

- [ ] `omarchy-theme-set <theme>` on t14 changes kitty's live palette without rebuild
- [ ] `~/.config/kitty/kitty.conf` on t14 contains `include ~/.config/omarchy/current/theme/kitty.conf`
- [ ] rog / thinkcentre kitty.conf unchanged (byte-identical to pre-change)
- [ ] `nix flake check --no-build` passes

## Open Questions

1. **Ghostty scope**: Fix ghostty in the same change (same `lib.mkForce` → `lib.mkDefault` pattern in `home-linux/ghostty.nix`), or defer to a follow-up?
2. **Opacity**: omarchy-nix sets `background_opacity = "0.95"`, nixos-hosts sets `"0.6"`. With `mkDefault`, which wins depends on import order. Should we force `"0.6"` explicitly, or accept omarchy's `"0.95"` on t14?
3. **Keybindings**: omarchy-nix may define `ctrl+insert` / `shift+insert`. Accept merge, or explicitly override?
