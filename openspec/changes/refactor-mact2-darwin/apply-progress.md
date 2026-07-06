# Apply Progress: refactor-mact2-darwin

**Status**: Phase 1 complete, Phase 2 ready
**Last Updated**: 2026-07-06
**Total tasks**: 25 (across 4 phases)
**Repo**: glats/nixos-hosts
**Branch**: refactor/mact2-darwin
**Phase 1 commit**: 6ef0a5f

---

## Phase 1: Area 2 — mkDarwinHost specialArgs Fix

| # | Task | File | Status | Verified |
|---|------|------|--------|----------|
| 1.1 | Remove redundant `home-manager.extraSpecialArgs` from builder | `lib/mkDarwinHost.nix` | DONE | DONE |
| 1.2 | Verify `darwin/default.nix` passes all needed attrs | `darwin/default.nix` | DONE | DONE |

**Phase 1 gate**: `nix flake check --no-build darwinConfigurations.mact2` + `grep "home-manager.extraSpecialArgs" lib/mkDarwinHost.nix` == 0

---

## Phase 2: Area 1 — Darwin Profile Chain

| # | Task | File(s) | Status | Verified |
|---|------|---------|--------|----------|
| 2.1 | Create `modules/darwin/{profiles,system,services}/` | directories | 🔲 | 🔲 |
| 2.2 | Create `modules/darwin/system/nix.nix` (consolidated nix config) | NEW | 🔲 | 🔲 |
| 2.3 | Create `modules/darwin/profiles/base.nix` (pure aggregator) | NEW | 🔲 | 🔲 |
| 2.4 | Copy `darwin/homebrew.nix` → `modules/darwin/system/homebrew.nix` | COPY | 🔲 | 🔲 |
| 2.5 | Copy `darwin/settings.nix` → `modules/darwin/system/settings.nix` | COPY | 🔲 | 🔲 |
| 2.6 | Copy `darwin/mise.nix` → `modules/darwin/system/mise.nix` | COPY | 🔲 | 🔲 |
| 2.7 | Copy `darwin/wsdd.nix` → `modules/darwin/services/wsdd.nix` | COPY | 🔲 | 🔲 |
| 2.8 | Copy+slim `darwin/cachix.nix` → `modules/darwin/system/cachix.nix` | COPY+EDIT | 🔲 | 🔲 |
| 2.9 | Verify additive state (checkpoint before switchover) | `nix flake check` | 🔲 | 🔲 |
| 2.10 | Refactor `darwin/default.nix` — import profile, remove nix config | EDIT | 🔲 | 🔲 |
| 2.11 | Delete old `darwin/cachix.nix homebrew.nix settings.nix mise.nix wsdd.nix` | DELETE (5) | 🔲 | 🔲 |

**Phase 2 gate**: `nix flake check --no-build darwinConfigurations.mact2` + `ls darwin/` == only default.nix + profile dirs populated

---

## Phase 3: Area 3 — GPG + Ghostty Consolidation

| # | Task | File | Status | Verified |
|---|------|------|--------|----------|
| 3.1 | Create `shared/gpg.nix` (shared importKey + activation) | NEW | 🔲 | 🔲 |
| 3.2 | Refactor `home-linux/gpg.nix` — import shared, linux packages only | EDIT | 🔲 | 🔲 |
| 3.3 | Refactor `home-darwin/gpg.nix` — import shared, darwin packages only | EDIT | 🔲 | 🔲 |
| 3.4 | Rewrite `home-darwin/ghostty.nix` — migrate from `home.file` to `programs.ghostty` | REWRITE | 🔲 | 🔲 |

**Phase 3 gate**: `nix flake check --no-build` (all hosts) + `grep "home.file" home-darwin/ghostty.nix` == 0 + `grep "shared/gpg.nix" home-*/gpg.nix` == 2 matches

---

## Phase 4: Final Verification

| # | Task | Command / Check | Status |
|---|------|-----------------|--------|
| 4.1 | Full flake check — ALL configurations | `nix flake check --no-build` | 🔲 |
| 4.2 | Format all changed files | `format-nix` | 🔲 |
| 4.3 | Directory structure verification | `ls darwin/ modules/darwin/*/` | 🔲 |
| 4.4 | specialArgs leak check | `grep -c "home-manager.extraSpecialArgs" lib/mkDarwinHost.nix` == 0 | 🔲 |
| 4.5 | GPG shared import check | `grep "shared/gpg.nix" home-*/gpg.nix` == 2 matches | 🔲 |
| 4.6 | Ghostty migration check | `grep "programs.ghostty" home-darwin/ghostty.nix` matches, `home.file` absent | 🔲 |
| 4.7 | No secrets exposed | `git diff --stat` — no secrets/ changes | 🔲 |
| 4.8 | darwin/default.nix import consistency | No `./*.nix` imports, only profile import | 🔲 |

**Phase 4 gate**: All checks pass. Zero uncommitted formatting changes.

---

## Rollback Commands

```bash
# Phase 1 rollback (undo specialArgs removal)
git checkout -- lib/mkDarwinHost.nix

# Phase 2 rollback (undo profile chain)
git checkout -- darwin/
rm -rf modules/darwin/

# Phase 3 rollback (undo GPG + Ghostty)
git checkout -- shared/gpg.nix home-linux/gpg.nix home-darwin/gpg.nix home-darwin/ghostty.nix
```
