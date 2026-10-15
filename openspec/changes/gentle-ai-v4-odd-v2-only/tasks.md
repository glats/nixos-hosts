Superseded by adopt-gentle-ai-v4-odd-opencode2 (2026-10-15); content preserved as history.

# Tasks: One Gentle AI v4 / ODD Stack on V2

## Review Workload Forecast

| Field | Value |
|---|---|
| Observed changed lines | 3,115 implementation/consumer/test/runbook lines: 1,940 additions + 1,175 deletions across 31 owned paths; migration tracking artifacts counted separately in apply-progress.md; generated/foreign work excluded |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Preparation → atomic migration → authorized proof/docs; PR shape pending |
| Delivery strategy | exception-ok |
| Chain strategy | single coherent change; user accepted size:exception (Engram #3902) |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: single coherent change; accepted size:exception
400-line budget risk: High

Implementation authorization: user approval recorded in Engram #3902 supersedes
the earlier planning-only stop for candidate implementation. It does not
authorize staging, commits, push, PRs, live model calls, activation, service
restarts, decryption, or CLI/SDK upgrades. Production generations remain active.
Historical proposal/design/exploration snapshots are intentionally unchanged.

### Suggested Work Units

| Unit | Goal | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|
| 1 | Regression fixtures | `bun test pkgs/gentle-ai-assets/opencode-review-transport.test.ts`; `python3 shared/opencode/v2-agents.test.py`; `python3 shared/opencode/home-launcher.test.py` | N/A: inert | Remove fixtures |
| 2 | Atomic migration | `nix flake check --no-build`; `nix build .#gentle-ai-assets` | N/A: candidate only | Revert migration paths |
| 3 | Authorized proof/docs | Host eval matrix | Native receipt/delegation | Restore pins/assets/generations |

## Phase 1: Preparation Regression Fixtures

- [ ] 1.1 Extend existing `pkgs/gentle-ai-assets/opencode-review-transport.test.ts`, `shared/opencode/v2-agents.test.py`, and `shared/opencode/home-launcher.test.py`; capture RED locally, commit no failing tests. Cover eight threats: documentation classification; git cwd; signed-task/no-consent index; push refs; PR non-authorization; missing/wrong runtime/declaration, spaces/quotes, Linux/Darwin/server/standalone; wrong-role/replay/stale/background/session-reuse/empty/truncated/duplicate/disposed; foreign/modified/symlink-escape and archive/auth preservation. Use upstream classifier (read-only), sandbox `jq`, assert unchanged authority/refs/index.
- [x] 1.2 Add inert cases in `pkgs/gentle-ai-assets/opencode-review-transport.test.ts` and new `pkgs/gentle-ai-assets/render_test.go`; preserve raw output, dispatched `agent`, and `rolebound`/`relay`/`nonce`/`failclosedcapcheck`. Adapters never parse authority/verdict; no policy engine.

Partial fixture coverage: 1.1 has upstream content-classification/transport tests,
local relay/graph/wrapper checks and ownership conflict/history preservation
proof, not the full eight-family authorization/runtime matrix. 1.2 inert fixture
scope is complete: 24 tagged-relay Bun tests cover opaque bytes, role/nonce,
cross-session/call binding, duplicate/replay/disposal, quoted cwd and incomplete
frames; exporter native discovery/render checks pass. Exact-tag native Go tests
own wrong nonce/role, stale authority, runtime/declaration/capability and budget
refusal proof (55 CLI top-level/197 subtests), not plugin authority logic.
Transport fixture completion does not certify organic host/runtime compatibility.
1.1 remains partial: native read-only Git/consent/structured-ref and nondeciding
delivery checks are now proven; arbitrary no-consent staging/push/PR behavior is
repository/user-policy guidance, not a native delivery-enforcement mechanism.

## Phase 2: One Atomic Candidate Migration

- [x] 2.1 Update `flake.nix`, `flake.lock`, and `pkgs/gentle-ai/default.nix` to v4.0.0, valid hash/toolchain, provenance, registry root, and config-scoped wrapper; CLI/SDK 2.0.14 stays absent approved coupling evidence.
- [x] 2.2 Update `pkgs/gentle-ai-assets/default.nix`, `pkgs/gentle-ai-assets/render_test.go`, and `pkgs/gentle-ai-assets/v2-plugins/`; build-only vendored Go exports from upstream source (read-only), no CLI. Test with `nix build .#gentle-ai-assets`, not root Go.
- [x] 2.3 Update `shared/opencode.nix` and `shared/opencode/runtime-config.nix` for existing HM wrapper/environment, private PATH, host-config/RTK/Engram, and plugin ownership; retain `opencode2`/`opencode2-home` roots.
- [x] 2.4 Update `shared/opencode/{agents.nix,v2-agents.nix,local-agent-overlays.json,providers-base.nix}`, `shared/ai-assets.nix`, `shared/claude-code.nix`, `shared/assets/skills/`, `shared/shell-aliases.nix`, and `docs/gentle-ai-update.md`; atomically replace graph/assets/owned cleanup, preserve provider policy, foreign files, archives, and selected-work links.

Phase 2 checkmarks mean candidate implementation/configuration achieved, not
complete acceptance verification, platform certification or deployment. Existing
`shared/ai-assets.nix` source lists were reused unchanged; consumer integration
uses the new immutable union-tree helper. Selected migration/history links and
future unfinished-work selection/handshake are documented; no bulk conversion
or production ODD document was created. Native Darwin, organic runtime/model/MCP,
behavioral authorization/recovery and actual fleet rollback remain Phase 3 gates.

## Phase 3: Authorized Proof and Cutover

- [ ] 3.1 Add recovery assertions in `shared/opencode/v2-agents.test.py` and `shared/opencode/home-launcher.test.py` for contract `odd/tasks/<feature>.md` (read-only) and Engram topic `odd/<feature>/tasks` (read-only): IDs, readback, outage/pending mirror, conflict, interruption, no conversion/deletion; no production ODD docs.
- [x] 3.2 Map S1–S14: pin; enabled; disabled/legacy; grants; commands; runbook; gate; routing; admitted roles; refusal; authorization; recovery; cutover; continuity. Run `go -C pkgs/nixos-scripts test ./...` only if helpers change; otherwise use Python/Bun commands.
- [x] 3.3 Run `nix flake check --no-build`; Linux `rog/thinkcentre/t14` system+integrated HM, Darwin `macm5` system+integrated HM, four standalone HM drvPaths, native builds separately. Darwin IFD is unknown outside Mac; unavailable is UNVERIFIED.
- [ ] 3.4 After proof and explicit model/network plus ODD delegation/MCP authority, run rog-first receipts then host proof; update `docs/gentle-ai-update.md` rollback gates. No activation, commit, push, PR, or SDK bump without separate approval.
- [ ] 3.5 Verify rollback restores pins/assets/HM generations and preserves credentials, sessions, receipts, OpenSpec history, dirty branch/index, and archives; stop before activation or publication.

Phase 3 status: 3.1 now asserts the full rendered identity/readback/outage/conflict/
resume contract, but ODD file/mirror orchestration is model instructions, not a
shipping Go persistence executor; LLM compliance is not offline-proven. Native
read-only recovery diagnostic checks pass, not ODD task-store recovery behavior.
3.2 scenario mapping/test inventory is complete, not scenario acceptance.
3.3 has flake check and nine Linux evaluations. The initial native Darwin runtime
discovery failure remains unexplained history; the unchanged renderer passes its
actual three-second discovery test on explicit reprobe (#3952). A separately
authorized acceptance continuation now passes Darwin system/integrated juan HM/
standalone HM evaluations, explicit native binary/assets aggregate build and full
native Darwin system plus standalone HM build (#3957/#3958). Full native Linux
builds subsequently passed for all six system/standalone targets, including
integrated HM closure membership (#3968). These certify the original reviewed
source. The approved three-profile retirement and same-backend NVIDIA alias
received final-source regates: Linux shared check, nine evaluations, six native
builds and built schema check (#3992/#3993), plus a fresh final-source Mac handoff,
three evaluations, native binary/assets and full system/standalone builds with
integrated closure membership (#4001/#4002). Task 3.3 is complete at fingerprint
`12d82f4746470b91b04967bea52842e70537a70492c3a382606ee08b200f9dfb`;
see `native-final-readiness-check.md` for exact receipts. Native build success is
not organic CLI/runtime certification or activation. 3.4 received
bounded initial rog model/MCP authorization (#3931), but stopped at credential-
isolation preflight (#3932): no inherited OpenAI key and no established safe
read-only saved-account route; no server/session/model call or receipt created.
User approval #3983 explicitly reopened private native login and a bounded rog
cycle. Private OAuth and native guard/controller readiness now pass. The latest
cycle (#4128) proves foreground parent/worker lineage, configured Luna model and
succeeded child completion. Native shell evidence proves assertion RED 1 to
GREEN 0 across ten typed inputs, preserved test bytes and final GREEN byte
equality (#4133). After GREEN the worker ran an excluded Git status command
masked with `|| true`; it disclosed that action and the parent stopped without
ODD readback/mirroring. Scope compliance failed. Model-free Engram reads pass;
full mirror/recovery and native review receipts remain unaccepted. Offline
initial-absence, setup-batching and terminal-scope prompt fixes
(#4112/#4125/#4137) pass eleven pure suites and strict typing, not future model
compliance. A subsequent cycle (#4140) passed full TDD without worker Git commands,
but its parent exhausted eight steps before ODD readback and omitted pre-write
mirror/readback. Offline coherent checkpoint ordering and fresh final-evidence
windows now pass twelve pure suites, strict typing and scoped independent review
(#4153/#4157/#4159); they do not certify runtime ODD compliance. Approval #4140
is consumed. A later ordered-checkpoint cycle (#4161) stopped after two HTTP
admissions when the parent performed catalog-only setup and ended the turn.
No worker or ODD was created. Its same-execute setup correction (#4168) passes
scoped review, Node-only sequencing scenarios and twelve pure suites (#4173),
not native/model-compliance certification. Approval #4161 is consumed. The October
14 preflight17 continuation likewise consumed two preparations/HTTP admissions:
native project discovery and registry search succeeded, but the parent omitted
the full registry get and stopped before any ODD/worker stage (#4179). No native
error or exhausted budget was demonstrated. Administrative registry selection
and a genuine 50-skill current-index refresh now have exact full file/Engram
readback proof (#4186), not organic parent compliance. Owned groups are closed;
the failed cycle was not retried. A separately approved preflight18 cycle (#4189)
also stopped at two admissions without a full get (#4195). Current registry457
was absent from its top ten hits; administrative expanded search retrieves it,
but historical same-topic records make topic-only selection ambiguous.
The harness now gates same-parent TASK on a read-only bootstrap with one distinct
search-bound full get matching complete native registry bytes (#4201). Scoped
independent review, strict typing and thirteen pure suites pass (#4203); original
ODD/recovery proofs, steps8/global20/20/deadline and product fingerprints are
unchanged. Approval #4206 then exercised preflight19: eight preparations/HTTP
admissions, complete native registry/skill reads and successful config20 search,
but zero observation gets before the eighth text-only generation (#4212).
`bootstrap_registry_unproven` reproduces from actual retained context; no TASK,
worker or recovery was issued. No parser/native/MCP error or exhausted global
budget was demonstrated. Owned groups are closed, all source/config/index hashes
unchanged, and #4206 is consumed. Another paid cycle requires explicit approval;
no step/budget increase, fallback or proof relaxation is authorized. Task 3.4
remains unchecked. See
`live-rog-cycle-check.md` for distinct attempt evidence. No production
database/account copy, model/version fallback, activation, or Git delivery is
authorized. 3.5 now has actual immutable consumer-tree
synthetic rollback/retry, modified refusal and synthetic credential/session/
receipt/OpenSpec/ODD/mirror preservation proof, not real pins/generation restore.

## Apply Checkpoint — 2026-10-08

The coherent candidate is now wired into the actual flake: source/binary/assets,
rendered ODD graph, tagged relay, native private HM wrapper, isolated registry,
provider mappings, Claude/OpenFang consumers and conservative ownership cleanup.
Installed production generations remain unchanged. Candidate NONLIVE validation
is recorded; COMPLETE verification/deployment is not claimed. Phase 2 is 4/4
implemented; Phase 1 is 1/2 fixture tasks complete; Phase 3 is 1/5 task actions
complete (scenario mapping only). Remaining acceptance gates above are not
implied passes. Accepted `size:exception` remains valid.

The actual asset package imports the exporter and builds successfully with the
canonical vendorHash `sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=`.
Both candidate Python suites, all 24 tagged-relay Bun tests, actual Nix CLI
V2/Claude/OpenFang ownership/multiupgrade fixtures, ordinary full Go suite,
focused uncached Go race tests, flake check and nine Linux evaluations pass.
Expanded sandboxed tagged Go contracts pass 64 top-level/243 subtests; JSONL
evidence is retained by `pkgs/gentle-ai-assets/contracts.test.py`.
Darwin cross-compile is compile-only; native Darwin/live/fleet proof is pending.
The broad Go race run fails unrelated netconsole test fixture races; it is not
reported green. Historical migration RED and its later GREEN are retained in
`apply-progress.md`, not presented here as current failures.

Independent focused review #3923 confirms P1/P2 resolved: actual Nix CLI preserved
178 post-journal edits with zero overwritten; second-generation pending retry
works, clears retry authority and retains original rollback bytes. The residual
external-editor check-to-rename window remains disclosed. This review is scoped
ownership evidence, not full migration acceptance or delivery authorization.

Full commands, output paths, limitations and continuation are recorded in
`apply-progress.md`. This SDD migration remains the explicit selected work;
no production ODD feature document or bulk historical conversion was created.
