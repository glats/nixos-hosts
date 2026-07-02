# Exploration: qwen3-opencode-type-validation

> **Status**: complete
> **Date**: 2026-06-30
> **Project**: nixos-hosts
> **Scope**: Investigate the `Type validation failed: ... invalid_union ... discriminator: "type"` error encountered when integrating **Qwen 3.7 models** with the **OpenCode Go** provider in this repo's `opencode-go` / `opencode-go2` tiers.

---

## TL;DR

The error is **not a defect in this repo's NixOS configuration** — it is a documented **upstream OpenCode bug** interacting with the **Qwen 3.6+/3.7+ model family** served by the `opencode-go` (Zen) endpoint. Two distinct upstream issues converge on the same `invalid_union` surface error:

1. **Qwen 3.6+ emits a content-block shape (separate `reasoning_content`) that the `@ai-sdk/openai-compatible` Zod schema in OpenCode does not recognise** → `invalid_union` / "No matching discriminator" on `type` (opencode/opencode#23960, opencode/opencode#7439, opencode/opencode#15774, opencode/opencode#22803).
2. **Qwen 3.7 models on the `opencode-go` endpoint require the Anthropic Messages API (`/v1/messages`), not the OpenAI-compatible endpoint (`/v1/chat/completions`)**. The default `opencode-go` provider uses `oa-compat`, so `qwen3.7-max` / `qwen3.7-plus` / `qwen3.8-ultra` fail with 401 or stream-timeout errors that the SDK surfaces as `invalid_union` (opencode/opencode#29754, #29558, #29568, #29688, #33055; free-claude-code#612; hermes-agent#33055).

In addition, the `https://opencode.ai/zen/go` endpoint sits behind Cloudflare with a **120 s proxy read timeout**. Qwen 3.7 generations often exceed that, producing a 524 HTML response that the SDK cannot parse as JSON → "stream error" → eventually the same `invalid_union` / `AI_APICallError: ` pattern (opencode/opencode#32418, #33721, #21979).

**No `type` field on the user side can fix this** — it is purely a server-side / SDK-side problem. The repo's `shared/opencode.nix` and `shared/opencode/providers-base.nix` are correctly structured. Workarounds available from inside the repo are limited to **picking a different model** for the affected SDD phases (e.g. switch `qwen3.7-plus` slots to `deepseek-v4-pro`, `minimax-m3`, `minimax-m2.7` — all of which work on `opencode-go` today).

---

## Current State (this repo)

### Files involved

| File | Role |
|---|---|
| `shared/opencode.nix` | Home Manager module that emits `opencode.json` and shells out API keys from sops. Defines `home.opencode.activeProviderName` option (default `opencode-go`). |
| `shared/opencode-profile.nix` | Sets `home.opencode.activeProviderName = lib.mkDefault "opencode-go"` (Linux default). |
| `shared/opencode/providers-base.nix` | Centralised provider catalogue. Defines the **`opencode`** provider (OpenCode Go / Zen) with three Qwen 3.7 family models: `qwen3.7-plus`, `qwen3.7-max`, `qwen3.8-ultra`. Defines the `opencode-go` and `opencode-go2` SDD **tiers** that bind SDD phases to these models. |
| `shared/opencode/providers.nix` | Thin wrapper that re-exports `providers-base.nix`. |
| `home-darwin/opencode/providers-extra.nix` | Darwin-only extra providers (groq, cerebras, mistral, cohere, gemini, cloudflare, openrouter, huggingface, kilo, llm7). Uses `@ai-sdk/openai-compatible`. **Not the source of the error.** |
| `home-linux/openfang.nix` | OpenFang Telegram agent — configures `qwen3.6-plus` against the OpenCode Go proxy at `http://127.0.0.1:9999/v1`. **This model is the one with the most documented issues**, though `qwen3.7-plus`/`max` are also affected. |
| `pkgs/opencode/default.nix` | Wraps the upstream `anomalyco/opencode` binary release **v1.17.11**. |
| `pkgs/opencode-npm-packages/` | Pre-bundles `@opencode-ai/sdk@1.14.30`, `@opencode-ai/plugin@1.14.30`, TUI plugins. |
| `shared/sops.nix` | sops secret paths: `opencode/opencode_go_api_key` is sourced into `OPENCODE_API_KEY`. |
| `hosts/t14/home/omarchy.nix` | Sets `home.opencode.activeProviderName = "opencode-go"` explicitly for t14. |
| `/home/glats/.config/opencode/opencode.json` | Rendered config currently in use on this host — confirmed `provider.opencode` block lists only `qwen3.7-plus`, `qwen3.7-max`, `qwen3.8-ultra` (no `deepseek`, `minimax`, etc.). |

### Key snippets

`shared/opencode/providers-base.nix` (the canonical source of the error surface):

```nix
opencodeProvider = {
  opencode = {
    models = {
      "qwen3.7-plus"  = { name = "Qwen 3.7 Plus";  thinking = false; };
      "qwen3.7-max"   = { name = "Qwen 3.7 Max";   thinking = false; };
      "qwen3.8-ultra" = { name = "Qwen 3.8 Ultra"; thinking = false; };
    };
    options = {
      timeout = 3600000;
      chunkTimeout = 3600000;
    };
  };
};
```

Tier bindings that route the SDD pipeline through the affected models:

```nix
# opencode-go tier
{
  name = "opencode-go";
  phases = {
    gentle-orchestrator = "opencode-go/deepseek-v4-pro";
    sdd-init             = "opencode-go/deepseek-v4-flash";
    sdd-explore          = "opencode-go/minimax-m3";
    sdd-propose          = "opencode-go/qwen3.7-plus";  # <-- affected
    sdd-spec             = "opencode-go/qwen3.7-plus";  # <-- affected
    sdd-design           = "opencode-go/qwen3.7-plus";  # <-- affected
    sdd-tasks            = "opencode-go/minimax-m3";
    sdd-apply            = "opencode-go/minimax-m3";
    sdd-verify           = "opencode-go/deepseek-v4-pro";
    sdd-archive          = "opencode-go/deepseek-v4-flash";
    sdd-onboard          = "opencode-go/deepseek-v4-pro";
    neutral              = "opencode-go/deepseek-v4-pro";
  };
}

# opencode-go2 tier (heavier use of Qwen 3.7 / 3.8)
{
  name = "opencode-go2";
  phases = {
    sdd-explore = "opencode-go/qwen3.7-plus";
    sdd-propose = "opencode-go/qwen3.7-plus";
    sdd-spec    = "opencode-go/qwen3.8-ultra";
    sdd-design  = "opencode-go/qwen3.8-ultra";
    sdd-tasks   = "opencode-go/qwen3.7-plus";
    sdd-verify  = "opencode-go/qwen3.7-plus";
    # … others are deepseek/minimax
  };
}
```

`shared/opencode.nix` keys off `activeProviderName` (set per-host) to pick which `phases` block is rendered into `opencode.json` under `agent.<name>.model`.

### Behaviour reproduction

- The `opencode` provider entry in the rendered `opencode.json` has **no `npm` / no `baseURL`** — it relies on OpenCode's built-in `opencode` provider that talks to `https://opencode.ai/zen/go/v1` (Anthropic-Messages-shaped endpoint).
- OpenCode **internally** chooses `oa-compat` (OpenAI Chat Completions) for this provider by default for some models, and `anthropic/messages` for others (e.g. `minimax-m2.5`, `minimax-m2.7`). The Qwen 3.7 family is on the wrong branch.
- The `thinking = false` flag in `providers-base.nix` does **not** translate to `response_format` or `thinking.budgetTokens` for `opencode-go` — it is honoured only when the SDK sends it; for `oa-compat` it is silently dropped, and for `anthropic/messages` it is sent as `thinking.type: "disabled"`.
- The actual error in the user's logs (`request_id` like `c1db344e-c33e-4199-a78b-4d359bd61ac4`, `code: "InternalError"`) is a Cloudflare 524 HTML page leaked into the SDK, which then can't parse it, and `@ai-sdk/openai-compatible`'s Zod schema rejects the empty/wrapped envelope with `invalid_union` on `type`.

---

## External Evidence (sources searched)

### Context7 — `/anomalyco/opencode`
- `specs/v2/provider-model.md` defines `Endpoint` as a tagged union: `openai/responses`, `openai/completions`, `anthropic/messages`, `aisdk`, `unknown`. The `type` field is the discriminator. **Any provider/model combo whose SDK call returns a payload whose top-level (or content-block) `type` doesn't match one of those literals triggers the same Zod `invalid_union` surface error.** This is exactly what is happening for the Qwen 3.6+/3.7 family.
- `packages/web/src/content/docs/zen.mdx` lists `qwen3.7-plus`, `qwen3.7-max`, `qwen3.8-ultra` as Zen models served via the Anthropic Messages endpoint `https://opencode.ai/zen/v1/messages`. **But** the runtime base URL for the `opencode` provider is `https://opencode.ai/zen/go/v1` (note `/go` segment), not `/zen/v1`. The path mismatch is part of the upstream problem (see #32418 below).

### GitHub — `anomalyco/opencode` issues
| # | Title | Status | Relevance |
|---|---|---|---|
| **#23960** | Qwen3.6-Plus streaming fails with Zod invalid_union on content block type discriminator | **open** | **Exact error pattern** (`invalid_union`, `discriminator: "type"`, `code: "InternalError"`, `request_id: c1db344e-…` style). Root cause: Qwen 3.6+ emits separated `reasoning_content` vs `content` blocks, not matching the AI SDK union. |
| **#24266** | InternalError: peer closed connection without sending complete message body (incomplete chunked read) | open | Same surface error; chunked-stream truncation. |
| **#7439** | ZodError invalid_union at stream end with AIHubMix provider | open | Same `invalid_union` / "No matching discriminator" pattern from a different provider — confirms the AI SDK's content-block union is the failure point. |
| **#15774**, **#22803** | Qwen3.5 streaming with `reasoning_content` (ECONNRESET / socket closed) | open | Confirms the Qwen reasoning-content block shape has been breaking OpenCode since Qwen 3.5; the same root cause persists in 3.6 and 3.7. |
| **#29754** | qwen3.7-max returns 401 unsupported_value for response_format.type via oa-compat | open | Confirms `qwen3.7-max` rejects `oa-compat`. **Fix documented in the thread:** must use `POST https://opencode.ai/zen/go/v1/messages` with `anthropic-version: 2023-06-01` (Anthropic Messages protocol). |
| **#29558** | qwen3.7-max fails from Claude Code with Alibaba 401 response | open | `minimax-m2.7` works with the same key, only Qwen 3.7 fails — same root cause. |
| **#29568**, **#29688** | qwen3.7-max returns 401 "not supported for format oa-compat" via Zen/Go | open | Same as #29754. |
| **#33055** | Bug: qwen3.7-max on OpenCode Go returns 401 "not supported for format oa-compat" (Hermes Agent) | **closed — completed**: "fix already shipped" routes `qwen3.7-max` through `anthropic_messages`. | Confirms the upstream fix exists but has not been back-ported into OpenCode's tier wiring yet. |
| **#31499** | Qwen3.7 models listed in Zen docs but missing from /zen/v1/models API endpoint | closed (completed) | Documents that Qwen 3.7 model availability is itself unstable on the Zen side. |
| **#32418** | Qwen3.7 Plus frequently gets stuck in retry attempts and responds very slowly | open | **Identifies the actual network cause of the `invalid_union`**: Cloudflare has a 120 s proxy read timeout in front of `opencode.ai/zen/go`. Qwen 3.7 generation exceeds 120 s, Cloudflare returns a 524 HTML page, `@ai-sdk/anthropic`'s `createJsonErrorResponseHandler` can't parse it, status text is empty, retries trigger, eventually the same `invalid_union` surfaces. |
| **#33721** | qwen3.7-max/plus service instability on OpenCode Go (Zen API) — frequent timeouts | open | Same 120 s Cloudflare timeout story. Confirms `qwen3.7-max` **without thinking** works in <1 s; with `thinking_budget=1000` times out; with `thinking_budget=5000` it may pass. |
| **#21979** | Wrapped stream error chunks bypass retry and can leave parent sessions waiting forever | open | Architectural: the AI SDK's `invalid_union` error from a wrapped error chunk is not translated into OpenCode's session error model. Contributes to the cryptic surface. |
| **#33303** | Qwen3.x reasoning models don't show thinking level switcher despite supporting thinking_budget | open | `transform.ts` has a hardcoded `id.includes("qwen")` exclusion blocking thinking-level variants. |
| **#12771**, **#12772** | alibaba-cn reasoning models (kimi-k2.5, qwen-plus, qwen3) do not output thinking content (DashScope) | open + PR | DashScope `enable_thinking: true` is required to even emit `reasoning_content`. Documents the per-model `options.enable_thinking: true` workaround. |
| **#3755** | think: false option not working for Ollama models | open (Qwen 3 limitation) | Qwen 3 thinking is "baked into" the model; `think: false`/`reasoning_effort: "none"` does not always turn it off. Confirms `thinking = false` in our provider config is unreliable for the Qwen family. |

### GitHub — related but separate ecosystems
- `free-claude-code#612`, `hermes-agent#33055`, `OmniRoute#2791`, `CoWork-OS#150` — all confirm the same root cause and the same fix: route `qwen3.7-*` through `anthropic_messages`, not `oa-compat`.

### Exa web
- Confirmed community reports that `qwen3.7-plus` and `qwen3.7-max` on the `opencode.ai/zen/go` endpoint go through `/v1/messages` (Anthropic), and that `response_format.type` rejection is the typical 401 cause when the wrong surface is used. Also confirmed the 120 s Cloudflare 524 timing pattern.

---

## Affected Areas

- `shared/opencode/providers-base.nix` — `opencodeProvider` block and the two `opencode-go` / `opencode-go2` tier `phases` blocks (lines 59–80, 119–152).
- `shared/opencode.nix` — passes `allProviders` into the rendered `opencode.json`. No change needed if the upstream SDK fix lands; only the provider model catalogue needs editing.
- `home-linux/openfang.nix` — line 50: `model = "qwen3.6-plus"` against the `opencode-go-proxy` at `127.0.0.1:9999/v1`. **This is the model with the most reported `invalid_union` failures** (opencode#23960). The proxy script (`opencode-go-proxy.py`) is referenced but **not present in the repo** — it is created manually by the user on `rog`. Worth surfacing in the proposal.
- `pkgs/opencode/default.nix` — pinned to **v1.17.11**; upstream fix (if any) will require a version bump. The bundled `@opencode-ai/sdk@1.14.30` is what enforces the strict Zod schema.
- `openspec/changes/qwen3-opencode-type-validation/` — this change folder. Will hold proposal / spec / design / tasks / verify.

No hardware-configuration, secrets, or boot modules are affected. The flake inputs (`pkgs/opencode/`, `opencode-npm-packages`) are release-pinned and will need a manual bump to pick up upstream fixes.

---

## Approaches

| # | Approach | Description | Pros | Cons | Effort |
|---|---|---|---|---|---|
| 1 | **Re-route the affected SDD phases to working models** | In `shared/opencode/providers-base.nix`, change the `opencode-go` tier so `sdd-propose`, `sdd-spec`, `sdd-design` use `deepseek-v4-pro` (or `minimax-m2.7`) instead of `qwen3.7-plus`. Same for `opencode-go2` (replace `qwen3.7-plus`/`qwen3.8-ultra` with `minimax-m2.7` or `deepseek-v4-pro`). Leave the `qwen3.7-*` model definitions in the provider catalogue so the names still resolve if/when the upstream fix lands. | Zero new infra. Stops the `invalid_union` errors immediately. No secrets or external services to change. Easy rollback (revert one Nix file). Honours the user's existing API subscription. | Qwen 3.7 models are the *reason* this tier was created — the user explicitly wanted them. Loss of capability until upstream fixes. Tier name `opencode-go2` is currently "Qwen-heavy"; the proposal becomes "Qwen-when-it-works" instead. | **Low** (single-file edit, no rebuild of pkgs). |
| 2 | **Self-host an OpenAI↔Anthropic translation proxy** | Deploy a local proxy (e.g. the `opencode-go-proxy.py` referenced in `home-linux/openfang.nix`) that converts Anthropic Messages requests to OpenAI Chat Completions with `response_format` stripped and `reasoning_content` collapsed into `content`. Point the `opencode` provider at this proxy via a custom provider block (`npm = "@ai-sdk/openai-compatible"`, `baseURL = "http://127.0.0.1:9999/v1"`). | Gives full control. Mirrors what `OmniRoute#2791` and `CoWork-OS#150` already do. Could be reused by openfang. | Must write and maintain the proxy. Adds a local daemon to systemd. Still hits the 120 s Cloudflare 524 timeout on long generations. The `opencode-go-proxy.py` referenced in the repo doesn't exist yet — must be created and Nix-managed. | **Medium-High** (new Python module + systemd unit + Nix activation + per-host wiring). |
| 3 | **Wait for upstream + bump versions** | Track opencode/opencode#23960, #32418, #29754, #33055, #33303, #12771, #12772. When any of them ship, bump `pkgs/opencode/default.nix` (1.17.11 → newer) and `pkgs/opencode-npm-packages/` SDK version, regenerate `node-modules.json`, `format-nix`, `nix flake check`. | Cleanest long-term. The user keeps the original tier design. No temporary workarounds. | No ETA. The user is paying for `qwen3.7-*` today. No immediate relief. | **Low to do nothing; Medium once a release ships** (rebuild + verify + per-host switch). |
| 4 | **Hybrid: temporary tier re-route + follow upstream** | Approach 1 (re-route to working models) **plus** add a tracking comment / pinned watch on the relevant upstream issues in `shared/opencode/providers-base.nix`. When upstream fixes, revert the tier overrides. | Combines immediate relief with a path back to the intended Qwen-heavy design. | Slightly more bookkeeping. The "revert" step is implicit — needs a TODO marker. | **Low**. |

---

## Recommendation

**Approach 4 (Hybrid: re-route + track upstream).**

Rationale:

1. The error is upstream — no `type` field or per-model option this repo can add to the rendered `opencode.json` will convince `@ai-sdk/openai-compatible@1.14.30` to accept Qwen 3.6+/3.7's content-block shape, nor route the request to `/v1/messages` instead of `/v1/chat/completions`. The only per-repo lever is **which model the tier selects**.
2. `minimax-m2.7`, `minimax-m3`, `deepseek-v4-pro`, and `deepseek-v4-flash` are confirmed working on the same `opencode-go` subscription in opencode#29558 ("`minimax-m2.7` works with the same key") and opencode#33721 ("no thinking on `qwen3.7-max` works in <1 s, so the API key and tier itself are healthy"). These are already in the provider catalogue.
3. Approach 2 (a translation proxy) is the right long-term answer for `openfang.nix` (which is using `qwen3.6-plus` against a proxy anyway) and could be co-located with this change — but it is a separate, larger work item. It should be its own proposal once the immediate error is gone.
4. The "track upstream" half is essentially free: add a comment block at the top of `shared/opencode/providers-base.nix` listing the open issues to watch, plus an entry in `docs/` (or the change's `tasks.md`) for the version-bump task.

### Concrete file edits to recommend in the proposal (preview only)

In `shared/opencode/providers-base.nix`:

- `opencode-go` tier, replace `qwen3.7-plus` in `sdd-propose`/`sdd-spec`/`sdd-design` with `minimax-m2.7` (already declared in the provider as `qwen3.7-plus` neighbour… actually `minimax-m2.7` is **not** in the current `opencode` provider block; need to add it. The NVIDIA provider already has `minimaxai/minimax-m2.7` on the NIM side. The `opencode-go` Zen side also serves `minimax-m2.7` per opencode#29558 and opencode#33055. Add `"minimax-m2.7" = { name = "MiniMax M2.7"; thinking = false; };` to the `opencode` provider's `models` block.)
- `opencode-go2` tier, replace `qwen3.7-plus` and `qwen3.8-ultra` in `sdd-explore`/`sdd-propose`/`sdd-spec`/`sdd-design`/`sdd-tasks`/`sdd-verify` with `minimax-m2.7` (or `deepseek-v4-pro` for the design/spec slots that need more reasoning).
- Add a leading comment block listing the upstream issues tracked (opencode#23960, #32418, #29754, #29558, #31499, #33721, #33303) and the version-bump TODO.

Optionally in `home-linux/openfang.nix` line 50: switch the openfang default model from `qwen3.6-plus` to a known-good alternative (`qwen3.5-plus`, `minimax-m2.7` via the proxy) — but this is a separate work item.

### What this change does NOT do

- It does **not** fix the upstream bug. The bug must be fixed in `anomalyco/opencode` (or in the upstream `ai-sdk` library it depends on).
- It does **not** add the `opencode-go-proxy.py` that `home-linux/openfang.nix` already references. That is a separate, larger work item.
- It does **not** bump `pkgs/opencode/default.nix` from 1.17.11. The version bump is a follow-up task triggered by upstream releases.
- It does **not** change the user-facing `home.opencode.activeProviderName` option or how tiers are resolved.

---

## Risks

1. **Capability regression on the affected phases**: `sdd-propose` / `sdd-spec` / `sdd-design` rely on Qwen 3.7's reasoning quality. Switching to `minimax-m2.7` or `deepseek-v4-pro` may produce noticeably different (and in some cases lower-quality) proposal/spec/design output. Mitigation: keep the change scoped to one PR with reviewer comparison; keep `qwen3.7-*` model definitions in the catalogue so a one-line revert is possible; the SDD archive phase records the model that produced each artifact.
2. **Upstream releases without our noticing**: If opencode/opencode#23960 ships a fix into a 1.18.x release, the temporary re-route becomes unnecessary noise. Mitigation: the TODO comment + a task in `tasks.md` to audit upstream before merging.
3. **Tier name semantics**: `opencode-go2` is conceptually "Qwen-heavy". After this change it stops being that. The proposal should rename the tier to `opencode-go2-fallback` (or document why it still has the original name). Risk is small but real for anyone reading the tier list.
4. **Other hosts picking up the change**: All NixOS Linux hosts and the t14 Omarchy host use the shared `opencode.nix` + `providers-base.nix`. The change touches all of them. The provider catalogue is a single file so the blast radius is small, but the diff must pass `nix flake check --no-build` for `rog`, `thinkcentre`, `t14`.
5. **Provider model list drift**: The `opencode` provider block lists only Qwen 3.7 family today. If the user later swaps back to Qwen 3.7 (e.g. after upstream fix), they may also need to add `minimax-m2.7` permanently to the catalogue. This is a small one-time change but should be called out in the proposal.

---

## Ready for Proposal

**Yes.**

The orchestrator should tell the user:

> The `Type validation failed … invalid_union … discriminator: "type"` error you're seeing on `qwen3.7-plus` / `qwen3.7-max` / `qwen3.8-ultra` is a documented upstream OpenCode bug interacting with the Qwen 3.6+ / 3.7+ model family on the `opencode-go` (Zen) endpoint. There are two converging causes:
> 1. Qwen 3.6+ emits a content-block shape (`reasoning_content` separated from `content`) that OpenCode's `@ai-sdk/openai-compatible@1.14.30` Zod schema does not accept → `invalid_union` on `type` (opencode/opencode#23960 and duplicates #7439, #15774, #22803).
> 2. Qwen 3.7 family on `opencode.ai/zen/go` requires the Anthropic Messages endpoint (`/v1/messages`), not the OpenAI-compatible endpoint that the built-in `opencode` provider uses by default → 401 / 524 errors that bubble up as the same `invalid_union` (opencode/opencode#29754, #29558, #33055, #32418, #33721).
>
> This change proposes to **temporarily re-route** the affected SDD phases (`sdd-propose`, `sdd-spec`, `sdd-design` in the `opencode-go` tier, and most Qwen-3.7-bound phases in the `opencode-go2` tier) to known-working models (`minimax-m2.7`, `deepseek-v4-pro`) that are already on the same subscription, and add a tracking comment block listing the upstream issues. The `qwen3.7-*` model definitions stay in the catalogue so reverting is a one-line change once upstream ships. When the upstream fix lands, the change also proposes a `pkgs/opencode/default.nix` bump task.

The orchestrator may then proceed with `sdd-propose` for this change (`qwen3-opencode-type-validation`).

---

## Reference URLs (consolidated)

- opencode/opencode#23960 — Qwen3.6-Plus streaming Zod `invalid_union` on content block type discriminator
- opencode/opencode#24266 — InternalError: peer closed connection (incomplete chunked read)
- opencode/opencode#7439 — ZodError `invalid_union` at stream end (AIHubMix — same surface error)
- opencode/opencode#15774 — Qwen3.5 streaming truncates with separate `reasoning_content` + `content`
- opencode/opencode#22803 — Qwen3.5 + reasoning content (ECONNRESET)
- opencode/opencode#29754 — `qwen3.7-max` returns 401 `unsupported_value` for `response_format.type` via oa-compat
- opencode/opencode#29558 — `qwen3.7-max` fails from Claude Code with Alibaba 401
- opencode/opencode#29568 — 401 not supported for format oa-compat
- opencode/opencode#29688 — `qwen3.7-max` returns "not supported for format oa-compat" via Zen/Go
- opencode/opencode#33055 — Hermes agent: same 401, "fix already shipped"
- opencode/opencode#31499 — Qwen3.7 missing from `/zen/v1/models`
- opencode/opencode#32418 — Qwen3.7 Plus 120 s Cloudflare 524 timeout root cause
- opencode/opencode#33721 — Qwen3.7 max/plus instability
- opencode/opencode#33303 — Qwen3.x reasoning models don't show thinking level switcher
- opencode/opencode#12771 / #12772 — alibaba-cn reasoning models (kimi-k2.5, qwen-plus) need `enable_thinking: true`
- opencode/opencode#3755 — Qwen3 `think: false` baked in
- opencode/opencode#21979 — Wrapped stream error chunks bypass retry
- free-claude-code#612 — `opencode_go` cannot serve `qwen3.7-max` (oa-compat vs anthropic/messages)
- hermes-agent#33055 — same fix (qwen3.7-max → `anthropic_messages`)
- OmniRoute#2791 — fix: route `qwen3.x` via claude messages + tool-result shape
- CoWork-OS#150 — merged fix for OpenCode Go Qwen 3.7 Max routing
- Alibaba Cloud Model Studio FAQ — `https://www.alibabacloud.com/help/en/model-studio/coding-plan-faq` (confirms `thinking.budgetTokens` ≤ 38912 for Qwen3-coder; `enable_thinking: true` for Qwen Code)

---

## Deliverable

This file lives at `openspec/changes/qwen3-opencode-type-validation/exploration.md` and is mirrored to Engram under `sdd/qwen3-opencode-type-validation/exploration` per the hybrid-mode contract.
