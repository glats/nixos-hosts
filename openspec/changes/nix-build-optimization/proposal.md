# Proposal: Nix Build Optimization

## Intent

NixOS builds are excessively long and freeze the laptop. Root causes: unbounded parallelism (NixOS defaults `max-jobs=auto`, `cores=0` → hundreds of parallel compiler instances → OOM), GC deleting build outputs (forces full recompile), missing cache parity between linux/darwin hosts, and `bin/nixos-build` not leveraging the already-installed `nh` tool.

## Scope

### In Scope
- Limit build parallelism to prevent OOM/freezes
- Retain build outputs across garbage collection
- Mirror `trusted-substituters` for non-root users
- Lock `nix.registry.nixpkgs` to flake-locked version
- Sync darwin cachix to linux-side parity
- Wire `nh os` into `bin/nixos-build` wrapper

### Out of Scope
- Pinning `nixpkgs` to a specific commit (Tier 2, separate change)
- Determinate Nix migration (Tier 3, separate change)
- Remote builder setup (Tier 3)
- Removing t14 `xdg-desktop-portal` overlay (waiting on upstream fix)

## Capabilities

### New Capabilities
None

### Modified Capabilities
None

## Approach

1. **`modules/base/nix.nix`**: Add `max-jobs = lib.mkDefault 1`, `keep-outputs = true`, `trusted-substituters` mirroring the substituter list
2. **`darwin/cachix.nix`**: Add aseipp fastly mirrors + missing caches (nixpkgs-unfree, flox, nixpkgs) to match linux side
3. **`bin/nixos-build`**: Replace `nixos-rebuild` calls with `nh os` for switch/boot/test; add `--raw` flag to fall back to `nixos-rebuild`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/base/nix.nix` | Modified | Add max-jobs, keep-outputs, trusted-substituters |
| `darwin/cachix.nix` | Modified | Sync cache list with linux-side `modules/base/cachix.nix` |
| `bin/nixos-build` | Modified | Wire `nh os` as default, `--raw` fallback to `nixos-rebuild` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `max-jobs=1` slows multi-package builds | Low | `mkDefault` allows per-host override |
| `keep-outputs` grows `/nix/store` ~30% | Medium | GC is manual (`automatic=false`); use `--delete-older-than 30d` |
| `nh` lacks full `nixos-rebuild` parity | Low | `--raw` flag keeps `nixos-rebuild` as escape hatch |

## Rollback Plan

Revert the single commit and `nixos-build switch`. All changes are additive `nix.settings` values and a shell script swap — no destructive operations.

## Dependencies

- `programs.nh` must be enabled on all NixOS hosts (already configured in `modules/base/nh.nix`)

## Success Criteria

- [ ] Laptop stays responsive during `nixos-build switch`
- [ ] Already-built packages are not recompiled after GC
- [ ] Non-root `nix shell nixpkgs#X` uses locked nixpkgs (no fresh tree fetch)
- [ ] `nixos-build switch` shows diff via `nh` before activating
- [ ] Darwin host has same cache coverage as linux hosts
- [ ] Total changed lines < 400 (review budget)
