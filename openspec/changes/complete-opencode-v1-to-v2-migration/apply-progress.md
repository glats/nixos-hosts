# Apply Progress: Complete OpenCode V1-to-V2 Migration

## Phase 1: Engram Lifecycle Parity

| Task | Status | Evidence |
|---|---|---|
| 1.1 | Complete | RED test failed against the original metadata-only adapter, then passed after root resolution and idempotent registration were implemented. |
| 1.2 | Complete | RED coverage exercises prompt redaction, all four save-tool injections, Task passive capture, nudge, and compaction directive. |
| 1.3 | Complete | RED failure-policy coverage proves attributed writes reject unresolved sessions while optional context hooks resolve without throwing. |
| 1.4 | Complete | `pkgs/engram-assets/engram-v2.ts` ports memory instructions, root attribution, prompt capture, save-tool injection, passive capture, compaction, and private-tag stripping using the V2 hook API. |
| 1.5 | Complete | Focused Bun test and direct TypeScript check against the pinned `@opencode/plugin` 2.0.14 package passed; the mocked localhost harness recorded session, prompt, passive observation, context, and compaction payloads. |

## TDD Cycle Evidence

| Task | RED | GREEN | Refactor |
|---|---|---|---|
| 1.1–1.3 | `bun test pkgs/engram-assets/engram-v2.test.ts` failed: 0 pass, 3 fail against the original adapter | Same command passed: 3 pass, 0 fail, 12 assertions | Removed only the temporary package symlink and kept the adapter bounded to the pinned V2 hooks |

## Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command | `NODE_PATH=/nix/store/dals03h3rvllh7m6h6iknpmywim66lki-opencode-npm-packages-v2-2.0.14/lib/node_modules bun test pkgs/engram-assets/engram-v2.test.ts` — exit 0; 3 pass, 0 fail, 12 assertions |
| Runtime harness | Local mocked localhost HTTP harness — persisted `/sessions`, `/prompts`, `/observations/passive`, `/context`, and compaction directive payloads were asserted; no paid provider or deployment invoked |
| Pinned API type-check | TypeScript 5.9.3 `--noEmit` against the staged `@opencode/plugin` 2.0.14 declarations — exit 0 |
| Rollback boundary | Revert `pkgs/engram-assets/engram-v2.ts` and `pkgs/engram-assets/engram-v2.test.ts`; V1 assets and unrelated dirty files are untouched |

## Notes

The pinned V2 API provides `session.prompt`, `session.context`, `session.compaction`, and tool hooks rather than the V1 `chat.message` and experimental system-transform names. The adapter uses the available V2 hooks and does not modify `flake.nix`; the pinned package was tested directly as requested.

## Phase 2 and Phase 3 Evidence

- Phase 2: the scoped round-3 dual review is recorded as `APPROVED` in `judgment-day-round-3.md`. This approval covers JD-1/JD-2 Engram parity only; it is not full migration or cutover approval.
- Phase 3: `evidence-ledger.md` records all 22 gate IDs and host-specific M-4.3 rows. The static cluster was actually rerun: completed contracts are `PASS`, missing/uncompleted inventory is `PENDING`, failed focused assertions are `FAIL`, and only unavailable native Darwin, runtime, BrowserMCP, and provider evidence remains `BLOCKED`.
- Decision: `NO-GO` for cutover. V1 remains default and `opencode2` remains opt-in.

## Phase 4 documentation/evidence reconciliation — 2026-09-29

| Task | Status | Evidence |
|---|---|---|
| 4.1 | Complete | `docs/opencode-v2-final-cutover.md` records the current NO-GO and links the append-only ledger correction. The ledger documents P-4.4 FAIL, P-4.2/P-4.3 PENDING, and effective counts of PASS 6, FAIL 1, PENDING 3, BLOCKED 12. |
| 4.2 | Pending | No default flip or migration was performed; V1 remains default and `opencode2` remains opt-in pending separate authorization and passing mandatory proofs. |

The correction preserves the original receipts. It distinguishes the Go-owned
selector/git-safety contract from the thin adapter's review invocation; no local
Go provider contract is claimed, and the upstream thin plugin is cited only as
prior art.

## Phase 5 isolated review-relay slice — 2026-09-29

| Task | Status | Evidence |
|---|---|---|
| 5.1 | Complete | `opencode-review-transport.ts` now registers pinned V2 `ctx.tool.hook("execute.before"/"execute.after")` hooks, filters `subagent` calls to the six review agents, relays opaque V1 start/prompt/complete/result frames with `node:child_process.spawn`, and projects refusal on swallowed hook errors. No binding, schema authority, budget, capture, or git logic was added. |
| 5.2 | Complete | `bun test pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.test.ts` — exit 0; 4 pass, 0 fail, 11 assertions. The fake Bun child covers prompt/result, non-review pass-through, incomplete/refused output, cleanup, and unchanged working-tree marker. |
| 5.3 | Complete | Focused test passed. A direct pinned-SDK TypeScript command was attempted but was blocked by the environment's missing `@types/node`; the relay remains covered by Bun execution. P-4.2 and P-4.3 remain PENDING because this fake child cannot prove Go-owned selector/git-state behavior; P-4.4 remains FAIL until organic runtime proof. |

### Work Unit Evidence

| Evidence | Result |
|---|---|
| Focused test command | `bun test pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.test.ts` — exit 0; 4 pass, 0 fail, 11 assertions |
| Runtime harness | Fake Bun child process only; no deployment, paid provider, Go selector proof, or organic OpenCode runtime was invoked |
| Pinned SDK type-check | Attempted with TypeScript 5.9.3 against pinned 2.0.14 declarations; blocked: `TS2688 Cannot find type definition file for 'node'` in the available environment |
| Rollback boundary | Revert only `pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.ts`, its adjacent test, and this Phase 5 evidence; V1, Go, flake, deployment, and unrelated dirty files remain untouched |

The first hook test used the caller agent and an invalid string-shaped child
result. A correction now reads the target agent from the subagent arguments,
requires a completed child result with a session ID, and replaces both the
structured output and content. The corrected fake-child test run passed:
5 tests, 17 assertions. The pinned-SDK type check remains unproven, as do the
Go selector/git-state gates and organic review round-trip.

The test was relocated to `pkgs/gentle-ai-assets/opencode-review-transport.test.ts`
after discovering that `v2-plugins/*.ts` files are all packaged as live
plugins. The earlier command in this work-unit table was run before the move;
the current command must target the new test location.
