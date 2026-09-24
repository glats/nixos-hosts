# Tasks: Simplify Worktree CLI

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250–350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single direct-to-master commit (mandatory atomic wiring) |
| Delivery strategy | exception-ok |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | CLI verbs, cwd resolution, shim, wiring, docs (one atomic master commit) | Direct to master | `go -C pkgs/nixos-scripts test ./...` | Temp Git repo + fake `nix`/`opencode`; flake evals per matrix | Revert the single commit; shim keeps old invocations working |

Single commit required: allowlist + prompt + wrapper + CLI must ship atomically (proposal risk 1).

## Phase 1: RED tests (resolver + command surface)

- [x] 1.1 Add `ResolveTaskID(stateDir, cwd)` table tests in `pkgs/nixos-scripts/internal/managedworktree/managedworktree_test.go`: exact match resolves; main checkout cwd → not match; legacy worktree named `managed`/`managed-demo` cwd → not match (path equality, never prefix); relative vs absolute mismatch → not match; malformed record → error (fail, never guess).
- [x] 1.2 Add command tests in `pkgs/nixos-scripts/cmd/code-work/main_test.go`: `check`/`ready`/`status` from main checkout or legacy worktree error "not inside a managed worktree", mutate no state, non-zero exit.
- [x] 1.3 Add shim tests: `code-work managed start demo` forwards to `new`, prints one stderr deprecation hint, exits with canonical code; `--help` output contains no `managed` entry; old forms `managed check/ready/inspect/integrate/cleanup` map to their canonical handlers preserving exit codes.
- [x] 1.4 Add admission tests for ready/merge clean gates: dirty staged change, `git commit -a`, empty index → denial before execution (threat: Commit state).

## Phase 2: Core implementation

- [x] 2.1 Implement `ResolveTaskID(root, cwd string)` in `pkgs/nixos-scripts/internal/managedworktree/managedworktree.go`: iterate valid records, return id where `Clean(record.Path) == Clean(cwd)`; no match → "not inside a managed worktree" error.
- [x] 2.2 Rename verbs in `pkgs/nixos-scripts/cmd/code-work/managed.go`: `start→new`, `integrate→merge`, `cleanup→clean`, `inspect→status`; `check <check> [target]`, `ready`, `status` infer ID via `ResolveTaskID`; keep `check` four allowlisted forms, option denial, capped builds; keep locks, state machine, integration/activation gates.
- [x] 2.3 Dispatch and help: wire top-level verbs in `pkgs/nixos-scripts/cmd/code-work/main.go` `usageTemplate`; hidden `managed` adapter prints stderr hint, stays out of `--help`, deletes next release.
- [x] 2.4 Shell wrapper: `linux/home/shell.nix` — route canonical verbs past legacy `*)` branch so `code-work new demo` never creates a legacy worktree named `new`.

## Phase 3: Wiring + declarative verification

- [x] 3.1 Allowlist: `shared/opencode/local-agent-overlays.json` — add `"code-work check *"` and keep existing managed form permissions for the shim window.
- [x] 3.2 Prompt: `shared/opencode/agents.nix` — reference canonical `code-work check` / top-level verbs.
- [x] 3.3 Docs: `docs/managed-agent-worktrees.md` — new verb table, cwd resolution rule, migration note.
- [x] 3.4 Unit verification: `go -C pkgs/nixos-scripts test ./...` all green including original lock/state-machine tests unchanged.
- [x] 3.5 Build: `go -C pkgs/nixos-scripts build ./cmd/code-work` clean.
- [x] 3.6 Format touched files: `nix fmt -- pkgs/nixos-scripts/cmd/code-work/main.go pkgs/nixos-scripts/cmd/code-work/managed.go pkgs/nixos-scripts/internal/managedworktree/managedworktree.go pkgs/nixos-scripts/cmd/code-work/main_test.go pkgs/nixos-scripts/internal/managedworktree/managedworktree_test.go shared/opencode/agents.nix linux/home/shell.nix` (Go files via gofmt/lint per repo convention).

## Phase 4: Flake verification + delivery

- [x] 4.1 eval `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` (allowlist/prompt/wrapper eval).
- [x] 4.2 eval `nix eval .#homeConfigurations.rog.activationPackage.drvPath` (agents.nix HM wiring).
- [ ] 4.3 eval `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` (Darwin Home Manager wiring).
- [ ] 4.4 `nix flake check --no-build`.
- [ ] 4.5 Commit all files atomically direct to master in one commit (CLI + tests + allowlist + prompt + wrapper + docs); no PR chain.
