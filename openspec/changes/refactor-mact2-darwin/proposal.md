# Proposal: Refactor mact2 Darwin Configuration

## Metadata
- Change ID: refactor-mact2-darwin
- Execution mode: auto
- Artifact store: hybrid
- Delivery strategy: single-pr
- Review budget: standard

## Intent
Restructure the Darwin configuration to mirror the NixOS profile-chain pattern already present in the repo, eliminate known asymmetries between `mkDarwinHost` and `mkHost`, and consolidate duplicated GPG/Ghostty Home Manager logic across platforms.

## Scope

### In-Scope
1. **Darwin profile chain** -- Move flat `darwin/*.nix` system modules into categorized `modules/darwin/system/` and `modules/darwin/services/` subdirectories; create `modules/darwin/profiles/base.nix` as a pure import aggregator; refactor `darwin/default.nix` to import the profile instead of individual files; extract nix config from `darwin/default.nix` into `modules/darwin/system/nix.nix`
2. **`mkDarwinHost.nix` specialArgs deduplication** -- Remove the redundant `home-manager.extraSpecialArgs` inline block from `mkDarwinHost.nix` so that `darwin/default.nix` is the sole owner of that config, matching `mkNixosHost` behavior
3. **GPG and Ghostty consolidation** -- Extract shared GPG `importKey` logic into `shared/gpg.nix`; migrate `home-darwin/ghostty.nix` from raw `home.file` to `programs.ghostty` HM module

### Out-of-Scope
- Dendritic pattern (flake-parts + import-tree) -- unnecessary for 1 Darwin host
- Unifying NixOS and Darwin system modules into a shared `common.nix` -- intersection too small
- Moving `darwin/default.nix` entirely into `modules/darwin/` -- user config and HM setup are per-host concerns
- Modifying `shared/` or `shared-modules.nix` canonical list structures -- already well-designed
- Changing anything under `modules/base/`, `modules/profiles/`, or NixOS host configs

## Approach

### Area 1: Introduce Darwin Profile Chain
**Problem**: `darwin/default.nix` is both an import aggregator AND contains inline configuration (nix settings, nix-homebrew, home-manager, user config, environment variables). The six darwin system modules sit in a flat directory with no categorization or profile chain. A second Darwin host would need to duplicate the aggregator logic.

**Solution**: Mirror the NixOS `modules/profiles/` pattern exactly. Create `modules/darwin/profiles/base.nix` -- a pure import aggregator that lists categorized darwin modules. Move each `darwin/*.nix` system module into `modules/darwin/system/` or `modules/darwin/services/` as appropriate. Extract the inline nix config from `darwin/default.nix` into `modules/darwin/system/nix.nix`. Refactor `darwin/default.nix` to import only the profile (for system modules) plus keep its per-host concerns (home-manager, users, environment, services enablement). Update `lib/mkDarwinHost.nix` import path accordingly.

**Files**:
| File | Action |
|------|--------|
| `modules/darwin/profiles/base.nix` | NEW -- darwin profile import aggregator |
| `modules/darwin/system/nix.nix` | NEW -- extracted nix config from `darwin/default.nix` + `darwin/cachix.nix` |
| `modules/darwin/system/cachix.nix` | MOVED from `darwin/cachix.nix` -- substituters and trusted keys |
| `modules/darwin/system/homebrew.nix` | MOVED from `darwin/homebrew.nix` |
| `modules/darwin/system/settings.nix` | MOVED from `darwin/settings.nix` |
| `modules/darwin/system/mise.nix` | MOVED from `darwin/mise.nix` |
| `modules/darwin/services/wsdd.nix` | MOVED from `darwin/wsdd.nix` |
| `darwin/default.nix` | REFACTORED -- imports `modules/darwin/profiles/base.nix`, retains HM + user config |
| `lib/mkDarwinHost.nix` | UPDATE -- import path from `../darwin` to `../darwin` (unchanged, works via `darwin/default.nix`) |

### Area 2: Fix mkDarwinHost.nix specialArgs Asymmetry
**Problem**: `mkDarwinHost.nix` passes `home-manager.extraSpecialArgs` inline in its modules list (lines 42-52), while `darwin/default.nix` also sets `home-manager.extraSpecialArgs` (lines 58-65). This creates a confusing double-passing. `mkNixosHost` does not have this pattern -- `modules/base/home-manager.nix` owns that responsibility exclusively.

**Solution**: Remove the `home-manager.extraSpecialArgs` block from `mkDarwinHost.nix`. Let `darwin/default.nix` be the single owner. The builder only sets `specialArgs` for `darwinSystem`, not for child subsystems.

**Files**:
| File | Action |
|------|--------|
| `lib/mkDarwinHost.nix` | REMOVE lines 42-52 (the inline `home-manager.extraSpecialArgs` block) |
| `darwin/default.nix` | Already sets `home-manager.extraSpecialArgs` -- verify it passes all needed attrs |

### Area 3: Consolidate GPG and Ghostty Duplication
**Problem 3a (GPG)**: `home-linux/gpg.nix` and `home-darwin/gpg.nix` share a byte-identical `importKey` function and activation script. Only the package list differs (pinentry-curses vs pinentry_mac + nix-index). Future changes to GPG key import logic risk platform drift.

**Solution 3a**: Extract the shared `importKey` function into `shared/gpg.nix` as a module fragment. Keep per-platform files thin with just their package lists and the shared import.

**Problem 3b (Ghostty)**: `home-darwin/ghostty.nix` uses raw `home.file` to write config text, duplicating palette generation that already exists in `home-linux/ghostty.nix` via `programs.ghostty` HM module (which supports darwin since ghostty 1.0+).

**Solution 3b**: Migrate `home-darwin/ghostty.nix` to use `programs.ghostty` with the same `themes.nix-colors` attrset pattern, matching the Linux version. Keep darwin-specific settings (e.g., `macos-option-as-alt`) as overrides.

**Files**:
| File | Action |
|------|--------|
| `shared/gpg.nix` | NEW -- shared `importKey` function with activation script |
| `home-linux/gpg.nix` | REFACTORED -- imports `shared/gpg.nix`, retains linux-specific packages only |
| `home-darwin/gpg.nix` | REFACTORED -- imports `shared/gpg.nix`, retains darwin-specific packages only |
| `home-darwin/ghostty.nix` | REFACTORED -- migrate from `home.file` to `programs.ghostty` HM module |

## Tradeoffs

| Option | Pros | Cons |
|--------|------|------|
| Move all darwin modules to `modules/darwin/` (recommended) | Mirrors NixOS pattern exactly; clean separation of system vs host; enables future darwin hosts | ~8 files to move; import path updates needed |
| Keep flat `darwin/` but extract `darwin/profiles/base.nix` | Minimal file movement; still separates aggregation from inline config | Does not fix the flat directory problem; `darwin/` remains mixed concern |
| Adopt Dendritic/flake-parts | Community-popular pattern; auto-importing | Heavy infrastructure for 1 Darwin host; new flake input; adds complexity without proportional benefit |

## Implementation Order

1. **Phase 1: Area 2 (specialArgs fix)** -- 1 file changed, lowest risk, verifiable with `nix flake check --no-build darwinConfigurations.mact2`
2. **Phase 2: Area 1 (Darwin profile chain)** -- ~9 files moved/created, core structural change, verifiable per-move
3. **Phase 3: Area 3 (GPG + Ghostty dedup)** -- 4-5 files, cosmetic but reduces maintenance drift

Each phase is independently buildable and testable. Phases 1 and 2 can be combined into a single commit if the diff stays under 400 lines. Phase 3 can be a separate commit or combined if the total stays within budget.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Import path breakage during file moves (Area 1) | Medium | High (build fails) | Move files one at a time; run `nix flake check --no-build darwinConfigurations.mact2` after each move |
| `home-manager.extraSpecialArgs` removal breaks HM resolution (Area 2) | Low | High (HM cannot resolve `inputs`/`self`) | `darwin/default.nix` already passes it; verify with dry-run before switch |
| `programs.ghostty` darwin support incomplete for macOS-specific keys (Area 3) | Medium | Medium (missing `macos-option-as-alt`) | Ghostty HM module supports darwin since v1.0; verify key passthrough; fall back to `home.file` for unsupported keys |
| GPG shared module breaks activation order on either platform | Low | Medium (keys not imported) | Test GPG import activation on both platforms after refactor |
| Line count exceeds 400-line review budget | Medium | Low (chained PR needed) | Phase 1+2 estimate: ~250 lines; Phase 3: ~150 lines; can deliver as 2 commits in single PR or chain if needed |
