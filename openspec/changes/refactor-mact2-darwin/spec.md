# Spec: Refactor mact2 Darwin Configuration

**Change**: `refactor-mact2-darwin`
**Status**: Draft
**Parent artifacts**:
- `openspec/changes/refactor-mact2-darwin/exploration-report.md`
- `openspec/changes/refactor-mact2-darwin/proposal.md`

---

## ADDED Requirements

### R1: Darwin Profile Chain

The Darwin system modules SHALL mirror the NixOS `modules/profiles/` pattern: a pure import aggregator (`modules/darwin/profiles/base.nix`) that lists categorized darwin modules, with individual modules organized by concern under `modules/darwin/system/` and `modules/darwin/services/`.

#### R1.1: Profile Aggregator Must Be a Pure Import List

`modules/darwin/profiles/base.nix` MUST be a pure import aggregator — it SHALL contain ONLY an `imports` list and NO inline configuration (no `nix.settings`, no `homebrew.*`, no `system.*`, no `services.*`, no `environment.*`). This mirrors `modules/profiles/base.nix`.

**Scenario R1.1.1 — Pure import list**
- **Given**: `modules/darwin/profiles/base.nix`
- **When**: evaluated
- **Then**: it contains only `{ imports = [ ... ]; }` with zero top-level config keys beyond `imports`.

#### R1.2: System Modules Categorized Under `modules/darwin/system/`

All darwin system modules from the flat `darwin/` directory SHALL be moved to `modules/darwin/system/` or `modules/darwin/services/` based on their concern:

| Source (removed) | Destination (created) | Category |
|---|---|---|
| `darwin/nix.nix` | N/A (inline config extracted) | — |
| `darwin/cachix.nix` | `modules/darwin/system/cachix.nix` | system |
| `darwin/homebrew.nix` | `modules/darwin/system/homebrew.nix` | system |
| `darwin/settings.nix` | `modules/darwin/system/settings.nix` | system |
| `darwin/mise.nix` | `modules/darwin/system/mise.nix` | system |
| `darwin/wsdd.nix` | `modules/darwin/services/wsdd.nix` | services |

**Scenario R1.2.1 — Module locations**
- **Given**: the refactored repository
- **When**: `ls modules/darwin/system/` and `ls modules/darwin/services/`
- **Then**: all six modules exist at their destination paths and the original `darwin/*.nix` files no longer exist (except `darwin/default.nix`).

#### R1.3: Inline Nix Config Extracted to `modules/darwin/system/nix.nix`

The inline `nix.settings`, `nix.enable`, and `nixpkgs.config.allowUnfree` blocks currently in `darwin/default.nix` (lines 21-33) SHALL be extracted into a new `modules/darwin/system/nix.nix` module. This file MUST include:

- `nix.settings.experimental-features = [ "nix-command" "flakes" ];`
- `nix.enable = false;` with comment referencing Determinate installer
- `nixpkgs.config.allowUnfree = true;`

The `nix.registry.nixpkgs.flake` pinning and build-optimization settings (`max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`) currently in `darwin/cachix.nix` SHALL be consolidated into `modules/darwin/system/nix.nix` so that all `nix.*` settings live in a single file. `modules/darwin/system/cachix.nix` thereafter SHALL contain only substituters/trusted-keys configuration.

**Scenario R1.3.1 — Nix settings consolidated**
- **Given**: `modules/darwin/system/nix.nix`
- **When**: evaluated
- **Then**: it sets `nix.settings.experimental-features`, `nix.enable`, `nixpkgs.config.allowUnfree`, `nix.settings.max-jobs`, `nix.settings.cores`, `nix.settings.keep-outputs`, `nix.settings.trusted-substituters`, and `nix.registry.nixpkgs.flake`.

**Scenario R1.3.2 — Cachix file contains only substituter config**
- **Given**: `modules/darwin/system/cachix.nix`
- **When**: evaluated
- **Then**: it sets ONLY `nix.settings.substituters`, `nix.settings.trusted-public-keys`, and `environment.systemPackages = [ cachix ]`. It does NOT set `nix.registry`, `max-jobs`, `cores`, `keep-outputs`, or `trusted-substituters` (those are in nix.nix).

#### R1.4: `darwin/default.nix` Imports the Profile Instead of Individual Files

`darwin/default.nix` SHALL replace its current individual module imports (`./mise.nix`, `./cachix.nix`, `./homebrew.nix`, `./settings.nix`, `./wsdd.nix`) with a single import of `../modules/darwin/profiles/base.nix`. The home-manager, nix-homebrew, user config, environment, and services enablement blocks SHALL remain in `darwin/default.nix`.

**Scenario R1.4.1 — Single profile import**
- **Given**: `darwin/default.nix`
- **When**: evaluated
- **Then**: its `imports` list includes `../modules/darwin/profiles/base.nix` and does NOT include `./mise.nix`, `./cachix.nix`, `./homebrew.nix`, `./settings.nix`, or `./wsdd.nix`.

**Scenario R1.4.2 — Inline nix config removed**
- **Given**: `darwin/default.nix`
- **When**: evaluated
- **Then**: it does NOT set `nix.settings`, `nix.enable`, or `nixpkgs.config.allowUnfree` (those are in `modules/darwin/system/nix.nix`).

**Scenario R1.4.3 — Per-host config preserved**
- **Given**: `darwin/default.nix`
- **When**: evaluated
- **Then**: it still sets `nix-homebrew.*`, `home-manager.*`, `system.primaryUser`, `users.users`, `environment.*`, and `services.wsdd.enable`.

#### R1.5: Builder Import Path Retains Correct Resolution

`lib/mkDarwinHost.nix` imports `../darwin` (line 32), which resolves to `darwin/default.nix`. After refactoring, `darwin/default.nix` still exists at the same path and imports the profile transitively. The builder SHALL continue to work without import path changes.

**Scenario R1.5.1 — Builder import unchanged**
- **Given**: `lib/mkDarwinHost.nix`
- **When**: evaluated
- **Then**: the `../darwin` import in its modules list resolves to `darwin/default.nix`.

#### R1.6: `flake.nix` Requires No Changes

The `flake.nix` `darwinConfigurations.mact2` binding calls `mkDarwinHost { hostname = "mact2"; }`. Since neither `mkDarwinHost` nor `darwin/default.nix` change their interface or paths, `flake.nix` SHALL remain unmodified.

**Scenario R1.6.1 — Flake unchanged**
- **Given**: `flake.nix`
- **When**: diffed against the pre-refactor version
- **Then**: the `darwinConfigurations` block and `mkDarwinHost` import are identical.

#### R1.7: Flat `darwin/` Directory Reduced to `default.nix` Only

After all moves, the `darwin/` directory SHALL contain only `default.nix`. All other `.nix` files (`mise.nix`, `cachix.nix`, `homebrew.nix`, `settings.nix`, `wsdd.nix`) SHALL be removed from `darwin/`.

**Scenario R1.7.1 — Clean darwin/ directory**
- **Given**: the refactored repository
- **When**: `ls darwin/`
- **Then**: only `default.nix` is present.

---

### R2: mkDarwinHost specialArgs Fix

The `lib/mkDarwinHost.nix` builder SHALL no longer pass `home-manager.extraSpecialArgs` inline. This responsibility SHALL be owned exclusively by `darwin/default.nix`, which already declares it.

#### R2.1: Remove Inline `home-manager.extraSpecialArgs` from Builder

`lib/mkDarwinHost.nix` SHALL remove its inline `home-manager.extraSpecialArgs` block (currently lines 42-52). The builder SHALL continue to pass `specialArgs` to `darwinSystem` (lines 13-23).

**Scenario R2.1.1 — Builder no longer sets HM extraSpecialArgs**
- **Given**: `lib/mkDarwinHost.nix`
- **When**: evaluated
- **Then**: the modules list does NOT contain any `home-manager.extraSpecialArgs = { ... }` block.

**Scenario R2.1.2 — Builder still passes system specialArgs**
- **Given**: `lib/mkDarwinHost.nix`
- **When**: evaluated
- **Then**: the `specialArgs` attrset passed to `darwinSystem` includes `inputs`, `self`, `username`, `system`, `host`, `primaryUser`, and `javaVersion`.

#### R2.2: `darwin/default.nix` Must Pass All Required attrs

`darwin/default.nix`'s `home-manager.extraSpecialArgs` block (lines 58-65) already passes `inputs`, `self`, `primaryUser`, and `javaVersion`. After removing the builder's block, this SHALL be the sole declaration of `home-manager.extraSpecialArgs` for mact2.

**Scenario R2.2.1 — Single source of truth**
- **Given**: the full module evaluation for `darwinConfigurations.mact2`
- **When**: home-manager resolves `extraSpecialArgs`
- **Then**: the attrs come exclusively from `darwin/default.nix` (not duplicated from the builder).

**Scenario R2.2.2 — Required attrs available**
- **Given**: `darwin/default.nix`'s `home-manager.extraSpecialArgs`
- **When**: inspected
- **Then**: it includes `inputs`, `self`, `primaryUser`, and `javaVersion` (at minimum the same set the removed builder block provided).

---

### R3: GPG Consolidation

The byte-identical `importKey` function and activation script duplicated across `home-linux/gpg.nix` and `home-darwin/gpg.nix` SHALL be extracted into a shared module. Per-platform files SHALL retain only their platform-specific package lists.

#### R3.1: Shared GPG Module Created

`shared/gpg.nix` SHALL be created as a Home Manager module that:
- Defines the `importKey` function (identical to the current definition in both files)
- Wires `home.activation.importGpgKeys` using that function
- References `config.sops.secrets."github/work_gpg_fingerprint".path`, `config.sops.secrets."github/work_gpg_key".path`, `config.sops.secrets."github/personal_gpg_fingerprint".path`, and `config.sops.secrets."github/personal_gpg_key".path` (the same secret paths already declared by `shared/sops.nix`)
- Does NOT set `home.packages` (that remains per-platform)

**Scenario R3.1.1 — Shared module structure**
- **Given**: `shared/gpg.nix`
- **When**: evaluated
- **Then**: it defines the `importKey` function with the same bash logic as the current files, and wires `home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ...`.

#### R3.2: Linux GPG Imports Shared Module

`home-linux/gpg.nix` SHALL import `../../shared/gpg.nix` and SHALL set `home.packages` with only `gnupg` and `pinentry-curses`. It SHALL NOT redefine `importKey` or `home.activation.importGpgKeys`.

**Scenario R3.2.1 — Linux minimal file**
- **Given**: `home-linux/gpg.nix`
- **When**: evaluated
- **Then**: its `imports` list includes `../../shared/gpg.nix` and it sets `home.packages = [ gnupg pinentry-curses ]` with no activation script or importKey definition.

#### R3.3: Darwin GPG Imports Shared Module

`home-darwin/gpg.nix` SHALL import `../../shared/gpg.nix` and SHALL set `home.packages` with only `gnupg`, `pinentry_mac`, and `nix-index`. It SHALL NOT redefine `importKey` or `home.activation.importGpgKeys`.

**Scenario R3.3.1 — Darwin minimal file**
- **Given**: `home-darwin/gpg.nix`
- **When**: evaluated
- **Then**: its `imports` list includes `../../shared/gpg.nix` and it sets `home.packages = [ gnupg pinentry_mac nix-index ]` with no activation script or importKey definition.

#### R3.4: Identical GPG Import Behavior

After consolidation, both platforms SHALL produce the same activation behavior: GPG keys are imported from sops secrets if not already present in the keyring.

**Scenario R3.4.1 — Activation behavior unchanged**
- **Given**: GPG keys available from sops secrets on either platform
- **When**: `home-manager` activation runs
- **Then**: both `work` and `personal` GPG keys are imported into the keyring (or skipped if already present), with identical log output.

---

### R4: Ghostty Migration to `programs.ghostty`

`home-darwin/ghostty.nix` SHALL migrate from raw `home.file` text config to the `programs.ghostty` Home Manager module, matching the pattern already used by `home-linux/ghostty.nix`.

#### R4.1: Use `programs.ghostty` HM Module

`home-darwin/ghostty.nix` SHALL set `programs.ghostty.enable = true` and declare settings via `programs.ghostty.settings` instead of `home.file."Library/Application Support/com.mitchellh.ghostty/config".text`. It SHALL declare the theme via `programs.ghostty.themes` (the `nix-colors` attrset pattern) instead of `home.file.".config/ghostty/themes/customColor".text`.

**Scenario R4.1.1 — Module-based config**
- **Given**: `home-darwin/ghostty.nix`
- **When**: evaluated
- **Then**: it uses `programs.ghostty.enable = true`, `programs.ghostty.settings`, and `programs.ghostty.themes`. It does NOT use `home.file`.

#### R4.2: Darwin-Specific Settings Preserved

The darwin-specific Ghostty settings SHALL be preserved in the migration:
- `macos-option-as-alt = "left"` (not present in the Linux config)
- `selection-foreground` using `base00` (Linux uses `base05` — this difference is intentional and SHALL be kept)
- `clipboard-paste-protection = false` from Linux config SHALL be added to Darwin (present in Linux but absent in current Darwin)
- `font-size = 11`, `maximize = true`, and `keybind` from Linux SHALL be added to Darwin for consistency

**Scenario R4.2.1 — Darwin-specific key preserved**
- **Given**: `home-darwin/ghostty.nix` after migration
- **When**: `programs.ghostty.settings` is evaluated
- **Then**: it includes `macos-option-as-alt = "left"` and `selection-foreground` mapped to `base00`.

**Scenario R4.2.2 — Cross-platform alignment**
- **Given**: both `home-darwin/ghostty.nix` and `home-linux/ghostty.nix`
- **When**: compared
- **Then**: shared settings (font-family, font-feature, background-opacity, scrollback-limit, window-padding-balance, window-padding-color, clipboard-write, clipboard-paste-protection, maximize, keybind, term, font-size, bold-color) are identical across both platforms.

#### R4.3: Theme Palette Uses Same `nix-colors` Pattern

The `programs.ghostty.themes.nix-colors` block SHALL use the same `config.colorScheme.palette` mappings as `home-linux/ghostty.nix`. The palette mapping (base00-base0F to ANSI 0-21) SHALL be identical across platforms.

**Scenario R4.3.1 — Palette matching**
- **Given**: both ghostty configs
- **When**: the `nix-colors` theme palette is evaluated on both platforms with the same colorScheme
- **Then**: the generated ANSI 0-21 color mappings and background/foreground/cursor/selection colors are identical (except `selection-foreground` which differs by design per R4.2).

#### R4.4: Linux Ghostty Unchanged

`home-linux/ghostty.nix` SHALL NOT be modified as part of this change.

**Scenario R4.4.1 — Linux file untouched**
- **Given**: `home-linux/ghostty.nix`
- **When**: diffed against the pre-refactor version
- **Then**: there are zero changes.

---

## Module Interface

### New: Darwin Profile (`modules/darwin/profiles/base.nix`)

- **Role**: Pure import aggregator for all darwin system modules. Mirrors `modules/profiles/base.nix`.
- **Imports**:
  - `../system/nix.nix` — nix settings, registry, build opts
  - `../system/cachix.nix` — substituters, trusted keys, cachix package
  - `../system/homebrew.nix` — homebrew taps, brews, casks, activation
  - `../system/settings.nix` — macOS defaults, SSH, firewall, activation scripts
  - `../system/mise.nix` — mise tooling activation scripts
  - `../services/wsdd.nix` — WS-Discovery daemon module (options + config)
- **No inline config**: zero top-level keys beyond `imports`.
- **Consumed by**: `darwin/default.nix` (line `imports = [ ../modules/darwin/profiles/base.nix ... ]`)

### New: Darwin Nix System Module (`modules/darwin/system/nix.nix`)

- **Role**: All `nix.*` settings consolidated from `darwin/default.nix` and `darwin/cachix.nix`.
- **Configures**:
  - `nix.settings.experimental-features`
  - `nix.enable`
  - `nixpkgs.config.allowUnfree`
  - `nix.settings.max-jobs`
  - `nix.settings.cores`
  - `nix.settings.keep-outputs`
  - `nix.settings.trusted-substituters`
  - `nix.registry.nixpkgs.flake`
- **Inputs needed**: `inputs` (for `nix.registry.nixpkgs.flake`), `lib` (for `mkDefault`/`mkMerge`)

### New: Shared GPG Module (`shared/gpg.nix`)

- **Role**: Shared GPG key import logic used by both Darwin and Linux HM configs.
- **Exports**: `importKey` function definition and `home.activation.importGpgKeys` wiring.
- **Inputs needed**: `config` (for `sops.secrets` paths), `pkgs` (for `gnupg` binary reference), `lib` (for `hm.dag.entryAfter`)
- **Does NOT set**: `home.packages` (left to per-platform importers)
- **Depends on**: `shared/sops.nix` (declares the `github/work_gpg_*` and `github/personal_gpg_*` secret paths)

### Modified: Darwin GPG Module (`home-darwin/gpg.nix`)

- **Before**: 29 lines — defines importKey, activation, packages
- **After**: ~10 lines — imports `shared/gpg.nix`, sets `home.packages = [ gnupg pinentry_mac nix-index ]`

### Modified: Linux GPG Module (`home-linux/gpg.nix`)

- **Before**: 28 lines — defines importKey, activation, packages
- **After**: ~8 lines — imports `shared/gpg.nix`, sets `home.packages = [ gnupg pinentry-curses ]`

### Modified: Darwin Ghostty Module (`home-darwin/ghostty.nix`)

- **Before**: 50 lines — `home.file` with raw text config and theme file
- **After**: ~80 lines — `programs.ghostty` with `settings` and `themes` attrsets
- **Gains**: shared settings from Linux (clipboard-paste-protection, maximize, keybind, term, font-size), plus nix-colors theme palette

---

## Affected Configurations

| File | Action | Lines (est.) | Details |
|---|---|---|---|
| `modules/darwin/profiles/base.nix` | NEW | ~15 | Pure import aggregator for darwin system modules |
| `modules/darwin/system/nix.nix` | NEW | ~40 | Extracted nix settings + registry + build opts from `darwin/default.nix` + `darwin/cachix.nix` |
| `modules/darwin/system/cachix.nix` | MOVED + SLIMMED | ~50 | From `darwin/cachix.nix`; retains only substituters + trusted-keys + cachix package; nix build opts moved to `nix.nix` |
| `modules/darwin/system/homebrew.nix` | MOVED | ~64 | From `darwin/homebrew.nix`; content unchanged |
| `modules/darwin/system/settings.nix` | MOVED | ~230 | From `darwin/settings.nix`; content unchanged |
| `modules/darwin/system/mise.nix` | MOVED | ~84 | From `darwin/mise.nix`; content unchanged |
| `modules/darwin/services/wsdd.nix` | MOVED | ~86 | From `darwin/wsdd.nix`; content unchanged |
| `darwin/default.nix` | REFACTORED | ~55 | Remove individual `.nix` imports; import `modules/darwin/profiles/base.nix`; remove inline `nix.*` config; keep HM/user/env config |
| `lib/mkDarwinHost.nix` | TRIMMED | ~10 removed | Remove `home-manager.extraSpecialArgs` block (lines ~42-52) |
| `shared/gpg.nix` | NEW | ~25 | Shared importKey function + activation script |
| `home-linux/gpg.nix` | REFACTORED | ~8 | Imports `shared/gpg.nix`; sets linux-specific packages only |
| `home-darwin/gpg.nix` | REFACTORED | ~10 | Imports `shared/gpg.nix`; sets darwin-specific packages only |
| `home-darwin/ghostty.nix` | REWRITTEN | ~80 | Migrate from `home.file` to `programs.ghostty`; add cross-platform settings parity |
| `darwin/cachix.nix` | REMOVED | — | Moved to `modules/darwin/system/cachix.nix` |
| `darwin/homebrew.nix` | REMOVED | — | Moved to `modules/darwin/system/homebrew.nix` |
| `darwin/settings.nix` | REMOVED | — | Moved to `modules/darwin/system/settings.nix` |
| `darwin/mise.nix` | REMOVED | — | Moved to `modules/darwin/system/mise.nix` |
| `darwin/wsdd.nix` | REMOVED | — | Moved to `modules/darwin/services/wsdd.nix` |

**Total estimated diff**: ~300 lines (additions + deletions across ~13 changed/created/removed files)

---

## Verification Scenarios

### VS1: Darwin Profile Chain — Build Integrity

- **Given**: the refactored `darwinConfigurations.mact2`
- **When**: `nix flake check --no-build darwinConfigurations.mact2`
- **Then**: exits 0 with no evaluation errors

### VS2: Darwin Profile Chain — Import Resolution

- **Given**: `darwin/default.nix`
- **When**: evaluated
- **Then**: imports only `modules/darwin/profiles/base.nix` plus `inputs.home-manager.darwinModules.home-manager` and `inputs.nix-homebrew.darwinModules.nix-homebrew` (no individual `./cachix.nix`, `./settings.nix`, etc.)

### VS3: mkDarwinHost Builder — No Duplicate HM extraSpecialArgs

- **Given**: `lib/mkDarwinHost.nix`
- **When**: evaluated
- **Then**: the modules list contains no `home-manager.extraSpecialArgs` block. The only source of `extraSpecialArgs` for mact2 HM is `darwin/default.nix`.

### VS4: GPG — Shared Module Correctness

- **Given**: `shared/gpg.nix` created and imported by both `home-linux/gpg.nix` and `home-darwin/gpg.nix`
- **When**: each platform's HM config is evaluated
- **Then**: both define `home.activation.importGpgKeys` with identical bash logic, and the per-platform files only differ by their `home.packages` lists

### VS5: GPG — Activation Behavior Preserved

- **Given**: both platform HM configs after GPG consolidation
- **When**: activation scripts are compared
- **Then**: the `importGpgKeys` activation text is byte-identical between platforms (same function logic, same secret paths)

### VS6: Ghostty — Darwin Uses `programs.ghostty`

- **Given**: `home-darwin/ghostty.nix` after migration
- **When**: HM is evaluated for mact2
- **Then**: `programs.ghostty.enable = true` and the config is declared via `programs.ghostty.settings` and `programs.ghostty.themes` (not `home.file`)

### VS7: Ghostty — Darwin Theme Matches Linux

- **Given**: both `home-darwin/ghostty.nix` and `home-linux/ghostty.nix` with the same `colorScheme`
- **When**: the `nix-colors` theme palette is evaluated
- **Then**: ANSI color mappings 0-21 use the same `config.colorScheme.palette` keys, and background/foreground/cursor/selection-background colors match

### VS8: Ghostty — Darwin-Specific Overrides Preserved

- **Given**: `home-darwin/ghostty.nix` after migration
- **When**: `programs.ghostty.settings` is evaluated
- **Then**: includes `macos-option-as-alt = "left"` and `selection-foreground` derived from `base00` (not `base05` as on Linux)

### VS9: Ghostty — Cross-Platform Settings Parity

- **Given**: both ghostty configs after migration
- **When**: compared key-by-key
- **Then**: `clipboard-paste-protection`, `maximize`, `keybind`, `term`, `font-size`, `bold-color` settings are identical across platforms (these were previously missing from Darwin)

### VS10: Full Flake Check — mact2

- **Given**: the complete refactored flake
- **When**: `nix flake check --no-build`
- **Then**: exits 0 for all NixOS configurations (rog, thinkcentre, t14) and the darwin configuration (mact2)

### VS11: Flat Directory Cleanup

- **Given**: the refactored repository
- **When**: `ls darwin/`
- **Then**: only `default.nix` exists (no `cachix.nix`, `homebrew.nix`, `settings.nix`, `mise.nix`, or `wsdd.nix`)

### VS12: NixOS Hosts Unaffected

- **Given**: the refactored repository
- **When**: `nix flake check --no-build` run for NixOS hosts
- **Then**: rog, thinkcentre, and t14 evaluations are identical to pre-refactor (no changes to `modules/`, `home-linux/`, or `lib/mkHost.nix`)

---

## Non-Goals

The following are explicitly out of scope for this change:

- **Dendritic/flake-parts pattern** — unnecessary for a single Darwin host; would add flake input and import-tree overhead without proportional benefit
- **Unifying NixOS and Darwin system modules** — the intersection of system options between platforms is too small to justify a `common.nix` abstraction (per Jadarma's community consensus)
- **Moving `darwin/default.nix` entirely into `modules/darwin/`** — user config, home-manager setup, nix-homebrew, and environment variables are per-host concerns that belong in `darwin/default.nix`
- **Changing `shared/` or `shared-modules.nix` canonical list structures** — these are already well-designed cross-platform patterns
- **Modifying `modules/base/home-manager.nix` or any NixOS system module** — only darwin-side and shared HM modules are touched
- **Modifying `lib/mkHost.nix` (`mkNixosHost`)** — the NixOS builder is left unchanged (even though it also has an inline `home-manager.extraSpecialArgs` block; that's a separate concern)
- **Modifying `flake.nix`** — the flake bindings and builder calls are unchanged
- **Modifying `home-linux/ghostty.nix`** — the Linux ghostty config is already in the target pattern
- **Moving `wsdd.nix` to `hosts/mact2/services/`** — wsdd is a general-purpose Darwin service module (declares its own `options` and `config`), not a host-specific one; it belongs in `modules/darwin/services/`
