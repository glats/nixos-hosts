# Proposal: dedup-structure

## Intent
Reduce Linux/Darwin duplication so future Nix changes edit one source.

## Scope

### In Scope
- Shared network resilience settings for Nix.
- Shared cachix substituters and public keys.
- `baseHomeConfig` wrapper for all standalone HM configs.
- Single source for GitHub PAT sops declarations.
- Common package set between `linuxPackages` and `darwinPackages`.
- Audit remote-desktop sharability.

### Out of Scope
- Functional behavior changes.
- Secrets content edits.

## Capabilities

### New Capabilities
None (refactor only).

### Modified Capabilities
None (config deduplication).

## Approach
Move duplicated Nix settings into `shared/` or `lib/` helpers; keep platform-specific wiring in host files.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/nix-resilience.nix` | New | Shared network settings |
| `shared/cachix.nix` | New | Shared substituters/keys |
| `shared/github-tokens.nix` | New | Shared PAT sops declarations |
| `flake.nix` | Modify | Use `baseHomeConfig` for rog/thinkcentre/t14 |
| `lib/packages.nix` | Modify | Common package set |
| `linux/home/remote-desktop.nix` | Comment | Sharability audit note |
| `darwin/home/remote-desktop.nix` | Comment | Sharability audit note |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Merge priority changes | Low | Keep `lib.mkBefore`/`lib.mkAfter` in consumers |
| HM extra args drift | Low | Preserve per-host `extraSpecialArgs` |

## Rollback Plan
Revert any single commit; each change is independent.

## Success Criteria

- [ ] `nix flake check --no-build` passes.
- [ ] No duplicate declarations remain.
