## Verification Report

**Change**: `sub-agent-instructions`
**Commit**: `eea5527`
**Date**: 2026-07-01
**Mode**: Standard (no strict TDD)
**Artifacts**: proposal.md, exploration.md, tasks.md

---

### Completeness (Tasks)

| Task | Description | Status |
|------|-------------|--------|
| 1.1 | Create `shared/opencode/instructions/universal.md` | ✅ Done |
| 1.2 | Create `shared/opencode/instructions/orchestrator.md` | ✅ Done |
| 2.1 | Add `instructionOverlays` to `local-agent-overlays.json` | ✅ Done |
| 2.2 | Modify `agents.nix` overlayAgent with instruction logic | ✅ Done |
| 3.1 | Add `home.file` entries in `opencode.nix` | ✅ Done |
| 3.2 | Update activation script file list | ✅ Done |
| 4.1 | Sync `sdd-orchestrator.md` with fork Review Lens Selection | ✅ Done |
| 5.2 | `nix flake check --no-build` passes | ✅ Done |

**Summary**: 8/8 tasks complete. No incomplete tasks.

---

### Build & Flake Check

| Check | Result | Evidence |
|-------|--------|----------|
| `nix flake check --no-build` | ✅ PASS | All checks passed (rog, thinkcentre, t14 NixOS configs, formatter). Zero errors. |

---

### Spec Compliance Matrix

| # | Criterion | Result | Evidence |
|---|-----------|--------|----------|
| 1 | `local-agent-overlays.json` has `instructionOverlays.subagent` and `.gentle-orchestrator` | ✅ PASS | Lines 42-45: `"instructionOverlays": { "subagent": ["instructions/universal.md"], "gentle-orchestrator": ["instructions/universal.md", "instructions/orchestrator.md"] }` |
| 2 | `agents.nix` `overlayAgent` prepends instruction references to matching agent prompts | ✅ PASS | Lines 99-118: `localInstructions` block with `gentle-orchestrator`/`subagent` match, prompt prepend with `{file:./...}` syntax |
| 3 | `universal.md` and `orchestrator.md` exist and are deployed to `~/.config/opencode/` | ✅ PASS | `~/.config/opencode/instructions/universal.md` (237 lines, 9492 bytes), `~/.config/opencode/instructions/orchestrator.md` (115 lines, 4832 bytes). Content matches source exactly (`diff` returns empty). |
| 4 | Activation script copies both files from symlink to writable real copy | ✅ PASS | `opencode.nix` line 158: `for file in ... instructions/universal.md instructions/orchestrator.md ...; do` with `readlink -f` + `cp` logic |
| 5 | `sdd-orchestrator.md` contains Review Lens Selection table and updated review rules | ✅ PASS | 5 mentions of "Review Lens" / "review lens": Rules 3, 4, 6, heading, Cost/Balance section. Table with 5 risk signal rows present. |
| 6 | `nix flake check --no-build` passes with zero errors | ✅ PASS | All flake outputs validated. |

---

### Correctness

| Check | Result | Evidence |
|-------|--------|----------|
| universal.md content parity with SYSTEM_RULES.md | ✅ PASS | `diff` (minus coupling comment) returns empty. 237 vs 236 lines (1-line coupling comment header). |
| orchestrator.md content parity with sdd-review-policy.md | ✅ PASS | `diff` (minus coupling comment) returns empty. 115 vs 114 lines (1-line coupling comment header). |
| All 10 SDD sub-agents receive universal.md | ✅ PASS | Built `opencode.json`: sdd-init, sdd-explore, sdd-propose, sdd-spec, sdd-design, sdd-tasks, sdd-apply, sdd-verify, sdd-archive, sdd-onboard all have `{file:./instructions/universal.md}` prepended to prompt. |
| gentle-orchestrator receives universal.md + orchestrator.md | ✅ PASS | Built `opencode.json`: `"prompt":"{file:./instructions/universal.md}\n{file:./instructions/orchestrator.md}\n\n{file:./AGENTS.md}"` |
| Neutral agent NOT affected | ✅ PASS | Built `opencode.json`: neutral agent prompt is `"{file:./IDENTITY.md}\n\n{file:./SYSTEM_RULES.md}"` — unchanged. |
| Other non-SDD sub-agents also receive universal.md (jd-*, review-*) | ✅ PASS | All 7 extra sub-agents (jd-fix-agent, jd-judge-a, jd-judge-b, review-readability, review-reliability, review-resilience, review-risk) have universal.md — correct since they are subagents and the overlay applies to all `mode: "subagent"` agents. |
| Rule 3 wording updated | ✅ PASS | "fresh-context review" → "concrete review lens(es) selected by Review Lens Selection" |
| Rule 4 wording updated | ✅ PASS | "fresh audit" → "concrete audit/review lens(es) selected by Review Lens Selection" |
| Rule 6 wording updated | ✅ PASS | "fresh context for adversarial review" → "fresh context with the selected concrete review lens(es) for adversarial review" |
| Cost/Balance wording updated | ✅ PASS | "Use fresh reviewers" → "Use concrete review lenses" |
| Deployed files match source | ✅ PASS | `diff` between source and `~/.config/opencode/instructions/*.md` returns empty. |

---

### Design Coherence

| Design Decision | Status | Evidence |
|-----------------|--------|----------|
| Instruction overlay parallel to toolOverlays/permissionOverlays | ✅ Coherent | `agents.nix` lines 99-118 mirror the structure of `localTools` (lines 91-97) and `localPermission` (line 98). Pure additive, no breakage. |
| `{file:./...}` prompt prepend | ✅ Coherent | Uses OpenCode's native file-reference syntax. Prepend ensures instructions load before agent-specific prompt text. |
| `instructions/` subdirectory for deployment | ✅ Coherent | Files deployed to `instructions/` subdirectory, referenced as `{file:./instructions/...}` — matches overlay paths. |
| Orchestrator gets both universal + orchestrator | ✅ Coherent | Designed per exploration.md: universal rules apply to ALL agents, orchestrator gets additional SDD review policy. |
| Neutral agent unchanged | ✅ Coherent | Neutral agent is not a subagent and has its own prompt in `local-agent-overlays.json` — correct exclusion. |

---

### Issues

| Severity | Description |
|----------|-------------|
| — | No issues found. |

---

### Final Verdict

**PASS** ✅

All 6 success criteria met. All 8 tasks complete. `nix flake check --no-build` passes with zero errors. Content parity verified between source and deployed files. No regressions detected in non-SDD agents. The `sdd-orchestrator.md` sync has all required Review Lens Selection content (5 mentions, table with 5 risk rows, updated Rules 3/4/6 and Cost/Balance wording).

**Ready for archive.**
