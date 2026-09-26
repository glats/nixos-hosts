## Exploration: port-opencode-v2-provider-allowlist

### Current State

The repo runs OpenCode V1 and V2 side-by-side (base change `migrate-opencode-v1-to-v2`, in progress — NOT altered here). Two isolated runtimes are generated from `shared/opencode.nix`:

- **V1** (`dir = "opencode"`, `version = "v1"`) emits a full declarative `opencode.json`: `agent`, `provider`, `mcp`, `permission`, `plugin`, `disabled_providers`, `tools`, `compaction` (`shared/opencode/runtime-config.nix:99-127`).
- **V2** (`dir = "opencode-v2"`, `version = "v2"`) emits only `{ "update": "disable" }` (`runtime-config.nix:96-97`). No providers, agents, mcp, permissions, or plugins are emitted today.

Only **two** providers are declared in the `provider` map (`allProviders = nvidiaProvider // opencodeProvider`, `shared/opencode/providers-base.nix:83`):

- `nvidiaProvider` (`providers-base.nix:7-72`): a custom, non-catalog NVIDIA NIM provider (`npm = "@ai-sdk/openai-compatible"`, `options.baseURL`, `options.apiKey`, `options.headers."Authorization" = "Bearer {env:NVIDIA_API_KEY}"`, 12 explicit models).
- `opencodeProvider` (`providers-base.nix:74-81`): options-only (`timeout`, `chunkTimeout`) for the built-in OpenCode Zen/Go provider; no declared models.

Every other provider used at runtime (`opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`) resolves from the bundled models.dev catalog plus environment credentials — never declared in the `provider` map.

`shared/opencode-profile.nix:19-29` sets `home.opencode.disabledProviders = [ cerebras cloudflare-ai-gateway cloudflare-workers-ai cohere groq kilo mistral openrouter google ]` (9 providers), emitted in V1 as `disabled_providers`.

`shared/opencode.nix:192-233` exports **13 sops secrets as 14 zsh env vars** at shell init (global, inherited by BOTH V1 and V2 shells): NVIDIA, GROQ, CEREBRAS, OPENCODE (go), OPENROUTER, MISTRAL, COHERE, GEMINI, CLOUDFLARE (token + account id), HUGGINGFACE (`HF_API_KEY`), KILO, AIHUBMIX.

Per-host active routing profile (`activeProviderName`), confirmed by grep:

| Host | Setting (source) | Provider prefixes |
|---|---|---|
| rog | `hosts/rog/home/default.nix:18` = `openai-opencode-go-heavy` | openai, opencode-go |
| thinkcentre | `hosts/thinkcentre/home/default.nix:12` = `openai-medium` | openai |
| t14 | `hosts/t14/home/default.nix:26` = `openai-medium` | openai |
| macm5 (integrated) | `hosts/macm5/default.nix:76` = `work-copilot-anthropic-light` | github-copilot, anthropic |
| macm5 (standalone) | `flake.nix:382` = `anthropic-opencode-free` | anthropic, opencode, opencode-go |

macm5 has **two** real home configurations (integrated nix-darwin + standalone HM), so its active set is the union of both rows.

### Which Declarative Providers Are Actively Referenced (Proof)

The 22 routing profiles in `providers-base.nix` reference model strings under exactly **6** provider prefixes: `opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia`.

- **`nvidia` — NOT active on any host, but PRESERVED (user decision).** `activeProviderName` grep across `flake.nix` and all `hosts/*` returns only the five values in the table above; none is `nvidia`. The `nvidia` model strings appear only inside the dormant legacy `nvidia` profile (`providers-base.nix:717-741`) and nowhere in `agents.nix` output or any active overlay. Per the user's direction, the dormant profile, its `nvidiaProvider` definition (`providers-base.nix:7-72`), and its `NVIDIA_API_KEY` export are all **kept as-is** — not removed, not fixed. (The profile still carries latent bugs — some lines use `nvidia/nvidia/…`, others `nvidia/…` — but these are pre-existing and out of scope here.) The only other NVIDIA consumer is `shared/shell-gpt.nix`, which calls the NIM API through its **own** config (exports `OPENAI_API_KEY` from the sops secret, `shell-gpt.nix:47-48`) — it does **not** use the OpenCode `nvidia` provider.
- **`opencode` — active, keep.** Referenced by active profiles (`anthropic-opencode-free` on macm5-standalone, and `opencode-free`/`anthropic-opencode-free` reference `opencode/*` free models). `opencodeProvider` only sets timeouts for this active provider.

**Conclusion:** no declarative provider is removed. `nvidia` is dormant (no host selects it) but deliberately preserved, so `allProviders` (`providers-base.nix:83` = `nvidiaProvider // opencodeProvider`) stays intact. The central allowlist therefore keeps `nvidia` as an allowed provider ID (see below).

### Which Credential Exports Are Necessary (Proof)

`sops.secrets."opencode/*"` are declared in `shared/sops.nix:9-47`; the zsh exports are `shared/opencode.nix:192-233`. Cross-referencing consumers (grep of every env-var name and `sops.secrets."opencode/*"` across the tree):

| Env var (opencode.nix) | Provider | Provider status | Other consumer | Verdict |
|---|---|---|---|---|
| `OPENCODE_API_KEY` | opencode-go | **active** (rog, macm5) | — | **KEEP in opencode.nix** |
| `NVIDIA_API_KEY` | nvidia | **dormant (preserved)** | shell-gpt has its **own** export (`shell-gpt.nix:47-48`); same secret, independent consumer | **KEEP in opencode.nix** |
| `GROQ_API_KEY` | groq | disabled | **`groq-voice-dictation`** (active change) reads `GROQ_API_KEY` (`openspec/changes/groq-voice-dictation/exploration.md:28,80`) | **RE-HOME to dictation module** |
| `CEREBRAS_API_KEY` | cerebras | disabled | none | remove |
| `OPENROUTER_API_KEY` | openrouter | disabled | none | remove |
| `MISTRAL_API_KEY` | mistral | disabled | none | remove |
| `COHERE_API_KEY` | cohere | disabled | none | remove |
| `GEMINI_API_KEY` | google | disabled | none | remove |
| `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` | cloudflare | disabled | none | remove |
| `KILO_API_KEY` | kilo | disabled | none | remove |
| `HF_API_KEY` | huggingface | orphaned (not disabled, never referenced) | none | remove |
| `AIHUBMIX_API_KEY` | aihubmix | orphaned (secret value is empty `""`) | none | remove |

Net: the zsh credential exports that remain in `shared/opencode.nix` are `OPENCODE_API_KEY` (active) and `NVIDIA_API_KEY` (dormant-but-preserved). `GROQ_API_KEY` moves **out** of `opencode.nix` and is re-homed into the `groq-voice-dictation` change so dictation alone receives it (see "Groq export re-home" below). The other 10 env vars (cerebras, openrouter, mistral, cohere, gemini, cloudflare×2, kilo, huggingface, aihubmix) have **no consumer anywhere** and are safe to remove from both `opencode.nix` and (optionally) `sops.nix`/`.sops.yaml`.

### Groq Export Re-Home (Concrete Paths)

`GROQ_API_KEY` is exported today at `shared/opencode.nix:196-198` from `config.sops.secrets."opencode/groq_api_key"` (declared `shared/sops.nix:15-17`, value in `secrets/user/opencode.yaml`). No code currently reads the variable — the dictation engine does not exist yet, and OpenCode's `groq` provider is already in `disabledProviders` (`shared/opencode-profile.nix:24`) — so removing the export is lossless for OpenCode today.

Re-home plan (owned by the `groq-voice-dictation` change, not this one):
- **Remove** the `GROQ_API_KEY` export block from `shared/opencode.nix` (lines 196-198).
- **Keep** the sops secret `opencode/groq_api_key` (`shared/sops.nix:15-17`) unchanged — it simply becomes single-consumer (dictation).
- **Add** the export to a dictation-owned Home Manager module — concretely `linux/home/groq-dictation.nix` (dictation is Linux-only; macOS native dictation is untouched), registered in `linux/home/shared-modules.nix`, exporting `GROQ_API_KEY` via `programs.zsh.initContent` exactly like the `shared/shell-gpt.nix:46-50` precedent. Alternatively, if the dictation engine reads the sops secret path directly (per `groq-voice-dictation/exploration.md:80`), no new env export is needed and removal alone is sufficient.

### V2 Policy Semantics — External Evidence (GitHub source + issues + official docs)

**1. V2 `providers` (plural) is additive, not an allowlist.** It adds/overrides catalog entries; it can never hide another provider.

**2. `enabled_providers` / `disabled_providers` are V1-only.** Official V2 docs state "Use `provider.use` instead of the V1 `enabled_providers` and `disabled_providers` lists. V1 files still load." The V1→V2 migration does not convert them.

**3. The V2-native deny/allow mechanism is `experimental.policies` with `provider.use`.** Authoritative docs (`opencode.ai/v2/docs/policies`, `specs/v2/provider-policy.md`): allowlist = `deny *` first, then `allow` each provider; ordered, last match wins, default `allow`. "A provider denied by policy disappears from the catalog and model selection even when it has valid credentials."

**4. Enforcement is wired into the active path (UPDATE from prior exploration).** Prior exploration relied on issue `#34971` (filed 2026-07-02 against v1.17.13, "v2 Catalog only consumed by `debug v2`"; closed `not_planned` by stale bot on 2026-09-03, never marked "fixed"). Source inspection of current `anomalyco/opencode` shows the v2 `Catalog.Service` is now consumed by the real runtime, not only `debug v2`:
   - `packages/core/src/catalog.ts` — `PolicyActions = Schema.Literals(["provider.use"])`; `finalize` evaluates policy and `catalog.provider.remove(...)` on deny.
   - `packages/server/src/handlers/model.ts` — `model.list` → `catalog.model.available()`.
   - `packages/server/src/handlers/provider.ts` — `provider.list` → `catalog.provider.available()`.
   - `packages/core/src/session/runner/model.ts` — `SessionRunnerModel.resolve` consumes `Catalog.Service` (execution-path model resolution).
   - A dedicated `catalog.test.ts` asserts deny removes a provider.
   So the "not enforced" risk has materially receded: policy now filters both listing and execution. It remains **experimental**, so an empirical deny-smoke is retained as a verify gate (cheap insurance), but the change should no longer be gated as "likely broken." Upstream is at ~2.0.16 (issue `#51241`); the nixpkgs-pinned `opencode-v2` version must be confirmed at apply time.

**5. No model-level allowlist yet.** Issue `#44070` (open) requests a `model.use` action; today the only per-model control is `providers.<id>.models.<model>.disabled = true` (a denylist). The "central allowlist" is therefore **provider-level** for both runtimes; model-level allowlisting is not possible in V2.

**6. V2 catalog entries (Kilo, Groq, …) are NOT repo imports.** They come from OpenCode's bundled models.dev catalog at runtime, so Nix cannot "remove" them. Hiding them requires runtime policy enforcement (`provider.use` deny) — exactly the distinction the user asked to preserve.

### Approaches

1. **Single central Nix provider allowlist (6 IDs) + prune dead credential exports + re-home groq (user-confirmed).** Define ONE allowlist — the 6 provider IDs `opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia` — in a central Nix location. V1 derives `disabled_providers` from it (curated deny list of catalog providers outside the allowlist); V2 derives `experimental.policies` (deny `*` + allow each of the 6). In the same change, prune the 10 no-consumer credential exports, **preserve** the `nvidia` provider + dormant profile + `NVIDIA_API_KEY` export untouched, and re-home `GROQ_API_KEY` out of `opencode.nix` into the dictation change.
   - Pros: one source of truth; no V1/V2 allowlist drift; `nvidia` survives as a first-class allowed provider (no dangling model strings, no secret/export churn for shell-gpt); removes 10 orphan/disabled credential exports; matches "V2 catalog entries need runtime enforcement" reality.
   - Cons: V1's emitted `disabled_providers` changes (intentional, but breaks the old "V1 byte-identical" assumption from the prior exploration — see Risks); the `nvidia` allowlist entry is a no-op in V2 today (nvidia is not declared in V2's `providers` map) unless/until the dormant profile is ported to V2; groq export re-homing is a cross-change coordination point.
   - Effort: **Low-Medium**.

2. **Separate V1/V2 allowlists (rejected).** Prior exploration's shape: a V2-only policy + `nvidia` port, independent of V1. Explicitly rejected by the user ("Do not create separate V1/V2 allowlists").

3. **Full explicit re-declaration of every allowed provider + models in V2 `providers` (rejected).** Re-declares catalog providers (~29+ model IDs) with drift/maintenance burden; still needs policy because `providers` is additive; contradicts "remove unused definitions."

### Recommendation

**Approach 1.** Introduce a single central provider allowlist in Nix — the **6** provider IDs `opencode`, `opencode-go`, `anthropic`, `openai`, `github-copilot`, `nvidia` — derived from the active routing profiles plus the preserved dormant `nvidia` profile (stated explicitly beside `providers-base.nix`), and emit from it:
- V1: `disabled_providers` = the curated deny set (catalog providers outside the allowlist — today cerebras, cloudflare-ai-gateway, cloudflare-workers-ai, cohere, groq, kilo, mistral, openrouter, google). `nvidia` is a custom (non-catalog) provider, so it stays enabled via the `provider` map and never enters this list; the deny list is unchanged at 9 entries.
- V2: `experimental.policies` = `[{deny provider.use *}, {allow provider.use <each of the 6>}]`.

In the same change, prune only the dead credential surface with the proof above: remove the 10 no-consumer exports (cerebras, openrouter, mistral, cohere, gemini, cloudflare×2, kilo, huggingface, aihubmix) and re-home `GROQ_API_KEY` out of `opencode.nix` into the dictation change. **Do not touch** `nvidiaProvider`, the dormant `nvidia` profile, `allProviders`, or the `NVIDIA_API_KEY` export — all are preserved per the user's decision. Keep `shell-gpt.nix` and every sops **secret** untouched (the `nvidia` and `groq` secrets stay; only their OpenCode exports are affected).

Derive the allowlist from a single list rather than hardcoding it in two places, so V1 and V2 cannot drift. Do not alter the in-progress base V1/V2 coexistence change's runtime structure — this change only adjusts the shared provider surface (allowlist, credential exports), which is orthogonal to how the two runtimes are generated.

### Risks

- **`provider.use` is experimental.** Source now wires it into listing + execution, and docs assert deny semantics, but it carries no hard guarantee across nixpkgs's pinned version. Keep the empirical deny-smoke as a verify gate; fallback is env-scrubbing (already happening here) plus per-model `disabled` denylist.
- **`groq` re-home is a cross-change dependency.** Removing `GROQ_API_KEY` from `opencode.nix` is safe today (no current consumer), but dictation breaks unless the `groq-voice-dictation` change ships its own export before (or with) this change. Must be coordinated; the removal and the re-home land in two different changes.
- **Dormant `nvidia` surface stays dead but present.** The preserved `nvidia` profile/provider/export add an allowlist entry and keep a 12-model block + static-key header that no host selects. This is intentional (user decision), but it means the allowlist is 6 IDs with one dormant member, and the profile's latent `nvidia/nvidia/…` vs `nvidia/…` bugs remain unaddressed (out of scope).
- **`nvidia` allowlist entry is a no-op in V2 today.** V2 does not declare `nvidia` in a `providers` map (it emits only `{ update = "disable" }`), so `allow provider.use nvidia` allows nothing until the dormant profile is ported to V2. Harmless, but worth stating so reviewers don't expect `nvidia` to appear in V2's catalog after this change.
- **V1 emitted `disabled_providers` changes.** Unlike the prior exploration's "V1 byte-identical" invariant, this approach re-derives `disabled_providers` from the central allowlist. `nvidia` is **not** removed from V1's `provider` map (it stays), so the only V1-visible change is the `disabled_providers` derivation. The base `migrate-opencode-v1-to-v2` change's runtime structure must remain untouched.
- **No `model.use`.** New models on the 6 allowed providers still appear automatically (`#44070` open). Provider-level allowlist only; a model-level pass is a future change.

### Test Plan

- **Eval:** V2 `opencode.json` gains `experimental.policies` (deny `*` + allow the 6); V1 `opencode.json` **keeps** `nvidia` in `provider` and re-derives `disabled_providers`; `nix eval .#homeConfigurations.<host>.activationPackage.drvPath` for each host succeeds; `nix flake check --no-build`.
- **Format:** `nix fmt --` on touched files only.
- **Empirical V2 smoke (rog):** `opencode2 models` lists only the 6 allowed providers (Kilo, Groq, cerebras, mistral, google, etc. absent); `opencode2 run -m groq/<model> "hi"` is rejected — the gate that proves `provider.use` enforces in the pinned version.
- **shell-gpt regression:** `sgpt --shell "hi"` still resolves against NVIDIA NIM (secret + `shell-gpt.nix` export intact, untouched).
- **OpenCode nvidia export regression:** `NVIDIA_API_KEY` still exported in the OpenCode shell env (provider preserved).
- **dictation handoff:** `GROQ_API_KEY` no longer exported by OpenCode's shell init; the `groq-voice-dictation` change owns the export (verified against its own test plan once it lands).

### Affected Areas

- `shared/opencode/providers-base.nix` — add/emit the central allowlist (6 provider IDs). `nvidiaProvider`, the dormant `nvidia` profile, and `allProviders` are **preserved, untouched**.
- `shared/opencode.nix` — expose the central allowlist as a single option (or derive it); strip the dead zsh exports down to `OPENCODE_API_KEY` + `NVIDIA_API_KEY`; **remove the `GROQ_API_KEY` export (lines 196-198)** for re-homing.
- `shared/opencode/runtime-config.nix` — V1 branch emits `disabled_providers` from the central allowlist; V2 branch emits `experimental.policies` (deny `*` + allow the 6).
- `shared/opencode-profile.nix` — `disabledProviders` becomes a derivation from the central allowlist (or is removed in favor of the central source).
- `shared/sops.nix` / `.sops.yaml` — optional follow-on: drop the 10 orphan/disabled secrets (cerebras, openrouter, mistral, cohere, gemini, cloudflare×2, kilo, huggingface, aihubmix). The `opencode/groq_api_key` and `opencode/nvidia_api_key` secrets stay. Out of strict scope if only exports are being pruned.
- `linux/home/groq-dictation.nix` + `linux/home/shared-modules.nix` — the **re-home target** for `GROQ_API_KEY`, owned by the `groq-voice-dictation` change (not this one). Reference/coordination only; do not modify here.
- `openspec/changes/groq-voice-dictation/` — coordination reference; its exploration/proposal currently assume `GROQ_API_KEY` is exported by `shared/opencode.nix` (`exploration.md:28,40,80`), so that change must pick up the export as part of its own work.
- `openspec/changes/migrate-opencode-v1-to-v2/` and `openspec/specs/gentle-ai-declarative-runtime/spec.md` — reference only, do not modify.

### Ready for Proposal

**Yes.** Both user decisions are now folded in: (1) the dormant `nvidia` profile, its `nvidiaProvider` definition, and the `NVIDIA_API_KEY` export are all **preserved** (the allowlist grows to 6 IDs to keep `nvidia` allowed), and (2) `GROQ_API_KEY` is **re-homed** out of `opencode.nix` into the `groq-voice-dictation` change. The change is a single central provider allowlist consumed by both runtimes (V1 `disabled_providers`, V2 `provider.use` policies); `OPENCODE_API_KEY` and `NVIDIA_API_KEY` remain the only OpenCode zsh exports, and 10 no-consumer exports are pruned. The orchestrator should tell the user: the two confirmations are resolved (nvidia preserved, groq re-homed), and the only remaining coordination item is the cross-change handoff — the `groq-voice-dictation` change must ship the `GROQ_API_KEY` export (concretely in `linux/home/groq-dictation.nix`, registered in `linux/home/shared-modules.nix`) before or alongside this change's removal of it from `shared/opencode.nix`.
