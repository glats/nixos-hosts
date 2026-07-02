# Apply Progress: Unify Color System

## Status: COMPLETED

## Tasks

- [x] TASK-1: Create `lib/colors.nix` — DONE
- [x] TASK-2: Refactor `modules/desktop/kmscon.nix` — DONE
- [x] TASK-3: Refactor `home-linux/mate.nix` — DONE
- [x] TASK-4: Update `home-linux/theme.nix` GTK CSS — DONE
- [x] TASK-5: Fix `home-darwin/ghostty.nix` color8 — DONE
- [x] TASK-6: Format all modified files — DONE
- [x] TASK-7: Run `nix flake check` — PASSED

## Validation Log

### TASK-1 Validation
- `hexToRgb "0d73cc"` → `"13,115,204"` ✓
- `doubleHex "ab"` → `"aabb"` ✓
- `byteDoubleHex "cc0403"` → `"cccc04040303"` ✓

### TASK-2 Validation
- `grep -n 'hexToRgb =\|^  p = {' modules/desktop/kmscon.nix` → no matches ✓
- palette-mapped values produce correct rgb:
  - `base00` (black) → `"0,0,0"` ✓
  - `base05` (white) → `"221,221,221"` (= "dddddd") ✓
  - `base08` (red) → `"204,4,3"` (= "cc0403") ✓

### TASK-3 Validation
- `grep -n 'hexToRgb =\|doubleHex =\|byteDoubleHex =' home-linux/mate.nix` → only aliases from import (no definitions) ✓
- Wrapped call site: `"rgb(${hexToRgb "000000"})"` → `"rgb(0,0,0)"` ✓

### TASK-4 Validation
- `grep -n '505050\|ffffff' home-linux/theme.nix` → no matches ✓

### TASK-5 Validation
- `grep -n 'base04' home-darwin/ghostty.nix` → no matches ✓
- `diff home-linux/ghostty.nix home-darwin/ghostty.nix` → only platform-specific differences (file paths, `macos-option-as-alt`) ✓

### TASK-6 Validation
- `nix fmt -- --check <files>` → no changes needed ✓

### TASK-7 Validation
- `nix flake check` → "all checks passed!" ✓

## Deviations from Design

### Deviation: kmscon.nix import path
- **Design said**: `import ../lib/colors.nix { inherit lib; };` from `modules/desktop/kmscon.nix`
- **Implemented**: `import ../../lib/colors.nix { inherit lib; };`
- **Reason**: The design had a path bug. `modules/desktop/kmscon.nix` is at depth 2, so the correct relative path to repo-root `lib/colors.nix` is `../../lib/colors.nix`, not `../lib/colors.nix` (which would resolve to `modules/lib/colors.nix` and fail).

## Modified Files
- `lib/colors.nix` (new)
- `modules/desktop/kmscon.nix`
- `home-linux/mate.nix`
- `home-linux/theme.nix`
- `home-darwin/ghostty.nix`
