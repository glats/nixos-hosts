## Exploration: Gentle AI v3 on the already V2-only fleet

### Current State

Snapshot: 2026-10-07. This is the NEW change `gentle-ai-v3-v2-only`, not a continuation of `gentle-ai-v3-opencode-v2-multihost`. `openspec/config.yaml` declares hybrid persistence. Mandatory Context7, GitHub-personal identity/source/issues/prior-art, and Exa research preceded repository inspection. This is exploration; the formal sdd-research phase and its historical blocked gate do not apply. Only this artifact and Engram observations were written; no pins, code, state, proposal, activation, live model calls, commits, or PRs were authorized.

The primary checkout is actually on `feature/rog-on-demand-ssh-relay-transport`, HEAD `152eb8c84beebb9f322f47108b442af8c71acc34`, with substantial unrelated dirty relay/code/document/artifact work. Retirement commit `4ed62bac3e06120ea361ef757bf4aaf6bfc36292` is an ancestor of this HEAD. Do not switch branches, stage the dirty tree, or treat this checkout as a clean master candidate. The orchestrator reports retirement committed/pushed on master and rog deployment post-verification PASS at the exact candidate, fresh standalone PONG and all seven MCPs; macm5 retirement deployment is intended but not verified. No remote deployment verification was attempted here.

| Surface | Refreshed evidence |
| --- | --- |
| Canonical Gentle source | `flake.nix:77` pins v2.5.0, commit `f5dd1a6cf1823371374c7b2bef5b71e4790a146a`; installed store binary reports `gentle-ai dev`, not a release version string |
| OpenCode | Bare `opencode` is absent from the inspected PATH; `opencode2 --version` reports `opencode v2.0.14` |
| V2 SDK | `pkgs/opencode-npm-packages-v2/versions.json`: plugin/client/schema/protocol 2.0.14, Effect 4.0.0-rc.112 |
| Latest published v3 / target | v3.7.0, published 2026-09-23; commit `6dee8f833aec9e46015759c5065a9035795d9af1`, annotated tag object `7ef749d12023d8d390b3cc3d0557f20176a200b1`; refreshed releases AND tags on October 7 found no newer v3 patch |
| Target Go | Module `github.com/gentleman-programming/gentle-ai/v3`, `go 1.25.10`; entry remains `cmd/gentle-ai`; existing vendorHash cannot be reused without recomputation |
| Target provider contract | Release contract 1.2.0; wire `gentle-ai.provider-transport/v1`; unchanged identifiers are not full behavioral equivalence proof |
| Platforms | rog/thinkcentre/t14 x86_64-linux; macm5 aarch64-darwin; all four also have standalone Home Manager outputs |

The current integration is declarative Nix, not upstream install/sync. `pkgs/gentle-ai-assets/default.nix` already removes delivered `opencode/plugins` (V1) and installs three repo-owned native V2 adapters into `opencode-v2/plugins`. `shared/opencode/runtime-config.nix:77-87` loads these plus local host-config/RTK and the Engram V2 adapter. It still consumes upstream `opencode/commands`; `shared/opencode/agents.nix:20` consumes `sdd-overlay-single.json`, persona and root AGENTS.md. These source assets are not an active V1 runtime and must not be deleted merely because their directory is named `opencode`.

#### Decisive receipt capability boundary

At exact v3.7.0, `internal/cli/review_transport_capability.go` admits OpenCode immutable receipt review ONLY if `GENTLE_AI_OPENCODE_RELAY_CONTRACT` is empty AND runtime detection succeeds with major V1. `internal/opencode/runtime.go` probes literal `opencode --version`, bounded to three seconds / 4096 bytes, and parses `^(?:opencode |OpenCode )?v?([12])\.[0-9]+\.[0-9]+$`. It has no `opencode2` fallback. Today's `opencode v2.0.14` output would parse as V2 if probed, but bare `opencode` is absent, so detection fails. Either condition leaves review unsupported.

`internal/cli/review_opencode_transport.go` applies that SAME capability gate before reading relay input. Both native negotiated review and the repo-local relay therefore refuse on this V2-only fleet with `immutable_review_transport_unsupported`. Upstream tests explicitly assert refusal before input for V2/unknown and prevent a staged V2 declaration from inheriting V1 capability. No plugin replacement, true-version wrapper alias, or environment declaration can enable this v3 capability. Fake V1 versions, bypassing admission, reintroducing V1, and lifetime dual stacks are excluded.

This is a genuine baseline-to-target capability regression, not merely an unproven promise: the later migration ledger records scoped terminal approved/acknowledged receipts on macm5 and rog with v2.5.0. Earlier historical explorations' runtime-unproven statements do not erase those later exact-case proofs. They do not prove all-host stability or v3 compatibility either. Ordinary advisory code review can still inspect code and report findings; it cannot mint Go-owned immutable receipts or satisfy receipt-authority gates. Requesting v3 does NOT authorize disabling receipt review.

#### Compatibility inventory

- SDD is present at v3.7.0: status, preflight, attempt, task-result and archive-compose CLI implementations, all SDD graph agents including research, root skills and shared protocol assets. The local V2 adapter's `sdd-status --cwd ... --json` and `sdd-task-result --phase ... --cwd ... --input ...` forms remain accepted. The failure schema remains `gentle-ai.sdd-task-result-failure/v1` with empty/malformed/latched terminal codes. Exact output and continuation semantics still require regression tests, not just flag-name checks.
- Upstream ships five `opencode/plugins-v2` assets built/typechecked against SDK 2.0.4; the repo deliberately uses its own 2.0.14 adapters. Upstream SDD adapter adds grouped preflight and differs in continuation/API semantics. Do not wholesale adopt it. Local `sdd-task-result.ts` protects completed results, ignores running background acknowledgements, and latches typed failures; its phase list still omits research, a known gap separate from this exploration's no-research scope. Preserve these semantics; do not import a new formal research gate accidentally.
- Repo relay uses the compatible start/prompt/complete/result wire schema, but currently maps unsupported admission into generic `go_refused` rather than preserving the precise code. If a limited upgrade is accepted, narrow diagnostic compatibility may be necessary; it must not fake success or weaken Go admission.
- Source-owned override is NOT automatically redundant: `pkgs/gentle-ai/default.nix:24-26` still patches the embedded V1 skill-registry asset. Delivered V1 plugins have already been removed from the asset derivation. Upstream's V2 plugin uses `ctx.location.directory`; local V2 registry uses `process.cwd()`. Neither observation alone proves the embedded override can be deleted. Drop only with behavior regression proof for the affected source/runtime paths.
- Target binary's `internal/skillregistry/registry.go` still scans literal `~/.config/opencode/skills`, not `~/.config/opencode-v2/skills`, and does not honor the isolated V2 root in the inspected source list. Other Claude/Codex/shared roots can populate the registry, but equivalent content does not prove correct V2 path ownership. A fixture must prove generated registry paths resolve into canonical current managed skills without requiring archived V1 files. Fix at the narrow source-owned scanner layer only if the fixture fails; do not recreate V1 delivery or add a new manifest/Go entry point.
- The binary embeds `all:opencode` upstream, including source V1 assets; registry/runtime detection read executable/home paths independently of this embed. Retaining inert upstream embedded source is not reinstalling V1. Explicitly verify no V1 plugin paths reappear in deployed config; upstream `plugins-v2` copied into the asset package must not become accidentally auto-loaded alongside local adapters.
- Shared assets also feed Claude Code (`shared/claude-code.nix`) and other consumers. Upstream AGENTS.md/skills changes can alter model/review/workflow policy even when local adapters stay unchanged. Compare generated graph, permission order, executor prompts, model routing, provider allowlist, MCP environments, Engram paths, and local overlay precedence before/after.

#### Refreshed external evidence and applicability

All source paths below were inspected at v3.7.0, not main. Release age or issue counts were not used as stability proof.

1. [v3.7.0 release/provenance](https://github.com/Gentleman-Programming/gentle-ai/releases/tag/v3.7.0), [tags API](https://api.github.com/repos/Gentleman-Programming/gentle-ai/tags?per_page=100), [tag object](https://api.github.com/repos/Gentleman-Programming/gentle-ai/git/tags/7ef749d12023d8d390b3cc3d0557f20176a200b1), [go.mod](https://github.com/Gentleman-Programming/gentle-ai/blob/v3.7.0/go.mod): exact target, module/toolchain, contract 1.2.0. No newer released v3 fix found.
2. [Capability source](https://github.com/Gentleman-Programming/gentle-ai/blob/v3.7.0/internal/cli/review_transport_capability.go), [relay source](https://github.com/Gentleman-Programming/gentle-ai/blob/v3.7.0/internal/cli/review_opencode_transport.go), [runtime detection](https://github.com/Gentleman-Programming/gentle-ai/blob/v3.7.0/internal/opencode/runtime.go), [negative tests](https://github.com/Gentleman-Programming/gentle-ai/blob/v3.7.0/internal/cli/review_opencode_v2_capability_test.go): conclusive no-V2 receipt capability, including missing bare command.
3. [Target compatibility doc](https://github.com/Gentleman-Programming/gentle-ai/blob/v3.7.0/docs/opencode-compatibility.md): V2 native review unavailable; scripted ordinary-child transport tests are not isolated reviewer/authority/real-model proof. Darwin fixture evidence does not transfer to Linux or SDK 2.0.14.
4. [Issue #4984](https://github.com/Gentleman-Programming/gentle-ai/issues/4984), still open on refresh: v3.7.0 / Linux / OpenCode 2.0.16 V2 refusal, consistent with target source. Historical #5117/#5126/#5129/#4805 were V1-side reports, not proof of target V2 faults. [#5094](https://github.com/Gentleman-Programming/gentle-ai/issues/5094) reports v3.7.0 Windows/Pi lineage timeout; relevant caution for a separate alternate-runtime route, not a demonstrated Linux V2 timeout.
5. [PR #4728](https://github.com/Gentleman-Programming/gentle-ai/pull/4728): v3 partial V2 groundwork, not complete certification. [PR #5115](https://github.com/Gentleman-Programming/gentle-ai/pull/5115): native V2 review work belongs to the later v4 release, not v3.7.0. [PR #5110](https://github.com/Gentleman-Programming/gentle-ai/pull/5110), open on refresh: V2 model-catalog hardening, not released v3 receipt support. Do not infer tag fixes from closed/merged main PRs; current main also advertises unreleased contract changes.
6. [Issue #5364](https://github.com/Gentleman-Programming/gentle-ai/issues/5364): legacy statusline/logo installer state on Windows, not a demonstrated defect in this already-cleaned declarative V2 deployment. Old sync ownership/SDK provisioning issues are bypassed only because this change does not run unmanaged install/sync; binary runtime gates are NOT bypassed by Nix.
7. Context7 `/websites/opencode_ai_v2` and Exa independently retrieved official [plugin migration](https://opencode.ai/v2/docs/build/plugins/migrate-v1) and [V1 migration](https://opencode.ai/v2/docs/migrate-v1/): implementations require real porting, V2 uses domain hooks/native schemas and ordered permissions. These current docs establish API principles, not empirical compatibility of every current example with pinned 2.0.14.

### Affected Areas

- `flake.nix`, `flake.lock` — canonical v2.5.0 to exact v3.7.0 source pin only, after product decision.
- `pkgs/gentle-ai/default.nix` — new vendorHash, Go toolchain compatibility, embedded override proof, honest version/provenance verification; no new entry point.
- `pkgs/gentle-ai-assets/default.nix`, `pkgs/gentle-ai-assets/skill-registry-worktree-root.ts` — target asset inventory, retain V1 delivered-plugin removal/local V2 selection, conditional override deletion only.
- `pkgs/gentle-ai-assets/v2-plugins/{sdd-task-result,opencode-review-transport,skill-registry}.ts` and `pkgs/gentle-ai-assets/opencode-review-transport.test.ts` — preserve existing contracts; change only a demonstrated target incompatibility/diagnostic, not a transport capability workaround.
- `shared/opencode/{agents,v2-agents,v2-permissions,runtime-config}.nix`, `shared/opencode/local-agent-overlays.json` — compatibility review of target graph/assets with canonical V2 emission; not a presumption that all require edits.
- `shared/ai-assets.nix`, `shared/claude-code.nix`, `shared/skills/`, `pkgs/local-ai-assets/` — shared assets and later-wins local protocol overrides; enumerate final SDD/reviewer consumers before replacement.
- `shared/opencode/v2-agents.test.py` — existing test asserts historical V1 runtime output parity despite completed retirement; characterize this stale expectation before narrowly rebasing regression assertions. Never restore V1 to make it pass.
- `docs/gentle-ai-update.md`, `docs/gentle-ai-omo-workflow.md` — update canonical release/provenance and explicit limitations if adopted; unrelated dirty cutover docs stay untouched here.

Unchanged invariants: `pkgs/opencode-v2/`, V2 npm pins, `shared/shell-aliases.nix` isolated `opencode2`/Darwin-only `opencode2-home`, providers/MCP/Engram, auth/session roots and archives, per-host imports, retirement fail-closed auth seeding and safe remote asset sync. Overlays/package indexes need review, not new exposure plumbing. No XDG cutover, repeated retirement, new manifests, or CLI upgrade without explicit coupling proof.

### Approaches

1. **Pin v3.7.0 with an explicitly accepted OpenCode receipt limitation** — keep SDD and local 2.0.14 adapters, make only necessary package/asset compatibility changes.
   - Pros: smallest v3-only change; canonical source/assets; preserves isolation and SDD; no CLI upgrade.
   - Cons: native AND relay immutable receipt review unavailable on OpenCode V2; ordinary advisory review is not equivalent. Default-on RDD introduced in v3.5 can produce a typed stop; disabling/scoping mode requires user approval and is not performed here.
   - Effort: Medium, conditional on operator accepting the actual capability tradeoff and validation gates.

2. **Defer v3 while preserving the current single V2 stack** — retain v2.5.0 until a released SDD-preserving v3 admits V2 with adequate proof, or the user accepts the limitation.
   - Pros: preserves scoped proven baseline receipts; no fake capability or dual stack; minimal immediate risk.
   - Cons: does not yet fulfill the requested v3 upgrade; no released newer v3 route was found. Early v3.0/3.1 absence of explicit gating is not stability/certification evidence and is not recommended as an escape hatch.
   - Effort: Low.

3. **Separate supported Claude/Codex receipt route** — v3.7.0 compiles Claude prompt-carried and Codex scratch-process receipt transports without V1. Both executables are visible locally, but authentication, target-host availability, policy equivalence and complete runtime proof were not tested.
   - Pros: potentially retains receipts without V1 if the user chooses another runtime for that workflow.
   - Cons: separate product/routing scope, not native OpenCode V2 receipt support; no automatic runtime substitution, forged `--agent`, inferred auth, or silent transfer of authority is admissible.
   - Effort: Medium–High; requires explicit choice and separate proof, not assumed as the recommendation.

### Recommendation

Defer implementation and obtain the receipt-capability decision first. If the user explicitly accepts the limitation, approach 1 is the minimal candidate: exact v3.7.0, current CLI/SDK 2.0.14, existing local adapters, necessary source/assets compatibility only. Do not adopt upstream plugins wholesale or force v4/ODD. If immutable receipt review through OpenCode V2 remains mandatory, approach 2 is the safe recommendation; v3.7.0 cannot meet it. Alternate Claude/Codex routing is an optional separate decision, not an implicit solution.

Candidate acceptance must include the following distinct proofs, none run or marked PASS by this exploration:

1. Sandboxed Linux/Darwin Gentle package/assets builds with recomputed vendorHash and selected Nix Go toolchain satisfying 1.25.10; no build-time network/toolchain fallback, no hidden active V1 assets, all required source command/graph/Claude/shared skill files present. Verify provenance despite current `dev` version string.
2. Focused relay, task-result and Engram Bun/TypeScript tests, `go -C pkgs/nixos-scripts test ./...`, relevant Python generated-graph/launcher tests, target binary SDD flag/failure-schema fixtures and upstream negative capability tests. Address only demonstrated stale/incompatible expectations with preserved V2 behavior.
3. `nix flake check --no-build`; separate NixOS toplevel evaluations for rog, thinkcentre, t14; separate native Darwin toplevel and integrated HM evaluation for macm5; all four standalone HM activationPackage evaluations. Asset `builtins.readFile` introduces IFD/platform constraints: unavailable native Darwin build/evaluation is UNKNOWN/BLOCKED, not PASS from Linux flake checks.
4. Generated config/agent/provider/model/permission/MCP parity against the current candidate baseline, final skill/executor prompt/path ownership, registry fixture without archived V1 files, no new globally accessible provider, and no auth/session/receipt state reset. Check local overlays win as intended after upstream assets change.
5. Only under later explicit authorization: rog-first isolated candidate plugin boot, real SDD delegation with terminal result admission and background/empty/malformed/latch cases, MCP plus Engram reachability, exact native AND relay receipt refusal (or complete supported alternate-runtime lifecycle if separately selected), then distinct native macm5 and thinkcentre/t14 runtime proofs. rog-first staging does not exclude Darwin or imply fleet readiness. No live models were called here.
6. Version rollback preserves V2 roots, immutable historical receipt/state readability and independent Home Manager/system generations; do not roll back through archived runnable V1 or rewrite newer authorities into older formats.

### Risks

- Product blocker: OpenCode V2 immutable receipts would be removed by this v3 target; the user has not accepted that loss. A green advisory review or plugin-load check cannot satisfy it.
- Go toolchain/vendorHash/build sandbox, source scanner V2 path ownership, generated policy/asset regressions and native Darwin/standalone IFD evaluations remain unproven.
- Local relay diagnostics currently hide the exact unsupported code; target receipt refusal must not be misreported as successful relay certification or a transient retryable model failure.
- Baseline scoped receipts and rog retirement PASS do not prove v3 or all hosts; macm5 retirement deployment remains unverified in this handoff.
- Dirty feature checkout includes unrelated staged/untracked changes; candidate construction and eventual commits must isolate the authorized source/asset delta without changing that work.

### Ready for Proposal

No — exploration is complete, but one product decision is unresolved. Ask whether to (a) accept v3.7.0 with no OpenCode V2 immutable receipt review while preserving SDD/advisory review, (b) defer v3 and preserve the existing V2 receipt path, or (c) separately scope a real supported Claude/Codex receipt workflow. Do not equate the new-change request with receipt-loss consent. No formal research gate is inherited, and no proposal/state/implementation should be created by this executor. Stop after exploration.
