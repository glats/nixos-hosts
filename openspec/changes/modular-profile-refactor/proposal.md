# Proposal: Modular Profile Refactor

## Intent

SDD #1 (suite separation) and #2 (per-host audit) left `lib.mkIf (cfg != "gnome")` gates scattered across 4 profile files — 19 in `base.nix`, 2 in `dev.nix`, 3 in `media.nix`, 2 in `browsers.nix`. Every profile threads `{ pkgs, config, lib }` just to support the `nonGnome` helper. This is the third refactor of package composition in as many changes — time to finish the job.

**Goal**: Zero inline conditions. Suite-level decisions happen in `packages.nix` by choosing which profiles to import, not by gating individual packages inside profiles.

## Scope

### In Scope
- Remove ALL `lib.mkIf` / `nonGnome` helpers from `base.nix`, `dev.nix`, `media.nix`, `browsers.nix`
- Split `base.nix` → `core.nix` (truly shared) + `cli-extra.nix` (11 CLI tools omarchy duplicates)
- Move 8 X11/MATE desktop apps (scrot, xclip, flameshot, copyq, gpaste, conky, hexchat, gtk-engine-murrine) from `base.nix` into `mate.nix`
- `mate.nix` imports `cli-extra.nix` internally
- `dev.nix`, `media.nix`, `browsers.nix` become condition-free — accept harmless duplicates on t14 (Nix deduplicates at store level)
- Rewrite `packages.nix` to compose profiles by suite with zero conditionals

### Out of Scope
- Changes to `omarchy-nix` (no upstream PRs)
- Host `default.nix` files (suite declarations unchanged)
- `options.nix`, `virt.nix` (already condition-free)
- Package additions or removals (pure restructuring)

## Capabilities

### New Capabilities
None — pure internal refactor, no user-facing behavior change.

### Modified Capabilities
None — no existing `openspec/specs/` affected.

## Approach

**Profile-level composition replaces package-level gating.**

```
modules/base/profiles/
├── core.nix        ← ALL hosts: bat, zip, htop, meld, gparted, tree, networking tools,
│                      nix tools, themes, remmina, pipewire-module-xrdp, etc. (~70 pkgs)
├── cli-extra.nix   ← MATE only: fzf, curl, wget, unzip, fastfetch, btop, coreutils,
│                      lazygit, lazydocker, jq, ghostty (11 pkgs — omarchy dups on t14)
├── mate.nix        ← MATE DE + X11 apps + materia-theme + imports cli-extra.nix
├── gnome.nix       ← gnome-system-monitor only (unchanged)
├── dev.nix         ← ALL hosts: gcc, gnumake, nodejs, go, bun, neovim, etc. (ungated)
├── media.nix       ← ALL hosts: mpv, wiremix, ffmpeg, intel GPU, gstreamer (ungated)
├── browsers.nix    ← ALL hosts: chrome, edge, chromium, brave (ungated)
├── virt.nix        ← ALL hosts: qemu, docker, etc. (unchanged)
```

**`packages.nix` composition:**
```nix
sharedProfiles  = [ ./core.nix ./dev.nix ./virt.nix ./media.nix ./browsers.nix ];
mateOnlyProfiles = [ ./mate.nix ];     # pulls in cli-extra.nix internally
gnomeOnlyProfiles = [ ./gnome.nix ];
```

**Duplicate acceptance** (dev/media/browsers): t14 evaluates mpv, ffmpeg, wiremix, chromium, brave, gnumake, nodejs from BOTH nixos-hosts and omarchy-nix. Same derivation → same `/nix/store` path → zero runtime cost. This is preferable to splitting profiles further (which would create 4+ micro-files for 7 packages).

**What t14 does NOT get from nixos-hosts**: X11/MATE apps (scrot, conky, flameshot, etc.) and CLI extras (fzf, curl, etc.) — these live in `mate.nix`/`cli-extra.nix` which t14 never imports.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/base/profiles/base.nix` | Removed | Split into `core.nix` + `cli-extra.nix` + X11 apps → `mate.nix` |
| `modules/base/profiles/core.nix` | New | ~70 shared packages, zero conditions |
| `modules/base/profiles/cli-extra.nix` | New | 11 CLI tools omarchy duplicates |
| `modules/base/profiles/mate.nix` | Modified | Add X11 apps + `imports [ ./cli-extra.nix ]` |
| `modules/base/profiles/dev.nix` | Modified | Remove `nonGnome` helper + 2 gates |
| `modules/base/profiles/media.nix` | Modified | Remove `nonGnome` helper + 3 gates |
| `modules/base/profiles/browsers.nix` | Modified | Remove `nonGnome` helper + 2 gates |
| `modules/base/packages.nix` | Modified | Replace `suitePkgs` if/else with shared/mate/gnome profile lists |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| t14 closure grows from harmless dups | Certain | ~7 extra derivations evaluated but already in omarchy closure. Negligible. |
| X11 app accidentally lands in `core.nix` | Low | Review checklist: scrot, xclip, flameshot, copyq, gpaste, conky, hexchat, gtk-engine-murrine MUST be in `mate.nix` |
| `cli-extra.nix` import cycle in `mate.nix` | Low | `mate.nix` imports `cli-extra.nix` as a plain list concat — no Nix module system involvement |
| Profile function signatures change breaks import | Low | `core.nix`, `dev.nix`, `media.nix`, `browsers.nix` drop `{ config, lib }` from args (no longer needed). `packages.nix` updates import call sites. |

## Rollback Plan

Single commit in `glats/.nixos`. `git revert` restores all `nonGnome` gates and the monolithic `base.nix`. No secret changes, no upstream dependencies, no data migration.

## Dependencies

- None. Self-contained within `modules/base/profiles/` and `modules/base/packages.nix`.

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` clean
- [ ] Zero `lib.mkIf` or `nonGnome` in any profile file (`rg "mkIf|nonGnome" modules/base/profiles/` returns nothing)
- [ ] Zero `{ config, lib, ... }` in profiles that no longer need them (`core.nix`, `cli-extra.nix`, `dev.nix`, `media.nix`, `browsers.nix` take only `{ pkgs }`)
- [ ] t14 closure contains zero X11/MATE apps (scrot, conky, flameshot, copyq, gpaste, hexchat)
- [ ] t14 closure contains zero CLI extras from nixos-hosts (fzf, curl, wget, lazygit, etc. — provided by omarchy-nix instead)
- [ ] rog/thinkcentre closure unchanged (same packages as before refactor)
