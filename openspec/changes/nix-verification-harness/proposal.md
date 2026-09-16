# Proposal: Nix Verification Harness

## Intent

Replace the archived formatter, remove redundant host checks, and clarify verification coverage while preserving nixos-26.05 compatibility and worktree safety.

## Scope

### In Scope

- Set all three flake formatters to RFC-166 `pkgs.nixfmt-tree`.
- Reformat all `.nix` files in one format-only commit and record that commit in `.git-blame-ignore-revs`.
- Remove rog, thinkcentre, and t14 toplevels from `checks.x86_64-linux`; add a cheap format check only if 26.05 supports deterministic fail-on-change behavior.
- Keep `format-nix` as the `/etc/nixos` check/messaging front-end, collapsing its per-file loop where parity permits.
- Update `AGENTS.md` and `openspec/config.yaml` with formatter, coverage, and worktree-safe command guidance.

### Out of Scope

- Defer treefmt-nix (Nix-only overkill), deadnix (noisy/unsafe auto-fix), git-hooks.nix (agent-flow mismatch), and nix-eval-jobs/hydraJobs (no build matrix).
- Reject statix (false positives/second parser), flake-checker (conflicts with the 26.05 pin), and GitHub Actions CI (local builds and unsuitable Darwin runners).

## Capabilities

### New Capabilities

- `nix-verification-harness`: Tree-safe formatting, non-redundant checks, and explicit coverage boundaries.

### Modified Capabilities

- None.

## Approach

Wire `nixfmt-tree`, then simplify checks/tooling. In this worktree, never run `format-nix`; run bare `nix fmt` and eval/check commands from the worktree cwd. Isolate formatter output in one commit, then record it separately in blame-ignore. Preserve all three tiers and document that tier 3 excludes Darwin and standalone Home Manager outputs.

## Affected Areas

| Area | Impact |
|---|---|
| `flake.nix` | Formatter and checks simplified |
| `**/*.nix` | RFC-166 format-only rewrite |
| `pkgs/nixos-scripts/cmd/format-nix/` | Front-end retained and streamlined |
| `AGENTS.md`, `openspec/config.yaml` | Policy and worktree commands corrected |
| `.git-blame-ignore-revs` | Format commit recorded |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Format diff obscures history | High | Isolated commit plus blame-ignore entry |
| Coverage is overestimated | Medium | Document Darwin/HM exclusions and targeted evals |
| Worktree formats main checkout | Medium | Prohibit `format-nix`; use cwd-scoped `nix fmt` |

## Rollback Plan

Revert the blame-ignore, format-only, and harness commits independently; host definitions remain unchanged.

## Dependencies

- `pkgs.nixfmt-tree` and `pkgs.nixfmt` from pinned nixos-26.05.

## Success Criteria

- [ ] Bare `nix fmt` stays in the worktree; its isolated commit has no semantic changes.
- [ ] `nix flake check --no-build` evaluates each NixOS configuration without duplicate custom toplevel checks.
- [ ] Targeted evals pass for rog, thinkcentre, t14, mact2, macm5, and standalone Home Manager configurations.
- [ ] `format-nix --check` retains its main-checkout contract, and docs state its worktree prohibition and tier-3 coverage limits.
