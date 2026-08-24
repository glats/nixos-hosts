## Exploration: mact2 OpenAI proxy via rog — REVISED FEASIBILITY ANALYSIS

> **Re-explore / feasibility reassessment.** The prior implementation assumed a
> server-side OpenAI Platform API key on `rog`. The user's actual intent is: seed
> valid OpenCode/OpenAI auth from `rog` (a copied OAuth session artifact), then
> route runtime traffic from `mact2` through a proxy on `rog`. This document
> re-derives feasibility against current OpenCode OpenAI auth behavior and states
> whether the existing change should be revised, split, or abandoned.

### Feasibility Verdict

**Conditionally feasible — but only under a transport-proxy shape, not the
implemented API-gateway shape.** The seeded ChatGPT OAuth material is NOT an
OpenAI Platform API key and cannot back an OpenAI-compatible gateway. It is
usable only by OpenCode's built-in `openai` provider internals. The existing
implementation (custom `openai-proxy` provider + `oai.glats.org/v1` gateway +
`upstream_key`) is therefore **not feasible** for the OAuth-seeded model and must
be revised. The seed-distribution half of the change is correct and reusable.

---

### Current State

OpenCode stores credentials at `~/.local/share/opencode/auth.json`, keyed by
provider ID. The `openai` entry is one of two shapes (verified against
`anomalyco/opencode` `packages/opencode/src/auth/index.ts`):

```jsonc
// API-key shape — targets https://api.openai.com/v1
{ "openai": { "type": "api", "key": "sk-..." } }

// OAuth/ChatGPT shape — targets the ChatGPT Codex backend, NOT api.openai.com
{ "openai": {
    "type": "oauth",
    "access": "<JWT, ~1h>",
    "refresh": "<refresh token, ~30-90d>",
    "expires": 1710000000000,
    "accountId": "org-..."          // optional
} }
```

The built-in `openai` provider (`packages/opencode/src/plugin/openai/codex.ts`)
is the **only** code path that understands the OAuth shape. When `auth.type ===
"oauth"` it:

1. Refreshes via `POST https://auth.openai.com/oauth/token` with the public
   `client_id = app_EMoamEEZ73f0CkXaXp7hrann` (PKCE / `refresh_token` grant);
2. Rewrites `/v1/responses` and `/chat/completions` requests to
   `CODEX_API_ENDPOINT = https://chatgpt.com/backend-api/codex/responses`
   (a different host from `api.openai.com`); and
3. Sets `Authorization: Bearer <access>`, `ChatGPT-Account-Id: <accountId>`,
   `x-openai-internal-codex-residency`, `originator: opencode`, a custom
   `User-Agent`, and `session-id` headers. `apiKey` is set to a literal
   `OAUTH_DUMMY_KEY` — no `sk-` key is involved at all.

A custom `@ai-sdk/openai-compatible` provider (the implemented `openai-proxy`)
takes a **different code path**: it sends `Authorization: Bearer <apiKey>` to its
configured `baseURL` using the AI SDK's OpenAI-compatible client. It performs no
OAuth refresh, no Codex-endpoint rewrite, and no `ChatGPT-Account-Id` header. The
`chat.headers`/`chat.params` hooks in `codex.ts` are also gated on
`providerID === "openai"`.

OpenCode has first-class outbound proxy support via standard env vars
(`HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY`, resolved by
`packages/opencode/src/util/proxy-env.ts`), and the OpenAI plugin explicitly
wires the proxy into its WebSocket transport (`ws.ts`: "Bun does not apply
HTTP(S)_PROXY to WebSockets unless the proxy is supplied explicitly"). The
desktop client calls `http.setGlobalProxyFromEnv()`.

The repo already implemented (committed, `ad18332..ff6b31c`): a loopback Python
OpenAI-compatible gateway (`linux/system/services/web/opencode-proxy.nix`) that
validates a scoped client bearer key and re-originates to
`https://api.openai.com/v1` with a server-side `openai_proxy/upstream_key`; an
`openai-proxy` custom provider + `openai-{full,medium,light}-proxy` tiers in
`shared/opencode/providers-base.nix`; `mact2` switched to
`home.opencode.activeProviderName = "openai-medium-proxy"`; and
`bin/install-opencode-auth-seed` for encrypted seed delivery into `auth.json`.
The built-in `openai` provider family (`openai-full/medium/light`) remains intact.

---

### Affected Areas

- `linux/system/services/web/opencode-proxy.nix` — wrong model: an API gateway
  that re-originates to `api.openai.com/v1` with an `sk-` key. Must become (or be
  replaced by) a transport-level forward proxy.
- `linux/system/services/web/nginx.nix` — currently exposes `oai.glats.org/v1`;
  the transport-proxy shape needs a different exposure (CONNECT/TCP stream, not a
  `/v1` reverse proxy).
- `shared/opencode/providers-base.nix` — `openai-proxy` provider + the three
  `openai-*-proxy` tiers are not viable for OAuth material and should be removed.
- `hosts/mact2/default.nix` — `activeProviderName = "openai-medium-proxy"` should
  revert to a built-in `openai-*` tier; `mact2` must keep the built-in `openai`
  provider so OAuth refresh + Codex signing run on `mact2`.
- `hosts/rog/default.nix` + `hosts/rog/secrets.nix` — drop `upstream_key`;
  optionally keep a proxy-auth credential for an authenticated forward proxy.
- `shared/opencode.nix` — replace `OPENAI_PROXY_API_KEY` export with
  `HTTPS_PROXY`/`NO_PROXY` wiring for the transport proxy.
- `shared/sops.nix` + `secrets/host/rog/openai-proxy.yaml` — retire `upstream_key`
  (the API key); the seed becomes the full `openai` OAuth credential.
- `bin/install-opencode-auth-seed` — keep, but the seed payload must be the full
  `{ openai: { type: "oauth", access, refresh, expires, accountId } }` object, not
  a proxy client key.
- `openspec/changes/mact2-openai-proxy-via-rog/specs/opencode-runtime-proxy/spec.md`
  — must be rewritten around transport proxying, not an API gateway.

---

### Answers to the Required Questions

**Q1. Is the `auth.json` material usable for general runtime proxying?**
Partially — and only in one specific way. The `refresh` token + the public
`client_id` can mint fresh access tokens at `auth.openai.com/oauth/token` (this is
exactly what OpenCode's built-in provider does). But the resulting `access` token
is a **ChatGPT Codex backend bearer token**, not an OpenAI Platform API key: it is
consumed against `https://chatgpt.com/backend-api/codex/responses` with a
`ChatGPT-Account-Id` header, and it is **not** valid against `api.openai.com/v1`.
So it is usable for runtime only if the consumer reproduces OpenCode's built-in
`openai` provider behavior (OAuth refresh + Codex endpoint rewrite + account-id
header). It is not a drop-in API credential.

**Q2. Can a custom `openai-proxy` provider reuse seeded OAuth material?**
No. `@ai-sdk/openai-compatible` sends `Authorization: Bearer <apiKey>` to its
`baseURL` and does not implement OAuth refresh, the Codex endpoint rewrite, or the
`ChatGPT-Account-Id` header. The OAuth credential is opaque to it. The implemented
`openai-proxy` provider cannot consume the seeded session; it requires an API-style
credential path (which is exactly what the user does not want).

**Q3. What component must authenticate to OpenAI?**
OpenCode's **built-in `openai` provider internals running on `mact2`**. That is
the only code that knows the OAuth refresh flow and the ChatGPT Codex backend
protocol. `rog` must be a **dumb transport relay** (HTTP CONNECT / forward proxy)
that carries the already-signed requests from `mact2` to
`auth.openai.com`/`chatgpt.com`; `rog` holds no credential and does not
re-authenticate.

**Q4. Feasible without OpenAI Platform API keys?**
Yes — conditionally. The working shape is:
1. Seed the full OAuth `auth.json` from `rog` → `mact2` (OpenAI's own CI/CD docs
   describe this exact "seed `auth.json`, let the client refresh it" pattern for
   ChatGPT-managed Codex auth);
2. Keep `mact2` on the **built-in `openai` provider** (do not switch to a custom
   provider);
3. Route OpenCode's outbound HTTPS through a **transport proxy on `rog`** via
   `HTTPS_PROXY` (with `NO_PROXY=localhost,127.0.0.1` for the OAuth callback).

**Q5. Revise, split, or abandon?**
**Revise.** Keep the bootstrap-seed capability (correct concept, correct
`auth.json` target). Replace the runtime half: delete the `openai-proxy` provider/
tiers and the OpenAI-compatible gateway; revert `mact2` to a built-in `openai`
tier; introduce a transport-level forward proxy on `rog`; drop the `sk-` upstream
key. If the user also wants the server-side API-key path as an optional fallback,
that can live as a separate, clearly-named capability rather than being conflated
with the OAuth-seeded flow.

---

### Approaches (revised)

1. **Transport forward proxy on `rog` + built-in `openai` provider on `mact2`
   (recommended)** — `rog` runs an authenticated HTTP CONNECT forward proxy (or a
   SOCKS5/TCP stream) reachable from `mact2`; `mact2` seeds the OAuth `auth.json`
   from `rog` and sets `HTTPS_PROXY` to `rog`. OpenCode's built-in `openai`
   provider does OAuth refresh + Codex signing on `mact2`; `rog` relays the bytes.
   - Pros: no Platform API key required; reuses OpenCode's first-class proxy env
     support; `rog` holds no credential (lower secret surface); matches the user's
     stated intent exactly; seed flow is OpenAI-documented.
   - Cons: `HTTPS_PROXY` is process-global (proxies all OpenCode traffic through
     `rog`, not just OpenAI); shared OAuth credential has a single-flight refresh /
     rotation hazard (see Risks); forward proxy must be authenticated to avoid an
     open relay.
   - Effort: Medium (mostly reverting the gateway + adding a forward proxy).

2. **Keep the OpenAI-compatible gateway, but back it with the OAuth token
   (attempted current shape)** — the gateway re-originates to OpenAI using the
   OAuth access token.
   - Pros: none meaningful for this goal.
   - Cons: **not feasible** — the OAuth token is not valid against
     `api.openai.com/v1` and targets `chatgpt.com/backend-api` with account-id
     headers; a generic gateway cannot reproduce the built-in provider's signing.
   - Effort: already spent (this is the current code).

3. **Server-side Platform API key on `rog` (explicitly rejected by user)** — the
   prior design, workable only if the user accepts paying API credits via an
   `sk-` key.
   - Pros: simple, stateless, no OAuth rotation issues.
   - Cons: requires an OpenAI Platform API key + billing; contradicts the stated
     intent.
   - Effort: already implemented.

---

### Recommendation

Revise to **Approach 1**. Keep the bootstrap-seed delivery (with the seed payload
changed to the full `openai` OAuth credential). Replace the API gateway with a
transport forward proxy on `rog`, keep `mact2` on the built-in `openai` provider,
and configure `HTTPS_PROXY`. Remove `openai-proxy`/`openai-*-proxy` and the
`upstream_key` secret. This is the only shape that satisfies "seed auth from rog,
route runtime through proxy" without an OpenAI Platform API key.

### Risks

- **Shared-OAuth rotation**: one OAuth refresh token cannot safely be used by two
  machines concurrently — a refresh on one rotates/revokes the token and breaks the
  other (OpenAI's CI/CD docs warn: "do not share the same file across concurrent
  jobs or multiple machines"). After seeding, `rog` must stop using the copied
  credential, or `mact2` needs its own login.
- **`HTTPS_PROXY` is global**: it will tunnel all of OpenCode's outbound traffic
  (models.dev, plugins, other providers) through `rog`; `NO_PROXY` must exclude
  localhost for the OAuth callback server and any local services.
- **Egress block reach**: the original `mact2` failure was
  `Forbidden: blocked by a gateway or proxy`. If the macOS egress filter also
  intercepts the CONNECT handshake to `rog`, the tunnel itself may be blocked; this
  must be confirmed first (does `mact2` → `rog` CONNECT succeed, and is `rog`'s
  OpenAI egress clean?).
- **Seed staleness**: OAuth refresh tokens expire (~30–90d). If `mact2` cannot
  refresh through the proxy (or is idle past expiry), the seeded `auth.json` goes
  stale and must be re-seeded.

### Ready for Proposal

Yes — but the existing proposal/design/spec/tasks are stale against this finding.
The orchestrator should: (1) confirm `rog` has clean OpenAI egress and that
`mact2`→`rog` CONNECT is reachable; (2) confirm the user accepts process-global
`HTTPS_PROXY` and the single-machine-per-OAuth-credential constraint; (3) re-scope
the runtime spec around a transport proxy and revert the API-gateway artifacts.
