# Tasks: Complete OpenCode V1-to-V2 Migration

## Review Workload Forecast

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Engram parity: port six V1 behaviors + RED tests | PR 1 | `bun test pkgs/engram-assets/engram-v2.test.ts` | type-check vs pinned `@opencode/plugin` 2.0.14 (`pkgs/opencode-npm-packages-v2`, read-only) | Revert `engram-v2.ts`, test, `flake.nix` check |
| 2 | Ledger + gate reconciliation + JD round 2 | PR 2 | `nix flake check --no-build` | receipt-only gate runs per host | Delete ledger; uncheck reconciled gates |
| 3 | Four-host runtime proofs + cutover doc | PR 3 | `nix flake check --no-build` + per-host evals | SDD/review, BrowserMCP, deny, isolation per host | Revert `docs/opencode-v2-final-cutover.md` |

Decision needed before apply: No — PR chain strategy is deferred until PR preparation; apply does not create PRs.
Chained PRs recommended: Yes
Chain strategy: pending at PR preparation
400-line budget risk: High

Phase 1 authored code was bounded to `pkgs/engram-assets/engram-v2.ts` + its test. The separately authorized Phase 5 review relay and test are the only additional code edit; other adapters, broker (R14–R30), generator/remaps, and provider allowlist remain verification targets — never re-implemented.

## Phase 1: Engram Lifecycle Parity (bounded correction)

- [x] 1.1 RED `pkgs/engram-assets/engram-v2.test.ts`: root attribution + Engram session registration idempotence fail on current adapter; V1 `engram.ts` and `vanilla.nix` (read-only).
- [x] 1.2 RED: prompt redaction, four save-tool injections (`mem_save`, `mem_save_prompt`, `mem_session_summary`, `mem_capture_passive`), Task passive capture, nudge, compaction directive.
- [x] 1.3 RED failure policy: attribution fails closed; capture/context/nudge fail open after bounded localhost timeout.
- [x] 1.4 Port six behaviors into `pkgs/engram-assets/engram-v2.ts`: memory instructions, session attribution, prompt capture, save-tool injection, passive capture, compaction; strip private tags.
- [x] 1.5 GREEN + pinned-API type-check in `flake.nix`; local integration proves persisted session, prompt, observation, compaction payloads.

## Phase 2: Scoped Dual Re-judgment

- [x] 2.1 Record the scoped round-3 re-judgment in `judgment-day-round-3.md`; predecessor round-1/round-2 records stay immutable.
- [x] 2.2 Two independent judges re-reviewed JD-1/JD-2 against the corrected adapter and tests; the source round-3 record is `APPROVED`.
- [x] 2.3 Parity is accepted only for the frozen Engram scope; runtime persistence and cutover remain unproven.

## Phase 3: Gate Reconciliation (22 gates, receipt-only)

- [x] 3.1 Create `evidence-ledger.md` with gate, host, action, result, evidence, status, blocker, and rerun columns.
- [x] 3.2 Run the feasible static/eval cluster and record every gate, including the Darwin platform limitation.
- [x] 3.3 Attempt the safe rog static/runtime boundary; record runtime and provider gates as blocked without deployment or paid queries.
- [x] 3.4 Record independent four-host proof rows; no host's evidence substitutes for another's.
- [x] 3.5 Record unavailable funds, pairing, runtime, and platform dependencies as `BLOCKED` with reproduction and rerun owner/action.
- [x] 3.6 Reconcile predecessor status conservatively; no failed or blocked gate is checked.

## Phase 4: Cutover Decision (separate authorization)

- [x] 4.1 Record go/no-go in `docs/opencode-v2-final-cutover.md`: any failed/blocked/absent gate → NO-GO; all-pass → ELIGIBLE, AWAITING EXPLICIT AUTHORIZATION.
- [ ] 4.2 Default flip requires separate explicit authorization; V1 stays default, `opencode2` opt-in, V1 rollback intact.

## Phase 5: V2 Review Relay (isolated implementation slice)

- [x] 5.1 Implement the thin V2 `subagent` hook relay for review agents using the pinned V1 wire envelope and `node:child_process.spawn`; keep Go authoritative for binding, prompt, admission, and capture.
- [x] 5.2 Add fake-child Bun coverage for prompt/result relay, non-review pass-through, fail-closed incomplete/refused output, cleanup, and no working-tree mutation.
- [x] 5.3 Run the focused relay tests and pinned SDK type-check attempt; leave Go-owned selector/git-state gates P-4.2/P-4.3 pending and P-4.4 failed until organic runtime proof.
