# Exploration: integrate-jev-opencode-harness

Rerun of the prior exploration under the tool-adoption workflow. Context7 was
**unavailable** (monthly quota exceeded), so the OpenCode plugin-SDK API could
not be verified against official docs; every other claim below is backed by
GitHub, Exa, `models.dev` (the registry behind `models.opencode.ai`), and
`nixos_nix`, and unsupported prior claims are corrected inline.

## Tool identity — verified (low ambiguity)

JEV is **TypeSafe AI's "System One" decision model**, not a text-generating
LLM. Evidence converges from the official announcement, the hosted-API docs,
LangChain's integration post, and the model registry:

- Official blog ("Introducing System One Models & Jev", 2026-09-15,
  typesafe.ai): JEV "gives up string generation" and returns **typed,
  calibrated, probabilistic decisions** — it cannot emit an invalid type or
  hallucinate a format. Trained with RLCD. Early access.
- Hosted API only, closed weights. `POST https://api.typesafe.ai/v1/systemone`,
  `Authorization: Bearer $TYPESAFE_API_KEY`, body `{ model, state, questions }`.
- Three question shapes, evaluated in parallel in one round trip: **choice**
  (≤255 options → winning key + per-option probabilities + confidence),
  **score** (2–10 ordered levels → fractional score + distribution + legend),
  **noul** (calibrated yes/no → probability 0..1).
- Pricing: **$0.042 / 1M input tokens, output free** (direct,
  console.typesafe.ai). A third-party managed layer (jevtypesafeai.com) resells
  at $0.42 / 1M prepaid — 10× the direct rate.
- Latency 70–500 ms; rate limits 250k tokens/s and 1,200 requests/min; context
  ~64k tokens (state + questions) and ~32k (state + longest question).
- Registry (`models.dev` / `models.opencode.ai`): `typesafe/jev-latest` under
  lab **Typesafe**, 6 providers (unnamed), context 64,000, **output 0**,
  tool-call `Yes`, structured `No`, closed weights, release 2026-09-15.

The etymology "named after William Stanley Jevons" from the prior draft is
**unverified** — every source traces the "System One" name to Kahneman's
fast/slow distinction, not Jevons.

## Verified vs. unknown (corrections to the prior draft)

### Verified

- API endpoint, auth, request/response shape, three question types, pricing,
  rate limits, latency, and context budgets — as above.
- Canonical prior art: `TypeSafeAI/jev-harness` (**MIT**, TypeScript) —
  "an LLM proposes, Jev answers narrow questions, code decides".
- OpenCode guardrail prior art: `codebam/jev-guardrails` / `@codebam/dsh-jev-guardrails`
  documents the **OpenCode plugin hook `tool.execute.before`** for a
  pre-execution tool-call gate (plus Hermes `pre_tool_call`, DeepSeek Harness
  `tools/pre-execute`, and an MCP bridge). This is the concrete hook name the
  prior draft left as "a pre-tool-use permission/ask hook".
- A second transport exists: **OpenRouter Decisions API** at model
  `~typesafe/jev-latest` (per `codebam/jev-guardrails`), which this harness can
  reach with its already-exported `OPENROUTER_API_KEY` — no new secret.
- SDKs: LangChain `langchain-typesafe` (Python: `TypeSafeClassifier`,
  `ModelRouterMiddleware`, `AutoModeMiddleware`); Vercel AI SDK
  `experimental_evaluate` (`typesafe-ai/jev`). Community SDKs: Java
  (`spring-ai-community/spring-ai-typesafe`), Rust, Ruby, Go
  (`itsmostafa/typesafe-mcp`), Python stdio (`ThePFMind/jev-mcp`).
- Nix packages: **none** — `nixos_nix` search for `jev` and `typesafe` returns
  no JEV/SDK package (only unrelated Haskell "Typesafe Config" libraries).

### Unknown / unsupported (removed from the prior draft)

- "JEV is already served by OpenCode Zen (`opencode/jev-latest`,
  `opencode/jev-1.13`, `opencode/jev-1.13-free`), Cloudflare AI Gateway
  (`cloudflare-ai-gateway/typesafe/jev`), NanoGPT (`nano-gpt/typesafe/jev-latest`)"
  — **unverified**. The registry lists only `typesafe/jev-latest` (Typesafe lab)
  with 6 unnamed providers; this repo's `providers-base.nix` contains **no**
  JEV/TypeSafe/Cloudflare/NanoGPT entry. The "Zen free-catalog audit 2026-09-09
  did not list JEV" note was unsupported.
- "SDKs: Python + JS (TypeSafe first-party) and `@opencode-ai/models`" —
  **unverified**. No first-party TypeSafe SDK and no `@opencode-ai/models`
  package were established; confirmed SDKs are LangChain Python + Vercel AI SDK.
- "OSS prior art: `jev-harness` (PyPI), `jev-guardrails`, `jev-gates`,
  `jev-dsh-decision`" — `jev-harness` is a **GitHub repo (TypeScript)**, not a
  PyPI package; `jev-gates` was **not found**. Confirmed: `TypeSafeAI/jev-harness`,
  `codebam/jev-guardrails`, `Devin-AXIS/jev-dsh-decision`.
- Exact OpenRouter/Zen/Cloudflare availability in *this* account is unverified;
  the transport must be confirmed before any proposal.

## Tool-adoption gates

| Gate | Finding |
| --- | --- |
| Canonical source / release / license | typesafe.ai; early-access release 2026-09-15 (`jev-latest`, pinned `jev-1.13.0`); **hosted API, closed weights**; reference harness MIT. |
| Pin / update / telemetry | Model versions pinnable (`jev-1.13.0`); TypeSafe states `jev-latest` "can shift behavior" and rate limits "move without notice". Telemetry behavior unverified. |
| Processes / listeners / network | Remote HTTPS outbound to `api.typesafe.ai` (or OpenRouter / a reseller). No local listener. An MCP integration is a local **stdio** child process (matches existing `mcps-base.nix` pattern). |
| Local state / filesystem / secret boundaries | No required local state. Needs a new `TYPESAFE_API_KEY` sops secret **only** for the direct route; the OpenRouter route reuses `OPENROUTER_API_KEY`. The API receives `state` = tool args / file contents / web text — attacker-reachable. |
| Linux + arm64-darwin | Hosted API is platform-agnostic (both supported). Any bundled client must be pure Go/TS (no native binaries) — the harness's Go-op and TS-plugin paths are both cross-platform. |
| Security | **Prompt injection is the documented risk**: TypeSafe states "state is data, and jev-1.13 does not treat it as hostile by default." Model is ~9 days old; ecosystem immature; no advisory surface yet. |

**Verdict: defer pending clarification** (integration class and transport are
unresolved, not the identity). Once clarified, a narrow, pinned integration is
viable; see Recommendation.

## Current State

The harness is **generated**, not hand-edited: `shared/opencode/*.nix` emits
`~/.config/opencode/opencode.json` (V1 keys) plus `commands/`, `skills/`,
`plugins/`, `package.json`, `node_modules/`, `tui.json`.

- `shared/opencode/providers-base.nix`: `nvidiaProvider` (custom
  `@ai-sdk/openai-compatible`), `opencodeProvider` (built-in, timeout-only), and
  20+ routing profiles (`canonicalProviders` + `legacyProviders`) mapping SDD
  phases to `opencode/*`, `opencode-go/*`, `anthropic/*`, `openai/*`,
  `github-copilot/*`, `nvidia/*`. **No JEV/TypeSafe entry exists.**
- `shared/opencode/runtime-config.nix`: emits `agent`, `provider`, `mcp`,
  `permission`, `plugin`, `compaction`, optional `disabled_providers`/`tools`.
  **No `small_model`/title-model key is emitted.**
- `shared/opencode/plugins.nix`: 6 managed local plugins (`model-variants`,
  `opencode-review-transport`, `sdd-task-result-artifacts`, `skill-registry`,
  `engram`, `rtk`) + 3 npm plugins. **No classifier/guardrail plugin**;
  approval is the static `permissions.nix` allow/deny/ask map with no model in
  the loop.
- `shared/opencode/mcps-base.nix`: `github-personal/work`, `nixos`, `context7`,
  `engram`, `browsermcp`, `exa` — an MCP entry is the lowest-friction addition.
- `shared/opencode.nix`: exports sops keys at zsh init — including
  `OPENROUTER_API_KEY`, but **not** `TYPESAFE_API_KEY`. `runtimeConfig = { dir
  = "opencode"; label = "default"; }` is the single-runtime assumption.
- `openspec/changes/migrate-opencode-v1-to-v2/`: proposal approved (**parallel,
  isolated V2 runtime beside V1**, `@opencode/cli@2.0.14`), delta specs written,
  **no design/tasks/code yet**. Load-bearing field map: `provider`→`providers`,
  `plugin`→`plugins`, `npm`→`package`/`aisdk:`, `small_model`→`agents.title.model`,
  and plugin SDK `@opencode-ai/plugin` (V1 1.18.22) → `@opencode/plugin` (V2).
  The migration **defers V2 ports of 6 local + 3 npm plugins** — any JEV plugin
  added now must be planned for that port.

## Affected Areas

- `shared/opencode/providers-base.nix` — only if JEV is registered as an
  addressable model/routing target (currently no such entry).
- `shared/opencode/plugins.nix` + `runtime-config.nix` — where a managed JEV
  guardrail plugin (`tool.execute.before`) would be registered/deployed
  (mirrors the `rtk`/`engram` `enable` + `src` pattern).
- `shared/opencode/mcps-base.nix` — where a JEV MCP server (stdio) would be
  added as a `local` MCP.
- `shared/opencode.nix` — a new `TYPESAFE_API_KEY` sops export **only for the
  direct route**; a new HM option (`home.opencode.plugins.jev.enable`); the
  `runtimeConfig` single-runtime assumption.
- `.sops.yaml` + `secrets/shared/…` — new creation rule for the TypeSafe key
  (specific rule before generic host rules), direct route only.
- `shared/assets` / `pkgs.gentle-ai-assets` (or a Go op under
  `pkgs/nixos-scripts/`) — packaging for a `.ts` plugin source or a Go decision
  CLI, matching where `rtk.ts`/`engram.ts` are sourced or Go ops live.
- (Forward) the future parameterized generator from `migrate-opencode-v1-to-v2`
  — a JEV emission must land in both V1 and V2 trees without disturbing
  V1 byte-identical output.

## Approaches

1. **MCP decision server (recommended as the safe default).** Add a `local`
   stdio MCP (`jev-mcp`-style, or a thin Go server under `pkgs/nixos-scripts`)
   exposing `jev_evaluate` / `jev_route`, reachable via the existing
   `OPENROUTER_API_KEY` (OpenRouter `~typesafe/jev-latest`) or a new
   `TYPESAFE_API_KEY`.
   - Pros: zero plugin-SDK porting (immune to V1→V2 SDK break); reuses the
     existing MCP mechanism; universal across clients; lowest coupling.
   - Cons: not a true pre-execution guardrail (no `tool.execute.before` hook
     interception); a decision tool the agent must opt to call; another child
     process.
   - Effort: Low.

2. **Guardrail plugin (`tool.execute.before`).** Add a managed local plugin
   using the OpenCode plugin hook `tool.execute.before` (verified via
   `codebam/jev-guardrails`) to gate dangerous tool calls, with policy and
   allowlists in code.
   - Pros: idiomatic "LLM writes, Jev decides, code acts"; sits in the real
     pre-execution path; matches the repo's managed-plugin pattern.
   - Cons: new `.ts` asset + `TYPESAFE_API_KEY` (or OpenRouter); V2 port to
     `@opencode/plugin` later (migration defers plugin ports); the hook exists
     only in V1 SDK (unverified for V2).
   - Effort: Medium.

3. **Model/provider registration only.** Reference `typesafe/jev-latest` and
   wire it to the one cheap-model slot OpenCode exposes (V1 `small_model` /
   V2 `agents.title.model`) or an opt-in "classifier" profile.
   - Pros: minimal config surface; no new secret if routed via OpenRouter.
   - Cons: JEV is not a text model, so the title/small-model slot is a category
     error and delivers marginal value; which provider actually serves
     `typesafe/jev-latest` in this account is unverified.
   - Effort: Low (low value).

## Recommendation

**Defer the proposal until role + transport are answered**, then land a narrow
integration:

- **Transport:** prefer the **OpenRouter Decisions API (`~typesafe/jev-latest`)**
  through the existing `OPENROUTER_API_KEY` (no new secret) if it is confirmed
  to serve JEV in this account; otherwise TypeSafe direct with a new
  `TYPESAFE_API_KEY` sops secret.
- **Mechanism:** **Approach 1 (MCP decision server)** is the lowest-risk first
  step and is independent of the V1→V2 plugin-SDK break. **Approach 2**
  (`tool.execute.before` plugin) is the higher-value target but should be
  designed SDK-agnostic so the V2 port is a thin adapter, or deferred to the
  V2 runtime entirely.
- **Never** assign JEV to any SDD generation phase (category error). Keep
  permissions, path allowlists, and caps in code; the gate advises, the runtime
  enforces. Log full probability distributions for forensics.
- Treat it as a **separate change** from `migrate-opencode-v1-to-v2` (distinct
  lifecycle), with a forward-compatible emission contract.

## Risks

- **Category error:** assigning JEV (non-text, structured-only) to a generation
  phase silently breaks that phase; it must only fill decision/classifier slots.
- **Prompt injection (primary, documented):** `state` sent to JEV is
  attacker-reachable (tool args, file contents, web text). Never let the gate's
  state contain text that can rewrite the question; pass args as named fields;
  keep policy in code; ship an adversarial test set.
- **Transport uncertainty:** OpenRouter/Zen/Cloudflare availability in this
  account is unverified; the wrong choice wastes a secret + plugin integration.
- **SDK/plugin drift:** a V1-SDK plugin does not run in V2 (`@opencode-ai/plugin`
  vs `@opencode/plugin`); without an SDK-agnostic core the work duplicates at
  migration time.
- **Immature model/ecosystem:** JEV is ~9 days old; `jev-latest` shifts behavior;
  rate limits move without notice; calibrate and re-baseline thresholds.
- **Confidence handling:** a wrong high-confidence approve is the worst case;
  low-confidence results must fall back to the existing static permission path.

## Ready for Proposal

**No.** JEV's identity is verified, but the **role** (which decision point) and
**transport** (which route/key) are unresolved, and the model/ecosystem is
brand new. The orchestrator should ask the user:

1. **Role** — which decision should JEV own: tool-call gate
   (`tool.execute.before`), model routing, loop/completion detection, review
   triage, or a combination? (Determines plugin vs MCP vs model-registration.)
2. **Transport** — OpenRouter `~typesafe/jev-latest` via the existing
   `OPENROUTER_API_KEY` (no new secret) versus TypeSafe direct with a new
   `TYPESAFE_API_KEY` sops secret?
3. **Mechanism/class** — MCP decision server (lowest risk, V2-immune) vs
   OpenCode plugin (`tool.execute.before`, V2 port later) vs Go operational
   helper?
4. **V2 timing** — land V1-only now (defer the V2 port) or design SDK-agnostic
   so both land together under `migrate-opencode-v1-to-v2`?
