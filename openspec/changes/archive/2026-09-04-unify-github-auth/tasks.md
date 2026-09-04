# Tasks: Unify GitHub Auth

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 90-150 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Promote the shared GitHub MCP wrapper and switch platform imports | PR 1 | `nix eval --raw .#darwinConfigurations.mact2.config.system.build.toplevel.drvPath` | `nix eval` for shared-module import parity | `shared/github-mcp-wrapper.nix`, import swaps, old Darwin wrapper |
| 2 | Remove Linux PAT plumbing and dead imports | PR 1 | `nix eval --raw .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` | `nix eval` for rog/t14/thinkcentre configs | PAT service files, shell export block, sops declarations, host imports |
| 3 | Prove the full auth migration is clean and ready to land | PR 1 | `nix flake check --no-build` | `grep` for removed PAT/token-check references across repo | Verification-only; no code changes |

## Phase 1: Shared module foundation

- [x] 1.1 Create `shared/github-mcp-wrapper.nix` by copying `darwin/home/github-mcp-server-wrapper.nix` verbatim, keeping the `glats` and `jcuzmar-Falabella_FTC` account mapping.
- [x] 1.2 Update `darwin/home/shared-modules.nix` to import `../../shared/github-mcp-wrapper.nix` instead of `./github-mcp-server-wrapper.nix`.
- [x] 1.3 Delete `darwin/home/github-mcp-server-wrapper.nix` after the shared module is in place.

## Phase 2: Linux PAT cleanup and wiring

- [x] 2.1 Add `../../shared/github-mcp-wrapper.nix` to `linux/home/shared-modules.nix`.
- [x] 2.2 Remove `linux/system/services/github-mcp-server.nix` and `linux/system/services/github-token-check.nix`.
- [x] 2.3 Remove the GitHub MCP/token-check imports from `hosts/rog/default.nix`, `hosts/thinkcentre/default.nix`, and `hosts/t14/default.nix`.
- [x] 2.4 Remove the `GH_TOKEN` export block from `linux/home/shell.nix`.
- [x] 2.5 Delete only the `github/personal_pat` and `github/work_pat` secret declarations from `linux/system/base/sops.nix`; keep the GPG secrets untouched.
- [x] 2.6 Remove `shared/github-tokens.nix` and its imports (`shared/sops.nix`, `linux/system/base/sops.nix`) — found during verification gate 3.4; declarations survived via this alternate path and violated spec R3. Update stale comment in `darwin/home/sops.nix`.

## Phase 3: Verification gates

- [x] 3.1 Run `format-nix` after the Nix edits and confirm only intended files changed.
- [x] 3.2 Run `nix flake check --no-build` and confirm all four host evaluations still pass.
- [x] 3.3 Run `nix eval --raw .#nixosConfigurations.{rog,t14,thinkcentre}.config.system.build.toplevel.drvPath` and `nix eval --raw .#darwinConfigurations.mact2.config.system.build.toplevel.drvPath`.
- [x] 3.4 Grep the repo to prove no remaining `github/personal_pat`, `github/work_pat`, or `github-token-check` references exist outside `openspec/`.

## Phase 4: Commit

- [x] 4.1 Review the final diff and commit the unified auth cleanup as one work-unit style commit.

## Phase 5: Post-apply (manual, user-driven)

- [ ] 5.1 On each Linux host, verify the required `gh auth login --hostname github.com` accounts exist before switching.
- [ ] 5.2 Let the user handle host deploys/logins separately; do not add deploy or login steps to apply-phase implementation work.
