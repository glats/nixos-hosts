# Exploration: Single canonical Gentle AI v3 on OpenCode V2, all hosts, V1 retired

## Scope

Pin **ONE** canonical Gentle AI v3 (previous latest verified **v3.7.0**; confirmed
still the latest v3 tag at 2026-10-02) for the **OpenCode V2 runtime only**, across
all four hosts (rog/thinkcentre/t14 = `x86_64-linux`; macm5 = `aarch64-darwin`),
with V1 retired safely only after runtime validation. No v4/ODD migration, no
indefinite coexistence. Exploration only — no code change, no activation, no
commit; the dirty tree is preserved. Reuses evidence from
`gentle-ai-stack-stability/exploration.md` and `gentle-ai-v4-harness/exploration.md`
(not overwritten).

## Correction audit trail (2026-10-02)

This file was reconciled against the verified addendum appended below. Corrections,
each marked inline with ~~strikethrough~~ + SUPERSEDED/REVISED:

1. #5117/#5126 (and #5129/#4805) are **V1** runtime defects, not V2; only #4984 is
   the V2 by-design refusal. See "Decisive upstream statements".
2. The repo-local relay is **not** a viable review substitute on v3 V2 — the
   addendum proves `gentle-ai review opencode-transport` refuses V2 at the Go gate.
   Original Approach 1 and its "relay proves instead" acceptance language are
   superseded.
3. "proven local adapters" was an over-claim — adapters are source-compatible and
   2.0.14-pinned but have no runtime test evidence.
4. Verification gate 4 and "Ready for Proposal" are revised to expect a relay
   refusal (not completion) and to require a product decision before proposal.

No state.yaml, research.md, code, or config was changed; this update is confined to
exploration.md and the Engram explore artifact.

## Current state (verified in tree, 2026-10-02)

- `flake.nix` pins `gentle-ai-src` to **v2.5.0** (commit `f5dd1a6c`, `flake.lock`
  383-399), comment "do not track main".
- `pkgs/gentle-ai/default.nix`: `buildGoModule`, `subPackages = [ "cmd/gentle-ai" ]`,
  `vendorHash = "sha256-todsAjNOtV/fX4agsaqFwC0MHerMCVB0ufJk1sGSm/Y="`, `postPatch`
  overrides `internal/assets/opencode/plugins/skill-registry.ts` with the local
  `skill-registry-worktree-root.ts` (`TODO(upstream)`).
- `pkgs/gentle-ai-assets/default.nix`: copies `internal/assets/{opencode,skills,
  claude,cursor,windsurf,gemini,codex,kimi,qwen,kiro}` + root `skills/` + `AGENTS.md`;
  applies the same skill-registry override; vendors **local V2 plugins** from
  `v2-plugins/` (`sdd-task-result.ts`, `opencode-review-transport.ts`,
  `skill-registry.ts`) because upstream v2.5.0 shipped no V2 plugins.
- OpenCode V1: `pkgs/opencode/default.nix` → **1.18.32**; SDK
  `@opencode-ai/plugin@1.18.32` (`pkgs/opencode-npm-packages/versions.json`).
- OpenCode V2: `pkgs/opencode-v2/default.nix` → CLI **2.0.14**; SDK
  `@opencode/plugin@2.0.14` (`pkgs/opencode-npm-packages-v2/versions.json`).
- V2 runtime (`shared/opencode/runtime-config.nix` `v2ManagedPlugins`, 62-71) loads
  the local `rtk.ts` + the three vendored gentle-ai V2 plugins + `engram.ts`; the
  V2 agent graph is remapped from the V1 graph by `v2-agents.nix` (sdd-* executor
  contract injection, `subtask`→`subagent` rewrite in activation).
- In-flight, must be preserved: `complete-opencode-v1-to-v2-migration`,
  `fix-opencode-v1-v2-credential-collision`, `port-gentle-ai-sdd-to-opencode-v2`,
  `opencode2` launcher/standalone/proxy parity (`shared/shell-aliases.nix`
  170-216), credentials/sessions/MCP/Engram/providers.

## External evidence (verified 2026-10-02)

### Versions

| Item | Value | Source |
|---|---|---|
| Latest v3 tag | **v3.7.0** (2026-09-23, commit `6dee8f833aec9e46015759c5065a9035795d9af1`) | GitHub `list_tags` / `get_release_by_tag` |
| Latest tag overall | **v4.0.0** (out of scope — no v4/ODD) | GitHub `list_releases` |
| v3 Go module path | `github.com/gentleman-programming/gentle-ai/v3` | v3.7.0 `go.mod` (fetched raw) |
| v3 Go toolchain | `go 1.25.10` | v3.7.0 `go.mod` |
| Provider contract | `1.2.0` (unchanged) | v3.7.0 release body |
| v3 V2 SDK | `@opencode/plugin@2.0.4` (upstream ships against this) | `docs/opencode-compatibility.md` |
| Repo V2 SDK | `@opencode/plugin@2.0.14` | `pkgs/opencode-npm-packages-v2/versions.json` |

### v3.7.0 tag tree (fetched via GitHub git-trees API, commit `6dee8f83`)

- **SDD preserved**: `internal/cli/sdd_{archive_compose,attempt,preflight_hook,
  status,task_result}.go` all present. `cmd/gentle-ai/main.go` unchanged entry point.
- **Agent graph preserved**: `internal/assets/opencode/sdd-overlay-single.json` and
  `sdd-overlay-multi.json` both present (repo consumes `sdd-overlay-single.json`).
- **Assets preserved**: `internal/assets/opencode/persona-gentleman.md`,
  root `AGENTS.md` present.
- **V2 plugins now ship upstream** under `internal/assets/opencode/plugins-v2/`:
  `model-variants.ts`, `opencode-review-transport.ts`, `sdd-task-result-artifacts.ts`,
  `skill-registry.ts`, `telemetry-runtime.ts`. This is new vs v2.5.0.

### Decisive upstream statements on OpenCode V2 review

- `docs/opencode-compatibility.md`: for V2, "Native review … Unavailable; no
  positive review admission advertised." Immutable receipt-review transport
  requires the OpenCode CLI to advertise `ContractImmutableReviewExecutorV1` in
  its capability manifest (`internal/cli/review_transport_capability.go`); OpenCode
  V2 does not, and it is an active-agent check, not repository config.
- v3.7.0's shipped `plugins-v2/opencode-review-transport.ts` is explicitly marked
  *"Staged wire adapter. Native capability remains unavailable pending runtime
  proof."* Its relay uses `GENTLE_AI_OPENCODE_RELAY_CONTRACT=gentle-ai.opencode-relay/v2-staged`.
- Open runtime refusals on 3.7.0 (all **open**), reclassified by client runtime
  (see addendum): **V2 — by-design refusal** #4984 (selectorless preflight
  `immutable_review_transport_unsupported`, OpenCode 2.0.16). **V1 runtime defects**
  #5117 (reviewer Task refused as `immutable_review_transport_unsupported` while the
  same binding succeeds via `opencode-transport`; client 1.18.33), #5126
  (`opencode_review_transport_binding_invalid` when session root == review repo
  root), #5129 (intended-untracked capture block; client 1.18.33), #4805
  (immutable-runtime refusal regression; client 1.18.31). **Review-lifecycle budget**
  #5094 (25s `pre_native` budget exhaustion on active lineage; client line not
  re-verified).

### Installer/sync-only defects (bypassed by declarative Nix, not disqualifiers)

#4940, #5066, #5185, #5192, #5099 are all install/sync-delivery defects; the repo
does not run `install`/`sync`, so they do not block. They are excluded from the
runtime evidence matrix.

### Key divergence: two V2 adapter lineages

The repo's `v2-plugins/*` are a **repo-owned parallel implementation** against
`@opencode/plugin@2.0.14` that encode repo-specific contracts: the
`GENTLE_AI_SDD_FAILURE` handoff and phase validation in `sdd-task-result.ts`
(Effect hooks), the `gentle-ai.provider-transport/v1` relay in
`opencode-review-transport.ts`, and a `Bun.spawn` skill-registry. Upstream v3.7.0
ships a **different** set (`sdd-task-result-artifacts.ts` with grouped preflight;
`opencode-review-transport.ts` with a `v2-staged` relay contract;
`skill-registry.ts` using `ctx.location.directory`) against `@opencode/plugin@2.0.4`.
These are **not drop-in equivalent**, and adopting upstream's would require the
2.0.4→2.0.14 SDK reconciliation and re-validation of every repo-specific SDD
contract — churn the migration does not need.

## Affected areas (exact files)

| Area | File(s) | Impact for this change |
|---|---|---|
| Flake input | `flake.nix` (68-73), `flake.lock` (383-399) | `gentle-ai-src` v2.5.0 → v3.7.0 |
| Go derivation | `pkgs/gentle-ai/default.nix` | `vendorHash` recompute; `postPatch` skill-registry override droppable (upstream-fixed); meta |
| Asset derivation | `pkgs/gentle-ai-assets/default.nix` | skill-registry override install droppable; verify asset dirs at v3.7.0 |
| Local override | `pkgs/gentle-ai-assets/skill-registry-worktree-root.ts` | deletable once upstream `ctx.location.directory` fix adopted |
| Local V2 adapters | `pkgs/gentle-ai-assets/v2-plugins/{sdd-task-result,opencode-review-transport,skill-registry}.ts` | keep (repo-owned, 2.0.14-pinned) — do NOT swap for upstream plugins-v2 |
| V2 runtime | `shared/opencode/runtime-config.nix` (62-71, 176-292) | `v2ManagedPlugins` sources; asset/plugin staging |
| V1 runtime (retire) | `shared/opencode/runtime-config.nix` (V1 branch 294+), `shared/opencode/agents.nix`, `shared/opencode/plugins.nix` | removed only after V2 validated |
| Wrapper/aliases | `shared/shell-aliases.nix` (44-50 gsdd/gnext/greview; 170-216 opencode2* wrappers) | retarget `g*` aliases to V2 binary at retirement |
| Overlays | `overlays/linux.nix` (11-13), `overlays/darwin.nix` (51-53) | `gentle-ai`/`gentle-ai-assets` exposure (unchanged) |
| Package index | `lib/packages.nix` (28-37) | unchanged |
| Shared assets | `shared/ai-assets.nix` (25), `shared/claude-code.nix` (17-18,187,319) | claude/skill asset consumers of gentle-ai-assets |
| Homebrew (macm5) | `darwin/system/homebrew.nix` (19,24-26) | legacy `gga` tap — separate cleanup, do not conflate |
| Docs | `docs/gentle-ai-update.md`, `docs/gentle-ai-omo-workflow.md` | update version references |

## Approaches

### 1. ~~Pin v3.7.0, keep local V2 adapters, gate V1 retirement (recommended)~~ — SUPERSEDED

> Superseded by the addendum (2026-10-02). The premise that the repo-local relay is
> a viable review substitute on V2 is false at v3.7.0: `gentle-ai review
> opencode-transport` refuses V2 at its first statement. "proven local adapters" was
> an over-claim — the adapters are source-compatible and 2.0.14-pinned but have no
> runtime test evidence. Retain the bump/override-drop mechanics, but drop the "keep
> relay as substitute" and "proven" assertions; see "Revised recommendation and the
> V1-retirement gate" in the addendum for options 1/2/3.

Bump `gentle-ai-src` to v3.7.0, recompute `vendorHash`, drop the now-upstream
skill-registry override, keep the repo's `v2-plugins/*` (2.0.14-pinned,
source-compatible, encoding repo SDD contracts), validate the V2 runtime on all
four hosts, then retire V1 as a separate, gated step.

- Pros: preserves SDD (verified at tag); avoids `/v4` + SDK 2.0.4→2.0.14 churn;
  the V2 runtime's local adapters are untouched; reversible via generations.
- Cons: v3 has no V2 review transport at all (native AND relay both refused at the
  Go admission gate) — the acceptance limitation must be reported and gated; the
  adapters are not runtime-proven; vendorHash/asset tree re-verify required.
- Effort: Medium.

### 2. Pin v3.7.0 AND adopt upstream `plugins-v2` adapters

Swap the local `v2-plugins/*` for upstream `plugins-v2/*`, reconciling SDK 2.0.4
against the repo's 2.0.14 and re-validating the `GENTLE_AI_SDD_FAILURE` handoff and
the `v2-staged` relay against the repo's Go binary and OpenCode 2.0.14.

- Pros: tracks upstream asset lineage; drops repo-owned divergence.
- Cons: SDK mismatch is the exact #5184-class churn the repo has routed around;
  re-proves repo-specific SDD/executor contracts for no functional gain; higher risk.
- Effort: High.

### 3. Defer (no-op)

Keep v2.5.0 + local adapters. Does not satisfy the single-v3 mandate.

- Effort: None (not acceptable).

## Recommendation

> **SUPERSEDED** by the addendum (2026-10-02); retained here as the audit trail.
> Approach 1 as originally stated is not viable as written: at v3.7.0 the repo-local
> relay is refused on V2, so "keep the relay as the substitute for native review"
> cannot hold. See "Revised recommendation and the V1-retirement gate" in the
> addendum (options 1/2/3). The SDD CLI surface (sdd-status / sdd-task-result flags
> + handoff schema) is confirmed compatible at v3.7.0, so SDD progression itself is
> not blocked; only the review/RDD transport is.

~~Approach 1.~~ Pin v3.7.0 as the single canonical version, keep the repo-owned
`v2-plugins/*` (2.0.14-pinned, SDD-contract-encoding), drop the now-redundant
skill-registry override, and retire V1 only after the runtime gates below pass on
the fleet. This is a **scope/stability decision**, not a claim that v3.7.0 is
proven stable: it keeps SDD, avoids `/v4`, and does not entangle the repo's working
V2 adapters with upstream's divergent, 2.0.4-pinned, "staged/unavailable" plugins.

### Acceptance limitations that must be reported (not silently dropped)

- **No review transport on OpenCode V2 in v3.7.0** (corrected) — upstream documents
  "Native review … Unavailable". Both the native path AND the relay path
  (`opencode-review-transport.ts` → `gentle-ai review opencode-transport`) refuse V2
  at the Go admission gate (`immutable_review_transport_unsupported`), so the relay
  is **not** a viable substitute on a V2-only fleet. Do **not** promise completed
  review on V2. #4984 is the V2 by-design refusal; #5117/#5126 are V1 runtime
  defects, not V2 refusals.
- Capabilities that lack v3 support and must be **gated**: native immutable
  receipt-review transport on V2; community TUI plugins on V2 (upstream refuses,
  not silently omitted); anything relying on OpenCode V1-only assets after V1
  retirement (claude-auth, warden, model-variants/multimodal V1 adapters, the V1
  `sdd-overlay-single.json` agent graph).

### Rollout order (before V1 retirement)

1. Bump to v3.7.0 + keep local adapters; `nix flake check --no-build`; all host evals.
2. Prove runtime gates 1–5 on rog (Linux x86_64) + macm5 (aarch64-darwin) smoke.
3. Only after gates pass: retire V1 (flip default command, remove V1 runtime
   config/plugins/agent-graph, retarget `gsdd`/`gnext`/`greview`). Rollback is
   Home Manager generations on every host — reversible, no destructive contraction
   before validation.

## Verification matrix

Static / evaluation:

- `nix flake check --no-build` (shared).
- `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath`
- `nix eval .#nixosConfigurations.thinkcentre.config.system.build.toplevel.drvPath`
- `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath`
- `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`
- `nix eval .#homeConfigurations.<host>.activationPackage.drvPath` (standalone HM where applicable).

Runtime gates (declarative derivations only; never `install`/`sync`):

1. **Plugin boot** — all V2 plugins (sdd-task-result, opencode-review-transport,
   skill-registry, engram, rtk) load on OpenCode 2.0.14 with no API-shape/default
   export failure.
2. **MCP/Engram reachability** — Engram MCP + plugin reachable in an isolated session.
3. **Delegation/results** — a real delegated task returns a verifiable result,
   repeated to discriminate the #3796 interruption.
4. **Review execution (relay)** — capture the relay refusal on Linux: expect
   `immutable_review_transport_unsupported` on a V2-only PATH (deterministic
   refusal), and a false-positive V1 `prompt` frame only while the V1 `opencode`
   still coexists on PATH. The relay is NOT expected to complete a round-trip on V2;
   native review is reported unavailable (limitation), not faked by an eligibility
   read.
5. **Platform smoke** — Linux x86_64 full pass + aarch64-darwin smoke/remote proof.

## Risks

- v3 native V2 review is unproven/refused on Linux x86_64 (3/4 hosts) — #4984/#5117/#5126.
- SDK divergence: repo 2.0.14 vs upstream 2.0.4; staying on local adapters avoids it,
  but any future drift to 2.0.18/2.0.19 re-triggers #5042/#4795 loader-shape risk.
- `vendorHash` and the asset-dir layout at v3.7.0 must be re-verified (Go 1.25.10
  toolchain, `/v3` module path) — `subPackages = [ "cmd/gentle-ai" ]` stays valid
  (module-root relative).
- V1 retirement is the dominant blast radius (`sdd-overlay-single.json` V1 graph,
  V1 plugins, `gsdd`/`gnext`/`greview`, claude-code asset consumers) — must be a
  separately-gated step, not bundled into the bump.
- The `#4807` launcher fork-bomb (PATH wrapper names `nix`) intersects the repo's
  `opencode2` wrapper; verify overlap before trusting the launcher post-bump.

## Ready for Proposal

> **REVISED** by the addendum (2026-10-02). The original "Yes — with gates" is
> retained for the audit trail but is superseded on point (b): the relay does NOT
> prove review on V2 at v3.7.0.

**No — one product decision blocks it.** The proposal must (a) pin v3.7.0 as the
single version and keep the repo-owned `v2-plugins/*` adapters (source-compatible,
2.0.14-pinned, runtime-unproven), (b) record the acceptance limitation that **no
review transport is available on V2 in v3.7.0** (native and relay both refused) and
obtain a user decision among option 1 (bounded V1 review coexistence), option 2
(documented no-review-on-V2 limitation), or option 3 (stay v2.5.0), (c) sequence V1
retirement after the revised runtime gates pass on the fleet with generation-level
rollback, and (d) preserve the in-flight V1/V2 parity, credential-collision, and
launcher work. No activation, bump, or commit here.

---

# Addendum — focused review-transport / SDD compatibility (2026-10-02)

This addendum is a continuation of the exploration above. It does not redo the
host inventory; it inspects the exact repo-local V2 adapters against the
**v3.7.0 tag** (`6dee8f833aec9e46015759c5065a9035795d9af1`) and the current
pin **v2.5.0** (`f5dd1a6c`) and corrects the bug-classification in the section
"External evidence" above. All citations are source-verified at the tag; none
were runtime-executed (no activation was performed).

## Decisive finding — v3.7.0 closes the OpenCode V2 relay at the Go admission gate

The original recommendation treated the repo-local relay
(`opencode-review-transport.ts` → `gentle-ai review opencode-transport`) as the
"substitute" for native review on V2. That premise is **wrong for v3.7.0**:

- v3.7.0 `internal/cli/review_opencode_transport.go` makes the relay's first
  statement a capability gate:
  `if !reviewImmutableRuntimeCapability(model.AgentOpenCode).supportsImmutableReceiptReview() { return errors.New(reviewImmutableTransportUnsupportedCode) }`.
  (`reviewImmutableTransportUnsupportedCode = "immutable_review_transport_unsupported"`.)
- v3.7.0 `internal/cli/review_transport_capability.go`, `case model.AgentOpenCode`:
  (1) `if os.Getenv("GENTLE_AI_OPENCODE_RELAY_CONTRACT") != "" { return policy }` —
  the staged env-var declaration narrows to unsupported; and
  (2) `major, err := opencode.DetectRuntimeMajor(...); if err != nil || major != opencode.RuntimeV1 { return policy }`.
  `policy` is `reviewImmutableTransportUnsupported` (ineligible).
- v3.7.0 `internal/opencode/runtime.go` `DetectRuntimeMajor` runs `opencode --version`
  (bare `opencode` from PATH) and parses with
  `^(?:opencode |OpenCode )?v?([12])\.[0-9]+\.[0-9]+$`; only a `1.x` major returns
  `RuntimeV1`. `PluginDependency()` pins `@opencode/plugin@2.0.4` for V2.

Net effect at v3.7.0: `gentle-ai review opencode-transport` refuses with
`immutable_review_transport_unsupported` whenever the staged contract env var is
set **or** `opencode --version` does not report a `1.x` major. There is no
supported immutable receipt-review transport on OpenCode V2 at v3.7.0 — the
relay and the native path share the same compiled boundary and both refuse V2.
This is asserted by upstream tests `TestOpenCodeV2TransportCapabilityUnavailable`
("direct relay did not refuse before input") and
`TestOpenCodeV2TransportDeclarationCannotInheritV1` ("declared unproven host must
refuse before PATH probe").

**v2.5.0 differs materially.** v2.5.0 `review_opencode_transport.go` has **no**
capability gate at entry (first statement is `if len(args) != 0`), and v2.5.0
`review_transport_capability.go` sets `case model.AgentOpenCode: policy.Eligible = true`
unconditionally (no env-var check, no `DetectRuntimeMajor` check). So the
repo-local relay is *structurally unblocked* at v2.5.0 but *refused at v3.7.0*.
This is a concrete behavioral regression introduced between the current pin and
the target, not a cosmetic difference.

### Repo-host PATH nuance (why the relay can *look* alive pre-retirement)

The repo runs `opencode` = V1 (`1.18.32`) and `opencode2` = V2 (`2.0.14`).
`DetectRuntimeMajor` probes bare `opencode`, so on the repo's hosts the v3.7.0
relay would resolve `opencode --version` → `1.18.32` (V1) and **incidentally pass
the gate**, even though the plugin is running inside OpenCode V2. That is a
false-positive V1 attribution — exactly the coexistence the upstream staged
env-var declaration exists to refuse — and it disappears the moment V1 is
retired (then `opencode` resolves to V2 or is absent → refusal). It is not a
proof of V2 review.

## Q1 — repo-local relay vs v3.7.0 CLI wire contract (exact)

The repo-local `pkgs/gentle-ai-assets/v2-plugins/opencode-review-transport.ts`:

- Schema: `gentle-ai.provider-transport/v1` — matches v3.7.0
  `reviewerprovider.TransportCapability = "gentle-ai.provider-transport/v1"`
  (`internal/reviewerprovider/contract.go`).
- Frames: `start` / `prompt` / `complete` / `result` with `nonce`/`prompt`/
  `output`/`error` — matches v3.7.0 `openCodeTransportEnvelope` and
  `validateOpenCodeTransportStart`/`...Completion` (strict one-start + one-completion
  frames, `DisallowUnknownFields`).
- Spawn: `gentle-ai review opencode-transport` with **no** `GENTLE_AI_OPENCODE_RELAY_CONTRACT`
  env var. Stderr codes it greps for
  (`opencode_review_transport_(binding_invalid|materialization_unavailable|authority_unavailable|envelope_invalid)`)
  still exist in v3.7.0 (`openCodeTransportBindingInvalid`,
  `openCodeTransportFailure("opencode_review_transport_materialization_unavailable")`,
  `openCodeTransportAuthorityUnavailable`, `opencode_review_transport_envelope_invalid`).
  **However** the code the relay actually hits first on V2 —
  `immutable_review_transport_unsupported` — is NOT in that grep set, so the
  repo-local plugin classifies the refusal as the generic `go_refused` without a
  code, and the plugin surfaces `opencode_review_transport_relay_refused: go_refused`.
- API: repo-local uses the Promise plugin API (`@opencode/plugin`, `Plugin.define`
  + `ctx.tool.hook`); upstream v3.7.0 ships the same Promise API for
  `opencode-review-transport.ts`. Wire-compatible at the SDK-surface level (both
  2.x), though repo pins SDK `2.0.14` and upstream ships against `2.0.4`.

Upstream v3.7.0 `plugins-v2/opencode-review-transport.ts` differs from repo-local:
plugin id `gentle-ai.opencode-review-transport` (repo: `opencode-review-transport`),
a global cross-instance relay registry, a `ctx.shell.hook("create.before")` that
injects `GENTLE_AI_OPENCODE_RELAY_CONTRACT=gentle-ai.opencode-relay/v2-staged` into
every shell, and keying by `ctx.location.directory`+`workspaceID`. Critically, the
upstream plugin **exports the staged env var that makes its own relay refuse at the
Go gate** — it is deliberately a "staged wire adapter" whose Go admission is closed.

## Q2 — does native V2 unavailability also forbid the relay / opencode-transport invocation?

**Yes.** The relay command's first statement is the same
`reviewImmutableRuntimeCapability(AgentOpenCode).supportsImmutableReceiptReview()`
gate as native review. There is no distinct `opencode-transport` admission path
that bypasses it. The staged env var only *narrows* capability (comment in the
source: "A managed host declaration can only narrow capability, never enable it").
So neither "native review" nor "relay via opencode-transport" is available on V2
at v3.7.0. There is no capability-check bypass available in the repo without
forking the Go admission layer, which would violate the no-weakening-review-receipts
constraint.

## Q3 — can the repo-local SDD plugin call v3.7.0 CLI commands with identical schemas/flags?

Mostly yes, with one real divergence:

- `gentle-ai sdd-status --cwd <repo> --json` — flags `--json`, `--instructions`,
  `--cwd`, `--contract` are present in v3.7.0 `internal/sddstatus/status.go`
  `ParseCommandArgs`. The repo-local handoff continuation
  `gentle-ai sdd-status --cwd '<repo>' --json` is valid.
- `gentle-ai sdd-task-result --phase <phase> --cwd <repo> --input <path|->` — flags
  `--phase`, `--cwd`, `--change`, `--input`, `--task-model`, `--latched-phase`,
  `--latched-code` present in v3.7.0 `internal/cli/sdd_task_result.go`
  (`sddTaskResultUsage` matches byte-for-byte).
- Handoff schema `gentle-ai.sdd-task-result-failure/v1` with codes
  `sdd_task_result_empty` / `sdd_task_result_malformed` / `sdd_task_dispatch_latched`
  is identical between the repo-local `sdd-task-result.ts` and upstream
  `sdd-task-result-artifacts.ts`.

Divergences (not fatal to CLI compatibility, but semantic):

1. **Phase list**: repo-local `sdd-task-result.ts` `PHASES` omits `sdd-research`;
   upstream `sdd-task-result-artifacts.ts` `SDD_PHASES` includes it. The repo
   *deploys* the `sdd-research` skill and agent
   (`shared/opencode/runtime-config.nix` skill loop line 279 includes
   `sdd-research`; `shared/opencode/local-agent-overlays.json` has an `sdd-research`
   agent), so a delegated `sdd-research` phase returning empty/malformed output
   would **escape** the repo-local plugin's failure handoff. Consequence, not just
   naming.
2. **Continuation**: repo-local emits a CLI continuation
   (`gentle-ai sdd-status --cwd <repo> --json`); upstream emits prose
   (`SDD_TASK_CONTINUATION_GUIDANCE`) because #2855 — the host cwd does not
   identify the coordinator's selected change/store.
3. **API surface**: repo-local `sdd-task-result.ts` uses the Effect hooks
   (`@opencode/plugin/effect`, `ctx.session.hook("prompt")`, `ctx.tool.hook`,
   `ctx.event.subscribe`); upstream uses the Promise API. Both exist in SDK 2.0.14.
4. **Preflight authority**: upstream `sdd-task-result-artifacts.ts` adds a
   parent-confirmed grouped SDD preflight gate (Pace/Artifacts/PR-strategy) the
   repo-local plugin does not implement. If the repo later adopts the upstream
   plugin, it also adopts that gate.

## Q4 — minimally required / unproven SDK-adapter changes

- The repo-local V2 adapters (`opencode-review-transport.ts`,
  `sdd-task-result.ts`, `skill-registry.ts`) are pinned to `@opencode/plugin@2.0.14`
  (and `@opencode/plugin/effect@2.0.14`). Upstream v3.7.0 ships against
  `@opencode/plugin@2.0.4`. **No SDK change is required for the repo-local plugins
  to keep loading** — the Go binary is the CLI, independent of the plugin SDK; the
  plugins talk to OpenCode 2.0.14, not to the v3.7.0 binary's SDK. The 2.0.4↔2.0.14
  divergence only matters if the repo *adopts* upstream's `plugins-v2/*` (avoided).
- The only hard break is the **Go-side relay gate** (Q2): the repo-local relay is
  source-compatible but runtime-refused on V2 at v3.7.0. This is not a plugin/SDK
  change; it is an upstream admission-layer behavior change that no repo-side edit
  can legally reverse.
- Unproven (runtime): whether the repo-local relay ever completed a real review
  round-trip even at v2.5.0 (the prior exploration already flagged this as
  unproven). Nothing in this addendum changes that; it only adds that v3.7.0
  *guarantees* the refusal on a V2-only fleet.

## Bug applicability correction (V1 vs V2 vs installer)

The section above listed #5117 and #5126 among "V2" refusals. Source/issue
evidence corrects that:

- **#4984** — V2 (OpenCode 2.0.16) refused at preflight as
  `immutable_review_transport_unsupported`, supported runtimes "claude-code, codex".
  This is the **by-design** v3.7.0 V2 refusal (matches the source gate), reported as
  a bug because v2.3.0 had shipped OpenCode as eligible (#2479). **Runtime, V2.**
- **#5117** — client is OpenCode **1.18.33 (V1)**, "managed review-transport plugin",
  Linux x86_64. First reviewer dispatch refused, but the identical binding fed to
  `gentle-ai review opencode-transport` produced a valid prompt frame and a retry
  succeeded and was approved. This is a **V1 first-dispatch transient**, not a V2
  refusal; it *confirms the relay works on V1*, not on V2. **Runtime, V1.**
- **#5126** — all four 4R lens Tasks rejected with
  `opencode_review_transport_binding_invalid: Task repository context does not match…`
  when the session root is the review repo root (Windows/X64). Because the error is
  at the binding layer (deeper than the capability gate), this is **V1** (V2 would
  refuse at `immutable_review_transport_unsupported` before binding). **Runtime, V1.**
- **#5185** — v3.x → 4.0.0 sync refuses Gentle AI's own shipped
  `opencode-review-transport.ts` as "unverified ownership". **Installer/sync only**;
  the repo runs declarative Nix, not `install`/`sync`.
- **#4796** — sync refuses when `opencode --version` exceeds the 3 s probe.
  **Installer/sync only.**

Installer/sync defects (#4940, #5066, #5185, #5192, #5099, #4796) remain bypassed
by declarative Nix and do not block. The runtime-relevant V2 defect is #4984 and it
is by-design for v3.7.0, not a defect the repo can fix.

## Revised recommendation and the V1-retirement gate

The prior recommendation ("keep local `v2-plugins/*` and use the relay as the
substitute for native review") is **not viable at v3.7.0 on a V2-only fleet**: the
relay is refused for V2 at the Go gate. Options:

1. **Pin v3.7.0, keep local adapters, keep V1 alive for review only** — the only way
   to retain immutable receipt-review after the bump (V1 `opencode` is what passes
   `DetectRuntimeMajor`). Conflicts with "retire V1 / no indefinite coexistence";
   requires an explicit user decision on a bounded coexistence window.
   Effort: Low–Medium.
2. **Pin v3.7.0, retire V1, accept "no immutable receipt-review on V2" as a
   documented limitation** — SDD proceeds (SDD CLI and handoff are intact), but
   RDD receipt-review is disabled on the whole fleet. Must be stated, not silently
   dropped. Effort: Low (scope only).
3. **Stay on v2.5.0** (relay not gated) and re-evaluate when a v3 tag re-opens V2
   review — violates the "pin v3.7.0" mandate. Effort: None (not acceptable).

**Recommended: option 1**, with option 2 as the recorded acceptance limitation if
review on V2 is judged non-essential for this migration. Option 3 is the fallback
if review on V2 is a hard requirement and no newer v3 tag exists.

**Gate that prevents V1 retirement**: `gentle-ai review opencode-transport` (and
native review) refuse OpenCode V2 at v3.7.0 because
`reviewImmutableRuntimeCapability(AgentOpenCode)` requires an *unset*
`GENTLE_AI_OPENCODE_RELAY_CONTRACT` **and** an `opencode --version` that reports a
`1.x` major. Retiring V1 removes the only runtime that satisfies the second
condition, eliminating immutable receipt-review on V2. No repo change reopens this
without weakening the receipt-review boundary, which is out of scope.

## Compatibility test strategy (static + Linux + Darwin)

Static (source-verified, already done in this addendum):
- v2.5.0 vs v3.7.0 `review_transport_capability.go` and `review_opencode_transport.go`
  diff (gate added); `reviewerprovider.TransportCapability` schema equality; stderr
  refusal-code set; `sdd-status`/`sdd-task-result` flag parity.

Evaluation (no runtime activation required, runnable now):
- `nix flake check --no-build`; `nix eval .#nixosConfigurations.{rog,thinkcentre,t14}.config.system.build.toplevel.drvPath`;
  `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`;
  standalone HM `activationPackage.drvPath` where applicable.

Runtime proof (test plan only — destructive/live, not run here):
1. On rog (Linux x86_64), *before* V1 retirement, invoke
   `gentle-ai review opencode-transport` from inside a V2 session and capture the
   refusal string: expect `immutable_review_transport_unsupported` (V1-on-PATH
   false-positive) vs a real `prompt` frame (which would prove V1 attribution).
2. Repeat with `opencode` removed/PATH-pointed-at-V2 to prove the refusal is
   deterministic and not PATH-dependent.
3. Confirm `gentle-ai sdd-status --cwd <repo> --json` and
   `gentle-ai sdd-task-result --phase sdd-explore --cwd <repo> --input -` accept a
   malformed/empty input and render `sdd_task_result_empty` — proving the SDD CLI
   handoff is intact at v3.7.0.
4. macm5 (aarch64-darwin) smoke: plugin boot + Engram/MCP reachability + a delegated
   task round-trip; review expected to refuse the same way (capability is
   platform-independent in the Go code).
5. Darwin runtime-major probe: confirm `opencode --version` on macm5 reports V1
   (coexists) so the gate behavior is understood per-host before any retirement.

## Ready for Proposal (revised)

**No — one product decision blocks it.** The proposal cannot assume the relay is a
viable review substitute on V2 at v3.7.0. The orchestrator must (a) surface to the
user that v3.7.0 closes the V2 review relay at the Go admission gate, and obtain a
decision among option 1 (bounded V1 review coexistence), option 2 (documented
no-review-on-V2 limitation), or option 3 (stay on v2.5.0); (b) correct the bug
classification in the main body (#5117/#5126 are V1, not V2); and (c) fold the
revised runtime gate (plugin boot, MCP/Engram, delegation, review-refusal-expected,
platform smoke) into the verification matrix. The SDD CLI surface (sdd-status /
sdd-task-result flags + handoff schema) is confirmed compatible at v3.7.0, so SDD
progression itself is not blocked by this finding — only the review/RDD transport.
