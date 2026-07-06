# Exploration: Complete Instruction Migration

## Current State

### What was done in the previous change ("sub-agent-instructions")

The previous SDD change (archived at `openspec/changes/archive/2026-07-01-sub-agent-instructions/`, commit `eea5527`) implemented:

1. **Created** `shared/opencode/instructions/universal.md` — byte-identical copy of `SYSTEM_RULES.md` (236 lines)
2. **Created** `shared/opencode/instructions/orchestrator.md` — byte-identical copy of `sdd-review-policy.md` (114 lines)
3. **Added** `instructionOverlays` mechanism in `agents.nix` — all SDD sub-agents and the orchestrator receive instructions via `builtins.readFile ./instructions/universal.md` and `builtins.readFile ./instructions/orchestrator.md`
4. **Deployed** both files via `home.file` in `opencode.nix` plus activation script entries
5. **Updated** global `instructions` array in `opencode.json` to `["instructions/universal.md", "instructions/orchestrator.md"]`
6. **Synced** `sdd-orchestrator.md` with fork (Review Lens Selection)

### What was left behind (by explicit design in the previous proposal)

The previous proposal's "Out of scope" section stated: *"Removing `SYSTEM_RULES.md` or `sdd-review-policy.md` (keep as-is)"*.

### Current file status

| File | Deployed? | Referenced by agents? | Still exists in repo? |
|------|-----------|----------------------|----------------------|
| `shared/opencode/instructions/universal.md` | Yes | Yes (all sub-agents + neutral + orchestrator) | Yes |
| `shared/opencode/instructions/orchestrator.md` | Yes | Yes (orchestrator only) | Yes |
| `shared/opencode/SYSTEM_RULES.md` | No | No (zero agents) | Yes — orphan |
| `shared/opencode/sdd-review-policy.md` | No | No (zero agents) | Yes — orphan |
| `shared/opencode/IDENTITY.md` | Yes | Yes (neutral agent) | Yes |

### Agent instruction delivery — verified correct

All agents now receive instructions via `builtins.readFile` (build-time resolution), NOT `{file:./}` (runtime OpenCode file resolution):

- **Neutral agent** (`agents.nix` line 130): `builtins.readFile ./IDENTITY.md + "\n\n" + builtins.readFile ./instructions/universal.md`
- **SDD sub-agents** (`agents.nix` `overlayAgent` lines 110-111): `builtins.readFile ./${f}` where `f` comes from `instructionOverlays.subagent: ["instructions/universal.md"]`
- **gentle-orchestrator** (`agents.nix` `overlayAgent` lines 110-111): same mechanism, from `instructionOverlays.gentle-orchestrator: ["instructions/universal.md", "instructions/orchestrator.md"]`
- **Global instructions** (`opencode.nix` lines 72-75): `["instructions/universal.md", "instructions/orchestrator.md"]` — applies to parent agent runtime

Zero references to `{file:./}` remain in any `.nix` or `.json` files. Zero references to `SYSTEM_RULES.md` or `sdd-review-policy.md` remain in `opencode.nix`, `agents.nix`, or `local-agent-overlays.json`.

### File identity confirmation

- `shared/opencode/SYSTEM_RULES.md` and `shared/opencode/instructions/universal.md` are **byte-identical** (`diff` returns empty)
- `shared/opencode/sdd-review-policy.md` and `shared/opencode/instructions/orchestrator.md` are **byte-identical** (`diff` returns empty)

## Changes Required (with justification)

### 1. Delete `shared/opencode/SYSTEM_RULES.md`

**Justification**: Zero agents reference this file. It is not deployed. All content is served from `instructions/universal.md` (byte-identical copy). Keeping it creates confusion and drift risk — a developer might edit `SYSTEM_RULES.md` expecting changes to propagate, but they won't reach any agent.

### 2. Delete `shared/opencode/sdd-review-policy.md`

**Justification**: Same reasoning. Zero agents reference it. It is not deployed. All content is served from `instructions/orchestrator.md` (byte-identical copy).

### 3. Update `bin/sync-opencode-remote`

**Justification**: This rsync script includes `--include='SYSTEM_RULES.md'` (line 161) and `--include='sdd-review-policy.md'` (line 164) in its whitelist. Since these files will no longer exist at `~/.config/opencode/`, these includes are dead entries. The `instructions/` directory is already covered by `--include='instructions/'` + `--include='instructions/**'` (lines 169-170), so `instructions/universal.md` and `instructions/orchestrator.md` are already synced.

**Action**: Remove the two dead include lines.

### Files that stay unchanged

| File | Why unchanged |
|------|--------------|
| `shared/opencode/agents.nix` | Already uses `builtins.readFile` correctly for all paths |
| `shared/opencode/local-agent-overlays.json` | Already points to `instructions/universal.md` and `instructions/orchestrator.md` |
| `shared/opencode.nix` | Already uses new paths for deployment, activation, and global instructions |
| `shared/opencode/IDENTITY.md` | Still used by neutral agent (`builtins.readFile ./IDENTITY.md`) |
| `shared/opencode/instructions/universal.md` | The new source of truth for universal rules |
| `shared/opencode/instructions/orchestrator.md` | The new source of truth for orchestrator policy |
| `shared/opencode/plugins.nix` | Comment referencing SYSTEM_RULES.md by name is descriptive text, not functional |
| `openspec/specs/review-gates/spec.md` | References `sdd-review-policy.md` in a scenario description. Out of scope for this change — the spec tests orchestrator behavior, not file paths. |

## Affected Files

| File | Change | Type |
|------|--------|------|
| `shared/opencode/SYSTEM_RULES.md` | Delete | Remove orphan |
| `shared/opencode/sdd-review-policy.md` | Delete | Remove orphan |
| `bin/sync-opencode-remote` | Remove lines 161 and 164 (`--include='SYSTEM_RULES.md'` and `--include='sdd-review-policy.md'`) | Cleanup |

## Risks

1. **Other open changes reference these files**: The in-progress change `pasar-opencode-remoto` references `sdd-review-policy.md` in its design/proposal/spec artifacts. When it eventually gets applied, it might look for files that no longer exist. Mitigation: these are design artifacts, not functional code — they describe a desired state that includes these files. Since the files will no longer be deployed, the change's design may need update when it's time to apply it. This is not a regression — it's a natural consequence of superseding an earlier design.

2. **History confusion**: Someone looking at git history might wonder where `SYSTEM_RULES.md` went. Mitigation: the commit message and this exploration document explain the migration clearly.

3. **`nix flake check` might complain**: If any Nix expression references `./SYSTEM_RULES.md` or `./sdd-review-policy.md` via `builtins.readFile`, the flake check will fail at evaluation time. Verified: no such references exist in active code.

## Design Decision: Why not keep SYSTEM_RULES.md/sdd-review-policy.md?

The previous SDD change was explicitly scoped to keep these files as-is. This was the correct decision at the time — the change was already large (~415 lines) and keeping the legacy files minimized risk.

Now that the instruction overlay mechanism has been verified working (8/8 tasks complete, 6/6 success criteria met, deployed and running), the legacy files have no remaining purpose:

- **No agent reads them**: All instruction delivery is via `builtins.readFile` → `instructions/universal.md` / `instructions/orchestrator.md`
- **No code references them**: `opencode.nix`, `agents.nix`, `local-agent-overlays.json` all use new paths
- **They are byte-identical duplicates**: Deleting them eliminates the only copy of the data — the new files are the exact same content
- **Drift hazard**: Two copies of the same content inevitably diverge

The only reason to keep them would be backward compatibility for external tools or workflows. The only external reference is `bin/sync-opencode-remote`, which we update as part of this change.

## Ready for Proposal

Yes. The scope is minimal (3 files, ~6 lines changed). The verification is straightforward. The risk is near-zero since no functional code references the deleted files.

The change supersedes the "keep SYSTEM_RULES.md as-is" boundary of the previous SDD change, which was always intended to be temporary.
