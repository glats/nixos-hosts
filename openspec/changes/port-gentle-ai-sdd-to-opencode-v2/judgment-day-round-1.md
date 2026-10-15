# Judgment Day Round 1 — V2 Engram Adapter

**Target**: `3a9ff66cab1f809b783a0856a07afca376ae2d78`

**Scope**: V1-to-V2 Engram functional parity, limited to the V2 adapter, its
runtime wiring, the pinned V2 plugin API, and available V1 implementation
evidence. Uncommitted worktree files were excluded.

## Corroborated Findings

### JD-1 — V2 Engram adapter lacks functional parity

**Severity**: critical

Both independent judges found that `pkgs/engram-assets/engram-v2.ts` only
records `engram_session_id` in prompt metadata. It does not inject the session
ID into Engram MCP save operations and does not create/register an Engram
session.

**Evidence**:

- `pkgs/engram-assets/engram-v2.ts:7-14`
- pinned V2 `ctx.tool.hook("execute.before", ...)` API
- V1 `engram.ts:525-540` session-id injection

**Impact**: normal V2 `mem_save`, `mem_save_prompt`, and session-summary calls
cannot reliably be attributed to the active OpenCode session.

### JD-2 — V2 memory continuity behavior is absent

**Severity**: critical

Both judges found no V2 equivalent for V1 prompt capture, passive Task-result
capture, permanent memory instructions/save nudge, compaction context, or the
compaction persistence directive.

**Evidence**:

- V1 `engram.ts:478-705`
- pinned V2 `ctx.session.hook` supports `prompt`, `context`, and `compaction`
- `shared/opencode/runtime-config.nix:59-71,208-212,269-292`

**Impact**: the V2 MCP remains manually usable, but it does not preserve V1's
memory lifecycle guarantees through normal work or compaction.

## Informational Finding

The planned V2 adapter registration and `mem_save`/`mem_search` acceptance gate
remains unchecked in this change's task register.

## Verdict

**JUDGMENT: ESCALATED**

Round-one correction requires explicit user approval. If approved, the bounded
work unit is to port the V1 memory lifecycle through the documented pinned V2
session and tool hooks, add focused tests, and submit it to a scoped second
round of both judges.
