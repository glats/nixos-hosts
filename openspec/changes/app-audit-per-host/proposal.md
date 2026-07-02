# Proposal: App Audit Per Host

## Intent

Remove redundant package declarations on t14 (where omarchy-nix already provides them) and drop the `imv` image viewer from omarchy-nix (t14 keeps `loupe`). Shared profiles currently declare ~18 packages that omarchy-nix also installs for t14 — harmless on disk (Nix deduplicates builds) but adds eval noise and makes the inventory harder to reason about.

**Why now**: The per-host audit (`exploration.md`) made the duplication visible. The `my.desktop.suite` option (from `host-desktop-suite-separation`) provides the exact gate needed to conditionally exclude these packages on t14 without affecting rog/thinkcentre.

## Scope

### In Scope
1. **omarchy-nix**: Remove `imv` HM module (`modules/home-manager/imv.nix`) and its import from `modules/home-manager/default.nix`. t14 keeps `loupe` as sole image viewer.
2. **nixos-hosts**: Gate 18 duplicated packages in shared profiles (`base.nix`, `dev.nix`, `media.nix`) with `lib.mkIf (cfg != "gnome")` so they install on rog/tc but not t14.
3. **Verify t14 package coverage**: Confirm all non-duplicated shared-profile packages (e.g. `bat`, `delta`, `aria2`, `htop`, networking utils) actually reach t14 via `modules/base/packages.nix`. If any are missing, fix the wiring.

### Out of Scope
- Browsers (`browsers.nix`) — kept shared, no gating (user decision)
- `libsecret` — kept in both base profiles AND omarchy-nix for redundancy (user decision)
- `ripgrep`, `fd` — these are HM-level duplicates (`home-linux/neovim.nix`), not in shared system profiles. Out of scope for this change.
- omarchy-only packages (`obsidian`, `vlc`, `krita`, `spotify`, `localsend`, etc.) — stay omarchy-only, no changes
- Packages not duplicated by omarchy (e.g. `bat`, `delta`, `htop`, `meld`, `windsurf`) — remain in shared profiles for all hosts

## Capabilities

### New Capabilities
- `conditional-dedup-gate`: `lib.mkIf (cfg != "gnome")` wrapper for packages duplicated by omarchy-nix, applied in shared profiles

### Modified Capabilities
None (no existing `openspec/specs/` to modify)

## Approach

Change shared profile functions from `{ pkgs }: [...]` to `{ pkgs, config, lib }: [...]` and wrap duplicated packages with `lib.mkIf (config.my.desktop.suite != "gnome")`. Update `packages.nix` to pass `config` and `lib` to profile imports.

**Packages to gate** (18 total):
- `base.nix`: `git`, `btop`, `fastfetch`, `curl`, `wget`, `unzip`, `fzf`, `jq`, `coreutils`, `gnome-themes-extra`, `lazygit`, `lazydocker`, `ghostty`
- `dev.nix`: `gnumake`, `nodejs`
- `media.nix`: `ffmpeg`, `mpv`, `wiremix`

**Helper pattern**:
```nix
{ pkgs, config, lib }:
let
  cfg = config.my.desktop.suite;
  nonGnome = pkg: lib.mkIf (cfg != "gnome") pkg;
in
with pkgs;
[
  (nonGnome git)
  bat          # not duplicated — always included
  ...
]
```

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/base/profiles/base.nix` | Modified | Gate 13 duplicated packages with `nonGnome` helper |
| `modules/base/profiles/dev.nix` | Modified | Gate `gnumake`, `nodejs` |
| `modules/base/profiles/media.nix` | Modified | Gate `ffmpeg`, `mpv`, `wiremix` |
| `modules/base/packages.nix` | Modified | Pass `config` and `lib` to profile imports |
| `glats/omarchy-nix` `modules/home-manager/imv.nix` | Removed | Delete file |
| `glats/omarchy-nix` `modules/home-manager/default.nix` | Modified | Remove `./imv.nix` import (line 74) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `lib.mkIf` inside list not resolved by module system | Low | `environment.systemPackages` is a list-of-packages option; `mkIf` in list elements is standard NixOS pattern |
| Profile function signature change breaks import sites | Low | Only `packages.nix` imports these profiles; single call site to update |
| t14 loses a package it actually needs (not truly duplicated) | Med | User said "cuidado con borrar algo" — verify each gated package is actually provided by omarchy before gating. Rollback is a single revert. |
| omarchy-nix `imv` removal breaks HM eval | Low | `imv.nix` is a standalone HM module with no reverse dependencies; `loupe` remains as image viewer |

## Rollback Plan

**nixos-hosts**: Revert the profile changes (restores unconditional package lists). Single `git revert`.

**omarchy-nix**: Revert the `imv` removal (restores `imv.nix` and its import). Single `git revert`.

No data migration, no secret changes, no host-specific state affected.

## Dependencies

- `host-desktop-suite-separation` must be merged first (provides `my.desktop.suite` option and `packages.nix` composition)
- omarchy-nix changes and nixos-hosts changes are independent and can proceed in parallel

## Delivery Plan

| # | PR | Repo | Content | Est. lines |
|---|----|------|---------|------------|
| 1 | omarchy-nix PR | `glats/omarchy-nix` | Remove `imv.nix` + import | ~-62 |
| 2 | nixos-hosts PR | `glats/.nixos` | Gate 18 packages + pass config/lib to profiles + verify t14 coverage | ~+40/-20 |

Direct commits to main (user preflight: phase-pause, hybrid, single change, 2 review rounds).

## Success Criteria

- [ ] `nix flake check --no-build` passes in both repos
- [ ] `format-nix` clean in nixos-hosts
- [ ] t14 closure: no `imv` binary, `loupe` present as image viewer
- [ ] t14 closure: 18 gated packages absent (e.g. no duplicate `git` from base.nix — omarchy's `git` remains)
- [ ] rog/tc closure: all 18 gated packages still present (unchanged behavior)
- [ ] All non-duplicated shared packages (bat, delta, htop, networking utils, etc.) present on t14
- [ ] `libsecret` present on all 3 hosts (untouched)
- [ ] All browsers present on all 3 hosts (untouched)
