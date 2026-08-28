## Exploration: Approved OpenAI-compatible gateway on `rog` for Opencode

### Current State
`rog` already acts as the repo’s public web/services host: it imports the shared `linux/system/services/web/nginx.nix` module, terminates TLS for `glats.org` and `*.glats.org` through Cloudflare DNS ACME, and reverse-proxies multiple local services on loopback ports. OpenCode is configured through Home Manager (`shared/opencode.nix` + `shared/opencode/runtime-config.nix`) and already supports custom OpenAI-compatible providers via `@ai-sdk/openai-compatible` definitions in `shared/opencode/providers-extra.nix`, while the current `openai-*` tiers in `shared/opencode/providers-base.nix` explicitly rely on OpenCode’s browser/OAuth login flow. Secrets are managed with sops-nix: host/service secrets live in `hosts/rog/secrets.nix`, and shared OpenCode API keys live in `shared/sops.nix` and are exported into the shell by `shared/opencode.nix`.

### Affected Areas
- `hosts/rog/default.nix` — imports all current web/network/container modules for the target host.
- `hosts/rog/secrets.nix` — host-scoped secret declarations pattern for rog services.
- `linux/system/services/web/nginx.nix` — existing wildcard-domain TLS and reverse-proxy pattern for `*.glats.org`.
- `linux/system/services/web/*.nix` and `linux/system/services/network/*.nix` — service/container module patterns for loopback-bound services on rog.
- `shared/opencode.nix` — exports provider credentials from sops secrets into the runtime shell.
- `shared/opencode/runtime-config.nix` — generates `opencode.json` with provider definitions.
- `shared/opencode/providers-base.nix` — documents that built-in OpenAI tiers depend on ChatGPT Plus/Pro OAuth today.
- `shared/opencode/providers-extra.nix` — existing pattern for adding OpenAI-compatible custom providers with `baseURL` and `apiKey`.
- `shared/sops.nix` — shared user-level OpenCode secret declaration pattern.

### Approaches
1. **LiteLLM gateway behind nginx on `rog`** — Run LiteLLM as an internal container/service on loopback, terminate TLS at nginx on a new `*.glats.org` vhost, store upstream OpenAI credentials server-side, and point Opencode at the gateway using a dedicated provider entry.
   - Pros: Already matches repo patterns (nginx + loopback + containerized services); explicitly OpenAI-compatible; supports API-key auth, virtual keys, model allowlists, budgets, logging, and future multi-provider fallback; easiest path to an approved team/internal gateway.
   - Cons: Extra operational component; must harden master/admin access and avoid exposing the admin UI; LiteLLM has some security-sensitive proxy features that require careful configuration.
   - Effort: Medium

2. **Small custom reverse proxy for only OpenAI passthrough** — Build a narrow service that accepts a local gateway key, rewrites auth to a server-side OpenAI API key, and proxies only the minimal OpenAI endpoints Opencode needs.
   - Pros: Smaller attack surface if kept extremely narrow; fewer features to configure; avoids depending on a larger gateway product.
   - Cons: Higher implementation burden in this repo because there is no existing custom proxy module; must verify/maintain exact OpenAI-compatible semantics for streaming, models, errors, and future endpoint drift; weaker observability and key management unless reimplemented.
   - Effort: Medium/High

3. **Azure OpenAI endpoint as the approved upstream, optionally fronted by nginx** — Use Azure OpenAI as the sanctioned provider, authenticate with Azure-approved credentials (API key or Entra-based service identity on the upstream side), and expose either the Azure endpoint directly to Opencode or a thin `rog` gateway that standardizes the local base URL.
   - Pros: Often fits enterprise approval paths better than direct OpenAI; uses the OpenAI client shape with a different `base_url`; can reduce policy friction if corporate approval requires Azure tenancy controls.
   - Cons: Only feasible if the user/org already has Azure OpenAI access and deployed models; model names become deployment names; still may need a local gateway if the goal is central secret custody and stable `glats.org` endpointing.
   - Effort: Low/Medium if Azure is already available, High otherwise

### Recommendation
Recommended approach: **Approach 1 — LiteLLM behind existing nginx on `rog`, exposed on a dedicated subdomain such as `llm.glats.org` or `openai.glats.org`, with a dedicated gateway key for Opencode instead of the LiteLLM master key.**

Why this fits this repo best: the infrastructure patterns already exist for wildcard ACME, nginx reverse proxying, loopback-bound services, and sops-managed credentials; OpenCode in this repo already knows how to consume custom OpenAI-compatible `baseURL` providers; and LiteLLM gives a supported OpenAI-compatible gateway surface without relying on browser OAuth. This keeps the solution in the “approved internal gateway using server-side credentials” lane instead of trying to work around blocked browser auth.

### Risks
- Upstream approval risk: feasibility is conditional on having an approved server-side OpenAI or Azure OpenAI credential path; no gateway can help if policy forbids server-side API usage altogether.
- Exposure risk: publishing an OpenAI-compatible endpoint on `glats.org` requires clear access policy (public internet vs VPN/IP allowlist/Authelia) and strong key separation; do not expose admin/master capabilities to normal clients.
- Compatibility risk: Opencode’s custom provider path likely works, but exact required endpoints/streaming behavior for the user’s desired models should be validated against a real gateway before implementation.
- Secret-scope decision: the repo currently separates host secrets and shared user OpenCode secrets; the gateway design must decide whether upstream provider keys belong in `hosts/rog/secrets.nix`, `shared/sops.nix`, or both.
- Operational risk: LiteLLM is feasible, but should be pinned to a reviewed version and configured conservatively because recent upstream issues show that permissive passthrough and virtual-key features can create avoidable security mistakes.

### Ready for Proposal
Yes — **conditionally**. The next phase should proceed once the user confirms: (1) which upstream is allowed (direct OpenAI API vs Azure OpenAI), (2) whether the endpoint may be internet-exposed or must stay behind VPN/auth controls, (3) preferred subdomain under `glats.org`, and (4) whether the goal is single-user Opencode access only or a reusable internal gateway for multiple tools.
