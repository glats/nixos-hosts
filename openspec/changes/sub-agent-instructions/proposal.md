# Proposal: Sub-agent Instructions

## Intent

SDD sub-agents (sdd-explore, sdd-propose, sdd-spec, etc.) do not receive universal rules (Language Policy, Research First, Engram Protocol) or SDD review policy because gentle-ai does not propagate OpenCode's global `instructions` field to sub-agents. This change creates an instruction overlay mechanism that prepends `{file:./<doc>.md}` references to sub-agent and orchestrator prompts, parallel to the existing `toolOverlays`/`permissionOverlays` pattern in `agents.nix`. It also syncs the local `sdd-orchestrator.md` with the fork's Review Lens Selection feature.

## Scope

- **In**: Instruction overlay logic in `agents.nix`, new `instructionOverlays` key in `local-agent-overlays.json`, two new instruction files (`universal.md`, `orchestrator.md`), deployment in `shared/opencode.nix`, `sdd-orchestrator.md` sync.
- **Out**: Removing `SYSTEM_RULES.md` or `sdd-review-policy.md` (keep as-is), changing gentle-ai fork, changing flake inputs.

## Capabilities

1. **Universal instruction overlay**: Every SDD sub-agent receives universal rules (Language Policy, No Emojis, Research First, Verify Before Done, Secret Handling, Delegation Rules, Skills auto-load, Engram Protocol) via `{file:./universal.md}` prepended to its prompt.
2. **Orchestrator instruction overlay**: The `gentle-orchestrator` receives SDD review policy (review gates, iteration protocol, re-explore protocol, guard lines) via `{file:./orchestrator.md}` prepended to its prompt.
3. **Review Lens Selection sync**: Local `sdd-orchestrator.md` matches the fork version, adding the Review Lens Selection table and updating Rules 3/4/6 wording.

## Approach

### Instruction overlay mechanism

Add `instructionOverlays` top-level key to `local-agent-overlays.json`:

```json
"instructionOverlays": {
  "subagent": ["universal.md"],
  "gentle-orchestrator": ["orchestrator.md"]
}
```

In `agents.nix` `overlayAgent`, add instruction overlay processing parallel to the existing `localTools`/`localPermission` pattern. On match, prepend `{file:./filename}` references to the agent's `prompt` field. The matching logic: if agent is `gentle-orchestrator`, apply `instructionOverlays.gentle-orchestrator`; if agent mode is `subagent`, apply `instructionOverlays.subagent`.

### New instruction files

1. **`shared/opencode/universal.md`** — Full `SYSTEM_RULES.md` content (236 lines). Deployed via `home.file` to `~/.config/opencode/universal.md`.
2. **`shared/opencode/orchestrator.md`** — Full `sdd-review-policy.md` content (114 lines). Deployed via `home.file` to `~/.config/opencode/orchestrator.md`.

### Deployment

Add two `home.file` entries in `shared/opencode.nix` (under `mkRuntimeConfig`) for both new files, parallel to existing `SYSTEM_RULES.md` and `sdd-review-policy.md` entries. Add `universal.md` and `orchestrator.md` to the activation script's file list (line 150) so they are converted from Nix store symlinks to writable real copies.

### sdd-orchestrator.md sync

Update `shared/opencode/assets/opencode/sdd-orchestrator.md` to match the fork version:
- Insert Review Lens Selection table between Mandatory Delegation Triggers and Cost/Balance sections
- Update Rules 3, 4, 6 to reference "concrete review lens(es) selected by Review Lens Selection"
- Update Cost/Balance section to reference "concrete review lenses" instead of "fresh reviewers"

## Affected Areas

| Area | Impact |
|------|--------|
| `shared/opencode/local-agent-overlays.json` | New `instructionOverlays` key |
| `shared/opencode/agents.nix` | Instruction overlay processing in `overlayAgent` (~15 lines) |
| `shared/opencode.nix` | 2 `home.file` entries + activation script update (~12 lines) |
| `shared/opencode/instructions/universal.md` | New file, ~236 lines |
| `shared/opencode/instructions/orchestrator.md` | New file, ~114 lines |
| `shared/opencode/assets/opencode/sdd-orchestrator.md` | Sync with fork (~30 lines added/updated) |
| All SDD sub-agents | Receive universal rules (behavior improvement) |
| `gentle-orchestrator` | Receives orchestrator instructions |

## Risks

1. **Prompt size increase**: 236 lines added to sub-agent prompts. Mitigation: content replaces guesswork/errors that cost more tokens to fix; sub-agents are launched ad-hoc so no persistent inflation.
2. **universal.md drift from SYSTEM_RULES.md**: Both contain identical content; edits to one require updates to the other. Mitigation: document this coupling in both files.
3. **sdd-orchestrator.md future drift**: The fork may receive further updates. Mitigation: this is a maintenance concern, not a blocker for this change.
4. **Activation script omission**: If new files aren't added to the activation script file list, they remain as broken Nix store symlinks. Mitigation: must add `universal.md` and `orchestrator.md` to line 150's `for` loop.

## Rollback Plan

Revert the commit. All changes are additive — removing the `instructionOverlays` key restores previous behavior. Removing the two `home.file` entries and activation script entries restores previous deployment. The `sdd-orchestrator.md` sync is a content-only change in a single file — reverting it restores the pre-sync content. No migration or cleanup needed.

## Dependencies

- Requires `gentle-ai-assets` package (already in flake inputs) — no input changes
- `sdd-orchestrator.md` sync requires reading the fork version at `glats/gentle-ai/main`
- No new Nix packages or flake inputs needed

## Success Criteria

1. `local-agent-overlays.json` has valid `instructionOverlays.subagent` and `instructionOverlays.gentle-orchestrator` keys
2. `agents.nix` `overlayAgent` prepends instruction references to matching agent prompts
3. `universal.md` and `orchestrator.md` exist at correct paths and are deployed to `~/.config/opencode/`
4. Activation script copies both files from symlink to writable real copy
5. `sdd-orchestrator.md` contains Review Lens Selection table and updated review rules wording
6. `nix flake check --no-build` passes with zero errors
