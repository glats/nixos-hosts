# Exploration: macm4-migration

## Current State

The repository currently supports four hosts: three Linux (`rog`, `thinkcentre`, `t14`) and one macOS (`mact2` Intel, `x86_64-darwin`). The flake is pinned to **nixpkgs 26.05** solely because nixpkgs 26.11 dropped `x86_64-darwin` support. The new MacBook M4/M5 will be Apple Silicon (`aarch64-darwin`), which is supported on both 26.05 and later channels.

**Key existing infrastructure:**
- `lib/mkDarwinHost.nix` already accepts `system ? "x86_64-darwin"` parameter (line 6) — ready for `aarch64-darwin`
- `hosts/mact2/default.nix` uses `pkgs.stdenv.isAarch64` conditional for `systemPath` (line 83) — already architecture-aware
- `darwin/system/*.nix` modules are architecture-agnostic (nix, homebrew, settings, mise, cachix, wsdd)
- `darwin/home/shared-modules.nix` provides cross-platform HM modules (theme, ghostty, git, opencode, etc.)
- `pkgs/opencode/default.nix` already includes `aarch64-darwin` platform with verified hash
- `pkgs/leaf/default.nix` only has `x86_64-linux` and `x86_64-darwin` entries
- `pkgs/gentle-ai/default.nix` and `pkgs/engram/default.nix` only declare `x86_64-linux` and `x86_64-darwin` in `meta.platforms`
- `.sops.yaml` has `&host_mact2` key and creation rules referencing it for shared/user secrets
- `nix-vscode-extensions` input pinned to `1c7bb95` (last commit with `x86_64-darwin`) — must NOT be unpinned until mact2 retirement
- `bin/nixos-build` auto-detects Darwin and calls `darwin-rebuild` (lines 99-101)

## Affected Areas

| Path | Why Affected |
|------|--------------|
| `flake.nix` | Add `darwinConfigurations.macm4`, `packages.aarch64-darwin`, `formatter.aarch64-darwin`, standalone `homeConfigurations.macm4` |
| `lib/packages.nix` | Add `darwinPkgsAarch64 = pkgsFor "aarch64-darwin"` and `aarch64DarwinPackages` export |
| `hosts/macm4/default.nix` | New host entry (copy of mact2 pattern, system-aware) |
| `pkgs/leaf/default.nix` | Add `aarch64-darwin` entry with `leaf-macos-arm64` URL + hash; add platform |
| `pkgs/gentle-ai/default.nix` | Add `"aarch64-darwin"` to `meta.platforms` |
| `pkgs/engram/default.nix` | Add `"aarch64-darwin"` to `meta.platforms` |
| `.sops.yaml` | Add `&host_macm4` age key; update creation rules for `secrets/shared/`, `opencode.yaml`, `identities.yaml`, `atlassian.yaml` |
| `darwin/home/vscode.nix` | Works as-is (uses `pkgs.stdenv.hostPlatform.system` for extensions) |

## Approaches

### 1. Full Phase 1 as Single Deliverable (Recommended)
Execute all Phase 1 items in one commit/PR: create `hosts/macm4/`, update `flake.nix`, `lib/packages.nix`, and three custom package derivations. All verifiable via `nix flake check --no-build` and `nix eval` from Linux.

- **Pros**: Complete scaffold ready for Phase 2 bootstrapping; single review; atomic rollback via `git revert`
- **Cons**: ~150-200 lines changed (within 800-line budget); multiple file types
- **Effort**: Medium

### 2. Split by Artifact Type (Chained PRs)
- PR 1: `flake.nix` + `lib/packages.nix` (infrastructure)
- PR 2: `hosts/macm4/default.nix` (host entry)
- PR 3: Custom package updates (leaf, gentle-ai, engram)

- **Pros**: Smaller diffs per PR; focused reviews
- **Cons**: Intermediate states fail `nix flake check` until all PRs merged; more PR management overhead
- **Effort**: Medium-High (coordination overhead)

### 3. Minimal Scaffold First, Packages Later
Add only `flake.nix` + `hosts/macm4/` + `lib/packages.nix` initially; defer package platform additions until Phase 2 when building on actual hardware.

- **Pros**: Smallest initial diff; defers hash verification to hardware
- **Cons**: `nix flake check` will fail on missing `aarch64-darwin` platforms until packages updated; incomplete for standalone HM eval
- **Effort**: Low (initial), but creates broken intermediate state

## Recommendation

**Approach 1 (Full Phase 1 as Single Deliverable)** is recommended because:
1. All changes are pure evaluation-time (no hardware needed)
2. The 800-line review budget comfortably covers ~200 lines
3. `nix flake check --no-build` validates the entire scaffold atomically
4. Phase 2 (bootstrap) requires a working flake evaluation — partial scaffolds block hardware onboarding
5. Single commit `feat(darwin): add macm4 host scaffold (aarch64-darwin)` enables clean rollback

The custom package hashes (especially leaf's `sha256-q+B/PZVZlsR7qX12e9jFwsT9A2W8883En46sYkVFcU0=`) are documented in the migration plan and can be validated via `nix store prefetch-file` if needed.

## Risks

1. **sops age key generation**: Requires physical access to the new Mac (SSH host key → age key). Cannot be done in Phase 1. Documented in Phase 2 runbook.
2. **nix-vscode-extensions pin**: Must remain pinned until Phase 3. Verified: mact2 eval depends on it.
3. **Homebrew Rosetta**: `darwin/system/homebrew.nix` doesn't enable Rosetta 2 (`enableRosetta = true`). Apple Silicon Macs may need it for x86_64-only casks. Not configured currently — may need `homebrew.enableRosetta = true` in host config.
4. **opencode provider tier**: Migration plan notes `TODO(glatz): decidir tier opencode para macm4 (mact2 usa github-copilot-safe)`. Current `darwin/home/vscode.nix` uses `opencode-free` (line 48) vs mact2's `github-copilot-safe` (line 52). Decision needed before Phase 2.
5. **Channel migration timing**: Phase 3 migration to 26.11/unstable affects all 3 Linux hosts. Must be separate commit, tested on all hosts.
6. **Dead code**: `darwin/default.nix` duplicates `hosts/mact2/default.nix` and is not imported (per AGENTS.md line 104). Should be removed in Phase 3.

## Ready for Proposal

**Yes**. Phase 1 scope is well-defined, all code anchors verified, risks identified and documented. The orchestrator should proceed to `sdd-propose` with:
- Change name: `macm4-migration`
- Scope: Phase 1 only (flake scaffold, no hardware)
- Review budget: ~200 lines (well within 800)
- Delivery strategy: `ask-on-risk` (single PR acceptable)