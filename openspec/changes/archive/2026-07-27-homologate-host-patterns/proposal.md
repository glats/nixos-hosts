# Proposal: homologate-host-patterns

## Intent

4 hosts, 3 config patterns. Linux hosts: all config in `hosts/<name>/default.nix`. Darwin: config split across `darwin/default.nix` + `hosts/mact2/default.nix`. Fix: single pattern — every host self-contained.

## Scope

### In Scope
- Move `darwin/default.nix` (~50 lines) into `hosts/mact2/default.nix`
- Remove `../darwin` import from `lib/mkDarwinHost.nix` module list
- `darwin/` becomes pure module library (`darwin/system/*`, `darwin/services/*`, `darwin/home/*`) — same role as `linux/system/`

### Out of Scope
- `darwin/home/` stays as-is (already imported via host entry, fine)
- No file moves inside `darwin/` module tree
- No Linux host pattern changes

## Capabilities

**New Capabilities**: None — pure refactor, no spec-level behavior changes.

**Modified Capabilities**: None — nothing changes at the spec level.

## Approach

1. Append `darwin/default.nix` body into `hosts/mact2/default.nix`
2. Delete `darwin/default.nix`
3. Remove `../darwin` from `mkDarwinHost.nix` module list
4. `format-nix && nix flake check --no-build`

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/mact2/default.nix` | Modified | Absorbs darwin/default.nix config |
| `darwin/default.nix` | Removed | Config merged into hosts/mact2/ |
| `lib/mkDarwinHost.nix` | Modified | Remove `../darwin` from modules |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `nix flake check` or build breaks | Low | Exact copy, no logic change. `format-nix + flake check` catches any issues. |

## Rollback Plan

`git revert` the commit. Change is a single atomic move — revert restores 3-file state.

## Dependencies

None.

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] `hosts/mact2/default.nix` fully self-contained (no split config)
- [ ] `mkDarwinHost.nix` has no `../darwin` import
- [ ] All 4 hosts follow same pattern: config lives in `hosts/<name>/`
