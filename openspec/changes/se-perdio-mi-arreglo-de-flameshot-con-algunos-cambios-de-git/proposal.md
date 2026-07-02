# Proposal: Restore Flameshot X11 Legacy Screenshot Fix

## Intent

User reported losing their flameshot "arreglo" in commit `ffb327c`. Initial investigation incorrectly concluded MATE flameshot was intact. **Corrected finding**: the lost fix was a `flameshot.ini` config with `useX11LegacyScreenshot=true` — deleted when `cinnamon.nix` was removed in `ffb327c`. Without it, Flameshot v14 tries xdg-desktop-portal Screenshot, which fails on X11/xrdp sessions (no portal backend implements Screenshot on Cinnamon/MATE/xrdp).

## Root Cause

`stash@{2}` (the deleted `cinnamon.nix`) contained:

```nix
"flameshot/flameshot.ini".text = ''
  [General]
  contrastOpacity=188
  useX11LegacyScreenshot=true
'';
```

This config was in `cinnamon.nix`'s `xdg.configFile`, but it applies to **all X11/xrdp sessions** regardless of DE. When `cinnamon.nix` was deleted, the ini file disappeared. Flameshot v14 now defaults to the portal path, which has no backend on this setup → broken screenshots.

## Scope

### In Scope
- Add `flameshot/flameshot.ini` to `home-linux/mate.nix` `xdg.configFile` (~10 lines)

### Out of Scope
- Restoring `cinnamon.nix`, `xfce.nix`, `xfce-defaults.nix` (user doesn't use these DEs)
- Restoring XRDP multi-DE picker or `bin/xrdp-back-to-picker`

## Approach

Add the `flameshot.ini` entry to the existing `xdg.configFile` block in `home-linux/mate.nix` (block starts at line 264, flameshot autostart at lines 278-293):

```nix
# Flameshot v14 uses xdg-desktop-portal Screenshot by default.
# X11/xrdp sessions have no portal backend for Screenshot.
# Fall back to legacy X11 capture path.
"flameshot/flameshot.ini".text = ''
  [General]
  contrastOpacity=188
  useX11LegacyScreenshot=true
'';
```

Place immediately after the existing flameshot autostart `.desktop` entry for logical grouping.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/mate.nix` | Modified | Add `flameshot.ini` with `useX11LegacyScreenshot=true` to `xdg.configFile` |

## Constraints

- Review budget: ~10 lines (trivial)
- Delivery: direct to main, single commit
- Single file change

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `contrastOpacity=188` not desired | Low | User's original value from deleted config — matches their preference |
| `useX11LegacyScreenshot` removed in future flameshot | Low | Only relevant while v14+ lacks portal backend on X11/xrdp |

## Rollback Plan

Remove the `flameshot/flameshot.ini` entry from `mate.nix` and rebuild.

## Success Criteria

- [ ] `~/.config/flameshot/flameshot.ini` exists after rebuild with `useX11LegacyScreenshot=true`
- [ ] Flameshot captures screenshots correctly in MATE/xrdp sessions
- [ ] No regression in non-xrdp MATE sessions
