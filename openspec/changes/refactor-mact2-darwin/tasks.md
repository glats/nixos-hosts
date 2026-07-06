# Tasks: Refactor mact2 Darwin Configuration

**Created**: 2026-07-06
**Change ID**: refactor-mact2-darwin
**Phase**: Tasks
**Previous**: design.md (all components verified against current file state)

---

## Phase 0: Exploration artifacts (already done)

No implementation tasks. The following artifacts were completed in earlier phases:

- exploration-report.md — identified 6 inconsistencies, 3 refactoring areas, external patterns
- proposal.md — scoped the change to 3 areas, single-PR delivery
- spec.md — 4 requirements (R1-R4), 12 verification scenarios, module interfaces
- design.md — 13 components with exact content, file change map, migration path

---

## Phase 1: Area 2 — mkDarwinHost specialArgs Fix

### Task 1.1: Remove redundant home-manager.extraSpecialArgs from builder

- **File**: `lib/mkDarwinHost.nix`
- **Action**: Remove lines 41-52 (the `{ home-manager.extraSpecialArgs = { ... }; }` block)
- **Verified current state (lines 41-52)**:
  ```nix
        # Pass inputs to home-manager for module access
        {
          home-manager.extraSpecialArgs = {
            inherit
              inputs
              self
              username
              ;
            primaryUser = username;
            javaVersion = "temurin-25.0.1+8.0.LTS";
          };
        }
  ```
- **After removal**: `modules = [ ... ../darwin ... overlays ... ] ++ extraModules;` — only `specialArgs` for `darwinSystem` remains (lines 13-23)
- **Design ref**: Component 9 — builder trimmed, leaves `darwin/default.nix` as sole owner
- **Verification**: `grep -c "home-manager.extraSpecialArgs" lib/mkDarwinHost.nix` must return 0
- **Why safe**: `darwin/default.nix` already declares `home-manager.extraSpecialArgs = { inherit inputs self primaryUser javaVersion; }` at lines 58-65

### Task 1.2: Verify darwin/default.nix passes all needed attrs in its own extraSpecialArgs

- **File**: `darwin/default.nix`
- **Action**: Read-only verification. Confirm lines 58-65 include ALL attrs that the removed builder block provided
- **Verified current state (lines 58-65)**:
  ```nix
    extraSpecialArgs = {
      inherit
        inputs
        self
        primaryUser
        javaVersion
        ;
    };
  ```
- **Comparison with removed builder block**:
  | Attr | Builder (removed) | darwin/default.nix |
  |------|-------------------|---------------------|
  | `inputs` | yes | yes |
  | `self` | yes | yes |
  | `username` | yes | replaced by `primaryUser` (same value) |
  | `primaryUser` | yes (same as username) | yes |
  | `javaVersion` | yes | yes |
- **Verdict**: `darwin/default.nix` passes the superset. `primaryUser` and `username` are the same value (`jcuzmar`); `primaryUser` is the canonical name used throughout. All HM modules will resolve correctly.
- **Verification**: `nix flake check --no-build darwinConfigurations.mact2` must exit 0

### Phase 1 Verification Gate

```bash
nix flake check --no-build darwinConfigurations.mact2
grep -c "home-manager.extraSpecialArgs" lib/mkDarwinHost.nix  # must be 0
```

---

## Phase 2: Area 1 — Darwin Profile Chain

### Task 2.1: Create directory structure

- **Action**: `mkdir -p modules/darwin/{profiles,system,services}`
- **Verification**: `ls modules/darwin/profiles/ modules/darwin/system/ modules/darwin/services/` — all three directories exist (initially empty)

### Task 2.2: Create modules/darwin/system/nix.nix (NEW — consolidated nix config)

- **File**: `modules/darwin/system/nix.nix` (NEW)
- **Content source**: Design Component 2 (lines 115-181)
- **Sources consolidated from**:
  - `darwin/default.nix` lines 21-33: `nix.settings.experimental-features`, `nix.enable`, `nixpkgs.config.allowUnfree`
  - `darwin/cachix.nix` lines 57-106: `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`, `nix.registry.nixpkgs.flake`
- **Function args**: `{ lib, inputs, ... }:` — `lib` for `mkDefault`, `inputs` for `registry.nixpkgs.flake`
- **Verification**: `nix flake check --no-build darwinConfigurations.mact2` — additive (nothing imports this yet, so no change)
- **Design ref**: Component 2 — "Consolidated nix settings from darwin/default.nix + darwin/cachix.nix"

### Task 2.3: Create modules/darwin/profiles/base.nix (NEW — pure import aggregator)

- **File**: `modules/darwin/profiles/base.nix` (NEW)
- **Content source**: Design Component 1 (lines 84-99)
- **Exact content**:
  ```nix
  # Profile: Darwin base system configuration.
  # Pure import aggregator — mirrors modules/profiles/base.nix.
  # Contains ONLY an imports list with zero inline configuration.
  # Consumed by darwin/default.nix.
  {
    imports = [
      ../system/nix.nix
      ../system/cachix.nix
      ../system/homebrew.nix
      ../system/settings.nix
      ../system/mise.nix
      ../services/wsdd.nix
    ];
  }
  ```
- **Constraint**: MUST contain ONLY `{ imports = [ ... ]; }` — zero top-level keys beyond `imports` (spec R1.1)
- **Verification**: `nix flake check --no-build darwinConfigurations.mact2` — additive, not yet imported
- **Design ref**: Component 1 — mirrors `modules/profiles/base.nix`

### Task 2.4: Copy darwin/homebrew.nix to modules/darwin/system/homebrew.nix

- **Action**: Copy file, content unchanged (64 lines)
- **Source**: `darwin/homebrew.nix`
- **Dest**: `modules/darwin/system/homebrew.nix`
- **Verification**: `diff darwin/homebrew.nix modules/darwin/system/homebrew.nix` — must be identical
- **Design ref**: Component 4 — "Content unchanged from source"

### Task 2.5: Copy darwin/settings.nix to modules/darwin/system/settings.nix

- **Action**: Copy file, content unchanged (230 lines)
- **Source**: `darwin/settings.nix`
- **Dest**: `modules/darwin/system/settings.nix`
- **Verification**: `diff darwin/settings.nix modules/darwin/system/settings.nix` — must be identical
- **Design ref**: Component 5 — "Content unchanged from source"

### Task 2.6: Copy darwin/mise.nix to modules/darwin/system/mise.nix

- **Action**: Copy file, content unchanged (84 lines)
- **Source**: `darwin/mise.nix`
- **Dest**: `modules/darwin/system/mise.nix`
- **Verification**: `diff darwin/mise.nix modules/darwin/system/mise.nix` — must be identical
- **Design ref**: Component 6 — "Content unchanged from source"

### Task 2.7: Copy darwin/wsdd.nix to modules/darwin/services/wsdd.nix

- **Action**: Copy file, content unchanged (86 lines)
- **Source**: `darwin/wsdd.nix`
- **Dest**: `modules/darwin/services/wsdd.nix`
- **Verification**: `diff darwin/wsdd.nix modules/darwin/services/wsdd.nix` — must be identical
- **Design ref**: Component 7 — "Content unchanged from source"

### Task 2.8: Copy + slim darwin/cachix.nix to modules/darwin/system/cachix.nix

- **Action**: Copy `darwin/cachix.nix` to `modules/darwin/system/cachix.nix`, then remove the build-opt/registry block (original lines 57-106)
- **Content source**: Design Component 3 (lines 197-249)
- **Changes from source**:
  - Remove `inputs` from function params (now `{ lib, pkgs, ... }:`)
  - Remove `config` from function params (was unused)
  - Remove the third `lib.mkMerge` entry block (lines 57-96: `max-jobs`, `cores`, `keep-outputs`, `trusted-substituters`)
  - Remove `nix.registry.nixpkgs.flake = inputs.nixpkgs;` (line 106) — moved to nix.nix
  - Keep: `environment.systemPackages = [ cachix ]`, the `lib.mkMerge` of substituters + trusted-public-keys (original lines 24-56)
- **Verification**: Slimmed version sets ONLY `nix.settings.substituters`, `nix.settings.trusted-public-keys`, and `environment.systemPackages = [ cachix ]`. Does NOT set `nix.registry`, `max-jobs`, `cores`, `keep-outputs`, or `trusted-substituters` (those are in nix.nix).
- **Design ref**: Component 3 — "Slimmed from 107 lines to ~50 lines"

### Task 2.9: Verify additive state (pre-switchover checkpoint)

- **Action**: Run flake check with ALL new files created but NOT yet referenced
- **Command**: `nix flake check --no-build darwinConfigurations.mact2`
- **Expected**: exits 0. New files exist but `darwin/default.nix` still imports old files. No behavioral change.
- **If fails**: New files have syntax errors — fix before proceeding to Task 2.10

### Task 2.10: Refactor darwin/default.nix

- **File**: `darwin/default.nix`
- **Content source**: Design Component 8 (lines 303-382)
- **Specific changes**:
  1. Replace `imports` list — remove individual `./mise.nix ./cachix.nix ./homebrew.nix ./settings.nix ./wsdd.nix`, replace with single `../modules/darwin/profiles/base.nix`
  2. Remove `nix = { settings = { ... }; enable = false; };` block (lines 20-31)
  3. Remove `nixpkgs.config.allowUnfree = true;` (line 33)
  4. Keep ALL of: `nix-homebrew` config (lines 35-40), `home-manager` config (lines 42-66), `system.primaryUser` and `users.users` (lines 68-79), `environment.*` (lines 80-90), `services.wsdd.enable` (line 92)
- **Before**: 93 lines
- **After**: ~55 lines
- **Design ref**: Component 8 — "Per-host aggregation layer, retains only host-specific concerns"
- **Verification**: `nix flake check --no-build darwinConfigurations.mact2`

### Task 2.11: Delete moved darwin/*.nix files

- **Action**: Remove the 5 files that were moved to `modules/darwin/system/` and `modules/darwin/services/`
  ```bash
  rm darwin/cachix.nix darwin/homebrew.nix darwin/settings.nix darwin/mise.nix darwin/wsdd.nix
  ```
- **Verification**:
  1. `ls darwin/` — must show ONLY `default.nix`
  2. `nix flake check --no-build darwinConfigurations.mact2` — must exit 0
- **Design ref**: Spec R1.7.1 — "Clean darwin/ directory"

### Phase 2 Verification Gate

```bash
nix flake check --no-build darwinConfigurations.mact2  # must exit 0
ls darwin/  # must show only default.nix
ls modules/darwin/profiles/  # must show base.nix
ls modules/darwin/system/    # must show 5 files
ls modules/darwin/services/  # must show wsdd.nix
grep "modules/darwin/profiles/base.nix" darwin/default.nix  # exactly 1 match
grep "./mise.nix" darwin/default.nix  # no match
grep "./cachix.nix" darwin/default.nix  # no match
```

---

## Phase 3: Area 3 — GPG Consolidation (Phase 3a)

### Task 3.1: Create shared/gpg.nix (NEW — shared GPG import logic)

- **File**: `shared/gpg.nix` (NEW)
- **Content source**: Design Component 10 (lines 470-506)
- **What it contains**:
  - `importKey` function (byte-identical between the two current per-platform files)
  - `home.activation.importGpgKeys = lib.hm.dag.entryAfter [ "writeBoundary" ] ...` wiring
  - References `config.sops.secrets."github/work_gpg_fingerprint".path` etc. (declared by `shared/sops.nix`)
  - Does NOT set `home.packages` — that stays per-platform
- **Function args**: `{ config, lib, pkgs, ... }:`
- **Verification**: `nix flake check --no-build` — additive, not yet imported
- **Design ref**: Component 10 — "Shared GPG key import function and activation script"

### Task 3.2: Refactor home-linux/gpg.nix — import shared/gpg.nix

- **File**: `home-linux/gpg.nix`
- **Content source**: Design Component 11 (lines 519-529)
- **Changes**: Replace the 28-line file with ~8 lines:
  - Remove `importKey` function and `home.activation.importGpgKeys` block (moved to `shared/gpg.nix`)
  - Add `imports = [ ../../shared/gpg.nix ];`
  - Keep only `home.packages = with pkgs; [ gnupg pinentry-curses ];`
- **Function args**: `{ pkgs, ... }:` (simplified from `{ config, lib, pkgs, ... }:`)
- **Verification**: `nix flake check --no-build nixosConfigurations.rog` — Linux host still evaluates correctly
- **Design ref**: Component 11 — "Reduced from 28 lines to ~8 lines"

### Task 3.3: Refactor home-darwin/gpg.nix — import shared/gpg.nix

- **File**: `home-darwin/gpg.nix`
- **Content source**: Design Component 12 (lines 542-553)
- **Changes**: Replace the 29-line file with ~10 lines:
  - Remove `importKey` function and `home.activation.importGpgKeys` block (moved to `shared/gpg.nix`)
  - Add `imports = [ ../../shared/gpg.nix ];`
  - Keep only `home.packages = with pkgs; [ gnupg pinentry_mac nix-index ];`
- **Function args**: `{ pkgs, ... }:` (simplified from `{ config, lib, pkgs, ... }:`)
- **Verification**: `nix flake check --no-build darwinConfigurations.mact2`
- **Design ref**: Component 12 — "Reduced from 29 lines to ~10 lines"

### Task 3.4: Rewrite home-darwin/ghostty.nix — migrate from home.file to programs.ghostty

- **File**: `home-darwin/ghostty.nix`
- **Content source**: Design Component 13 (lines 572-639)
- **Changes**:
  - Replace `home.file."Library/Application Support/..."` with `programs.ghostty.settings`
  - Replace `home.file.".config/ghostty/themes/customColor"` with `programs.ghostty.themes.nix-colors`
  - Use `programs.ghostty.enable = true` (matching `home-linux/ghostty.nix` pattern)
  - Do NOT use `lib.mkForce` (Darwin has no competing ghostty module unlike Linux/omarchy)
- **Preserved darwin-specific settings**:
  - `macos-option-as-alt = "left"`
  - `selection-foreground` mapped to `base00` (Linux uses `base05`)
- **Added cross-platform parity settings** (were missing in Darwin):
  - `clipboard-paste-protection = false`
  - `font-size = 11`
  - `maximize = true`
  - `keybind = [ "shift+insert=paste_from_clipboard" ]`
  - `term = "xterm-256color"`
  - `bold-color = "bright"`
- **Verification**: 
  ```bash
  grep "programs.ghostty" home-darwin/ghostty.nix  # must match
  grep "home.file" home-darwin/ghostty.nix          # must NOT match
  nix flake check --no-build darwinConfigurations.mact2
  ```
- **Design ref**: Component 13 — "Migrate from raw home.file text to programs.ghostty HM module"

### Phase 3 Verification Gate

```bash
grep "shared/gpg.nix" home-linux/gpg.nix     # must match
grep "shared/gpg.nix" home-darwin/gpg.nix    # must match
grep "importKey" shared/gpg.nix              # shared file defines importKey
grep "programs.ghostty" home-darwin/ghostty.nix  # must match
grep "home.file" home-darwin/ghostty.nix     # must NOT match
nix flake check --no-build darwinConfigurations.mact2  # must exit 0
nix flake check --no-build nixosConfigurations.rog     # must exit 0
```

---

## Phase 3b: Area 3 — Ghostty Shared Module (iteration addition)

### Task 3.5: Create shared/ghostty.nix

- **Action**: Create `/home/glats/.nixos/shared/ghostty.nix`
- **Content**: Pure Nix function (NOT a module) that takes `{ colorScheme, selectionForegroundPalette ? "base05", extraSettings ? {} }` and returns `{ settings, theme }`. Contains:
  - 15 common ghostty settings
  - 22-color base16 palette
  - Theme colors (background, foreground, cursor, selection-background, selection-foreground)
  - Zero `isDarwin` conditionals
- **Design ref**: Component 14 in design.md
- **Verification**: `nix-instantiate --eval --strict shared/ghostty.nix` (syntax check)

### Task 3.6: Rewrite home-linux/ghostty.nix

- **File**: `/home/glats/.nixos/home-linux/ghostty.nix`
- **Action**: Rewrite to import `../../shared/ghostty.nix` and wrap with `lib.mkForce`
- **Content**: 
  ```nix
  { config, lib, ... }:
  let
    ghostty = import ../../shared/ghostty.nix {
      colorScheme = config.colorScheme;
    };
  in {
    programs.ghostty = {
      enable = true;
      settings = lib.mkForce ghostty.settings;
      themes = lib.mkForce ghostty.theme;
    };
  }
  ```
- **Design ref**: Component 15 in design.md
- **Verification**: `nix flake check --no-build nixosConfigurations.rog`

### Task 3.7: Rewrite home-darwin/ghostty.nix

- **File**: `/home/glats/.nixos/home-darwin/ghostty.nix`
- **Action**: Rewrite to import `../../shared/ghostty.nix` with darwin-specific parameters
- **Content**:
  ```nix
  { config, ... }:
  let
    ghostty = import ../../shared/ghostty.nix {
      colorScheme = config.colorScheme;
      selectionForegroundPalette = "base00";
      extraSettings = { macos-option-as-alt = "left"; };
    };
  in {
    programs.ghostty = {
      enable = true;
      package = null;
      settings = ghostty.settings;
      themes = ghostty.theme;
    };
  }
  ```
- **Design ref**: Component 16 in design.md
- **Verification**: `nix flake check --no-build darwinConfigurations.mact2`

### Task 3.8: Verify shared module integration

- **Commands**:
  ```bash
  ls shared/ghostty.nix                    # exists
  grep "import.*shared/ghostty" home-linux/ghostty.nix    # linux imports shared
  grep "import.*shared/ghostty" home-darwin/ghostty.nix   # darwin imports shared
  grep "macos-option-as-alt" home-darwin/ghostty.nix      # darwin has it
  grep "macos-option-as-alt" home-linux/ghostty.nix       # linux does NOT have it
  grep "lib.mkForce" home-linux/ghostty.nix               # linux has mkForce
  grep "lib.mkForce" home-darwin/ghostty.nix              # darwin does NOT have mkForce
  ```
- **Expected**: Both import shared, darwin-specific keys present only on darwin, mkForce only on linux

## Phase 4: Final Verification

### Task 4.1: Full flake check — ALL configurations

- **Command**: `nix flake check --no-build`
- **Expected**: exits 0 for ALL configurations (mact2, rog, thinkcentre, t14)
- **Unchanged hosts must still evaluate**: rog, thinkcentre, t14 are untouched by this change — their evaluation must be identical to pre-refactor
- **If fails**: check error output for specific host. If only mact2 fails, diagnose darwin module issue. If unrelated host fails, it's a pre-existing issue (note it, do not block).

### Task 4.2: Format all changed files

- **Command**: `format-nix`
- **Expected**: no uncommitted changes after formatting
- **If generates changes**: review with `git diff --stat`, ensure only intended files are touched

### Task 4.3: Directory structure verification

- **Verify**:
  ```bash
  ls darwin/                          # only default.nix
  ls modules/darwin/profiles/         # base.nix
  ls modules/darwin/system/           # nix.nix cachix.nix homebrew.nix settings.nix mise.nix (5 files)
  ls modules/darwin/services/         # wsdd.nix
  ls shared/                          # includes gpg.nix
  ```
- **Expected**: Each directory exists with the correct files. No extra files. No missing files.

### Task 4.4: specialArgs leak check

- **Command**: `grep -c "home-manager.extraSpecialArgs" lib/mkDarwinHost.nix`
- **Expected**: 0 (zero matches) — no duplicate `extraSpecialArgs` in the builder
- **Note**: `darwin/default.nix` still has `home-manager.extraSpecialArgs` — that's correct, it's the sole owner
- **Also verify**: `grep "home-manager.extraSpecialArgs" lib/mkHost.nix` — NixOS builder not touched (separate concern)

### Task 4.5: GPG shared import check

- **Commands**:
  ```bash
  grep "shared/gpg.nix" home-linux/gpg.nix     # must match (linux uses shared)
  grep "shared/gpg.nix" home-darwin/gpg.nix    # must match (darwin uses shared)
  grep "importKey" shared/gpg.nix              # shared file defines importKey
  ```
- **Expected**: Both platform files import the shared module. Shared module defines the function. Neither platform file defines `importKey` or `home.activation.importGpgKeys`.

### Task 4.6: Ghostty migration check (iteration)

- **Commands**:
  ```bash
  ls shared/ghostty.nix                                 # shared module exists
  grep "import.*shared/ghostty" home-linux/ghostty.nix  # linux imports shared
  grep "import.*shared/ghostty" home-darwin/ghostty.nix # darwin imports shared
  grep "programs.ghostty" home-darwin/ghostty.nix       # programs.ghostty present
  grep "home.file" home-darwin/ghostty.nix              # must NOT match
  grep "macos-option-as-alt" home-darwin/ghostty.nix    # darwin has it
  grep "macos-option-as-alt" home-linux/ghostty.nix     # linux does NOT have it
  grep "lib.mkForce" home-linux/ghostty.nix             # linux has mkForce
  grep "lib.mkForce" home-darwin/ghostty.nix            # darwin does NOT have mkForce
  grep "isDarwin\|stdenv.isDarwin" shared/ghostty.nix   # zero platform conditionals
  ```
- **Expected**: `shared/ghostty.nix` exists, both platforms import it, `programs.ghostty` present, `home.file` absent, darwin-specific keys only on darwin, mkForce only on linux, zero isDarwin in shared

### Task 4.7: No secrets exposed

- **Command**: `git diff --stat`
- **Expected**: No changes to `secrets/` directory or any plaintext secret values. Only Nix source files changed.
- **Also verify no sops decryption leak**: `git diff -- darwin/ modules/darwin/ lib/ shared/ home-*/gpg.nix home-*/ghostty.nix`

### Task 4.8: darwin/default.nix import consistency check

- **Commands**:
  ```bash
  grep "modules/darwin/profiles/base.nix" darwin/default.nix  # exactly 1 match
  grep "./mise.nix" darwin/default.nix          # no match
  grep "./cachix.nix" darwin/default.nix        # no match
  grep "./homebrew.nix" darwin/default.nix      # no match
  grep "./settings.nix" darwin/default.nix      # no match
  grep "./wsdd.nix" darwin/default.nix          # no match
  ```
- **Expected**: Individual file imports REMOVED. Single profile import present.

---

## Summary

| Phase | Tasks | Files Created | Files Copied | Files Edited | Files Deleted |
|-------|-------|---------------|--------------|--------------|---------------|
| 1 (specialArgs) | 1.1-1.2 | 0 | 0 | 1 | 0 |
| 2 (profile chain) | 2.1-2.11 | 2 | 4 | 1 (+1 slim) | 5 |
| 3a (GPG) | 3.1-3.3 | 1 | 0 | 2 | 0 |
| 3b (Ghostty iteration) | 3.5-3.8 | 1 | 0 | 2 | 0 |
| 4 (verification) | 4.1-4.8 | 0 | 0 | 0 | 0 |
| **Total** | **27 tasks** | **4** | **4** | **7** | **5** |

**Net line change (from design)**: creates +672 lines, deletes -728 lines, net -56 lines.
**Delivery strategy**: Single PR (~300 line diff, within standard review budget).
