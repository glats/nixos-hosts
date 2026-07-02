# Tasks: Sub-agent Instructions

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~415 |
| 400-line budget risk | Near-threshold |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr-default |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Near-threshold

**Note**: ~415 lines total, but ~350 are content copies from existing files (universal.md from SYSTEM_RULES.md, orchestrator.md from sdd-review-policy.md). Effective new logic is ~65 lines across JSON config, Nix overlay function, deployment, and orchestrator sync. Single PR is appropriate.

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Implement everything and verify | PR 1 | Single PR; base = main |

## Phase 1: Content Files

- [ ] 1.1 Create `shared/opencode/instructions/universal.md` — copy full content of `shared/opencode/SYSTEM_RULES.md` (236 lines). This is the universal instruction file deployed to all SDD sub-agents.
  - Source: `shared/opencode/SYSTEM_RULES.md` lines 1-236
  - Path: `shared/opencode/instructions/universal.md`
  - Add coupling note in both files: `<!-- NOTE: This file is a copy of shared/opencode/SYSTEM_RULES.md. Keep both in sync. -->`

- [ ] 1.2 Create `shared/opencode/instructions/orchestrator.md` — copy full content of `shared/opencode/sdd-review-policy.md` (114 lines). This instructs the gentle-orchestrator agent on SDD review policy, iteration protocol, guard lines, and re-explore protocol.
  - Source: `shared/opencode/sdd-review-policy.md` lines 1-114
  - Path: `shared/opencode/instructions/orchestrator.md`
  - Add coupling note in both files: `<!-- NOTE: This file is a copy of shared/opencode/sdd-review-policy.md. Keep both in sync. -->`

## Phase 2: Overlay Mechanism

- [ ] 2.1 Add `instructionOverlays` top-level key to `shared/opencode/local-agent-overlays.json`:
  ```json
  "instructionOverlays": {
    "subagent": ["instructions/universal.md"],
    "gentle-orchestrator": ["instructions/orchestrator.md"]
  }
  ```
  - Insert after `permissionOverlays` block (before closing `}`)

- [ ] 2.2 Modify `shared/opencode/agents.nix` — add `localInstructions` logic in `overlayAgent` function, parallel to existing `localTools` and `localPermission` patterns:
  - Add `localInstructions` block (after `localPermission`):
    - If name is `"gentle-orchestrator"` → `localOverlays.instructionOverlays.gentle-orchestrator or [ ]`
    - If upstream mode is `"subagent"` → `localOverlays.instructionOverlays.subagent or [ ]`
    - Otherwise → `[ ]`
  - Add prompt prepend in the return expression:
    ```nix
    // lib.optionalAttrs (localInstructions != [ ]) {
      prompt = (lib.concatStringsSep "\n" (map (f: "{file:./${f}}") localInstructions))
               + "\n\n"
               + (upstream.prompt or "");
    }
    ```
  - This prepends `{file:./instructions/universal.md}\n\n` to every sub-agent prompt and `{file:./instructions/orchestrator.md}\n\n` to the orchestrator prompt

## Phase 3: Deployment

- [ ] 3.1 Add `home.file` entries in `shared/opencode.nix` under `mkRuntimeConfig` for both instruction files (parallel to existing SYSTEM_RULES.md entry at lines 92-95):
  - `.config/opencode/instructions/universal.md` → source: `./opencode/instructions/universal.md`
  - `.config/opencode/instructions/orchestrator.md` → source: `./opencode/instructions/orchestrator.md`

- [ ] 3.2 Add both files to activation script's for-loop at line 150 of `shared/opencode.nix`:
  - Add `instructions/universal.md` and `instructions/orchestrator.md` to the `for file in ...` list
  - Line currently reads: `for file in opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md sdd-review-policy.md package.json .gitignore tui.json; do`
  - New: `for file in opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md sdd-review-policy.md package.json .gitignore tui.json instructions/universal.md instructions/orchestrator.md; do`

## Phase 4: sdd-orchestrator Sync

- [ ] 4.1 Sync `shared/opencode/assets/opencode/sdd-orchestrator.md` with fork version. Apply these changes (content sourced from `https://raw.githubusercontent.com/glats/gentle-ai/main/internal/assets/opencode/sdd-orchestrator.md`):
  - **Rule 3 (PR rule)**: Change `"run a fresh-context review"` → `"run the concrete review lens(es) selected by Review Lens Selection"`
  - **Rule 4 (Incident rule)**: Change `"stop and run a fresh audit before continuing"` → `"stop and run the concrete audit/review lens(es) selected by Review Lens Selection before continuing"`
  - **Rule 6 (Fresh review rule)**: Change `"use fresh context for adversarial review"` → `"use fresh context with the selected concrete review lens(es) for adversarial review"`
  - **Insert Review Lens Selection table**: Add new subsection `#### Review Lens Selection` between the Mandatory Delegation Triggers list and the `#### Cost and Context Balance` section. Table content:
    | Risk signal | Review lens |
    |---|---|
    | Clear naming, structure, maintainability, or small refactors | `review-readability` |
    | Behavior, state, tests, determinism, or regressions | `review-reliability` |
    | Shell/process integration, partial failures, recovery, or degraded dependencies | `review-resilience` |
    | Security, permissions, data exposure/loss, architecture, or dependencies | `review-risk` |
    | Large PR, hot path, or >400 changed lines | full 4R: `review-risk`, `review-resilience`, `review-readability`, `review-reliability` |
  - **Cost and Context Balance**: Change `"Use fresh reviewers after implementation..."` → `"Use concrete review lenses after implementation..."`

## Phase 5: Verify

- [ ] 5.1 Run `format-nix` to auto-format all changed Nix files
- [ ] 5.2 Run `nix flake check --no-build` to validate flake evaluates cleanly
  - If errors appear, fix them and re-run
- [ ] 5.3 Stage all changes for review with `git add -A`
  - DO NOT commit (user reviews first)
