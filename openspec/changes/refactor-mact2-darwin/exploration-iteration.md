# Exploration Iteration: Ghostty Palette Unification (Scope Addition)

**Date**: 2026-07-06
**Status**: Complete
**SDD Phase**: Explore (iteration on scope addition)
**Change**: refactor-mact2-darwin
**Trigger**: User reviewed Phase 3 apply results, requested palette deduplication via `shared/ghostty.nix`

---

## 1. Exact Duplication Identified

### 1.1 The 22-Color Base16 Palette (Identical in Both Files)

The `themes.nix-colors` block is the primary duplication target. After Phase 3, both files use `programs.ghostty` HM module with the same `themes.nix-colors` attrset structure. The palette mapping is identical across both platforms:

**`home-linux/ghostty.nix`** lines 45-71 (palette section):
```nix
palette = [
  "0=#${config.colorScheme.palette.base00}"
  "1=#${config.colorScheme.palette.base08}"
  "2=#${config.colorScheme.palette.base0B}"
  # ... 22 entries total (ANSI 0-21) ...
  "21=#${config.colorScheme.palette.base06}"
];
background = "#${config.colorScheme.palette.base00}";
foreground = "#${config.colorScheme.palette.base05}";
cursor-color = "#${config.colorScheme.palette.base05}";
selection-background = "#${config.colorScheme.palette.base02}";
selection-foreground = "#${config.colorScheme.palette.base05}";  # ← DIFFERS
```

**`home-darwin/ghostty.nix`** lines 37-68 (palette section):
```nix
palette = [
  "0=#${config.colorScheme.palette.base00}"
  "1=#${config.colorScheme.palette.base08}"
  "2=#${config.colorScheme.palette.base0B}"
  # ... 22 entries total (ANSI 0-21) ...
  "21=#${config.colorScheme.palette.base06}"
];
background = "#${config.colorScheme.palette.base00}";
foreground = "#${config.colorScheme.palette.base05}";
cursor-color = "#${config.colorScheme.palette.base05}";
selection-background = "#${config.colorScheme.palette.base02}";
selection-foreground = "#${config.colorScheme.palette.base00}";  # ← DIFFERS
```

### 1.2 Identical Blocks (Byte-Level)

| Section | Linux lines | Darwin lines | Identical? |
|---------|------------|-------------|------------|
| `palette` list (ANSI 0-21) | 45-70 (26 lines) | 37-62 (26 lines) | YES — byte-identical |
| `background` | 72 | 64 | YES |
| `foreground` | 73 | 65 | YES |
| `cursor-color` | 74 | 66 | YES |
| `selection-background` | 75 | 67 | YES |
| `selection-foreground` | 76 | 68 | NO — `base05` vs `base00` |

### 1.3 Settings Block — Mostly Identical

| Setting | Linux | Darwin | Status |
|---------|-------|--------|--------|
| `bold-color = "bright"` | line 25 | line 16 | Identical |
| `background-opacity = 0.8` | line 26 | line 17 | Identical |
| `clipboard-paste-protection = false` | line 27 | line 18 | Identical |
| `clipboard-write = "allow"` | line 28 | line 19 | Identical |
| `font-family = "CaskaydiaCove Nerd Font"` | line 29 | line 20 | Identical |
| `font-feature = "+liga"` | line 30 | line 21 | Identical |
| `font-size = 11` | line 31 | line 22 | Identical |
| `keybind = [ "shift+insert=paste_from_clipboard" ]` | line 32-34 | line 23-25 | Identical |
| `maximize = true` | line 35 | line 27 | Identical |
| `scrollback-limit = 4294967295` | line 36 | line 28 | Identical |
| `term = "xterm-256color"` | line 37 | line 29 | Identical |
| `theme = "nix-colors"` | line 38 | line 30 | Identical |
| `window-padding-balance = true` | line 39 | line 31 | Identical |
| `window-padding-color = "extend"` | line 40 | line 32 | Identical |
| `macos-option-as-alt = "left"` | — | line 26 | Darwin-only |
| `package = null` | — | line 14 | Darwin-only |
| `lib.mkForce` wrapping | lines 24, 43 | — | Linux-only |

### 1.4 Quantified Duplication

- **Total duplicated lines**: ~48 lines (26 palette + 5 theme colors + 15 settings + 2 structural)
- **Total per-platform file**: 80 lines (Linux) + 72 lines (Darwin) = 152 lines
- **Unique content per platform**: ~20 lines each (mkForce wrapper vs package=null + macos-option-as-alt + selection-foreground diff)
- **Duplication ratio**: ~63% of content is identical

---

## 2. `macos-option-as-alt` Harmlessness on Linux — Verified

### 2.1 Ghostty Configuration Model

Ghostty reads a flat configuration file (produced by the HM module from `programs.ghostty.settings`). Unknown or platform-inapplicable keys are **silently ignored** by Ghostty's config parser. This is documented behavior — Ghostty does not error on unrecognized configuration directives.

### 2.2 Proposed Design Eliminates the Question Entirely

With the function-based approach, `macos-option-as-alt` is passed via `extraSettings` parameter, which Darwin provides and Linux does not. The key never appears in the Linux configuration:

```
Linux config:   settings = { ... shared settings ... }    // no macos-option-as-alt
Darwin config:  settings = { ... shared ... macos-option-as-alt = "left" }
```

This is cleaner than relying on ghostty's silent-ignore behavior. The function interface makes platform differences explicit at the call site.

### 2.3 Even If It Did Appear — Safety Confirmed

Even if `macos-option-as-alt` were accidentally included in the Linux config (unlikely with the proposed design), Ghostty on Linux would ignore it. The Ghostty documentation states that platform-specific options are silently discarded when they don't apply to the current OS. No crash, no warning, no behavior change.

---

## 3. Shared Function Approach — Validated Against Nix Module System

### 3.1 Pattern: Pure Nix Function (NOT a HM Module)

The `shared/ghostty.nix` file is a **regular Nix file that evaluates to a lambda** (function), not a NixOS/Home Manager module. This is the same pattern as `overlays/darwin.nix` and `overlays/linux.nix` in this repo — pure functions that return attrsets.

**Why NOT a HM module**: If it were a HM module (`{ config, ... }: { programs.ghostty = ...; }`), it would need platform conditionals (`isDarwin`) to handle `lib.mkForce` vs no-mkForce, `macos-option-as-alt`, etc. A function lets the caller pass in platform-specific behavior as parameters — cleaner separation.

### 3.2 Import Mechanism

**Per-platform HM modules** (still in `home-linux/ghostty.nix` and `home-darwin/ghostty.nix`) use Nix's `import` keyword to invoke the function:

```nix
# home-linux/ghostty.nix (HM module)
{ config, lib, ... }:
let
  shared = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
  };
in
{
  programs.ghostty = {
    enable = true;
    settings = lib.mkForce shared.settings;
    themes = lib.mkForce shared.theme;
  };
}
```

```nix
# home-darwin/ghostty.nix (HM module)
{ config, ... }:
let
  shared = import ../../shared/ghostty.nix {
    colorScheme = config.colorScheme;
    selectionForegroundPalette = "base00";
    extraSettings = { macos-option-as-alt = "left"; };
  };
in
{
  programs.ghostty = {
    enable = true;
    package = null;
    settings = shared.settings;
    themes = shared.theme;
  };
}
```

### 3.3 Why This Works

1. **`import` is pure Nix** — It evaluates the file, which returns a function. The function is called with platform-specific parameters. The result is an attrset bound to a `let` variable used within the module body. This is standard Nix, not module-system magic.

2. **No `isDarwin` conditionals** — Platform differences are handled at the call site via function parameters, not inside the shared file.

3. **`shared-modules.nix` unchanged** — The per-platform `ghostty.nix` files remain HM modules at the same paths (`./ghostty.nix` in both module lists). The shared file is a function imported via `import`, not added to any module list.

4. **Evaluation is lazy** — The `import` inside the `let` binding is evaluated once per module evaluation, not per attribute access. No performance penalty.

### 3.4 Existing Precedent in This Repo

The `shared/gpg.nix` file (Phase 3, already applied) uses the HM module pattern (`{ config, lib, pkgs, ... }: { ... }`). That works because GPG has zero platform differences in its shared logic — the `importKey` function and activation script are byte-identical.

Ghostty is different — it has 3 platform differences (`mkForce`, `macos-option-as-alt`, `selection-foreground`). A HM module would need conditionals. A function avoids them entirely.

---

## 4. `shared-modules.nix` Changes — None Needed

### 4.1 Both File Lists Verified

**`home-darwin/shared-modules.nix`** line 14:
```nix
./ghostty.nix    # ← stays at same path
```

**`home-linux/shared-modules.nix`** line 29:
```nix
./ghostty.nix    # ← stays at same path
```

### 4.2 Why No Changes

- The per-platform `ghostty.nix` files remain HM modules at their existing paths
- The new `shared/ghostty.nix` is a pure function, NOT a HM module — it does NOT go in any `shared-modules.nix` list
- The function is imported via Nix's `import` keyword inside the per-platform modules, not via the HM `imports` list
- The import chains in `flake.nix` are unchanged — `flake.nix` imports the module lists, module lists import `./ghostty.nix`, `ghostty.nix` imports the shared function

### 4.3 `flake.nix` Also Unchanged

Neither `linuxHomeModules` nor `darwinHomeModules` bindings change. The home-manager module lists (`shared-modules.nix` files) are unchanged. The per-platform ghostty files are unchanged in path. Only their content changes.

---

## 5. Proposed Clean Function Interface

### 5.1 Function Signature

```nix
# shared/ghostty.nix
# Pure Nix function — NOT a Home Manager module.
# Returns { settings, theme } — bare attrsets without lib.mkForce.
#
# Parameters:
#   colorScheme                 — config.colorScheme (from nix-colors, has .palette attr)
#   selectionForegroundPalette? — base16 key for selection foreground (default: "base05")
#   extraSettings?              — attrset merged into settings (platform overrides)
{
  colorScheme
, selectionForegroundPalette ? "base05"
, extraSettings ? {}
}:
```

### 5.2 Return Value

```nix
rec {
  settings = {
    # All 15 shared settings — no platform conditionals
    bold-color = "bright";
    background-opacity = 0.8;
    clipboard-paste-protection = false;
    clipboard-write = "allow";
    font-family = "CaskaydiaCove Nerd Font";
    font-feature = "+liga";
    font-size = 11;
    keybind = [ "shift+insert=paste_from_clipboard" ];
    maximize = true;
    scrollback-limit = 4294967295;
    term = "xterm-256color";
    theme = "nix-colors";
    window-padding-balance = true;
    window-padding-color = "extend";
  } // extraSettings;   # ← platform overrides merged here

  theme = {
    nix-colors = {
      palette = [ /* 22 colors — single source of truth */ ];
      background = "#${p.base00}";
      foreground = "#${p.base05}";
      cursor-color = "#${p.base05}";
      selection-background = "#${p.base02}";
      selection-foreground = "#${p.${selectionForegroundPalette}}";  # ← parameterized
    };
  };
}
```

### 5.3 Call Sites

| Parameter | Linux | Darwin |
|-----------|-------|--------|
| `colorScheme` | `config.colorScheme` | `config.colorScheme` |
| `selectionForegroundPalette` | omitted (defaults to `"base05"`) | `"base00"` |
| `extraSettings` | `{}` (omitted) | `{ macos-option-as-alt = "left"; }` |

### 5.4 `lib.mkForce` Handling

`lib.mkForce` is NOT applied inside the shared function. It's the caller's responsibility:

- **Linux**: `settings = lib.mkForce shared.settings; themes = lib.mkForce shared.theme;` — overrides omarchy-nix's ghostty config
- **Darwin**: `settings = shared.settings; themes = shared.theme;` — no competing ghostty module, no mkForce needed

This separation means the shared function never needs to know about `lib.mkForce`, `omarchy-nix`, or any platform-specific module conflict resolution. Clean separation of concerns.

### 5.5 `package = null` Handling

`package = null` is Darwin-only (ghostty installed via Homebrew on Intel Mac). It stays inline in `home-darwin/ghostty.nix` because:
- It's not a setting — it's a `programs.ghostty` top-level attr
- It has no equivalent on Linux
- It's 1 line — extracting it would add complexity without proportional benefit

---

## 6. Lines of Code Saved

### 6.1 Before (Current Phase 3 State)

| File | Lines | Content |
|------|-------|---------|
| `home-linux/ghostty.nix` | 80 | Full HM module with palette + settings + mkForce |
| `home-darwin/ghostty.nix` | 72 | Full HM module with palette + settings + darwin overrides |
| **Total** | **152** | |

### 6.2 After (Proposed)

| File | Lines | Content |
|------|-------|---------|
| `shared/ghostty.nix` (NEW) | **~55** | Function: palette (26) + theme colors (5) + settings (15) + interface (9) |
| `home-linux/ghostty.nix` (REFACTORED) | **~15** | Import shared + mkForce wrapper |
| `home-darwin/ghostty.nix` (REFACTORED) | **~20** | Import shared + package=null + platform overrides |
| **Total** | **~90** | |

### 6.3 Savings

| Metric | Value |
|--------|-------|
| Lines saved (net) | **~62 lines** (152 -> 90) |
| Reduction | **~41%** |
| Duplicated palette lines eliminated | **33 lines** (26 palette + 5 theme + 2 structural) |
| Files where palette lives | 2 -> **1** |

Beyond line count, the primary value is **maintenance** — changing the color scheme palette, font, or any shared ghostty setting requires editing exactly one file instead of two. This eliminates the platform-drift risk that the original Phase 3 design (design.md Component 13) intentionally accepted.

---

## 7. File Change Map (Iteration Only)

### 7.1 New File

| File | Action | Lines | Notes |
|------|--------|-------|-------|
| `shared/ghostty.nix` | **CREATE** | ~55 | Pure Nix function — NOT a HM module |

### 7.2 Modified Files

| File | Action | Lines Before | Lines After | Delta |
|------|--------|-------------|-------------|-------|
| `home-linux/ghostty.nix` | **REWRITE** | 80 | ~15 | -65 |
| `home-darwin/ghostty.nix` | **REWRITE** | 72 | ~20 | -52 |

### 7.3 Unchanged Files

| File | Reason |
|------|--------|
| `home-linux/shared-modules.nix` | Module list unchanged — `./ghostty.nix` path same |
| `home-darwin/shared-modules.nix` | Module list unchanged — `./ghostty.nix` path same |
| `flake.nix` | No import path or binding changes |
| `openspec/changes/refactor-mact2-darwin/design.md` | Will need update in design phase |
| `openspec/changes/refactor-mact2-darwin/spec.md` | Will need R4 updated in spec phase |
| `openspec/changes/refactor-mact2-darwin/tasks.md` | Will need Task 3.4 updated in tasks phase |

---

## 8. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `import` path resolution fails | Low | High (build fails) | Use `../../shared/ghostty.nix` from each platform dir; verify flake check |
| `colorScheme` not available in scope | None | — | Both calling modules already receive `config` parameter and use `config.colorScheme` |
| Function return shape mismatch | Low | Medium (config invalid) | The `rec { settings; theme; }` shape exactly matches the attrset structure the calling modules assign to `programs.ghostty` |
| Darwin `package = null` still needed | None | — | Confirmed: ghostty flake has no x86_64-darwin package. `package = null` stays inline |
| Linux `lib.mkForce` still needed | None | — | Confirmed: omarchy-nix sets `programs.ghostty` on t14. `mkForce` stays inline |
| Shared file accidentally evaluated as module | None | — | The function is not in any `imports` list. Only called via `import` in `let` bindings |

---

## 9. Interaction with Existing Phase 3 Applied Work

### 9.1 What Phase 3 Already Did

Task 3.4 (commit `8227b25`) rewrote `home-darwin/ghostty.nix` from raw `home.file` to `programs.ghostty`. The palette was intentionally duplicated from `home-linux/ghostty.nix` at that time because the design.md scope did not include shared ghostty extraction. The original design (Component 13, lines 557-642) noted the duplication and accepted it as "acceptable for now":

> "The palette mapping is identical between Linux and Darwin except for `selection-foreground`"

### 9.2 What This Iteration Changes

The user reviewed the applied Phase 3 results and identified the duplication as unnecessary — the palette can be unified now via a shared function without waiting for a future change. This iteration is a scope INCREASE on Area 3 (Ghostty consolidation).

### 9.3 What Stays the Same

- GPG consolidation (shared/gpg.nix) is unchanged
- Darwin profile chain (Area 1) is unchanged
- mkDarwinHost specialArgs fix (Area 2) is unchanged
- All Phase 1-3 files not listed in section 7.2 are unchanged

### 9.4 Files to Verify After Iteration

```bash
# Verify shared function evaluates
nix-instantiate --eval -E '(import ./shared/ghostty.nix { colorScheme = { palette = { base00 = "000"; base01 = "111"; base02 = "222"; base03 = "333"; base04 = "444"; base05 = "555"; base06 = "666"; base07 = "777"; base08 = "888"; base09 = "999"; base0A = "aaa"; base0B = "bbb"; base0C = "ccc"; base0D = "ddd"; base0E = "eee"; base0F = "fff"; }; }; }).settings.theme'

# Verify full flake evaluation (all hosts)
nix flake check --no-build

# Verify palette exists in only one file
grep -l 'base0F.*base06' home-linux/ghostty.nix home-darwin/ghostty.nix shared/ghostty.nix
# Expected: only shared/ghostty.nix has the full palette

# Verify no isDarwin in shared file
grep -c isDarwin shared/ghostty.nix
# Expected: 0
```

---

## 10. Key Learnings

- The 22-color base16 palette is byte-identical between Linux and Darwin with exactly ONE exception: `selection-foreground` uses `base05` on Linux vs `base00` on Darwin. This single difference is easily handled via function parameterization.
- The `programs.ghostty` HM module's attrset shape (`{ settings, themes }`) maps perfectly to a function return value — no impedance mismatch.
- Using `import` (Nix keyword) vs `imports` (HM module list) is a clean boundary: the function handles what's shared, the module handles what's platform-specific (mkForce, package, extraSettings).
- The existing `shared/gpg.nix` (HM module pattern) works for GPG because GPG has zero platform differences in shared logic. Ghostty has 3 differences — a function is the better fit.
- `shared-modules.nix` needs zero changes because the per-platform ghostty files stay at the same paths. Only their content changes.
- The `home-linux/ghostty.nix` comment about t14 importing from `hosts/t14/home/ghostty.nix` is misleading — no such file exists. t14's ghostty config comes through the shared-modules chain. This comment can be cleaned up opportunistically during the rewrite.
