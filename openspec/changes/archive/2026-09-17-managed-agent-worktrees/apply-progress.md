# Apply Progress: managed-agent-worktrees

**Artifact mode:** hybrid (OpenSpec file plus Engram)
**Apply state:** focused remediation complete; independent `sdd-verify` remains next
**Delivery:** direct-master with the explicitly approved `size:exception`
**Testing mode:** Standard; `strict_tdd: false`
**Failed evidence revision remediated:** `sha256:0358998255837ace0b589a1b5d28a78c283c11fb86dfd9574bb97e34b8ce2b29`

## Completed Tasks

- [x] 1.1 Verified installed and packaged OpenCode 1.18.22. Both `--help` outputs expose `--agent`; the CLI accepts a positional project directory. A managed launch was exercised from a temporary repository with `opencode --agent managed-writing-task <worktree>` and was terminated by the harness timeout, leaving the active record and lock for explicit recovery.
- [x] 1.2 Added ID, metadata, transition, portable mkdir-lock, concurrency, persistence, and interrupted-state tests.
- [x] 1.3 Added selector, commit-state, allowlist, denial, and unsafe-integration admission tests.
- [x] 2.1 Added `internal/managedworktree` with validated task identity, atomic JSON persistence, lifecycle transitions, and repository-portable locks.
- [x] 2.2 Added managed start/ready/inspect/abandon/cleanup/recover-lock commands, matching-base reuse, active `git worktree lock`, and the verified OpenCode launch form.
- [x] 2.3 Added allowlisted checks and a serialized human integration gate with non-activating validation, explicit activation modes, merge rollback, and preserved failed-task work.
- [x] 3.1 Added the default-deny `managed-writing-task` permission overlay and global mutation-family denials, including external-directory, service, sudo, push, integration, cleanup, and generation protections.
- [x] 3.2 Added the named declarative agent and preserved all managed arguments in the Linux shell wrapper; no new Nix option was introduced.
- [x] 3.3 Linux host and standalone Home Manager evaluations passed where runnable; the generated t14 agent permission shape was inspected and contained default-deny Bash plus only the intended local grants.
- [x] 4.1 Added the command/lifecycle/capability/integration/recovery/portability/rollback runbook and aligned CLI help.
- [x] 4.2 Formatted touched Nix and Go files; Go tests and the `nixos-scripts` derivation passed.
- [x] 4.3 The full main-checkout format and flake gate passed. A temporary Git repository exercised start, explicit lock recovery, ready, failed integration, and failure retention.
- [x] 5.1 Legacy `code-work --prune` and legacy `--done`/`--abort` prune calls now acquire the portable managed lifecycle lock from the Git common directory.
- [x] 5.2 Added committed command-level temporary-repository tests for all deficiencies identified by independent verification, using only test-generated temporary repositories and command stubs.

## Work Unit Evidence

| Unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| Go lifecycle and admission | `go -C pkgs/nixos-scripts test ./...` — PASS; all packages passed, including `cmd/code-work` and `internal/managedworktree`. | Temporary Git repository: managed start created `managed/task-1` and `.worktrees/managed/task-1`; timeout left state `active`; `recover-lock`, `ready`, and failed `integrate --validate check` left state `ready-for-integration` and preserved the worktree. | `pkgs/nixos-scripts/cmd/code-work/main.go`, `main_test.go`, `managed.go`, and `internal/managedworktree/*`.
| OpenCode policy and declarative wiring | `nix eval --json .#homeConfigurations.t14.config.home.opencode.agents.managed-writing-task.permission` — PASS; default-deny Bash and external directory, scoped grants only. | Installed and packaged `opencode --version` — `1.18.22`; both help probes expose `--agent`; launch form was exercised in the temporary repository. | `shared/opencode/permissions.nix`, `shared/opencode/local-agent-overlays.json`, `shared/opencode/agents.nix`, `linux/home/shell.nix`.
| Contract and release proof | `format-nix && nix flake check --no-build` — PASS; `all checks passed!`; `nix build .#nixos-scripts --no-link` — PASS. | Temporary repository failure-retention scenario above; no host activation was run. | `docs/managed-agent-worktrees.md` and the CLI help text.
| Focused remediation | `go -C pkgs/nixos-scripts test -count=1 ./...` — PASS; all Go packages passed, including command-level temporary-repository tests. `nix build .#nixos-scripts --no-link` — PASS after adding the test-required Git build input. | Committed tests execute real `code-work` dispatch in temporary Git repositories: unique/conflicting start, allowlisted/denied check, lock contention, ready integration, failed validation retention, and dirty/non-ready/branch-mismatch rejection. | `pkgs/nixos-scripts/cmd/code-work/main.go`, `main_test.go`, `pkgs/nixos-scripts/default.nix`, and this remediation artifact.

## Verification Evidence

Passed:

- `opencode --version` and `opencode --help`; packaged `/nix/store/...-opencode-1.18.22/bin/opencode --version` and help.
- `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath`.
- `nix eval .#nixosConfigurations.thinkcentre.config.system.build.toplevel.drvPath`.
- `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath`.
- `nix eval .#homeConfigurations.rog.activationPackage.drvPath`.
- `nix eval .#homeConfigurations.thinkcentre.activationPackage.drvPath`.
- `nix eval .#homeConfigurations.t14.activationPackage.drvPath`.
- `nix eval --json .#homeConfigurations.t14.config.home.opencode.agents.managed-writing-task.permission`.
- `go -C pkgs/nixos-scripts test ./...`.
- `nix build .#nixos-scripts --no-link`.
- `format-nix && nix flake check --no-build`.

Blocked or partial external checks:

- `nix eval .#homeConfigurations.macm5.activationPackage.drvPath` and the macm5 Darwin toplevel are blocked by the pre-existing `undefined variable 'awk'` at `darwin/home/packages.nix:77`.
- The full t14 activation-package build was started but exceeded the six-minute harness timeout while building unrelated host packages; the direct configuration eval and agent JSON eval passed.
- No OS sandboxing, credential/network/port isolation, daemon concurrency change, push, commit, activation, or cleanup was performed.

## Deviations

The implementation adds `managed.go` alongside `main.go` to keep the legacy command readable while retaining one `code-work` binary. The integration `--validate build` path uses the repository's existing non-activating `nixos-build build` wrapper. These are compatible with the design and do not add Nix options or new runtime containment.
