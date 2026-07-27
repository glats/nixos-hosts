# Proposal: Homologate t14 → rog pattern

## Intent

t14 uses inline HM bridge with 14 redundant imports and 4 conflicting modules (theme, fontconfig, alacritty, gpg). Host diverges from rog/thinkcentre pattern (base/home-manager.nix + list-function home/). Align t14 to the standard for maintainability. Zero behavior change.

## Scope

### In Scope

- `hosts/t14/default.nix`: Replace inline HM block → `../../linux/system/base/home-manager.nix` import
- `hosts/t14/home/default.nix`: Convert from HM module (`{ config, pkgs, ... }`) → list function (`{ inputs }: [ ... ]`) with filtered shared-modules; add hyprdynamicmonitors
- `hosts/t14/home/omarchy.nix`: Absorb old default.nix HM content (waybar, kb scripts, HDM config); drop 14 redundant imports + `./default.nix` import
- `flake.nix`: Update standalone `t14` homeConfigurations to use `./home/default.nix { inherit inputs; }` + hyprdynamicmonitors inline

### Out of Scope

- Behavior changes to existing module content
- Extracting the filter list (4 conflicts) into a reusable lib function
- Migrating `home-manager.backupFileExtension` or other HM options

## Capabilities

None — pure refactor, no spec-level changes.

## Approach

1. Move old `default.nix` body → `omarchy.nix`. Drop 14 redundant paths from omarchy.nix imports.
2. Convert `default.nix` to list function. Import shared-modules.nix, filter 4 conflicts. Add omarchy.nix + hyprdynamicmonitors + t14 extras (remote-desktop, shell-gpt).
3. Add `base/home-manager.nix` to t14 default.nix imports. Remove inline HM block.
4. Align flake.nix standalone config to list function + hyprdynamicmonitors.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/t14/default.nix` | Modified | +1 import, −14 lines (inline HM block) |
| `hosts/t14/home/default.nix` | Rewritten | Set → list function |
| `hosts/t14/home/omarchy.nix` | Modified | Absorbs old default content, drops 14 imports |
| `flake.nix` | Modified | t14 standalone uses home/default.nix list |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Forgot one shared module | Low | Diff against todays shared-modules.nix |
| omarchy HM `inputs` missing from extraSpecialArgs | Low | base/home-manager.nix already passes it |
| HyprDynamicMonitors not in NixOS-integrated HM path | Low | Add to default.nix list |

## Rollback Plan

`git revert` the commit. The old inline HM block is fully self-contained.

## Dependencies

None.

## Success Criteria

- [ ] `nix flake check --no-build` passes for t14
- [ ] `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds
- [ ] 14 redundant imports removed from omarchy.nix
- [ ] All 4 conflicting modules (theme, fontconfig, alacritty, gpg) absent from t14 HM eval
