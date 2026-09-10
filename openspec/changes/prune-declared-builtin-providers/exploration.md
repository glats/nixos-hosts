## Exploration: prune-declared-builtin-providers

### Current State

`shared/opencode/providers-base.nix` (905 lines) declares four provider blocks and exports them plus the 22-profile list. The four blocks are:

- `nvidiaProvider` (lines 7–72) — custom `@ai-sdk/openai-compatible` NIM provider with `baseURL`/`apiKey`/`headers` and 13 models. **NOT in models.dev; must stay** (see below).
- `opencodeProvider` (lines 74–227) — OpenCode Zen, 33 models, each carrying `name` + `thinking = false`, plus provider `options.timeout = 3600000` / `chunkTimeout = 3600000`.
- `anthropicProvider` (lines 229–245) — 3 models (claude-opus-4-8, claude-sonnet-4-6, claude-haiku-4-5), display names only.
- `githubCopilotProvider` (lines 247–353) — 28-model static snapshot with a comment claiming it "prevents false 'model not valid' validation errors" during a dynamic-sync race.

Line 355: `allProviders = nvidiaProvider // opencodeProvider // anthropicProvider // githubCopilotProvider;` — flows into `opencode.json` `provider` key via `runtime-config.nix:91,98`. There is **no `openai` block** in the file — the user believed there was one, but `openai` has never been declared (profiles still route to `openai/*` and those resolve from the catalog, which is itself proof built-ins work undeclared).

`providers-extra.nix` (438 lines, 11 providers) is threaded by `providers.nix` as `extraProviders` but **no consumer reads that key** — `runtime-config.nix` only reads `providers.allProviders`, `agents.nix` only reads `activeProvider`/`getModelForPhase`.

Profile model strings are emitted by `agents.nix:40–66` into the agent graph; `runtime-config.nix:94–107` writes `opencode.json`. The 22 profiles are canonical (10) + legacy (12) concatenated at `providers = canonicalProviders ++ legacyProviders;` with an `_assertUniqueProviderNames` assertion (duplicate names only — no model-vs-declaration validation exists anywhere).

### Impact Verification Results

This is the user's core requirement. Three read-only experiments were run (scratch files under `/tmp/opencode/prune/`, never in the repo).

**1. Nix eval A/B (harness imports `providers-base.nix` via the pinned nixpkgs lib `a9e6d84`).**

- Base `providers` count: **22**. Pruned `providers` count: **22**.
- `providers` lists are **structurally identical** (full JSON equality, `True`; names list identical).
- `allProviders` keys: base `[anthropic, github-copilot, nvidia, opencode]` → pruned `[nvidia]` only.
- Every one of the 22 profiles' 12 phase keys (gentle-orchestrator, neutral, sdd-init/explore/propose/spec/design/tasks/apply/verify/archive/onboard) resolves to a `provider/model` string in both variants — no phase lost, no phase re-pointed.

**2. Catalog cross-check (definitive no-impact proof).** Extracted every unique `provider/model` reference from the pruned `providers` attrset and checked each model ID against `https://models.dev/api.json`.

| provider | total IDs referenced | in catalog | missing |
|---|---|---|---|
| anthropic | 3 | 3 | — |
| github-copilot | 10 | 10 | — |
| openai | 7 | 7 | — |
| opencode | 4 | 4 | — |
| opencode-go | 5 | 5 | — |
| nvidia | 4 | n/a (custom) | exempt (declared in-file) |
| **TOTAL (excl. nvidia)** | **29** | **29** | **0** |

Zero model IDs are missing from the models.dev catalog across all five built-in provider prefixes. The 3 anthropic models resolve to matching display names (note: catalog shows `claude-haiku-4-5` as "Claude Haiku 4.5 (latest)" vs the block's "Claude Haiku 4.5" — cosmetic, ID resolves). The 6 free Zen models exist under `opencode`. This is the definitive proof that deleting the three blocks has no impact on profile resolution.

**3. Consumer audit.** `extraProviders` has **zero consumers** (referenced only in `providers.nix` self-definition and `providers-extra.nix` export). The only consumers of the exported lets are `runtime-config.nix:91` (`allProviders`), `agents.nix:40/43/59/62/63` (`activeProvider`/`getModelForPhase`), `opencode.nix:12` (import). No file anywhere reads the named lets `opencodeProvider`/`anthropicProvider`/`githubCopilotProvider`, and the plugins (`model-variants.ts`, `opencode-review-transport.ts`) are runtime-only — they read the merged registry via the in-process SDK (`provider.list()`), never the `opencode.json` `provider` key at build time.

**4. Caveat (a) github-copilot deep-dive.** OpenCode's `provider.ts` (anomalyco/opencode, current rev) loads the bundled models.dev catalog first (`database`), then "extends database from config" via `mergeDeep` (lines 1480–1578) — config `provider` entries are an override/union, never a prerequisite. github-copilot additionally syncs dynamically via `plugin/github-copilot/models.ts` (`GET /models`, 5s timeout) and **prunes** any model whose `api.id` isn't in the Copilot API response. Consequences: (a) all 10 referenced github-copilot models already exist in the bundled catalog, so removing the static block cannot produce a "model not valid" at startup; (b) plan-level availability (a model pruned because the account doesn't expose it) is driven by the Copilot `/models` response and is **independent of the static block** — the block's models are pruned too. The block comment's claimed protection is stale. Relevant upstream issues are all plan/API-driven, not static-config-driven: #34644 (Copilot Student/auto-mode → provider absent entirely), #19338 (preview models rejected — token-exchange), #5623 (subagent `ProviderModelNotFoundError`). Affects only mact2 (`work-copilot-anthropic`).

**5. Caveat (b) opencode deep-dive.** In the config schema (`packages/core/src/v1/config/provider.ts`) the model object accepts `id, name, family, release_date, attachment, reasoning, temperature, tool_call, interleaved, cost, limit, modalities, experimental, status, provider, options, headers, variants` — **there is no `thinking` field**, so all 33 `thinking = false` entries are silently dropped. By contrast `options.timeout` and `options.chunkTimeout` are valid provider options with **default 300000 ms (5 min)**; the block's `timeout = 3600000` (full-request) and `chunkTimeout = 3600000` (SSE) are merged at provider.ts:1486/1651 and are **effective** — they extend the free Zen models' streaming window from 5 min to 1 h. So the `options` lines are live config (affect t14 + darwin base, active profile `opencode-free`); the model list + `thinking` are dead.

**6. nvidia MUST STAY** — confirmed in `provider.ts`: the `nvidia` custom loader sets `autoload: provider.source === "config"`, i.e. nvidia models only autoload when declared in `opencode.json` config. It is not in models.dev and needs `npm`/`baseURL`/`apiKey`, exactly as the current block provides.

### Affected Areas

- `shared/opencode/providers-base.nix` — delete `opencodeProvider`, `anthropicProvider`, `githubCopilotProvider`; shrink `allProviders`.
- `shared/opencode/providers-extra.nix` — delete (dead code).
- `shared/opencode/providers.nix` — drop the `builtins.pathExists`/`extraProviders` threading.
- `openspec/specs/gentle-ai-declarative-runtime/spec.md` — references `providers-base.nix` as the declarative-architecture anchor (no host consumption change; may need a wording touch if the block count changes).
- Not touched: any host `default.nix`, `flake.nix`, `darwin/default.nix`, `agents.nix`, `runtime-config.nix` consumers (they read `allProviders`/`providers`/`activeProvider`, all of which survive).

### Approaches

1. **A — Full cut + delete providers-extra.nix** — delete all three blocks, `allProviders = nvidiaProvider;`, delete `providers-extra.nix`, drop `extraProviders` threading.
   - Pros: maximal cleanup (~380 lines across two files); zero dead config left; matches user's mental model exactly.
   - Cons: removes the opencode provider `options.timeout/chunkTimeout` → t14 + darwin base revert to 5-min SSE chunk timeout for free Zen models (real, if low-probability, regression risk on long reasoning pauses); drops the github-copilot static snapshot (harmless per §4).
   - Effort: Low.

2. **B — Full cut but retain minimal opencode `options` (recommended)** — delete `anthropicProvider` + `githubCopilotProvider` + delete `providers-extra.nix`; reduce `opencodeProvider` to a tiny `{ opencode = { options = { timeout = 3600000; chunkTimeout = 3600000; }; }; }` block (drop the 33-model list and all `thinking` fields). `allProviders = nvidiaProvider // opencodeProvider;`.
   - Pros: ~350 lines of stale/declared-dead config removed; preserves the one piece of config with actual runtime effect (timeout); no behavior change on t14/darwin base; `thinking:false` dead fields gone.
   - Cons: keeps a 5-line opencode block the user might expect to vanish; still requires explaining why one block survives.
   - Effort: Low.

3. **C — Minimal safe cut only** — delete only `anthropicProvider` + `providers-extra.nix`; keep `opencodeProvider` and `githubCopilotProvider` untouched.
   - Pros: smallest blast radius; no timeout risk; no copilot-race discussion.
   - Cons: leaves 260+ lines of dead/stale config (opencode 33-model list + copilot 28-model snapshot); leaves the misleading copilot "race" comment in place; fails the user's actual goal (they want anthropic *and* copilot *and* opencode gone).
   - Effort: Low.

### Recommendation

**Approach B.** The verification proves the user's hypothesis is correct for profile routing — all 22 profiles are byte-identical after removing the three blocks, and all 29 referenced model IDs resolve from the models.dev catalog with zero misses. The single non-cosmetic exception is the opencode block's `options.timeout`/`chunkTimeout` (default 300 000 ms vs 3600 000 ms), which is live config that protects t14/darwin base against 5-minute streaming aborts on slow free Zen reasoning models. Approach B captures ~95% of the cleanup while keeping those 4 option lines so t14/darwin base behavior is unchanged. `providers-extra.nix` should be deleted regardless (dead code, zero consumers). The `thinking = false` fields are confirmed dead and can go with no effect.

### Risks

- t14/darwin base timeout regression if the opencode `options` are dropped (mitigated by B).
- mact2 github-copilot plan availability is orthogonal to this change (existing risk; static block never protected it).
- `openspec/specs/gentle-ai-declarative-runtime/spec.md` wording references `providers-base.nix` — re-read before archive; no host consumption changes.
- Stale AGENTS.md: it claims mact2 uses `openai-medium-proxy`, but code says `work-copilot-anthropic`; and the per-host override table lists `openai-medium` for thinkcentre (correct) but wrong for mact2. Out of scope here; note, do not fix.

### Ready for Proposal

Yes. The exploration delivers the user's demanded no-impact proof: 22 profiles structurally identical, 0 missing model IDs across 5 built-in providers, `allProviders` shrinks to nvidia (+ minimal opencode options under B), and the only live config that would otherwise be lost is the opencode timeout block. The orchestrator should tell the user: "Your hypothesis is confirmed for routing — all profiles survive byte-identical. One caveat: the opencode block's `options.timeout`/`chunkTimeout` are real config, not dead weight, so I recommend keeping just those 4 lines (Approach B). `thinking:false` everywhere is dead, `openai` was never declared, and `providers-extra.nix` is 438 lines of dead code — all safe to remove."
