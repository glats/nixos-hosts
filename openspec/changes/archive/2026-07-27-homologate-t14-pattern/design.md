# Design: Homologate t14 → rog Pattern

## Tech Approach

Strip inline HM block from t14/default.nix → import base/home-manager.nix bridge. Convert home/default.nix from HM module (set) → list function matching rog/thinkcentre. Absorb old default.nix body into omarchy.nix. Filter shared-modules via excludedPaths list to drop 4 conflicting modules.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Shared-module filtering | excludedPaths in home/default.nix: import shared-modules, filter with `builtins.filter` against path list | Simpler than lib function (per OOS). No reuse needed yet. Paths: theme, fontconfig, alacritty, gpg |
| Old default.nix body | Move content (waybar svc, kb scripts, HDM config, mouse-wiggle) → omarchy.nix via inline imports | Eliminates redundant `./default.nix` import. Keeps t14-specific overlays with omarchy |
| HM bridge | Same base/home-manager.nix import as rog/thinkcentre | Already passes inputs + hostName. Drop 14-line inline block. One import line replaces 14 |
| Standalone HM flake | Point to `./home/default.nix { inherit inputs; }` + HDM inline | Matches omarchy.nix self-contained pattern; avoids duplicate module errors |

## File Changes

| File | Action | Δ |
|------|--------|---|
| `hosts/t14/default.nix` | Modify | −14 inline HM block, +1 bridge import |
| `hosts/t14/home/default.nix` | Rewrite | Set → list function. 26 lines instead of 111 |
| `hosts/t14/home/omarchy.nix` | Modify | Absorb old default body. Remove 14 redundant paths. Drop `./default.nix` import |
| `flake.nix` | Modify | t14 standalone uses home/default.nix list + HDM |

## Interfaces

```nix
# home/default.nix — list function (same shape as rog/thinkcentre)
{ inputs }: let
  base = import ../../../linux/home/shared-modules.nix { inherit inputs; };
  excluded = [
    ../../../linux/home/theme.nix
    ../../../linux/home/fontconfig.nix
    ../../../linux/home/alacritty.nix
    ../../../linux/home/gpg.nix
  ];
in builtins.filter (m: !builtins.elem m excluded) base ++ [
  ./omarchy.nix
  ../../../linux/home/remote-desktop.nix
  ../../../linux/home/shell-gpt.nix
  { home.shell-gpt.enable = true; }
  inputs.hyprdynamicmonitors.homeManagerModules.default
]
```

## Migration

Single commit. `git revert` rollback. No data migration. Verify with `nix flake check --no-build` + `nix build .#nixosConfigurations.t14.config.system.build.toplevel`.

## Testing

| Layer | What | How |
|-------|------|-----|
| Build | t14 toplevel | `nix build .#nixosConfigurations.t14.config.system.build.toplevel` |
| Diff | Module content unchanged | Compare omarchy.nix before/after for equal EVAL |
| Verify | 4 conflicts absent | `nix eval` that excluded paths are not in HM imports |

## Open Questions

None.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.
