# Exploration: Sub-agent Instructions

## Current State

### The Gap

SDD sub-agents (sdd-explore, sdd-propose, sdd-spec, etc.) do NOT receive `SYSTEM_RULES.md` or `sdd-review-policy.md` because:

1. **gentle-ai does NOT use OpenCode's global `instructions` field** for sub-agents. The `instructions: ["SYSTEM_RULES.md", "sdd-review-policy.md"]` in `opencode.json` (built at `shared/opencode.nix:72-75`) only applies to the parent agent (neutral agent).

2. **Sub-agents get minimal inline prompts** from `sdd-overlay-single.json` (upstream, shipped with gentle-ai). The local overlays in `local-agent-overlays.json` have `toolOverlays` and `permissionOverlays` but **no `instructionOverlays`** mechanism exists yet.

3. **Consequence**: sub-agents lack:
   - Language Policy (ENGLISH ONLY) — risk of mixed-language output
   - No Emojis Policy — risk of emoji pollution
   - Research First / MCP tools directive — sub-agents may guess instead of verifying
   - Secret Handling rules — security risk
   - Delegation Rules — missed delegation opportunities in sub-agents
   - Engram Protocol — memory saves may be missed or malformed

### The Drift

The local override at `shared/opencode/assets/opencode/sdd-orchestrator.md` (393 lines) is BEHIND the fork version at `glats/gentle-ai/main`. The fork introduced a **Review Lens Selection** feature that the local override does NOT have. Specific diffs:

| Rule | Local (current) | Fork (target) |
|------|----------------|---------------|
| Rule 3 (PR rule) | "run a fresh-context review" | "run the concrete review lens(es) selected by Review Lens Selection" |
| Rule 4 (Incident rule) | "stop and run a fresh audit before continuing" | "stop and run the concrete audit/review lens(es) selected by Review Lens Selection" |
| Rule 6 (Fresh review) | "use fresh context for adversarial review" | "use fresh context with the selected concrete review lens(es) for adversarial review" |
| Cost/Balance section | "Use fresh reviewers" | "Use concrete review lenses" |

The fork adds an entire **Review Lens Selection** table (not present in local override):

| Risk signal | Review lens |
|-------------|-------------|
| Clear naming, structure, maintainability | `review-readability` |
| Behavior, state, tests, determinism, regressions | `review-reliability` |
| Shell/process integration, partial failures, recovery | `review-resilience` |
| Security, permissions, data exposure/loss, architecture | `review-risk` |
| Large PR, hot path, >400 changed lines | full 4R: all four lenses |

This table sits between Mandatory Delegation Triggers and Cost and Context Balance.

The local override file at `shared/opencode/assets/opencode/sdd-orchestrator.md` is deployed at line 104-107 of `shared/opencode.nix`:
```nix
".config/${runtimeCfg.dir}/sdd-orchestrator.md" = {
  force = true;
  source = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-orchestrator.md";
};
```

The source is `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-orchestrator.md` — this is the **local override** package. The local file at `shared/opencode/assets/opencode/sdd-orchestrator.md` gets built into that package. The fork version at `glats/gentle-ai/main/internal/assets/opencode/sdd-orchestrator.md` is the upstream source that needs to be merged into the local override.

## Content Split Plan

### Analysis of SYSTEM_RULES.md (236 lines)

Every section in SYSTEM_RULES.md applies to ALL agents — there is no orchestrator-specific content in it. Sub-agents need all of it:

| Section | Lines | Universal? | Reason |
|---------|-------|------------|--------|
| Code Language Policy (ENGLISH ONLY) | 3-23 | Yes | All agents write code |
| No Emojis Policy | 25-37 | Yes | All agents produce output |
| Plan Before Act | 41-44 | Yes | Performance optimization for all |
| Respond to User | 46-55 | Yes | All agents interact with user |
| Research First (MCP tools) | 57-65 | Yes | Critical for all agents |
| Verify Before Done | 67-77 | Yes | All agents should validate |
| When Blocked (Escalation) | 78-85 | Yes | All agents hit blockers |
| Secret Handling | 86-94 | Yes | Security-critical for all |
| Delegation Rules | 95-123 | Yes | Sub-agents should also delegate |
| Skills auto-load | 124-137 | Yes | Sub-agents need skill triggers |
| Engram Protocol | 139-236 | Yes | Memory persistence for all |

**Decision**: Create `universal.md` containing the full SYSTEM_RULES.md content. All SDD sub-agents and the neutral agent should receive it.

### Analysis of sdd-review-policy.md (114 lines)

This is orchestrator-only. It covers: SDD workflow diagram, review checkpoints, iteration protocol (full-iteration vs proceed), re-explore protocol, guard lines, verify gate, proceed escape hatch, artifact expectations, and orchestrator expectations. Sub-agents should NOT receive this — it would confuse them with orchestrator-level responsibilities.

**Decision**: Create `orchestrator.md` containing sdd-review-policy.md content. Only gentle-orchestrator receives it.

### Content Split Summary

| Source | Extracted to | Target agents |
|--------|-------------|---------------|
| SYSTEM_RULES.md (full) | `universal.md` | ALL agents (neutral + all SDD sub-agents) |
| sdd-review-policy.md (full) | `orchestrator.md` | gentle-orchestrator only |

### Existing Instruction Delivery (unchanged)

- **neutral agent**: receives SYSTEM_RULES.md via its prompt template in `local-agent-overlays.json`:
  ```json
  "prompt": "{file:./IDENTITY.md}\n\n{file:./SYSTEM_RULES.md}"
  ```
  This still works — neutral agent gets SYSTEM_RULES.md through its prompt. After this change, SYSTEM_RULES.md and universal.md will be identical, so neutral agent already gets the content.

- **global instructions**: `opencode.json` still contains `instructions: ["SYSTEM_RULES.md", "sdd-review-policy.md"]` for the parent agent runtime.

## Files to Create

| File | Content | Size |
|------|---------|------|
| `shared/opencode/universal.md` | Full SYSTEM_RULES.md content (236 lines) — all universal rules | ~236 lines |
| `shared/opencode/orchestrator.md` | Full sdd-review-policy.md content (114 lines) — orchestrator-only SDD review policy | ~114 lines |

Both files are deployed via `home.file` in `shared/opencode.nix` so OpenCode can reference them with `{file:./filename}` syntax.

## Files to Modify

| File | Change | Lines affected |
|------|--------|---------------|
| `shared/opencode/local-agent-overlays.json` | Add `instructionOverlays` top-level key with `subagent` and `gentle-orchestrator` | +8 lines |
| `shared/opencode/agents.nix` | Add instruction overlay processing in `overlayAgent` function (parallel to toolOverlays/permissionOverlays pattern) | +15 lines in overlayAgent |
| `shared/opencode.nix` | Add `home.file` entries for `universal.md` and `orchestrator.md`; add them to activation script's file list | +10 lines for home.file, +2 lines in activation |
| `shared/opencode/assets/opencode/sdd-orchestrator.md` | Sync with fork: add Review Lens Selection table, update rules 3/4/6 wording, update Cost/Balance wording | ~30 lines added/updated |

## Overlay Mechanism

### How `toolOverlays.subagent` works today (pattern to replicate)

In `agents.nix`, the `overlayAgent` function checks if the upstream agent has `mode == "subagent"` (line 94). If yes, it applies `toolOverlays.subagent` to ALL sub-agents. If the agent is specifically `gentle-orchestrator`, it applies `toolOverlays.gentle-orchestrator`.

```nix
localTools =
  if name == "gentle-orchestrator" then
    localOverlays.toolOverlays.gentle-orchestrator or { }
  else if upstream.mode or "" == "subagent" then
    localOverlays.toolOverlays.subagent or { }
  else
    { };
```

### Proposed `instructionOverlays` mechanism

Same pattern: an `instructionOverlays` key in `local-agent-overlays.json` with a list of instruction filenames.

**local-agent-overlays.json addition:**
```json
"instructionOverlays": {
  "subagent": ["universal.md"],
  "gentle-orchestrator": ["orchestrator.md"]
}
```

**agents.nix overlay logic:**
```nix
localInstructions =
  if name == "gentle-orchestrator" then
    localOverlays.instructionOverlays.gentle-orchestrator or [ ]
  else if upstream.mode or "" == "subagent" then
    localOverlays.instructionOverlays.subagent or [ ]
  else
    [ ];
```

**Prompt prepend in overlayAgent return:**
```nix
// lib.optionalAttrs (localInstructions != [ ]) {
  prompt = (lib.concatStringsSep "\n" (map (f: "{file:./${f}}") localInstructions))
           + "\n\n"
           + (upstream.prompt or "");
}
```

This prepends `{file:./universal.md}` to every sub-agent's prompt, and `{file:./orchestrator.md}` to the orchestrator's prompt, using OpenCode's native file-reference syntax.

### Why not the global `instructions` field

OpenCode's global `instructions` array in `opencode.json` only applies to the parent agent. Sub-agents (defined in `sdd-overlay-single.json`) do not inherit it. The agent overlay's `prompt` field is the correct mechanism for sub-agent instructions. Prepending `{file:./filename}` references to the prompt ensures the content is loaded by OpenCode's file-resolver at agent initialization time.

## Risks

1. **Prompt size**: Adding 236 lines of universal.md to every sub-agent prompt may increase token usage. Mitigation: the content is already present in the neutral agent's prompt; sub-agents are launched ad-hoc so there's no persistent inflation. The 236 lines replace guesswork/errors that cost more tokens to fix.

2. **universal.md drift from SYSTEM_RULES.md**: Both files will contain the same content. If SYSTEM_RULES.md is edited, universal.md must be updated. Mitigation: document this in both files; the instruction overlay could reference SYSTEM_RULES.md directly (`"subagent": ["SYSTEM_RULES.md"]`) if we want to avoid duplication. However, the user specifically requested `universal.md` — follow the design.

3. **orchestrator prompt duplication**: The orchestrator already receives sdd-orchestrator.md (via home.file and loaded through the OpenCode skill/agent system). Adding orchestrator.md as an instruction overlay prepends it to the orchestrator's prompt — this is additive, not conflicting. The sdd-review-policy content (review gates, iteration protocol) is specific enough that duplication at the prompt level is harmless.

4. **sdd-orchestrator.md sync conflict**: The local override file at `shared/opencode/assets/opencode/sdd-orchestrator.md` and the fork version may continue to drift if the fork receives updates. Mitigation: merge the Review Lens Selection feature now; future drift is a maintenance concern, not a blocker for this change.

5. **Activation script file list**: `shared/opencode.nix` line 150 hardcodes the list of files copied from symlinks to real copies: `"for file in opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md sdd-review-policy.md package.json .gitignore tui.json; do"`. Both `universal.md` and `orchestrator.md` must be added to this list, otherwise they remain as broken symlinks that OpenCode cannot read.

## Affected Areas

| Area | Impact |
|------|--------|
| `local-agent-overlays.json` | New `instructionOverlays` key |
| `agents.nix` | New instruction overlay logic in `overlayAgent` |
| `opencode.nix` | Two new `home.file` entries + activation script update |
| `sdd-orchestrator.md` (local) | Content sync with fork (Review Lens Selection) |
| All SDD sub-agents | Receive universal.md instructions (behavior improvement) |
| gentle-orchestrator | Receives orchestrator.md content (SDD review policy) |
| Neutral agent | Unchanged (already has SYSTEM_RULES.md via prompt) |

## Ready for Proposal

Yes — the scope is clear, the mechanism is well-understood (parallels existing `toolOverlays`/`permissionOverlays` pattern), and the content split is straightforward. The only design question is whether to create `universal.md` as a new file or reuse `SYSTEM_RULES.md` directly in the overlay list. The user's explicit direction is `universal.md`, so follow that. Ready for `sdd-propose`.
