# Design: Complete OpenCode V1-to-V2 Migration

## Technical Approach

Repair the bounded V2 adapters assigned to each implementation slice, then reconcile every unchecked predecessor gate into one immutable ledger. The current slice adds only the missing review relay and its isolated fake-child tests; it does not alter V1, deployment, providers, or cutover. A gate is complete only when it passes; `blocked`, `failed`, and pending runtime evidence satisfy neither completion nor cutover. V1 remains default and V2 remains `opencode2`. Even an all-pass ledger records only eligibility because this proposal does not authorize the flip.

## Architecture Decisions

| Decision | Choice | Alternatives / rationale |
|---|---|---|
| Engram parity boundary | One V2 `Plugin.define` adapter using pinned 2.0.14 session/tool hooks and `ctx.session.get`. | Rewriting Engram duplicates the Go authority; metadata-only behavior leaves JD-1/JD-2 unresolved. |
| Session ownership | Resolve the authoritative root, lazily `POST /sessions`, and inject its ID into attributed writes. | Child IDs inflate sessions; prompt metadata does not reach MCP arguments. |
| Failure policy | Registration/attribution for writes fails closed; prompt/passive capture, context fetch, and nudge fail open after bounded localhost timeouts. Strip private tags before HTTP writes. | Silent loss of write attribution is unacceptable; unavailable optional continuity must not crash OpenCode. |
| Evidence authority | Append-only ledger keyed by change/task ID; check a task only with a passing receipt. | “Implemented” or “blocked” is not proof; round one remains immutable. |
| Cutover | `failed` or `blocked` required gates force `NO-GO`; all-pass yields `ELIGIBLE, AWAITING EXPLICIT AUTHORIZATION`. | The proposal authorizes correction and re-judgment, not a default flip. |
| Review relay boundary | The V2 plugin hooks only `subagent` calls for the six review agents and relays opaque prompt/result frames through `gentle-ai review opencode-transport`; Go remains authoritative for binding, materialization, validation, budgets, admission, and capture. | Copying the upstream V4 contract or adding local selector/schema/budget logic would create a second authority. |

## Data Flow

```text
V2 prompt ──> resolve root ──> /sessions ──> /prompts
V2 context ──> memory protocol + debounced save nudge
mem_* before ──> resolve/register ──> args.session_id
Task after ──> /observations/passive
compaction ──> /context + FIRST ACTION REQUIRED directive
gate runner ──> receipt ledger ──> PASS eligibility / otherwise NO-GO
```

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/engram-assets/engram-v2.ts` | Modify | Port the six V1 lifecycle behaviors without changing V1. |
| `pkgs/engram-assets/engram-v2.test.ts`, `flake.nix` | Create/modify | Mock hooks/HTTP and expose a pinned-API check. |
| `pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.ts` | Modify | Add the minimal review-agent-only V2 relay over the pinned V1 envelope. |
| `pkgs/gentle-ai-assets/opencode-review-transport.test.ts` | Create | Exercise a fake child, refusal/incomplete output, non-review pass-through, cleanup, and no working-tree mutation outside the auto-installed plugins directory. |
| `openspec/changes/complete-opencode-v1-to-v2-migration/evidence-ledger.md` | Create | Store commands, host, revision, timestamps, exit/output, status, blocker, and rerun action. |
| Three predecessor `tasks.md` files | Reconcile | Check only passing gates; leave failed/blocked gates open. |
| `judgment-day-round-2.md`, `docs/opencode-v2-final-cutover.md` | Create/modify | Record scoped dual verdict and explicit go/no-go procedure. |

## Interfaces / Contracts

The adapter preserves V1 and Engram contracts `/sessions`, `/prompts`, `/observations/passive`, `/context`, and nudge lookups. Attributed tools are `mem_save`, `mem_save_prompt`, `mem_session_summary`, and `mem_capture_passive`.

The review boundary is split deliberately: the Go-owned provider binding remains
the authority for repository identity and git safety, while the thin TypeScript
adapter invokes the selector-free review relay from the active session directory
and returns its Go-admitted result. Relative `--cwd` aliases of the same Git
repository canonicalize to one identity; lifecycle `--cwd` may explicitly select
a different repository, which Go binds to its worktree/context authority. Unknown or
escaping repository locators and unrelated review hosts refuse before the
reviewer Task runs. The predecessor P-4.2 wording demanding rejection before
*any* subprocess described an obsolete adapter boundary: Go must run to resolve
the opaque binding, so putting that check back in TypeScript would duplicate
authority. P-4.3 is proved by Go's private `GIT_INDEX_FILE` and isolated
before/after Git snapshots, not a plugin staging guard. P-4.4's `--head`/env
prefix PR-command behavior is separate from the selector-free review relay:
the V2 shell/RTK hook preserves both PR arguments and leaves unsupported
`gentle-ai review` commands unchanged. The current upstream thin plugin is prior art,
not local proof of these contracts. The V2 relay implementation is an explicitly scoped
exception to the earlier Engram-only edit boundary; this does not authorize any
other adapter, Go contract, flake, deployment, provider, or default change.

The Nix interface remains compatible: `home.opencode.v2.{enable,runtimeRoot,projectConfigCommand}` and `home.opencode.v2.browserMcp.{enable,package,bridgePackage,bridgePort,location}` retain names/defaults. No option points V2 at V1 roots. A later authorized change must add default-runtime selection, atomically migrate backed-up V2 roots, retain a prior generation, and separately deprecate options; this change never removes V1.

## Evidence Ledger

| Change | Existing unchecked gates | Required receipt |
|---|---|---|
| `migrate-opencode-v1-to-v2` | 4.2, 4.3 | Four native toplevel/HM evals; per-host versions, root isolation, seed, credential, restart, recovery, and refusal smoke. |
| `port-gentle-ai-sdd-to-opencode-v2` | 1.4, 1.5, 1.7, 2.4, 3.1, 3.7, 4.1–4.4, 4.10, 5.3–5.7, R24, R28 | RED/schema receipts; assets/agents/MCPs; five real adapters; Git safety; formatting/evals; deny/drop/V1 identity; BrowserMCP paired concurrency/restart; provider-backed SDD/review round-trip. |
| `port-opencode-v2-provider-allowlist` | 5.3, 5.5 | Linux plus native Darwin evals and rog empirical provider denial. |

Provider funds, BrowserMCP pairing, host access, or platform absence records `BLOCKED` with reproduction and unblock owner/action. It leaves the task open and forces `NO-GO` until a passing rerun supersedes it.

## Testing Strategy

Unit tests prove root attribution, registration idempotence, prompt redaction, four argument injections, Task passive capture, protocol/nudge, compaction, and failure policy. The review relay tests use a fake child to prove the pinned V1 start/completion envelope, review-agent filtering, refusal projection, cleanup, and no local mutation; they do not prove Go selector validation, git-state safety, or organic runtime. Type-check/import against staged `@opencode/plugin@2.0.14`. Local integration proves persisted session, prompt, observation, and compaction payloads. Final proof runs eval/runtime matrices and one SDD/review round-trip on `rog`, `thinkcentre`, `t14`, and native `macm5`.

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior and RED proof |
|---|---|---|
| Documentation-like paths | N/A — no classifier changes. | None. |
| Git repository selection | Applicable in Go, not the adapter. | Relative aliases canonicalize; unknown/escaping locators and unrelated review hosts refuse before reviewer launch (P-4.2). |
| Commit state | Applicable in Go, not the adapter. | Empty, staged, and tracked `-a`-eligible states preserve HEAD, index, and worktree through bound materialization (P-4.3). |
| Push state | Applicable. | Tracking, first-push, and explicit refspec preserve ask/deny; no push. |
| PR commands | Applicable outside the review relay. | `--head` and environment prefixes need independent command pass-through proof (P-4.4). |
| Process integration | Applicable. | Hook timeout/failure policy, no secret leakage, BrowserMCP singleton/collision/recovery, and V2 service isolation receive RED and deployed tests. |

## Migration / Rollout

Land tests and correction, obtain scoped dual re-judgment, then run static/evaluation gates before runtime gates: `rog`, `thinkcentre`, `t14`, native `macm5`. Never infer one host from another. Any non-pass records `NO-GO`; all-pass records eligibility pending explicit authorization. Rollback reactivates the prior generation and restores backups while V1 remains intact.

## Open Questions

None.
