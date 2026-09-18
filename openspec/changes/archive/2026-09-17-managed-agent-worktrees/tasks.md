# Tasks: Managed Agent Worktrees

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 500–700 |
| 400-line budget risk | High |
| Chained PRs recommended | No — direct-to-master workflow selected |
| Suggested split | One direct-to-master implementation sequence: Go lifecycle, capability/runtime wiring, then documentation and full verification |
| Delivery strategy | direct-master |
| Chain strategy | Not applicable |

Decision needed before apply: No — direct-to-master workflow selected
Chained PRs recommended: No
Chain strategy: Not applicable
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Go lifecycle and admission | PR 1 | `go -C pkgs/nixos-scripts test ./...` | Temp Git repositories and fake commands | Go files only |
| 2 | OpenCode capability policy and declarative wiring | PR 2 | Targeted `nix eval` for four hosts | Generated `opencode.json` inspection | Shared OpenCode and shell files |
| 3 | Contract docs and release proof | PR 3 | `nix flake check --no-build` | Installed `opencode --help`/agent launch probe | Docs and command-help changes |

## Phase 1: Research and RED Guards

- [x] 1.1 Verify OpenCode with `opencode --version`, `opencode --help`, and the packaged executable; record exact `--agent`, cwd, and exit behavior before changing `pkgs/nixos-scripts/cmd/code-work/main.go`.
- [x] 1.2 Add RED tests in `pkgs/nixos-scripts/internal/managedworktree/managedworktree_test.go` for IDs, metadata, transitions, portable locks, concurrency, and interrupted-work preservation.
- [x] 1.3 Add RED tests in `pkgs/nixos-scripts/cmd/code-work/main_test.go` for relative/absolute/`git -C` selector mismatch, staged/`commit -a`/empty-index states, allowlist/denials, and unsafe integration.

## Phase 2: Go Code-Work Implementation

- [x] 2.1 Create `pkgs/nixos-scripts/internal/managedworktree/managedworktree.go` with task identity, JSON records, portable mkdir locks, transitions, recovery, and Git helpers.
- [x] 2.2 Extend `pkgs/nixos-scripts/cmd/code-work/main.go` with `managed start|ready|inspect|abandon|cleanup|recover-lock`, active Git locks, matching-base reuse, and the verified OpenCode launch command.
- [x] 2.3 Add `managed check` and `managed integrate` admission, serialized validation/build, explicit activation modes, failure-preserving rollback, and no auto-push/cleanup; make Phase 1 tests pass.

## Phase 3: Capability Policy and Runtime Wiring

- [x] 3.1 Modify `shared/opencode/permissions.nix` and `shared/opencode/local-agent-overlays.json` with the named default-deny managed-writing-task grants/denials, including no external directories, mutation, services, sudo, push, integrate, or cleanup.
- [x] 3.2 Modify `shared/opencode/agents.nix` and `linux/home/shell.nix` to emit the named agent and preserve managed command arguments; verify declarative Home Manager ownership and identical Linux/Darwin policy without new options.
- [x] 3.3 Run Tier 2 evals: `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` (repeat for `thinkcentre` and `t14`), `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`, and each `homeConfigurations.<host>.activationPackage.drvPath`; inspect agent JSON grants/denials.

## Phase 4: Contract, Documentation, and Verification

- [x] 4.1 Document the command contract, lifecycle states, capability levels, human integration/activation gate, recovery, portability limits, and rollback in `docs/managed-agent-worktrees.md`; keep CLI help aligned.
- [x] 4.2 Run Tier 1 `nix fmt -- shared/opencode/agents.nix shared/opencode/permissions.nix linux/home/shell.nix` and `gofmt` on touched Go files; run Tier 2 `go -C pkgs/nixos-scripts test ./...` and `nix build .#nixos-scripts`.
- [x] 4.3 Run Tier 3 `format-nix && nix flake check --no-build`; manually exercise start/check/ready/integrate failure retention in a temporary Git repo and verify the installed OpenCode launch probe again.

## Focused Remediation: Independent Verification Revision 0358998255837ace0b589a1b5d28a78c283c11fb86dfd9574bb97e34b8ce2b29

- [x] 5.1 Make legacy `code-work --prune`, including legacy cleanup callers, acquire the common-directory managed lifecycle lock.
- [x] 5.2 Add committed command-level temporary-repository tests covering unique and conflicting dispatch, serialized lifecycle/prune, failure retention, allowlisted checks, denied mutation without execution, successful ready-task integration, and dirty/non-ready/branch-mismatch rejection.
