## Exploration: mact2 OpenAI-compatible proxy via rog

### Current State
`mact2` already imports the shared Home Manager OpenCode stack, so its `opencode.json` and shell secret exports are generated from `shared/opencode.nix` and `shared/opencode/runtime-config.nix`. `rog` already hosts `glats.org` and `*.glats.org` behind nginx with wildcard ACME and loopback reverse-proxy patterns in `linux/system/services/web/nginx.nix`. The repo already supports custom OpenAI-compatible providers via `@ai-sdk/openai-compatible` in `shared/opencode/providers-extra.nix`, while the built-in `openai-*` tiers in `shared/opencode/providers-base.nix` are explicitly tied to ChatGPT Plus/Pro browser OAuth. Current upstream OpenCode evidence also shows the macOS OpenAI browser flow can fail with token-exchange 403s (#16281), and custom-baseURL work is fragile if the built-in `openai` provider ID is reused with stored OAuth state (#31926 / #25627).

### Affected Areas
- `hosts/rog/default.nix` — `rog` is the host that already imports nginx, Docker/OCI, and the public service stack.
- `hosts/rog/secrets.nix` — best existing place for host-scoped gateway upstream secrets on `rog`.
- `linux/system/services/web/nginx.nix` — existing wildcard TLS and reverse-proxy entry point for a new `oai.glats.org` vhost.
- `linux/system/services/web/*.nix` or `linux/system/services/network/*.nix` — repo pattern for adding one new loopback-bound service/container module on `rog`.
- `hosts/mact2/default.nix` — host-specific place if `mact2` needs a provider-tier switch or extra OpenCode initialization.
- `shared/opencode/providers-extra.nix` — likely place to add a new custom provider ID for the `rog` gateway.
- `shared/opencode.nix` — exports provider credentials into the OpenCode shell runtime on Darwin/Linux.
- `shared/sops.nix` — shared user secret declarations for the client-facing gateway key used by `mact2`.

### Approaches
1. **LiteLLM on `rog` behind nginx** — run LiteLLM on loopback, publish it at `https://oai.glats.org/v1`, keep the real upstream API credential on `rog`, and give `mact2` only a scoped gateway/client key under a new custom OpenCode provider ID.
   - Pros: Best fit for repo patterns; OpenCode already supports custom `baseURL` + `apiKey`; LiteLLM supports OpenAI-compatible routing plus scoped virtual keys; security guidance explicitly recommends virtual keys instead of the master key.
   - Cons: Adds one more service to operate; must harden admin/master access and avoid exposing management routes.
   - Effort: Medium

2. **Thin nginx-only auth-rewrite proxy on `rog`** — use nginx as the public `oai.glats.org` entry point and forward requests to a very small internal upstream that rewrites auth to a server-side OpenAI key.
   - Pros: Smaller runtime surface than LiteLLM; simpler if only one user and one upstream model family are needed.
   - Cons: Nginx alone is weak for per-client key lifecycle, model allowlists, and admin separation; preserving full OpenAI-compatible streaming/error behavior becomes custom work.
   - Effort: Medium/High

3. **Reuse built-in `openai` / OAuth path or override it with a proxy** — keep the existing OpenAI provider identity and try to force it through a custom base URL.
   - Pros: Lowest apparent config churn.
   - Cons: Not credible for this repo: it does not solve the current browser-auth failure, and upstream issues show built-in `openai` OAuth can ignore or override custom proxy intent.
   - Effort: Low, but not viable

### Recommendation
Recommend **Approach 1** for this repo: add a new `rog`-hosted OpenAI-compatible gateway, exposed at **`oai.glats.org`**, fronted by the existing nginx wildcard/TLS setup, and consumed by **`mact2`** through a **new custom OpenCode provider ID** (not `openai`) using `@ai-sdk/openai-compatible`.

Auth model: keep the real upstream OpenAI-compatible credential **server-side on `rog`**, and give `mact2` only a **gateway/client key** stored through the repo’s normal sops flow. Do **not** depend on browser OAuth for this change. This matches current OpenCode docs for custom providers, avoids the current macOS OAuth 403 failure, and avoids the auth-precedence hazards of reusing the built-in `openai` provider ID.

### Risks
- If the user does not have an allowed server-side upstream credential path, the gateway cannot replace OAuth by itself.
- Exposing `oai.glats.org` publicly requires clear policy for rate limiting, allowed routes, and whether admin endpoints/UI stay loopback-only.
- LiteLLM is a good fit, but only if deployed with a master key, scoped virtual/client keys, and secrets kept out of repo files.
- Using provider ID `openai` instead of a new custom ID risks collisions with stored OAuth state and baseURL handling.

### Ready for Proposal
Yes — after three decisions are confirmed: **(1)** which upstream credential model is allowed on `rog` (direct OpenAI API, Azure OpenAI, or another OpenAI-compatible upstream), **(2)** whether `oai.glats.org` may be internet-exposed or must be restricted (VPN/IP allowlist/basic auth/other), and **(3)** whether this is single-user for `mact2` only or a reusable internal gateway for other hosts/tools.
