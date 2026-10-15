# OpenCode V1-to-V2 Migration Evidence Ledger

This is an append-only receipt ledger for the 22 existing gate IDs. A gate is checked only when its named proof passes. `BLOCKED` is non-passing and requires a rerun; it is never inferred as approval. The ledger records Phase 2's scoped dual approval separately from runtime and cutover readiness.

**Run date**: 2026-09-29  
**Repository revision**: `3a9ff66cab1f809b783a0856a07afca376ae2d78` plus pre-existing dirty worktree changes  
**Policy**: no deployment, no paid provider invocation, no secret decryption, no default flip

## Phase 2 receipt

| Gate | Host | Action | Result | Evidence | Status | Blocker | Rerun |
|---|---|---|---|---|---|---|---|
| JD-1/JD-2 scoped re-judgment | N/A | Verify round-3 review record and focused harness scope | Both independent judges approved the frozen Engram scope | `openspec/changes/port-gentle-ai-sdd-to-opencode-v2/judgment-day-round-3.md`, mirrored at `judgment-day-round-3.md`; production adapter review hashes are recorded there | PASS (scoped only) | None within frozen scope | No; do not broaden this receipt into runtime proof |

## Gate receipts

The 22 IDs below are the existing gate set. `M-4.3` is one gate with four host-specific rows in the four-host section, not four separate gate IDs.

| Gate | Host | Action | Result | Evidence | Status | Blocker | Rerun |
|---|---|---|---|---|---|---|---|
| M-4.2 | N/A | Run the focused Engram/static parity harness | Bun test completed with 4 passing tests and 13 expectations | `timeout 60s bun test pkgs/engram-assets/engram-v2.test.ts` → exit 0; `4 pass`, `0 fail`, `13 expect() calls` | BLOCKED | The command proves the adapter harness, not the predecessor gate's full migration acceptance contract | Re-run the gate-specific M-4.2 receipt with its full acceptance assertions |
| P-1.4 | N/A | Check V2 asset/schema emission | Sandboxed V2 activation copied the command and skill trees, remapped `subtask` to `subagent`, and added all ten SDD delegation markers; no V1-path changes were present | `nix eval .#homeConfigurations.rog.config.home.activation.setupOpencodePluginRuntime-v2.data` → exit 0; extracted asset portion executed under `/tmp/opencode/p14-runtime`; 25 command files, 4,512 skill files, ten delegation markers; `git diff --name-only HEAD --` on V1 paths → empty | PASS | None for the P-1.4 asset contract; the full activation also exposed a separate missing `engram.ts` store path, outside this gate | Re-run if asset sources or V2 activation changes |
| P-1.5 | N/A | Confirm pinned V2 schema | Pinned V2 package and schema check evaluated successfully | Same flake receipt; `packages.x86_64-linux.opencode-npm-packages-v2` evaluated as `2.0.14`; schema check evaluated | PASS | None for this static gate | No rerun required unless inputs change |
| P-1.7 | Linux hosts | Run flake check and host evaluations | `rog`, `thinkcentre`, and `t14` toplevel drvPath evaluations passed; Darwin was not available | Flake exit 0; rog `/nix/store/fp9cdhld1i8dzdq14yssjjrh7lpgbylf-nixos-system-rog-26.05.20260822.a9e6d84.drv`; thinkcentre `/nix/store/fjyficghr3rhhr84fc03jyyrd544kqhd-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv`; t14 `/nix/store/2wgra6r2mag4s5125bx9r441gvv8h2fn-nixos-system-t14-26.05.20260822.a9e6d84.drv` | BLOCKED | Required Darwin/native matrix is unavailable on `x86_64-linux` | Re-run on native `macm5` and retain Linux receipts |
| P-2.4 | N/A | Inspect V2 skills/commands/remap inventory | The isolated `opencode2 debug agents` and `debug config` attempts timed out without output; the inventory command did not complete | `HOME=/tmp/opencode/p24-home XDG_CONFIG_HOME=/tmp/opencode/p24-home/.config timeout 30s opencode2 debug agents` → exit 124; same for `debug config` | PENDING | The static activation inventory passed, but the named `opencode2` inventory receipt is not complete; this is not a proven blocker | Re-run the debug inventory in a responsive V2 runtime sandbox |
| P-3.1 | N/A | Exercise deny/safety RED assertions | Generated V2 permissions contain deny rules for `sops*`, `sudo *`, and `nixos-build *`, while retaining ask rules for push variants | `nix eval --raw .#homeConfigurations.rog.config.home.file.".config/opencode-v2/opencode.json".source` plus JSON assertion → exit 0; 60 permission rules; all six required effects matched | PASS | None for the static deny/ask contract | Re-run if permission sources change |
| P-3.7 | rog | Inspect agent/MCP inventory | No live rog smoke was invoked | No receipt; no deployment performed | BLOCKED | Host runtime proof unavailable in this run | Run on rog with the existing opt-in V2 runtime |
| P-4.1 | N/A | Type-check five adapters against pinned API | All five V2 adapter sources type-checked against the pinned `@opencode/plugin` 2.0.14 declarations; temporary Bun/Node globals were confined to `/tmp/opencode` | `nix shell nixpkgs#typescript --command tsc -p /tmp/opencode/p41/tsconfig.json` → exit 0; `rtk-v2`, `sdd-task-result`, `skill-registry`, `opencode-review-transport`, and `engram-v2` checked | PASS | None for the pinned API type contract | Re-run if the pinned package or adapter hooks change |
| P-4.2 | N/A | Test git selector rejection | Focused read-only assertion found no relative/outside-worktree selector rejection in the V2 review transport | Python source assertion over `opencode-review-transport.ts` and `rtk-v2.ts` → exit 1; `relative/outside selector rejection FAIL` | FAIL | Required fail-closed selector behavior is absent; no subprocess or main-repository mutation was attempted | Implement the RED test and guard, then run it in `/tmp/opencode` |
| P-4.3 | N/A | Test empty/staged/-a commit safety | Focused read-only assertion found no empty/staged/`-a` safety guards in the V2 review transport; no git mutation calls were present | Python source assertion over `opencode-review-transport.ts` → exit 1; `empty/staged/-a guards FAIL`, `no git mutation calls PASS` | FAIL | The required safety behavior/test is absent, not blocked by environment access | Implement the RED test and fail-closed transport guard in a temp sandbox |
| P-4.4 | N/A | Test review argument pass-through | Focused read-only assertion found no explicit `--head`, environment-prefix forwarding, or review subprocess invocation | Python source assertion over `opencode-review-transport.ts` → exit 1; all three required checks `FAIL` | FAIL | The V2 transport is currently metadata-only and cannot satisfy pass-through | Implement the RED test and transport behavior without invoking a paid provider |
| P-5.3 | Linux hosts | Run formatting, Go suite, flake, and host matrix | Go suite and flake passed; Linux host evals passed; Darwin matrix unavailable | `timeout 120s go -C pkgs/nixos-scripts test ./...` → exit 0; `timeout 120s nix flake check --no-build` → exit 0; three Linux drvPath receipts above | BLOCKED | Native Darwin/standalone macm5 proof unavailable; `nix fmt -- --check` is unsupported by treefmt (`unknown flag: --check`) | Run `nix fmt -- --ci` on a native/worktree-safe environment and native macm5 evals |
| P-5.4 | Linux hosts | Run full matrix | Linux flake/toplevel/HM evaluations passed; Darwin evaluation omitted or platform-mismatched | Flake explicitly omitted `aarch64-darwin` and `x86_64-darwin`; macm5 toplevel failed with `Required system: 'aarch64-darwin'; Current system: 'x86_64-linux'` | BLOCKED | Native Darwin platform required | Re-run on macm5 |
| P-5.7 | N/A | Check final V1 diff and stale comments | V1-path diff and whitespace checks were clean; the scoped comment sweep found no stale V2 markers in V1 adapter/config comments | `git diff --check` → exit 0; `git diff --name-only HEAD --` on V1 paths → empty; Python comment sweep → `stale-comment candidates=0` | PASS | None in the scoped V1 paths | Re-run after any V1 asset or fallback change |
| A-5.3 | Linux hosts | Run provider allowlist full matrix | Linux flake and host evals passed; Darwin side unavailable; no provider query was attempted | Flake exit 0 and three Linux toplevel drvPaths above; no paid provider invoked | BLOCKED | Native Darwin evaluation and empirical provider proof unavailable; funds restriction forbids query | Re-run native Darwin static eval, then authorized non-paid denial smoke |
| P-4.10 | rog | Run five-adapter runtime smoke | Not run | No receipt; no deployment | BLOCKED | rog runtime and provider dependencies unavailable | Run opt-in rog smoke with no paid query |
| P-5.5 | rog | Run deny/proxy/drop smoke | Not run | No receipt; no deployment | BLOCKED | rog runtime proof unavailable | Run opt-in rog smoke |
| A-5.5 | rog | Run empirical provider denial | Not run by policy | No receipt; paid/provider invocation prohibited | BLOCKED | Provider funds/paid invocation unavailable | Run only with explicit non-paid denial fixture or authorized funds |
| R28 | rog | Restart native V2 service and query provider | Prior receipt says restart did not return and provider rejected for insufficient funds | `port-gentle-ai-sdd-to-opencode-v2/apply-progress.md` lines 24-29 and tasks R28 lines 214-217 | BLOCKED | Native restart follow-up and provider funds | Resolve service wait; rerun query only under authorization |
| P-5.6 | rog, thinkcentre, t14, macm5 | Run SDD/review round-trip on each host | Not run | No receipt; no provider invocation or deployment | BLOCKED | Four-host runtime and provider dependencies unavailable | Run independently on all four hosts; never infer across hosts |
| R24 | rog, thinkcentre, t14, macm5 | Run BrowserMCP paired concurrency/restart proof | Not run | No receipt; paired extension unavailable and no deployment | BLOCKED | BrowserMCP pairing/host access unavailable | Run independently on each host with paired extension |
| M-4.3 | rog | Run isolation/supervision slice | Static service declarations were evaluated by flake, but no live service/recovery proof was run | `nix flake check --no-build` exit 0; no `systemctl`, `launchctl`, deployment, or kill/recovery command run | BLOCKED | Runtime proof unavailable | Run the rog slice without changing V1 |

## Four-host rows for M-4.3

| Gate | Host | Action | Result | Evidence | Status | Blocker | Rerun |
|---|---|---|---|---|---|---|---|
| M-4.3 | rog | Evaluate isolation/supervision | Toplevel and HM drvPath evaluation passed; live service not exercised | rog toplevel and HM drvPath receipts above | BLOCKED | Evaluation is not runtime recovery proof | Run opt-in rog service/recovery harness |
| M-4.3 | thinkcentre | Evaluate isolation/supervision | Toplevel and HM drvPath evaluation passed; live service not exercised | thinkcentre toplevel and HM drvPath receipts above | BLOCKED | Evaluation is not runtime recovery proof | Run on thinkcentre |
| M-4.3 | t14 | Evaluate isolation/supervision | Toplevel and HM drvPath evaluation passed; live service not exercised | t14 toplevel and HM drvPath receipts above | BLOCKED | Evaluation is not runtime recovery proof | Run on t14 |
| M-4.3 | macm5 | Evaluate isolation/supervision | Evaluation stopped at Darwin platform mismatch | `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` → `Required system: 'aarch64-darwin'; Current system: 'x86_64-linux'` | BLOCKED | Native macm5 required | Run on macm5 |

## Decision

**NO-GO for cutover.** The scoped round-3 Engram judgment is approved, but the migration is not complete: the ledger contains blocked runtime, provider, BrowserMCP, four-host, and native Darwin gates. V1 remains default; `opencode2` remains opt-in. No predecessor gate is checked from this ledger unless its receipt is independently passing; no deployment or secret operation was performed.

## Phase 3 correction and static-cluster counts

Unattempted or incomplete static work is `PENDING`, not `BLOCKED`. A failed focused assertion is `FAIL`, even when the missing behavior is expected to be implemented later. Across the 22 gate IDs: **PASS 6, FAIL 3, PENDING 1, BLOCKED 12**. The separate JD-1/JD-2 scoped receipt remains `PASS (scoped only)`.

## Safe commands run

```text
timeout 60s bun test pkgs/engram-assets/engram-v2.test.ts
timeout 120s nix flake check --no-build
timeout 90s nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath
timeout 90s nix eval .#nixosConfigurations.thinkcentre.config.system.build.toplevel.drvPath
timeout 120s nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath
timeout 120s nix eval .#homeConfigurations.rog.activationPackage.drvPath
timeout 120s nix eval .#homeConfigurations.thinkcentre.activationPackage.drvPath
timeout 120s nix eval .#homeConfigurations.t14.activationPackage.drvPath
timeout 120s go -C pkgs/nixos-scripts test ./...
timeout 60s nix fmt -- --check  # unsupported: treefmt unknown flag --check
timeout 90s nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath  # blocked by platform mismatch
nix eval --raw .#homeConfigurations.rog.config.home.activation.setupOpencodePluginRuntime-v2.data  # P-1.4 activation source
HOME=/tmp/opencode/p24-home XDG_CONFIG_HOME=/tmp/opencode/p24-home/.config timeout 30s opencode2 debug agents  # P-2.4, exit 124
HOME=/tmp/opencode/p24-home XDG_CONFIG_HOME=/tmp/opencode/p24-home/.config timeout 30s opencode2 debug config  # P-2.4, exit 124
nix eval --raw .#homeConfigurations.rog.config.home.file.".config/opencode-v2/opencode.json".source  # P-3.1 generated permissions
nix shell nixpkgs#typescript --command tsc -p /tmp/opencode/p41/tsconfig.json  # P-4.1, exit 0
inline Python source assertion for P-4.2 selector rejection  # exit 1
inline Python source assertion for P-4.3 git safety  # exit 1
inline Python source assertion for P-4.4 pass-through  # exit 1
git diff --check  # P-5.7, exit 0
git diff --name-only HEAD -- <scoped V1 paths>  # P-5.7, empty
inline Python scoped V1 comment sweep  # P-5.7, stale-comment candidates=0
```

## 2026-09-29 correction: P-4.2–P-4.4 evidence classification

This correction is append-only. The original command results and their recorded
statuses above remain unchanged. A follow-up inspection confirmed that the
local `pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.ts` is
metadata-only and does not invoke a review relay.

The earlier P-4.2 and P-4.3 source-only assertions cannot establish behavioral
failures: selector validation is Go-owned, and the inspected transport contains
no actual git mutation path. Their effective statuses are therefore **PENDING**
(unverified, nonpassing), not FAIL. P-4.4 remains **FAIL** because the absent
review invocation means the required pass-through behavior is not present.
This does not claim that the Go provider contract is implemented locally; the
current upstream thin plugin is prior art only.

The P-4.2 rerun must exercise relative and outside-worktree selectors against
the actual Go binding before any review subprocess; the P-4.3 rerun must compare
the index and worktree before and after empty, staged, and `-a` cases in an
isolated repository. Neither can pass from inspection of the metadata-only
adapter. P-4.4 needs a relay implementation and a focused pass-through test
without a paid provider before its failed receipt can be superseded.

Effective counts across the 22 gate IDs are now: **PASS 6, FAIL 1, PENDING 3,
BLOCKED 12**. The effective cutover decision remains **NO-GO**: P-4.4 is
failed, P-4.2 and P-4.3 are nonpassing pending evidence, and the ledger still
contains blocked runtime, provider, BrowserMCP, four-host, and native Darwin
gates. No migration, deployment, git mutation, paid-provider invocation, or
archive operation was performed.

## 2026-09-29 append-only receipt: isolated V2 review relay

The prior design's Engram-only edit boundary was conservatively narrowed and
corrected for this explicitly authorized relay slice. The implementation is a
thin `subagent` hook adapter for review agents only. It uses the pinned V1
`gentle-ai.provider-transport/v1` start/completion envelope and delegates all
binding, prompt materialization, selector validation, git safety, admission,
budget, and capture authority to Go. No V1 or flake/nix file was changed.

| Gate | Host | Action | Result | Evidence | Status | Blocker | Rerun |
|---|---|---|---|---|---|---|---|
| P-4.2 | N/A | Run fake-child relay test | Adapter does not implement selector validation; fake child cannot exercise Go binding | `bun test pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.test.ts` exit 0; selector behavior not exercised | PENDING | Go-owned selector proof remains absent | Exercise relative/outside-worktree selectors against the actual Go binding |
| P-4.3 | N/A | Run fake-child relay test | Adapter has no git mutation path; fake child cannot prove Go commit-state safety | Same focused test; unchanged marker asserted; empty/staged/`-a` contract not exercised | PENDING | Go-owned git-state proof remains absent | Compare isolated repository state before/after the actual Go transport cases |
| P-4.4 | N/A | Run isolated review relay | The fake-child adapter tests pass, but the required runtime pass-through proof is absent | `bun test pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.test.ts` exit 0; 4 pass, 11 assertions | FAIL | Organic runtime proof and Go/provider-backed result admission remain absent | Run the V2 plugin in the pinned OpenCode runtime with an authorized fixture |

The focused test is not a runtime gate receipt and does not change the NO-GO
decision. The pinned SDK type-check attempt was blocked by missing `@types/node`
in the available environment; no deployment or paid provider invocation was
attempted.

### Focused correction after hook-shape review

The first isolated test incorrectly modeled the caller agent as the requested
review agent and represented the child result as a string. Against the pinned
2.0.14 `execute.before/after` types, the adapter now reads `input.agent` from
the subagent tool arguments and handles a completed child result object with
`sessionID` and raw `output`. Incomplete child output and orphaned completions
project a refusal instead of returning raw reviewer text. The corrected
`bun test pkgs/gentle-ai-assets/opencode-review-transport.test.ts`
exited 0 with **5 passing tests and 17 assertions**; this is still fake-child
evidence only, not pinned-SDK type proof or P-4.2/P-4.3/P-4.4 runtime proof.

The test was then relocated outside `v2-plugins/`: the asset derivation copies
every `v2-plugins/*.ts` into the runtime plugin directory, where a Bun test
must not be auto-loaded. Its current command is
`bun test pkgs/gentle-ai-assets/opencode-review-transport.test.ts`; the older
paths in the historical receipts above describe the original test location.

## 2026-09-30 append-only rog runtime attempt

The operator reported successful `nixos-build dry` and `switch` on rog and
macm5 at Git revision `8eb31b6`, and confirmed the installed V2 plugin bytes
match that revision on both hosts. On rog, the focused Bun relay test passed
(5 tests, 17 assertions) and four pinned Go transport tests passed. These
checks do not substitute for an organic OpenCode reviewer round-trip.

An isolated git candidate in `/tmp/opencode/relay-proof` received a native
medium-risk START with one `review-reliability` lens. The first CLI attempt
omitted the managed V2 environment and could not start its background service;
this was a test invocation error, not a plugin failure. With the managed V2
environment sourced, the normal V2 service was reachable, but the single
`opencode2 run --agent build --format json` session immediately returned
`provider.quota` / HTTP 402 (`Insufficient account funds`) before dispatching
the reviewer subagent. No review result was admitted, no paid reviewer was run,
and global RDD mode was returned to `off` and verified. The isolated lineage
remains `reviewing`; abandonment requires separate maintainer authorization,
so no fabricated cleanup was attempted.

| Gate | Host | Action | Result | Effective status | Blocker | Rerun |
|---|---|---|---|---|---|---|
| P-4.4 | rog | Invoke the V2 relay in a one-lens isolated review | OpenCode emitted `provider.quota` HTTP 402 before subagent dispatch | BLOCKED | No funded primary provider execution; no organic reviewer or Go admission proof | Use an authorized working provider in an isolated candidate, re-enter its native STATUS binding, and verify actual relay admission |

The historical P-4.4 FAIL receipt (missing implementation) is not rewritten:
the adapter now exists, but the required runtime behavior is still unproven.
Effective ledger counts are **PASS 6, FAIL 0, PENDING 3, BLOCKED 13**; cutover
remains **NO-GO**, and neither verify nor archive is authorized.

## 2026-09-30 append-only macm5 organic relay refusal

The macm5 operator prepared the same tiny isolated fixture, verified the
`value.js` 1-to-2 diff, and used native STATUS and candidate-scoped granted
consent to create lineage `review-fc253b3818eb2634` with exactly one
`review-reliability` slot. An ordinary V2 `opencode2 run` invoked the
`subagent` tool once with the collect input's exact binding. Its tool status
was `error`: `opencode_review_transport_relay_refused: relay_unavailable`.
The tool metadata recorded `providerCall.executed=false` and
`providerResult.executed=false`; the primary step reported cost 0.028092.
No reviewer result was captured or admitted; the operator made no retry and
returned global RDD mode to `off`.

A provider-free native Go START-only frame from that same fixture and binding
resolved `gentle-ai` on the operator's shell PATH, emitted a valid materialized
`prompt` frame and nonce, then returned the expected
`opencode_review_transport_provider_result_missing` on input EOF. This narrows
the organic refusal to the plugin's invocation context or frame handling;
neither process PATH nor session cwd has been proven as the root cause.

| Gate | Host | Action | Result | Effective status | Blocker | Rerun |
|---|---|---|---|---|---|---|
| P-4.4 | macm5 | One canonical organic review subagent attempt | V2 hook refused before reviewer dispatch; native Go accepts the same binding from the fixture shell | FAIL | Plugin invocation context/frame failure not yet localized; no admitted reviewer result | Inspect actual session cwd and safe subprocess failure class, fix at the narrow boundary, then retest once |

The preceding effective counts are historical snapshots, not overwritten:
after this observation the effective counts are **PASS 6, FAIL 1, PENDING 3,
BLOCKED 12**. Cutover remains **NO-GO**; neither a paid primary call nor a
Go-only materialization substitutes for review transport admission.

### Bounded correction candidate (published, not yet deployed or accepted)

Read-only session lookup in pinned `@opencode/plugin` 2.0.14 exposes the active
`SessionInfo.location.directory` by `ctx.session.get({sessionID})`. The local
adapter had captured `ctx.location.directory` once during plugin setup, so an
ordinary later session could relay Go from the wrong repository even when its
own session location was correct. A regression with intentionally different
setup and session directories failed against the old adapter and passes after
resolving the directory per invocation. Startup refusal now distinguishes a
missing executable (`executable_unavailable`) from a Go exit before a prompt
(`go_refused`) without leaking Go stderr or reviewer output; other failures
remain `relay_unavailable`. Eight focused fake-child tests (23 assertions),
the combined Engram suite (12 tests, 36 assertions), and Linux
`nix flake check --no-build` passed. This is a candidate fix and diagnostic
improvement, **not** proof of the macm5 root cause or an organic PASS. The
historical FAIL and NO-GO remain effective until a native redeployment and
one bounded reviewer attempt return Go admission evidence.

The two-file correction was committed as `941512c` and published on
`origin/master` at merge commit `19b5982` after integrating the remote-only
macm5 provider selection change. No second paid reviewer run, Mac rebuild,
or organic acceptance has been observed for that revision.

## 2026-09-30 append-only macm5 positive reviewer transport

After Mac activation, the operator reported Git revision `0f09dc6` (which
contains `941512c`), byte equality of the installed V2 plugin, and a native
STATUS reoffering the unchanged bound `review-reliability` input. One ordinary
`opencode2 run` then completed the `subagent` tool call for lineage
`review-fc253b3818eb2634`. Its output was a native
`gentle-ai.review-last-event-closure/v1` envelope with `state=approved`,
`store_revision=sha256:8968fd34635a5e5c7a83eafeace687b0438d1907b35f2cf72e070f16c3889df1`,
and a provider-issued `review.acknowledge-approved` continuation. The parent
reported that acknowledgement was **not** executed. The operator's shell trap
returned RDD mode to `off`.

This is positive **scoped macm5 organic pass-through and Go admission**; the
`providerCall.executed=false` in the parent subagent tool metadata does not
override the native last-event closure. A fresh target-bound STATUS must replay
the exact acknowledgement before this isolated lifecycle is terminal. It
does not prove P-4.2/P-4.3, four-host runtime, BrowserMCP, or migration
cutover. The historical macm5 refusal remains in the ledger; current P-4.4
overall is **PENDING** terminal/readback proof. Effective counts are **PASS 6,
FAIL 0, PENDING 4, BLOCKED 12**; the migration remains **NO-GO**.

### Terminal readback for the same macm5 fixture

Fresh target-bound STATUS replayed the exact `review.acknowledge-approved`
operation, target, revision, and token from the admitted last-event closure.
The macm5 operator executed it once and received
`gentle-ai.review-acknowledged/v1`, `action=acknowledged`,
`consumed_revision=sha256:8968fd34635a5e5c7a83eafeace687b0438d1907b35f2cf72e070f16c3889df1`,
and `authority=burned`. The bracketed global RDD switch returned to `off`.
The isolated macm5 reviewer lifecycle is terminal and **PASS (scoped)**; do
not replay the acknowledgement. Overall P-4.4 remains **PENDING** its full
named pass-through contract, and P-4.2/P-4.3 and the four-host matrix remain
nonpassing. Effective aggregate counts remain **PASS 6, FAIL 0, PENDING 4,
BLOCKED 12** and cutover remains **NO-GO**.

## 2026-09-30 append-only rog selector and Git-state diagnostics

Six focused tests in pinned Go `internal/cli` passed (`go -C
/nix/store/5py0hxh75rwz96b0v3s5yjc1s3avl2hv-source test ./internal/cli
-run '^(TestOpenCodeReviewTransportRefusesAnUnrelatedHostAndReoffersTargetSlots|TestOpenCodeReviewTransportRefusesHostLensFrameValueTampering|TestOpenCodeReviewTransportRefusesStandaloneCompletionWithoutAuthorityMutation|TestOpenCodeReviewTransportSessionFailuresDoNotMutateAuthority|TestReviewInspectCandidateRejectsUnboundInput|TestReviewFacadeUnbornHeadStagedWithNothingStagedRefusesActionably)$'
-count=1` → exit 0). No model or provider was called.

For P-4.2, a read-only `gentle-ai review status` from `/tmp/opencode` with
`--cwd ./relay-proof` and from the unrelated main repository with explicit
`--cwd /tmp/opencode/relay-proof` both selected the same temporary target and
stopped with `rdd_disabled`, without mutating either worktree. The predecessor
gate says reject relative/outside-worktree Git selectors before *any*
subprocess. The V2 adapter receives no such selector; Go deliberately permits
explicit cross-repository target selection under its binding contract.
These CLI `--cwd` probes do not establish that the gate's intended selector
class is the same one, so P-4.2 remains **PENDING** clarification. Do not
introduce a parallel TypeScript guard or call this PASS by redefining it.

For P-4.3, `/tmp/opencode/check-review-git-state.py` exercised three
independent temporary repositories: clean index, staged tracked change, and
unstaged tracked change eligible for `git commit -a`. In every case,
selectorless native STATUS while RDD was off and an unbound Go relay START
refused without a provider prompt, preserving exact HEAD, porcelain status,
index entries, staged diff, and unstaged diff. These are **passing isolated
negative controls**, not the required proof for valid enabled review across
empty/staged/actual `-a` flows. P-4.3 remains **PENDING**. Nothing was staged,
committed, or changed in the main repository by these diagnostics.

Effective counts stay **PASS 6, FAIL 0, PENDING 4, BLOCKED 12**. The remaining
P-4.2 policy ambiguity and P-4.3 positive-case coverage block any inference
of completion; V1 remains default and cutover/verify/archive remain NO-GO.

## 2026-09-30 append-only Go-bound gate resolution and Nix activation correction

The project owner delegated the ambiguous selector policy with a clear goal:
OpenCode V2 should work within the same Nix/Home Manager-owned stack as V1.
The predecessor P-4.2 literal, "reject relative and outside-worktree git
selectors before any subprocess," describes a pre-Go adapter that no longer
exists. The pinned relay rejects all CLI arguments
(`internal/cli/review_opencode_transport.go:165-168`); Go resolves the opaque
repository context from the host's registered worktrees, without a caller
target path (`internal/reviewtransaction/repository_locator.go:431-481`).
Canonical relative/absolute/symlink aliases of one repository must be
**accepted as the same identity**; missing, escaping, and unrelated aliases
must not reuse that authority. The Go reviewer Task is not launched on invalid
binding. `go -C /nix/store/5py0hxh75rwz96b0v3s5yjc1s3avl2hv-source test
./internal/reviewtransaction -run
'^(TestRepositorySelectionAcceptsEveryCwdAliasOfTheSameRepository|TestRepositorySelectionRejectsAliasesThatAreNotTheSameRepository|TestGitCommonDirectoryMismatchFailsBeforeAuthorityMutation)$'
-count=1` exited 0, as did the focused Go CLI tests in the previous entry.
This **replaces** the obsolete P-4.2 acceptance wording at the Go authority
boundary; it does not claim the old relative-path rejection literally occurs.
No parallel TypeScript selector parser was added. P-4.2 is **PASS under the
corrected Go-owned contract**.

P-4.3 now has positive no-provider evidence as well as the negative controls:
`python /tmp/opencode/check-bound-review-git-state.py` exited 0 under an
isolated HOME/USERPROFILE/XDG_CONFIG_HOME and three disposable Git repos. A
clean candidate refused without mutation; a staged candidate (staged
projection) and an unstaged tracked candidate (the `-a`-eligible state)
each obtained native START, candidate-scoped consent, target-bound STATUS,
and one Go reviewer `prompt` frame before the expected
`provider_result_missing` on EOF. Exact HEAD, real `.git/index` bytes,
`ls-files` entries, porcelain status, cached diff, and unstaged diff matched
before/after in every case. The Go snapshot builder uses a private
`GIT_INDEX_FILE` for `read-tree`, `git add -u`, and `write-tree`
(`internal/reviewtransaction/snapshot.go:1195-1240`). No `git commit -a`
was run, because running it would itself mutate the test repository; the
gate concerns transport behavior *when that tracked state exists*. P-4.3 is
**PASS for the Go-owned no-stage/no-commit boundary**, not proof of shell or
ordinary Git commands outside review.

A separate Nix lifecycle defect was corrected in `shared/opencode.nix`:
`restartOpencodeV2` previously compared only generated `opencode.json` to
its stamp, so plugin/skills/runtime changes could be installed without a
reload. The new Nix-generated fingerprint covers the managed activation
script (which embeds plugin/command/skill/npm source paths), generated JSON
source, managed V2 environment, and pinned OpenCode2 package; the stamp is
written only after reload/restart succeeds. `nix fmt -- shared/opencode.nix`,
rog/thinkcentre/t14 Home Manager evaluations, rog toplevel evaluation, and
`nix flake check --no-build` passed on Linux. Native macm5 HM evaluation is
still unavailable here: its aarch64-darwin `gentle-ai-assets` derivation
cannot be built on x86_64-linux. No host was deployed in this round.

The historical P-4.2/P-4.3 FAIL/PENDING rows above remain as receipt history;
effective gate counts after this corrected-boundary decision are **PASS 8,
FAIL 0, PENDING 2, BLOCKED 12**. P-4.4 still needs its full named command
pass-through proof, and host/provider/BrowserMCP prerequisites still block
verify, cutover, and archive. V1 remains default and the decision is **NO-GO**.

## 2026-09-30 append-only rog native V2 inventory and command pass-through

With the managed V2 environment sourced (no isolated fake HOME), `opencode2
debug agents` and `opencode2 debug config` exited 0; the prior P-2.4 timeout
under an incomplete isolated environment is historical. `opencode2 api
agent.list` returned 30 agents, including all ten SDD phase agents, three JD
agents, six review agents, and orchestrator/neutral/managed. `opencode2 api
plugin.list` returned five active local V2 adapters. `opencode2 mcp list`
reported seven connected servers. The generated local MCP configuration
includes explicit empty `HTTPS_PROXY`, `HTTP_PROXY`, and `ALL_PROXY` plus
`NO_PROXY=*`; that is declarative scrub evidence, **not** a live network
non-leak proof. P-2.4 is now **PASS**, while the full P-3.7 runtime/proxy
gate remains **BLOCKED** pending empirical non-leak proof.

P-4.4's originally coupled phrase combines separate operations. The V2
review relay is selector-free and does not compose PR CLI commands. The
shell/RTK hook owns `gh pr create --head` handling; its actual `rtk rewrite`
returned `rtk gh pr create --head feature/review --base main`, preserved
`env TEST_FLAG=fixture` ahead of that rewritten executable, and refused to
rewrite `TEST_FLAG=fixture gentle-ai review status ...` (exit 1), so the hook
leaves that original command intact. `bun test shared/opencode/rtk-v2.test.ts
pkgs/gentle-ai-assets/opencode-review-transport.test.ts
pkgs/engram-assets/engram-v2.test.ts` passed (13 tests, 38 assertions) with
focused executable pass-through assertions and no PR creation or provider
invocation. P-4.4 is **PASS at the V2 shell/RTK and review-relay boundaries**;
this is not a paid PR action or four-host runtime receipt.

Effective gate counts are now **PASS 10, FAIL 0, PENDING 0, BLOCKED 12**. The
five local plugin registrations do not prove each adapter's behavioral smoke,
BrowserMCP `connected` does not prove paired extension/restart, and Linux
cannot supply native Darwin proof. Cutover, verify, and archive remain **NO-GO**.

### Rog BrowserMCP read-only partial runtime probe

`systemctl --user is-active browsermcp` returned `active`. `ss -ltnp`
showed one loopback broker listener at `127.0.0.1:9010` (PID 1534) and one
port-9009 listener (PID 27348). Two separate Streamable HTTP clients sent
`initialize` to the loopback broker and both received HTTP 200 with distinct
MCP session IDs; `tools/list` returned 12 tools for each session, with the
same listener PIDs after the second handshake. `go -C pkgs/nixos-scripts
test ./internal/browsermcp` exited 0. No browser tool was invoked: paired
extension behavior, unpaired negative response, two actual OpenCode workspace
sessions, and restart/re-pair recovery were **not tested**. R24 remains
**BLOCKED**; `connected` and two protocol clients cannot replace its full
four-host paired runtime proof.

`nix build .#checks.x86_64-linux.opencode-v2-agent-schema --no-link`
passed, and the thinkcentre/t14 NixOS toplevel drvPaths evaluated on Linux.
These do not substitute for native Darwin or host runtime execution. Gate
counts remain **PASS 10, FAIL 0, PENDING 0, BLOCKED 12**, with V1 default
and NO-GO unchanged.

## 2026-09-30 append-only macm5 native evaluation of published fix

The macm5 operator reported clean HEAD `10f64dc`, which contains the
published `bc127bb` Nix V2 reload correction (verified as an ancestor of
`origin/master`). `bun test ./shared/opencode/rtk-v2.test.ts` passed (1 test,
2 assertions). Native `nix eval '.#homeConfigurations.macm5.activationPackage.drvPath'`
returned `/nix/store/i9ignpkw80vmx3d13jm2yawqx38f18mk-home-manager-generation.drv`;
native `nix eval '.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath'`
returned `/nix/store/jnpq4ws1pwimd84lzslw316n73hjncp4-darwin-system-26.05.c3e90c8.drv`.
Together with prior Linux `nix flake check --no-build`, rog, thinkcentre,
and t14 toplevel/HM evaluations, the P-1.7 four-host **evaluation** gate is
**PASS**. This does not prove any host activated the latest fingerprint, that
the service reloaded, or any other runtime gate. P-5.3/P-5.4 remain BLOCKED
for broader format/test/runtime requirements. Effective counts become
**PASS 11, FAIL 0, PENDING 0, BLOCKED 11**. Cutover/verify/archive stay
**NO-GO** and V1 remains default.

### macm5 activation and integrated Home Manager fingerprint readback

The macm5 operator subsequently ran `nixos-build dry` and `nixos-build
switch` at HEAD `10f64dc`. Both completed, with Home Manager executing
`setupOpencodePluginRuntime-v2` followed by `restartOpencodeV2`. Authorized
read-only SSH as `juan@macm5.local` (no sudo) confirmed a clean tracking
worktree at that revision, the V2 service reachable at loopback port 49374,
five active local V2 plugins, and 13 connected MCP servers after the initial
config-load interval. The first immediate post-switch probe briefly showed
no MCPs; a subsequent probe reported all 13. No browser tools or providers
were invoked.

The active fingerprint must be compared against the **integrated** Darwin
Home Manager module, not standalone `homeConfigurations.macm5`: the latter
evaluates a different, unrealized stamp derivation. The no-sudo SSH command
`nix eval --raw "$HOME/.config/nix#darwinConfigurations.macm5.config.home-manager.users.juan.home.activation.restartOpencodeV2.data"`
resolved `/nix/store/j12f7vbg28bszndiqbad2qyr0lz7yciv-opencode-v2-managed-runtime-fingerprint`.
That store file exists, and `cmp -s` against
`~/.local/opencode-v2/managed-runtime.activation` succeeded. This proves the
Nix-owned V2 fingerprint was activated on macm5; it does **not** prove a
paired BrowserMCP call, restart/re-pair, four-host supervision, or V1 default
cutover. M-4.3 and R24 remain BLOCKED for their broader runtime requirements.
Effective gate counts remain **PASS 11, FAIL 0, PENDING 0, BLOCKED 11** and
the migration remains NO-GO.

## 2026-09-30 append-only native macm5 Go suite blocker

No-sudo read-only SSH to macm5 confirmed `nix fmt -- --ci` on clean HEAD
`10f64dc` traversed 776 files, processed 218, and changed zero. The native
Go 1.27.1 suite (`mise exec -- go -C "$HOME/.config/nix/pkgs/nixos-scripts"
test ./...`) failed in six tests; a focused `-count=1` rerun reproduced all
six independently. Four are tied to Darwin's `/var` → `/private/var` temp
canonicalization: three tests compare literal alias paths (`cmd/ai-backup`,
`cmd/code-work`, `internal/projectinit`), while
`internal/reporoot.TestFlakePathWorktree` exposes real worktree detection
behavior because `os.Getwd()` and the caller root use different aliases.
`internal/sshtunnel.TestPickFreePortBusy` selected an ephemeral port around
64,000, putting its `+10,000` fallback above 65,535. The
`internal/tmuxtapm.TestTPMRuntimePathIsGuardedAndInherited` fixture still
expects coreutils/gawk/git/tmux in the Nix PATH prefix after the newer
tmux module intentionally reduced that prefix to bash.

These are reproducible native Mac suite failures, **not** evidence that the
OpenCode V2 fingerprint or the completed macm5 reviewer relay regressed.
P-5.3 is now **FAIL** rather than merely platform-BLOCKED; do not waive the
Go suite or change its expectations without checking the actual Darwin
behavior. This is a separate bounded Go work unit, not authority to edit
the RDD/review transport or flip defaults. Effective counts become **PASS 11,
FAIL 1, PENDING 0, BLOCKED 10**; verify, cutover, and archive remain NO-GO.

### Scoped Darwin Go correction candidate, not yet native-verified

The six failures were investigated as a separate Go work unit in the clean
`/tmp/opencode/mac-go-fixes` worktree based on `origin/master` `10f64dc`,
without touching the dirty primary tree. A new Linux symlink-alias regression
for `reporoot.FlakePath` failed before a four-line canonical-root comparison
fix and passed after it; the returned external root spelling is preserved.
Three tests now compare canonical Darwin temp paths without changing CLI
behavior. The busy-port tests reserve a low requested/fallback pair so macOS
ephemeral ports cannot overflow 65,535. The TPM PATH assertion now checks
the intentional bash-only Nix prefix and inherited PATH. Focused tests across
the six affected packages, `go -C pkgs/nixos-scripts test ./...`, focused
`go vet`, `nix flake check --no-build`, and the Nix-built Linux
`nixos-scripts` derivation passed. No Go production component beyond
`reporoot.FlakePath` was modified, and no Nix or V2 adapter file changed.

These are Linux/build and regression proofs **only**. The worktree is not
committed or pushed; macm5 has not run the correction. P-5.3 stays **FAIL**
until its full native Mac suite and the remaining named matrix pass. Counts
remain **PASS 11, FAIL 1, PENDING 0, BLOCKED 10** and cutover stays NO-GO.

### Native macm5 verification of the scoped Go correction

The seven-file work unit was committed as `acb46bf` and published on
`origin/master` without force. After confirming the macm5 branch was clean,
authorized no-sudo SSH fast-forwarded it from `10f64dc` to `acb46bf`.
`mise exec -- go -C "$HOME/.config/nix/pkgs/nixos-scripts" test ./...`
passed across all native Darwin packages, including each of the six previously
failing tests. `nix fmt -- --ci` processed 218 files with zero changes.
Current-revision macm5 standalone Home Manager and nix-darwin toplevel
drvPaths evaluated to
`/nix/store/l80z2swa3glkl9rw3dl1a0xa9wl8slpg-home-manager-generation.drv`
and `/nix/store/r7nlrc88pn16ljg441k4jdyzkf5sawsg-darwin-system-26.05.c3e90c8.drv`;
`nix build "$HOME/.config/nix#packages.aarch64-darwin.nixos-scripts"
--no-link` built the native Darwin `nixos-scripts` derivation. Linux full Go
tests, flake check, host evaluations, Go vet, and nixos-scripts Nix build
passed earlier against the same correction. The first Mac SSH attempt hit a
transient mDNS `Device or resource busy` error; a bounded retry resolved
`macm5.local` and completed the current-revision eval/build.

P-5.3 is now **PASS** for its named formatting/Go/build/evaluation matrix.
This does not certify P-5.4 four-host live runtime, provider-funded rog
review, paired BrowserMCP recovery, or the default flip. Effective counts
become **PASS 12, FAIL 0, PENDING 0, BLOCKED 10**. V1 stays default and
verify/cutover/archive remain NO-GO.

### Operator-reported BrowserMCP use

The operator reports having tested BrowserMCP in normal use and that it works.
This is a positive functional smoke report; the operator did not provide a
host, exact tool/result, pairing state, two-workspace concurrency, unpaired
negative, or restart/re-pair receipt. No browser action or broker restart was
performed by the assistant. R24 remains **BLOCKED** for its full mandatory
scenario; the operator report must not be silently promoted to four-host
proof. Counts remain **PASS 12, FAIL 0, PENDING 0, BLOCKED 10** and NO-GO.

### Rog current-model and installed-relay preflight

The operator reports rog's OpenCode2 orchestrator using OpenAI GPT-6 Sol is
answering normally. The earlier HTTP 402 is therefore limited to that older
attempt, not proof that all current OpenAI calls fail. Rog's active
`review-reliability` agent is separately configured for OpenAI
`gpt-5.6-terra`; orchestrator success does not test that reviewer model.
A read-only inspection found the installed V2 review plugin still captures
`ctx.location.directory` at setup. It differs from the tracked relay source
that resolves each active session's cwd (`941512c` and descendants). RDD
global mode is off; the isolated rog fixture still has a pending changed
candidate. Do **not** spend another reviewer call against this stale installed
adapter or treat the 402 as a current global provider block. For a rog-scoped
opt-in proof, first activate the published Nix-managed V2 runtime from a
clean revision while preserving the dirty primary worktree, verify installed
bytes and the reviewer model, then re-enter native STATUS and run at most one
bound review. This is not authorization to switch V1 default or archive the
original four-host change. Counts remain **PASS 12, FAIL 0, PENDING 0,
BLOCKED 10** and NO-GO.

### Rog post-build reviewer attempt: still not admitted

The operator reports OpenAI GPT-6 Sol orchestration responds on rog, so the
earlier 402 is historical and not a current account-wide verdict. The live
rog V2 agent inventory assigns `gentle-orchestrator` to OpenAI `gpt-6.1-sol`
and `review-reliability` separately to OpenAI `gpt-5.6-terra`. The installed
plugin initially differed from the tracked per-session adapter, then a later
byte comparison matched it; the active service lists the adapter. This does
not establish when the process loaded its hooks. The V2 service PID 123255
started at 11:11 local time; plugin file bytes can change independently of
the already-running in-memory hooks.

With RDD enabled temporarily, native STATUS reoffered the unchanged
`review-4c157155da22bead` one-lens slot for the isolated rog fixture. One
ordinary `opencode2 run --agent build --model openai/gpt-6.1-sol` invocation
called the `review-reliability` subagent exactly once but returned
`opencode_review_transport_relay_refused: relay_unavailable`; the primary
step recorded cost 0 and no reviewer result was admitted. The session's
location.directory correctly pointed to the fixture. RDD was returned to
`off`, and no paid retry or alternative provider was attempted. The observed
failure is before reviewer dispatch; it does not prove `gpt-5.6-terra` lacks
funds, nor that stale hooks are the definite cause. Rog organic transport
remains **BLOCKED/failed scoped smoke**, while the successful macm5 receipt
is unchanged. Full four-host migration stays NO-GO with effective aggregate
counts **PASS 12, FAIL 0, PENDING 0, BLOCKED 10** pending bounded root-cause
diagnosis and a fresh rog receipt.

### Rog direct Go preflight and activation timing

A provider-free START-only frame through `gentle-ai review
opencode-transport` from the same rog fixture and frozen binding emitted a
valid `prompt` frame, then the expected `provider_result_missing` on EOF.
RDD was returned to `off`; no reviewer ran. The updated managed V2 stamp
has mtime `2026-09-30 19:45` local, while the live OpenCode2 service process
(PID 123255) started at `11:11` local. The installed plugin bytes now match
the corrected tracked source, but these facts do **not** prove the process
reloaded that source into memory. The Nix activation invoked its native
`reload` path without requiring a PID change. Stale in-memory hooks are a
strong hypothesis for the generic organic refusal, not a confirmed root
cause. The two-host rog review proof stays blocked and no further paid call
or disruptive service restart was attempted. The old 402 is not a current
account-wide finding; the reviewer model's availability was not reached.

### Rog Nix activation correction candidate, not deployed

The managed V2 fingerprint changed at 19:45 while rog's OpenCode2 process
had been running since 11:11. The Nix activation used `opencode2 reload`
first, which returned success without replacing that process; the runtime
still refused an ordinary review even though the installed plugin bytes
matched the corrected source. Pinned OpenCode2 client APIs expose
`location.reload` for config consumers, but no verified local-plugin module
re-import through that operation. A one-file correction in a clean detached
worktree changes only `shared/opencode.nix`: upon a changed managed runtime
fingerprint, the Nix activation invokes the native background service
restart instead of treating config reload as sufficient, and writes the
stamp only after success. An existing Home Manager assertion was updated
to guard the new boundary. `nix fmt -- shared/opencode.nix`, evaluation of
the rog activation script (fingerprint check precedes restart and stamp),
and Linux `nix flake check --no-build` passed. This is a **candidate fix**,
not proof that stale hooks caused the rog failure. No service was restarted,
and no commit, push, host deployment, or provider retry was performed.
The rog review remains BLOCKED and counts remain **PASS 12, FAIL 0,
PENDING 0, BLOCKED 10** with V1 default and NO-GO unchanged.

### Rog environment-independent reviewer invocation candidate

After the published `221a4e7` V2 shell PATH correction, a fresh ordinary
bound reviewer call still returned `go_refused` before the reviewer ran
(primary step cost 0). The service's native shell, from that same fixture,
found both `gentle-ai` and `git`, reported RDD on during a bounded diagnostic,
and emitted a Go `prompt` frame; the failed tool input contained the exact
provider-issued binding. A whitelist-only probe of the actual OpenCode2
service process environment found **neither** Nix binary directory on its
bare PATH. A service can start outside the Nix-sourced shell wrapper, so
shell-only PATH injection does not make the plugin child portable. The
native last-event/Go semantics are unchanged and no provider result was
admitted on rog.

A three-file correction in a detached clean worktree keeps the adapter thin:
its invocation defaults are substituted by the Nix `gentle-ai-assets`
derivation with the absolute Nix `gentle-ai` executable and Nix Git bin path;
only the Go child inherits that Git prefix. `lib/packages.nix` supplies the
existing Go derivation to assets. The package build fails if either exact
substitution site disappears. The built Linux asset contains both store
paths. With PATH reset to `/usr/bin:/bin`, a provider-free Bun test imported
that built asset and received a materialized Go prompt for the bound fixture.
Existing Bun relay/RTK tests passed (9 tests, 25 assertions), and Linux
flake check, rog Home Manager evaluation, and Darwin asset drvPath evaluation
passed. This is **not** an organic rog PASS: no new provider call, native Mac
build, commit, push, or deployment has occurred for the candidate. Effective
counts stay **PASS 12, FAIL 0, PENDING 0, BLOCKED 10**, with V1 default and
NO-GO unchanged.

### Nix-baked relay published, rog activation withheld for safety

The three-file Nix-built reviewer invocation fix was committed/pushed as
`387977d`. Its Linux asset build and focused Bun tests passed; the built
adapter materialized a real bound Go prompt under PATH `/usr/bin:/bin`
without any provider. The current-revision rog system toplevel built from
an explicit clean `--flake` path. **It was not activated.** The safety
preflight `opencode2 api session.active` timed out before NixOS test
activation. A live OpenCode2 process still listens on `127.0.0.1:49374`,
but the API returned HTTP 401 Basic on `/api/session/active` and the CLI
reported its managed service as stopped. No TCP clients were established
in a read-only `ss` snapshot; that does not prove zero background requests.
Rog `home-manager-glats.service` has separately failed since boot because
`ensureNvimConfig` could not resolve github.com at 09:43; DNS now resolves.
The managed V2 stamp still predates this published fix. No secrets were
read, authorization bypassed, service killed/restarted, provider called,
or cutover attempted. A legitimate authenticated idle check or operator
confirmation that no V2 requests are active is required before the
controlled activation. Rog reviewer proof and full migration remain
BLOCKED; effective counts stay **PASS 12, FAIL 0, PENDING 0, BLOCKED 10**.

### Rog clean activation and unresolved Go child refusal

The operator confirmed all rog V2 sessions closed. A first explicit clean
NixOS test activation still could not acquire the switch lock: an older
Home Manager generation had restarted after the transient GitHub DNS outage
and was stuck in its `opencode2 reload` activation while an orphaned V2
process held the service port. A read-only `ss` snapshot found no established
connections. After verifying the orphan PID belonged to OpenCode2 and was
outside Home Manager's service cgroup, a graceful SIGTERM of only that PID
freed the port; no SIGKILL, secret access, or arbitrary process cleanup was
used. The old activation failed/released the lock. A subsequent explicit
`sudo -n nixos-rebuild test --flake '/tmp/opencode/v2-reload-fix#rog'`
completed on the clean `387977d` tree. Home Manager became active with
exit 0, the integrated V2 fingerprint byte-matched its managed stamp, and
the installed adapter contained the Nix absolute Go/Git paths. Native
STATUS reoffered the unchanged bound one-lens fixture.

One bounded ordinary OpenCode2 reviewer invocation nonetheless returned
`opencode_review_transport_relay_refused: go_refused` before the reviewer
ran (primary step cost 0); RDD mode was returned to off. A direct Go START
via an existing OpenCode2 session shell in the same fixture emitted a prompt,
and the failed subagent tool input carried the exact Go-issued binding. Thus
binary installation, Home Manager, the target state, and parent prompt
identity are proven, but the plugin child's particular Go refusal is not.
The previous 402 remains historical and is **not** evidence of a current
model-funding error. P-5.4 is **FAIL for rog runtime**, with other-host
matrix components still unavailable: effective counts are now **PASS 12,
FAIL 1, PENDING 0, BLOCKED 9**. No cutover or archive is permitted.

A narrow diagnostic-only adapter candidate in the detached worktree now
recognizes four allowlisted Go pre-prompt error codes from stderr, appending
only the machine code to the existing go_refused transport error. It never
exposes stderr text, paths, bindings or reviewer content and cannot admit a
result. Fake-child regression includes a private-path string and asserts
that only the allowlisted code is emitted. Focused Bun tests (10 tests,
27 assertions), Linux Nix asset build, and flake check passed. This candidate
is **not committed, pushed, deployed, or a positive rog review**; no extra
provider call was used to obtain a diagnosis.

### Rog terminal organic reviewer receipt after diagnostic deployment

The two-file sanitized refusal-code candidate was committed/pushed as
`512a637`; the bounded fake-child suite passed (10 tests, 27 assertions).
Rog's clean NixOS toplevel built at that commit. An old Home Manager
activation held the switch lock while a password-protected orphan V2 process
held port 49374. The operator had confirmed all V2 sessions closed; a
read-only connection snapshot had no established clients. Graceful SIGTERM
of only the verified orphan released the port, the old job exited, and
`sudo -n nixos-rebuild test --flake '/tmp/opencode/v2-reload-fix#rog'`
successfully activated the clean `512a637` generation. Home Manager
reported `active`, exit 0; the managed fingerprint matched its integrated
stamp and the installed V2 plugin included the allowlisted diagnostic.

Native STATUS reoffered the existing frozen `review-4c157155da22bead`
`review-reliability` input. One ordinary V2 subagent call completed and Go
returned `gentle-ai.review-last-event-closure/v1` with `state=approved`,
`store_revision=sha256:07ef44fbeba630a8fb26a03bebe61bd227ccaa7a7c757c9108395020a0263a23`.
A fresh target-bound STATUS replayed the exact one-time acknowledgement;
it was executed once and returned `gentle-ai.review-acknowledged/v1`,
`action=acknowledged`, matching consumed revision, and `authority=burned`.
No acknowledgement token is recorded here. RDD global mode returned to
`off`. **Rog and macm5 now each have a terminal, scoped organic V2 reviewer
fixture receipt.** The prior rog pre-provider refusal and HTTP 402 remain
historical, not current blockers. P-5.4 is no longer FAIL on rog, but remains
**BLOCKED** as the original four-host runtime matrix was not run on
thinkcentre/t14 (operator intentionally excluded those hosts from near-term
use). Effective counts revert to **PASS 12, FAIL 0, PENDING 0, BLOCKED 10**;
shared V1 default, verify, cutover, and archive remain NO-GO.

### Rog stale-primary activation failure and clean recovery

On October 1 the operator's ordinary `nixos-build test` failed because
`home-manager-glats.service` attempted a V2 config reload followed by plain
`cp` over the mode-0444 managed stamp; the unit journal reported Permission
denied. That script came from the **outdated, dirty primary checkout** at
`/home/glats/.nixos/shared/opencode.nix`, where `NIXOS_REPO` forces the
wrapper to evaluate even when invoked from another directory. It was not
the published fingerprint/restart/stamp implementation. Without modifying
the primary worktree, a read-only preflight found zero active V2 requests,
the clean detached worktree at `512a637`, and DNS available. An explicit
`sudo -n nixos-rebuild test --flake '/tmp/opencode/v2-reload-fix#rog'`
succeeded; Home Manager returned `active`/exit 0, its integrated runtime
fingerprint matched the managed stamp, and the V2 service was reachable with
zero active requests. No provider was called or review acknowledgement
replayed. This recovers the **temporary test generation** only: plain
`nixos-build` will still select the stale dirty primary checkout, and its
boot-persistent state has not been updated by this recovery. Do not call
the original four-host migration complete or archive it. Counts remain
**PASS 12, FAIL 0, PENDING 0, BLOCKED 10** with V1 default.

### Primary checkout reconciliation after stale-build failure

The operator requested that all further work use the primary
`/home/glats/.nixos` checkout, not a detached worktree. The primary branch
had one local and twelve remote commits divergent, plus unrelated dirty
tracked and untracked files. The only dirty tracked path overlapping incoming
commits was `shared/opencode/providers-base.nix`; its local patch was placed
in a reversible targeted stash (object `48dd9d1104d1df1f3f528cc00cd56c042f39d5e7`),
leaving every other dirty/untracked file in place. A non-rebasing merge of
`origin/master` preserved both commit lines (merge `17ae454`); its one
`shared/opencode.nix` conflict was resolved to the published
`cp --remove-destination` form. Applying the targeted stash conflicted in
one `copilot-custom` model block: the local GPT-6.1-Sol explore/propose
choices and upstream Sonnet-5.5 spec/design choices were both preserved.
`providers-base.nix` is again an unstaged local edit, and the stash is
retained as a backup, not popped. No other dirty or untracked files were
staged or committed. Rog NixOS and Home Manager drvPath evaluations,
`nix flake check --no-build`, focused Bun V2 tests (10/10), `nix fmt` of
the two resolved Nix files, and `git diff --check` passed on the primary.
The now-clean temporary V2 repair worktree was removed; pre-existing user
worktrees were not modified. Primary master is ahead of origin by two
commits but not behind. No persistent `switch`, push of the merge,
V1-default change, verify, or archive occurred. Effective ledger counts
remain **PASS 12, FAIL 0, PENDING 0, BLOCKED 10**, decision NO-GO for the
original four-host migration.

### Rog primary activation confirmed after reconciliation

The operator ran `nixos-build` from the reconciled primary checkout. A
read-only postflight found `home-manager-glats.service` active/exited 0;
the managed V2 activation stamp updated on October 1 at 14:47 and
byte-matched the current primary integrated Home Manager fingerprint. The
V2 service was reachable on loopback port 49374 with zero active requests,
and the installed review plugin retained the Nix-built Go/Git paths.
`nixos-rebuild list-generations` listed generation 981 (built at 14:46:43)
as Current. The operator did not provide the exact nixos-build subcommand,
so this receipt does not assert more about boot behavior than the observed
generation. RDD remained off; no review or acknowledgement was rerun.
Primary Git still has two unpublished commits and unrelated dirty work.
This is native rog configuration activation proof, not a four-host
cutover/verify/archive receipt: effective counts stay **PASS 12, FAIL 0,
PENDING 0, BLOCKED 10**, V1 default, NO-GO.
