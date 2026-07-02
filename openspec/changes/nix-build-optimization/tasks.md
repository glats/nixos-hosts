# Tasks: Nix Build Optimization

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~80-100 net additions across 3 files |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr-default |
| Chain strategy | N/A (single PR) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: N/A
400-line budget risk: Low

### Suggested Work Units

Not needed — total delta is well under 400 lines. Single PR to main.

## Phase 1: NixOS Base Module (`modules/base/nix.nix`)

- [x] 1.1 Change function signature `{ lib, ... }:` → `{ lib, inputs, ... }:` in `modules/base/nix.nix`
- [x] 1.2 Add `max-jobs = lib.mkDefault 1;` and `cores = 0;` to `nix.settings` (with comment about OOM prevention)
- [x] 1.3 Add `keep-outputs = true;` to `nix.settings` (with comment about GC pairing)
- [x] 1.4 Add `trusted-substituters = [ ... ];` list mirroring the 8 substituters (fastly mirrors + 6 cachix)
- [x] 1.5 Add `nix.registry.nixpkgs.flake = inputs.nixpkgs;` at top-level (locks flake registry)

**Verify**: `nix-instantiate --eval modules/base/nix.nix` returns valid attrset; `nix flake check --no-build` passes

## Phase 2: Darwin Cache Parity (`darwin/cachix.nix`)

- [x] 2.1 Add `substituters = lib.mkBefore [ "https://aseipp-nix-cache.freetls.fastly.net" "https://aseipp-nix-cache.global.ssl.fastly.net" ];` (fastly mirrors)
- [x] 2.2 Extend existing `substituters = lib.mkAfter [ ... ]` with 3 missing entries: `nixpkgs-unfree.cachix.org`, `cache.flox.dev`, `nixpkgs.cachix.org`
- [x] 2.3 Extend `trusted-public-keys = lib.mkAfter [ ... ]` with 3 matching public keys for the new cachix entries

**Verify**: `nix flake check --no-build` passes for darwin; `darwin-rebuild check` on mact2 confirms cache list includes new entries

## Phase 3: Build Wrapper Script (`bin/nixos-build`)

- [x] 3.1 Add `--raw` flag parsing alongside existing `--no-nom` filter loop
- [x] 3.2 Add `USE_NH` variable: `true` if `command -v nh` succeeds, `false` if `--raw` passed
- [x] 3.3 Update help text to document `--raw` flag and `nh`-by-default behavior
- [x] 3.4 Replace `switch` case: `nh os switch` (default) vs `sudo nixos-rebuild switch --flake ...` (`--raw`)
- [x] 3.5 Replace `boot` and `test` cases with `nh os boot` / `nh os test` (with `--raw` fallback)
- [x] 3.6 Replace `dry` case: `nh os switch --dry` (default) vs `sudo nixos-rebuild dry-activate` (`--raw`)
- [x] 3.7 Replace `upgrade` case: `nh os switch --update` (default) vs `nix flake update && sudo nixos-rebuild switch` (`--raw`)
- [x] 3.8 Update `safe` workflow: all 4 steps use `nh os` (default) or `nixos-rebuild` (`--raw`)

**Verify**: `bash -n bin/nixos-build` (syntax check); `bin/nixos-build help` shows new flag; `bin/nixos-build --raw check` still works

## Phase 4: Verification

- [x] V1 Run `nix fmt -- modules/base/nix.nix darwin/cachix.nix` — confirm nixfmt compliance
- [x] V2 Run `format-nix` — confirm full-repo formatting passes
- [x] V3 Run `nix flake check --no-build` — confirm flake evaluates without errors
- [x] V4 Run `bin/nixos-build dry` — confirm `nh os switch --dry` shows diff preview
- [x] V5 Run `bin/nixos-build --raw check` — confirm fallback path still works
- [ ] V6 Manual: on t14, run `bin/nixos-build switch` and observe `ps aux | grep -c nix` ≤ 1 (parallelism limit effective)
- [ ] V7 Manual: confirm `nix shell nixpkgs#hello` uses locked nixpkgs (no network tree fetch, exit <2s)
- [ ] V8 Manual: on mact2, `darwin-rebuild switch` and confirm build log shows cache hits from new cachix entries
