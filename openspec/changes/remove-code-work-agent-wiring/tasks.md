# Tasks: Remove Code-Work Agent Wiring

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10 (6 deletions + spec deltas 4) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single direct-to-master change |
| Delivery strategy | Direct-to-master per user; no commit until explicitly authorized |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Six source deletions + artifact updates | Direct-to-master | `nix flake check --no-build` | `nix eval` proofs (Phase 3) | Revert single commit; no lock/worktree/Go state |

## Phase 1: Source Deletions

- [x] 1.1 Delete the `code-work check` prompt sentence in `shared/opencode/agents.nix` (managedWritingAgent prompt, line ~159); retain profile, `permission` key, and `defaultAgents` injection.
- [x] 1.2 Delete `"code-work check *": "allow"` from `shared/opencode/local-agent-overlays.json` (`permissionOverlays.named.managed-writing-task.bash`).
- [x] 1.3 Delete `"code-work managed check *": "allow"` from the same Bash map and drop the trailing comma after `"go -C * test *": "allow"`.
- [x] 1.4 Delete the `wt-done`, `wt-abort`, `wt-list` zsh aliases in `linux/home/shell.nix` (lines ~45-47); retain `initContent` and `code-work()` wrapper.

## Phase 2: SDD Artifact Updates

- [x] 2.1 Confirm both delta specs exist and match implementation: `openspec/changes/remove-code-work-agent-wiring/specs/managed-agent-worktrees/spec.md` and `openspec/changes/remove-code-work-agent-wiring/specs/gentle-ai-declarative-runtime/spec.md` (read-only).
- [x] 2.2 Mark `tasks.md` checklist items complete as each finishes; record verification results.

## Phase 3: Verification

- [x] 3.1 JSON parse: `jq -e '.permissionOverlays.named["managed-writing-task"].bash | ((has("code-work check *") or has("code-work managed check *")) | not)' shared/opencode/local-agent-overlays.json` — exit 0.
- [x] 3.2 Nix eval generated profile: `nix eval --json .#homeConfigurations.rog.config.home.opencode.agents.managed-writing-task | jq -e '(.prompt | contains("code-work") | not) and ((.permission.bash | has("code-work check *")) | not) and (.permission.bash["git status*"] == "allow") and (.permission.bash["go test *"] == "allow")'`.
- [x] 3.3 Nix eval aliases gone, wrapper kept: `nix eval --json .#homeConfigurations.rog.config.programs.zsh.shellAliases | jq -e '(has("wt-done") or has("wt-abort") or has("wt-list")) | not'` AND `nix eval --raw .#homeConfigurations.rog.config.programs.zsh.initContent | grep -c 'code-work()' > 0`.
- [x] 3.4 Grep gates: `code-work` absent from both `shared/opencode` files; `wt-done\|wt-abort\|wt-list` absent from `linux/home/shell.nix`; wrapper still present.
- [x] 3.5 Format touched files: `nix fmt -- shared/opencode/agents.nix linux/home/shell.nix`.
- [ ] 3.6 Full gate: `nix flake check --no-build` passes (proves JSON parse via `builtins.fromJSON`).
- [ ] 3.7 Evaluate host-scoped targets: `nix eval .#homeConfigurations.rog.activationPackage.drvPath` and `.#homeConfigurations.thinkcentre...` and `.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`.
- [ ] 3.8 No Go change ⇒ `go -C pkgs/nixos-scripts test ./...` optional no-op; skip unless §3.6 fails.

## Phase 4: Closeout (No Commit)

- [x] 4.1 Report results to orchestrator/persisted memory. Do NOT commit — direct-to-master work only lands after explicit user authorization.
- [x] 4.2 Leave `simplify-worktree-cli` un-archived until this change archives (ordering dependency).
