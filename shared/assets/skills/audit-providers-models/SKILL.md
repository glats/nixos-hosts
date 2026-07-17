---
name: audit-providers-models
description: >
  Audit OpenCode model providers against uptime/benchmark data and SDD phase requirements
  to keep providers-base.nix assignments lean and reliable. Trigger: revisar modelos,
  auditar providers, modelos opencode, update models, providers base, model fit,
  check models, model audit.
metadata:
  version: "1.0"
---

## Activation Contract

Load when the user asks to audit, review, update, or check OpenCode provider models
in the NixOS config, especially `shared/opencode/providers-base.nix`. Also load
before any SDD change that touches model assignments.

## Hard Rules

- NEVER assign a model without checking current uptime at `opencode.ai/data/`.
- Models with uptime <90% or documented blocking issues stay commented out.
- Every phase-to-model assignment MUST cite a data point (uptime %, benchmark, issue).
- Edit `providers-base.nix` directly; run `format-nix && nix flake check --no-build` after.
- Search engram (`mem_search`) before auditing for past model decisions.

## Decision Gates

| Factor | Weight | Source |
|--------|--------|--------|
| Uptime | Highest | opencode.ai/data/ |
| SDD phase fit | High | Apply = MCP tool-use; Design = reasoning; Archive = cost |
| Known issues | Eliminator | providers-base.nix comments, opencode issues |
| Cost per session | Tiebreaker | opencode.ai/data/ |

### Phase-to-need mapping

| SDD phase | What the model MUST do |
|-----------|----------------------|
| gentle-orchestrator | Follow instructions literally, route subagents, respect done/retry/reiterate gate, never hallucinate |
| sdd-init | Fast bootstrap: detect test runners, create config |
| sdd-explore | Large context, multi-file reads, trace dependencies |
| sdd-propose | Reasoning + architecture, structured proposals |
| sdd-spec | Structured writing, detail-oriented, no omissions |
| sdd-design | Deep architectural reasoning, can be slower |
| sdd-tasks | Mechanical breakdown of specs, fast + cheap |
| sdd-apply | Follow instructions LITERALLY, surgical edits, heavy MCP tool use, never over-engineer |
| sdd-verify | Compare spec vs reality, code comprehension |
| sdd-archive | File moves/copies — cheapest possible |
| sdd-onboard | Guided walkthrough, follows script |
| neutral | Default interactions — fast + cheap |

## Execution Steps

1. Read `shared/opencode/providers-base.nix` — current assignments and blocked models.
2. Search engram: `mem_search("opencode model provider assignment")`.
3. Fetch `https://opencode.ai/data/` via `webfetch` for uptime, usage, cost.
4. For each SDD phase, pick the model with best uptime that fits the phase role.
5. Document the fit in a table: `Phase | Model | Uptime | Reason`.
6. Update phase assignments in `providers-base.nix`.
7. Run `format-nix && nix flake check --no-build`.

## Output Contract

- Updated `shared/opencode/providers-base.nix` with new assignments.
- A compact fit table: `Phase → Model → Uptime → Reason`.
- Passes `nix flake check --no-build`.
- Saved to engram as `decision` type with topic_key `providers/model-fit`.
