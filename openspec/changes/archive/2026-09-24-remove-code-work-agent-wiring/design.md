# Design: Remove Code-Work Agent Wiring

## Technical Approach

Apply the approved minimal deletion to the existing declarative configuration. Delete the single `code-work check` prompt line in `shared/opencode/agents.nix`, the two `code-work` Bash-map entries in `shared/opencode/local-agent-overlays.json`, and the three `wt-*` aliases in `linux/home/shell.nix`. The JSON deletion removes the comma after the final remaining `go -C * test *` entry so the source remains valid.

This implements both delta specs: the retained `managed-writing-task` profile permits editing, branch-local Git, and Go tests, but exposes no repository-provided `code-work` or Nix check command. The shared agent configuration affects rog, thinkcentre, t14, and macm5; the Linux aliases affect rog, thinkcentre, and t14.

## Architecture Decisions

| Option | Tradeoff | Decision |
|---|---|---|
| Delete only the six requested configuration elements | The managed agent intentionally loses fmt, eval, flake-check, and scoped-build access | Chosen: it exactly matches the proposal and specs without inferring a replacement capability. |
| Replace the deleted commands, profile, or aliases | Would expand authority or alter unrelated workflows | Rejected: no new architecture, interface, command, or behavior is required. |
| Remove or alter the wrapper/binary | Would break the existing operator and managed-task launch surfaces | Rejected: retain `managedWritingAgent`, `defaultAgents` injection, `code-work()` wrapper, and `code-work` binary unchanged. |

## Data Flow

No new data flow is introduced. Existing Home Manager evaluation continues to read the JSON overlay and emit the named agent profile:

`local-agent-overlays.json` -> `agents.nix` -> generated `managed-writing-task` profile

The profile no longer contains either Bash allowlist key, while its Git and Go-test keys remain. Linux zsh evaluation omits the three aliases but retains the existing `code-work()` wrapper.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/agents.nix` | Modify | Delete exactly the prompt line instructing `code-work check`; retain the profile and injection. |
| `shared/opencode/local-agent-overlays.json` | Modify | Delete exactly `code-work check *` and `code-work managed check *`; make the remaining final map entry comma-free. |
| `linux/home/shell.nix` | Modify | Delete exactly `wt-done`, `wt-abort`, and `wt-list`; retain `initContent` and `code-work()`. |

## Interfaces / Contracts

No Nix module options, APIs, data structures, commands, or profiles are added or changed. The existing generated profile contract narrows only by the two deleted Bash keys and prompt instruction.

## Testing Strategy

| Proof | Command | Expected result |
|---|---|---|
| JSON syntax and deleted entries | `jq -e '.permissionOverlays.named["managed-writing-task"].bash | ((has("code-work check *") or has("code-work managed check *")) | not)' shared/opencode/local-agent-overlays.json` | Valid JSON; both keys absent. |
| Generated managed-agent profile | `nix eval --json .#homeConfigurations.rog.config.home.opencode.agents.managed-writing-task | jq -e '(.prompt | contains("code-work") | not) and (.permission.bash | has("code-work check *") | not) and (.permission.bash | has("code-work managed check *") | not) and (.permission.bash["git status*"] == "allow") and (.permission.bash["go test *"] == "allow")'` | Prompt and permissions omit `code-work`; retained grants remain. |
| Linux alias deletion and wrapper preservation | `nix eval --json .#homeConfigurations.rog.config.programs.zsh.shellAliases | jq -e '(has("wt-done") or has("wt-abort") or has("wt-list")) | not'` and `nix eval --json .#homeConfigurations.rog.config.programs.zsh.initContent | jq -e 'contains("code-work()")'` | The aliases are absent and the wrapper remains. |

Only direct Nix evaluation and JSON proof are planned; no new test framework, Go test, flake check, build, or runtime command is introduced.

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no file classification or execution changes | None | None |
| Git repository selection | N/A — no Git invocation or cwd selection changes | None | None |
| Commit state | N/A — retained Git permissions are unchanged | None | None |
| Push state | N/A — no push behavior exists or changes | None | None |
| PR commands | N/A — no PR automation exists or changes | None | None |

## Migration / Rollout

No migration required. Deploy the declarative edits normally; rollback is a revert of the three-file deletion.

## Non-Goals

Do not add a replacement permission, check command, profile, alias, documentation update, Go/Nix packaging change, or new architecture. Do not modify the `code-work` wrapper or binary, worktrees, locks, lifecycle behavior, `permissions.nix`, or the managed-agent launch path.

## Open Questions

None.
