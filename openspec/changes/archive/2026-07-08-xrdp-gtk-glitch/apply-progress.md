# Apply Progress: xrdp Compositor Configuration

## Status: COMPLETE

## Summary

Removed picom from rog and thinkcentre host home-manager configs, and enabled marco compositing (removed dconf lock, set `compositing-manager = true`).

## Changes Applied

| File | Change |
|------|--------|
| `hosts/rog/home/modules.nix` | Removed `../../../home-linux/picom.nix` import (line 9) |
| `hosts/thinkcentre/home/modules.nix` | Removed `../../../home-linux/picom.nix` import (line 9) |
| `modules/base/dconf.nix` | Changed `compositing-manager = false` to `true`, removed `locks` block |

## Verification

- `format-nix` — passed (no formatting changes needed)
- `nix flake check --no-build` — passed (rog, thinkcentre, t14 all evaluated successfully)

## Next Step

Ready for `sdd-verify`.
