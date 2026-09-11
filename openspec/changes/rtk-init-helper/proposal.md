# Proposal: RTK Instruction Block Helper

## Intent

Replace the manual RTK guidance in `AGENTS.md` with a versioned, idempotently managed contract that preserves this repository's automatic, fail-open OpenCode rewriting rules without upstream `rtk init` output.

## Scope

### In Scope

- Add a Go `rtk-init` CLI supporting upsert, `--check`, `--remove`, `--dry-run`, and an optional target path.
- Add tested `internal/rtkinit` logic for marker validation, status, removal, checks, and atomic writes.
- Store the RTK contract in Go behind distinct versioned markers and migrate `AGENTS.md`.
- Package the binary through `nixos-scripts` for rog, thinkcentre, t14, and mact2.

### Out of Scope

- Changes to RTK, hooks, the OpenCode plugin, or other repositories.
- `CLAUDE.md`, separate `RTK.md`, hook patching, or interoperability with upstream RTK markers.

## Capabilities

### New Capabilities

- `rtk-instruction-management`: Manage, inspect, preview, and remove the repository-specific RTK contract.

### Modified Capabilities

None.

## Approach

Implement upstream-style block upsert semantics using `<!-- rtk-init-managed v1 -->` and `<!-- /rtk-init-managed -->`, isolated from upstream markers. Refuse malformed states; otherwise report Added, Updated, Unchanged, Missing, or Stale. Resolve default `AGENTS.md` through `internal/reporoot`, keep the command thin, write atomically, and run it once to migrate the manual section.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `pkgs/nixos-scripts/internal/rtkinit/` | New | Block logic and table-driven tests |
| `pkgs/nixos-scripts/cmd/rtk-init/main.go` | New | Thin CLI entry point |
| `pkgs/nixos-scripts/default.nix` | Modified | Build and expose `rtk-init` on all four hosts |
| `AGENTS.md` | Modified | Replace hand-written RTK section with managed v1 block |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Malformed markers cause unintended edits | Low | Refuse writes and test unmatched/duplicate marker cases |
| Atomic replacement alters unrelated data | Low | Preserve surrounding bytes and file mode; test no-op behavior |
| Contract drifts from deployed RTK behavior | Medium | Version the canonical block and make `--check` identify stale content |

## Rollback Plan

Revert the single change to remove the binary/package wiring and restore the prior hand-written `AGENTS.md` section. Before a code revert, `rtk-init --remove` can remove only the managed block.

## Dependencies

- Existing Go standard library and `internal/reporoot`; no new external dependency.

## Success Criteria

- [ ] Upsert, check, remove, dry-run, malformed refusal, and atomic-write behavior pass `go -C pkgs/nixos-scripts test ./...`.
- [ ] Repeated upsert is byte-stable; `--check` exits 0 only for the current block and 1 for missing or stale content.
- [ ] `AGENTS.md` contains exactly one managed v1 block and still forbids upstream `rtk init`.
- [ ] `format-nix` and `nix flake check --no-build` pass.
- [ ] Authored changes remain within the 400-line single-PR review budget.
