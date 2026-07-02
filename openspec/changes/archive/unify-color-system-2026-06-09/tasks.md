# Tasks: Unify Color System

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~120 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

## Phase 1: Foundation

- [x] **1.1** Create `lib/colors.nix` with shared helpers
  - **Files**: `lib/colors.nix` (new)
  - **Action**: Write `{ lib }:` attrset exporting `hexToRgb`, `doubleHex`, `byteDoubleHex` using `lib.fromHexString` and `lib.concatMap` / `lib.stringToCharacters`
  - **Validation**: `nix eval --expr 'let c = import ./lib/colors.nix { lib = (import <nixpkgs> {}).lib; }; in c.hexToRgb "0d73cc"'` returns `"13,115,204"`

## Phase 2: Consumer Refactoring

- [x] **2.1** Refactor `modules/desktop/kmscon.nix` to use shared library and palette
  - **Files**: `modules/desktop/kmscon.nix`
  - **Action**: Remove local `hexToRgb` (lines 4-11) and local `p` attrset (lines 13-30). Add `palette = import ../../shared/palette.nix;` and `colors = import ../lib/colors.nix { inherit lib; };` in `let`. Replace all `p.black`/`p.red`/... with `palette.palette.base00`/`palette.palette.base08`/... per the mapping table in spec. Replace `hexToRgb` calls with `colors.hexToRgb`.
  - **Validation**: `grep -n 'hexToRgb =\|p = {' modules/desktop/kmscon.nix` returns zero matches. `nix flake check` passes.

- [x] **2.2** Refactor `home-linux/mate.nix` to use `lib/colors.nix`
  - **Files**: `home-linux/mate.nix`
  - **Action**: Remove local `hexToRgb` (lines 9-17), `doubleHex` (lines 18-27), `byteDoubleHex` (lines 28-35). Add `colors = import ../lib/colors.nix { inherit lib; };` in `let`. Update line 236 `color = "${hexToRgb ...}"` to `color = "rgb(${colors.hexToRgb config.colorScheme.palette.base00})";`. Update lines 269, 273, 276, 277 to use `colors.doubleHex` and `colors.byteDoubleHex` (no wrapping change needed for these).
  - **Validation**: `grep -n 'hexToRgb =\|doubleHex =\|byteDoubleHex =' home-linux/mate.nix` returns zero matches. `nix flake check` passes.

- [x] **2.3** Update `home-linux/theme.nix` GTK CSS to use palette interpolation
  - **Files**: `home-linux/theme.nix`
  - **Action**: Replace hardcoded `#505050` on lines 26, 31, 35, 40, 41 with `#${config.colorScheme.palette.base02}`. Replace hardcoded `#ffffff` on lines 27, 32, 36, 42, 43 with `#${config.colorScheme.palette.base07}`.
  - **Validation**: `grep -n '505050\|ffffff' home-linux/theme.nix` returns zero matches (only interpolation remains). `nix flake check` passes.

- [x] **2.4** Fix `home-darwin/ghostty.nix` color8 drift
  - **Files**: `home-darwin/ghostty.nix`
  - **Action**: Change line 25 from `palette = 8=#${config.colorScheme.palette.base04}` to `palette = 8=#${config.colorScheme.palette.base03}`.
  - **Validation**: `grep -n 'base04' home-darwin/ghostty.nix` returns nothing. Diff against `home-linux/ghostty.nix` shows only platform-specific differences (file paths, `macos-option-as-alt`).

## Phase 3: Verification

- [x] **3.1** Format all modified `.nix` files
  - **Files**: `lib/colors.nix`, `modules/desktop/kmscon.nix`, `home-linux/mate.nix`, `home-linux/theme.nix`, `home-darwin/ghostty.nix`
  - **Action**: Run `nix fmt -- <path>` for each modified file, or `format-nix` for full repo.
  - **Validation**: `nix fmt -- --check` reports no changes needed.

- [x] **3.2** Run `nix flake check`
  - **Files**: entire repo
  - **Action**: Execute `nix flake check`.
  - **Validation**: Command exits with code 0.
