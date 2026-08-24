## Exploration: mact2 OpenAI transport proxy via rog

> This change REPLACES the wrong architectural assumption in
> `mact2-openai-proxy-via-rog`. That change built a custom OpenAI-compatible API
> gateway/provider (`openai-proxy` → `oai.glats.org/v1` → upstream `sk-` key).
> The corrected model is: **seed valid OpenCode/OpenAI auth from `rog` to
> `mact2`, then route runtime traffic through a transport/forward proxy on
> `rog`, keeping OpenCode's built-in `openai` provider on `mact2`.**

### Feasibility Verdict

**Technically feasible.** Verified against current OpenCode source and OpenAI
docs. OpenCode's built-in `openai` provider (ChatGPT OAuth) runs entirely
client-side on `mact2`: it refreshes at `auth.openai.com/oauth/token` and calls
`chatgpt.com/backend-api/codex/responses`. It only needs outbound HTTPS egress
to those hosts — which a transport forward proxy on `rog` provides. OpenCode has
first-class proxy-env support. The prior API-gateway shape is the only part that
is wrong and must be reverted.

---

### Current State

The repo committed the wrong model in `ad18332..ff6b31c`. Concrete artifacts:

- `linux/system/services/web/opencode-proxy.nix` — a loopback Python
  OpenAI-compatible gateway that validates a scoped client bearer key and
  re-originates to `https://api.openai.com` with a server-side `sk-` key.
- `shared/opencode/providers-base.nix` — `openaiProxyProvider` (custom
  `@ai-sdk/openai-compatible` provider `openai-proxy` → `oai.glats.org/v1`) plus
  an `openai-{full,medium,light}-proxy` tier family (lines ~355–403, ~706–770).
- `hosts/mact2/default.nix` — `home.opencode.activeProviderName =
  "openai-medium-proxy"`.
- `hosts/rog/default.nix` — imports `opencode-proxy.nix` (line 67), enables
  `services.opencodeProxy` (lines 214–223), plus a TimeoutStartSec override
  (line 193).
- `hosts/rog/secrets.nix` + `secrets/host/rog/openai-proxy.yaml` —
  `openai_proxy/upstream_key` (`sk-`) and `openai_proxy/client_key`.
- `shared/sops.nix` + `shared/opencode.nix` — shared `openai_proxy/client_key`
  secret and its `OPENAI_PROXY_API_KEY` export (lines ~106–108).
- `linux/system/services/web/nginx.nix` — `oai.glats.org` vhost proxying only
  `/v1/*` to the loopback gateway (lines 589–638).
- `bin/install-opencode-auth-seed` — fetch + age-decrypt + backup + merge of a
  seed into `~/.local/share/opencode/auth.json`. Conceptually correct, reusable.

Built-in assets that already exist and are intact: the `openai` provider is
OpenCode-native (not declared in `allProviders`), and the `openai-full/medium/
light` tiers in `providers-base.nix` reference `openai/gpt-*` model IDs. So
`mact2` can point at a built-in tier today.

**Connectivity already solved:** `rog` runs a WireGuard server (`wg0`,
`10.13.13.1`, endpoint `guard.glats.org`, IP forwarding + NAT for peers).
`mact2` is the `mac` peer at `10.13.13.3` and ships `wireguard-go` +
`wireguard-tools`. A private, encrypted, authenticated `mact2 → rog` tunnel
already exists — the transport proxy can bind to `10.13.13.1` and never touch
the public internet.

### Evidence (verified)

- **context7** (`/anomalyco/opencode`): `packages/opencode/src/util/proxy-env.ts`
  resolves `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/`NO_PROXY`, supports
  authenticated proxy URLs (`http://user:pass@host:port`) and wildcard
  `NO_PROXY`. `packages/opencode/src/auth/index.ts` stores creds at
  `~/.local/share/opencode/auth.json` (plain JSON, `0o600`), one credential per
  provider ID. `packages/opencode/src/plugin/openai/codex.ts`: on OAuth it
  proactively refreshes before each call (single-flighted in-process), rewrites
  to `CODEX_API_ENDPOINT`, sets `Authorization`/`ChatGPT-Account-Id`, and writes
  rotated tokens back. Login methods: `browser` (PKCE, localhost:1455) and
  `headless` (device-code).
- **github**: OpenCode has first-class proxy support and the OpenAI plugin wires
  the proxy into its WebSocket transport. No repo-level forward proxy exists yet
  (no `tinyproxy`/`squid`/`gost`/`3proxy` anywhere in `linux/` or `hosts/`).
- **exa** (OpenAI Codex CI/CD auth doc + `openai/codex` issues #10332, #26516):
  the "seed `auth.json`, let the client refresh in place" pattern is officially
  supported. Refresh tokens use **Refresh Token Rotation (RTR)** — single-use
  (with a limited reuse window, on the order of an hour per a codex maintainer).
  Explicit guidance: *"Do not share the same file across concurrent jobs or
  multiple machines"* and *"Reseed … if another machine or concurrent job
  rotated the token first."*
- **nixpkgs** (`nixos_nix`): `tinyproxy` 1.11.2 exists with a full
  `services.tinyproxy` NixOS module (`Listen`, `Port`, `settings`, `Anonymous`,
  `Filter`). This is the canonical light HTTP CONNECT forward proxy and needs no
  custom service code.

---

### What stays, what is reverted, what is new

| # | Item | Disposition | Notes |
|---|------|-------------|-------|
| 1 | `bin/install-opencode-auth-seed` | **KEEP (modify)** | Fetch/decrypt/backup/merge is correct. Change: seed payload = full `openai` OAuth object; `openai` key must OVERWRITE on merge (not "existing wins"). |
| 2 | `uploads/` bootstrap channel | **KEEP (re-evaluate)** | See dedicated section. |
| 3 | `linux/system/services/web/opencode-proxy.nix` | **REVERT (delete)** | The whole loopback API gateway is the wrong model. |
| 4 | `linux/system/services/web/nginx.nix` `oai.glats.org` vhost | **REVERT** | Transport proxy needs no public `/v1` reverse proxy. |
| 5 | `shared/opencode/providers-base.nix` `openaiProxyProvider` + `openai-*-proxy` tiers | **REVERT** | Remove provider, tiers, and their membership in `allProviders` + `providers`. |
| 6 | `hosts/mact2/default.nix` `activeProviderName` | **REVERT** | `openai-medium-proxy` → `openai-medium` (built-in tier). |
| 7 | `hosts/rog/default.nix` `opencode-proxy.nix` import + `services.opencodeProxy` + TimeoutStartSec | **REVERT** | Remove gateway enablement. |
| 8 | `hosts/rog/secrets.nix` + `shared/sops.nix` `openai_proxy/{upstream_key,client_key}` | **REVERT** | Drop the `sk-` upstream key. Reuse the sops file/rule for the forward-proxy credential. |
| 9 | `shared/opencode.nix` `OPENAI_PROXY_API_KEY` export | **REVERT** | Replace with `HTTPS_PROXY`/`NO_PROXY` wiring. |
| 10 | Forward proxy service on `rog` | **NEW** | `services.tinyproxy` bound to `10.13.13.1` (wg0), CONNECT-only to OpenAI hosts, optional Basic auth. |
| 11 | `HTTPS_PROXY`/`NO_PROXY` wiring on `mact2` | **NEW** | Via `home.opencode.extraInitContent` (or a mact2 launch-env wrapper). |
| 12 | Seed publisher on `rog` | **NEW** | `bin/publish-opencode-auth-seed`: read `rog`'s `auth.json` `openai` entry, age-encrypt to `mact2` key, write to uploads tree. (Does not exist today — the old tasks claimed a publisher that was never written.) |

---

### Answers to the Required Questions

**Q1. Is a transport-proxy architecture with built-in `openai` on `mact2`
technically feasible?**
Yes. OpenCode's built-in `openai` provider performs OAuth refresh + Codex
signing entirely on the client. It needs only egress to `auth.openai.com` and
`chatgpt.com` (port 443), which a CONNECT forward proxy on `rog` supplies.
OpenCode honors `HTTPS_PROXY`/`NO_PROXY` natively, so no provider override is
required on `mact2` — it keeps the built-in `openai` tier.

**Q2. Which parts can be kept as-is?**
`bin/install-opencode-auth-seed` (with a merge-semantics fix and a payload
change), the `uploads/` delivery channel, the built-in `openai` provider + tiers,
and the WireGuard tunnel (reused as the proxy transport).

**Q3. Which parts must be reverted?**
Everything tied to the API-gateway shape: `opencode-proxy.nix`, the
`oai.glats.org` vhost, `openaiProxyProvider` + `openai-*-proxy` tiers, the
`openai-medium-proxy` active-provider switch, the `services.opencodeProxy`
enablement, and the `openai_proxy/{upstream_key,client_key}` secrets + the
`OPENAI_PROXY_API_KEY` export.

**Q4. What new config/modules/scripts are needed?**
(a) A forward-proxy module on `rog` (recommend `services.tinyproxy`, bound to
`10.13.13.1`, CONNECT-port allowlist for 443, optional Basic auth). (b)
`HTTPS_PROXY=http://<cred>@10.13.13.1:<port>` + `NO_PROXY=localhost,127.0.0.1`
on `mact2`. (c) `bin/publish-opencode-auth-seed` on `rog`. (d) A sops secret for
the proxy credential (reuse/rename `secrets/host/rog/openai-proxy.yaml` and its
`.sops.yaml` rule).

**Q5. Does `uploads/` bootstrap still make sense, and in what exact form?**
Yes, as the seed delivery channel, but with a caveat. The `uploads/` tree is
served by nginx fancyindex and is readable on the LAN — so the seed MUST remain
age-ciphertext (encrypted to `mact2`'s host key `age1ngeet…`), never the
plaintext OAuth JSON. Exact form: `rog` publishes
`/run/media/stuff/droppy/nginx/opencode/mact2-auth-seed.age` =
`age -r <mact2_pub> -o …` of `{ "openai": { type, refresh, access, expires,
accountId } }`; `mact2` runs `bin/install-opencode-auth-seed` (default URL
`https://glats.org/uploads/opencode/mact2-auth-seed.age`). A stricter
alternative — `scp`/sops over the WireGuard tunnel or SSH — avoids the
LAN-readable path entirely and should be preferred if the uploads channel is
not required for other reasons. The uploads path is *convenient but not
mandatory* in the corrected architecture.

**Q6. What risks remain?**
See Risks below — dominated by shared-refresh-token rotation and proxy-env
scope.

---

### Approaches

1. **Transport forward proxy on `rog` (WireGuard-bound) + built-in `openai` on
   `mact2` (RECOMMENDED)** — `rog` runs `services.tinyproxy` on `10.13.13.1`
   (wg0), reachable only over the existing tunnel. `mact2` sets
   `HTTPS_PROXY`/`NO_PROXY` and keeps the built-in `openai` tier. Seed via
   `uploads/` (or scp) as bootstrap; prefer `opencode auth login` (headless
   device-code) through the proxy for an independent session.
   - Pros: no OpenAI Platform API key; reuses OpenCode's native proxy support;
     no public exposure (WG-only bind); `rog` holds no OpenAI credential; the
     WG tunnel already exists; tinyproxy is a stock NixOS module (near-zero
     custom code).
   - Cons: `HTTPS_PROXY` is process-global (see Risks); shared-seed rotation
     hazard if the seed is used instead of an independent login.
   - Effort: Medium (mostly reverting the gateway + ~30 lines of proxy config).

2. **Seed-only bootstrap (no proxy; rely on `mact2` reaching OpenAI directly)**
   — copy `rog`'s `auth.json`, revert the gateway, do nothing else.
   - Pros: minimal.
   - Cons: **does not solve the original problem** — the whole reason for this
     change is that `mact2` egress to OpenAI is blocked (`Forbidden: blocked by
     a gateway or proxy`). Seeding alone leaves runtime traffic blocked.
   - Effort: Low, but non-functional.

3. **Native login on `mact2` through the proxy, no seed at all** — after the
   proxy is up, run `opencode auth login` (headless device-code) on `mact2`;
   OpenCode reaches `auth.openai.com` via `HTTPS_PROXY`.
   - Pros: mints an **independent** session — zero shared-token rotation risk;
     no seed artifact to protect; simplest secret posture.
   - Cons: requires the headless flow to succeed end-to-end; a one-time
     interactive step on `mact2`; `browser` PKCE still won't work unless the
     macOS browser is also proxied (so use `headless`).
   - Effort: Low (same proxy, minus the seed machinery).

---

### Recommendation

**Approach 1, with Approach 3 as the preferred bootstrap.** Concretely:

1. **Revert the API-gateway change** (items 3–9 in the table) — delete
   `opencode-proxy.nix`, the `oai.glats.org` vhost, `openaiProxyProvider` +
   `openai-*-proxy` tiers, the `openai-medium-proxy` switch, and the
   `openai_proxy/*` secrets/export. Set `mact2`
   `home.opencode.activeProviderName = "openai-medium"`.
2. **Add a `rog` forward proxy**: `services.tinyproxy` bound to `10.13.13.1`
   (`Listen 10.13.13.1`, `Port 3128`), `ConnectPort` limited to `443`,
   `Filter`/allowlist scoped to `auth.openai.com`, `chatgpt.com`, and their CDN
   hosts, optional `BasicAuth` via a sops-managed credential (reuse the
   `openai-proxy.yaml` file/rule → rename to a forward-proxy secret).
3. **Wire `mact2`**: export `HTTPS_PROXY=http://<user>:<pass>@10.13.13.1:3128`,
   `HTTP_PROXY` (same), and `NO_PROXY=localhost,127.0.0.1` via
   `home.opencode.extraInitContent` — scoped to `mact2`, not globally.
4. **Bootstrap auth**: preferred path is `opencode auth login` (headless) on
   `mact2` through the proxy → independent session. Keep
   `bin/install-opencode-auth-seed` + `bin/publish-opencode-auth-seed` as the
   fallback/automation path, with the seed payload = full `openai` OAuth object
   and `openai`-key overwrite-on-merge semantics.
5. **Keep the built-in `openai` provider on `mact2`** — no custom provider.

Why: it matches the user's stated intent exactly, requires no OpenAI Platform
key, reuses existing repo primitives (WireGuard, sops, tinyproxy module), and
removes the only non-viable part (the API gateway).

### Risks

- **Shared-OAuth refresh rotation (highest)**: copying `rog`'s live `auth.json`
  `openai` entry puts the same refresh token on two machines. Refresh tokens are
  single-use (RTR). Whichever machine refreshes first (~1h access-token
  lifetime) rotates the token and invalidates the other's copy → the loser gets
  a hard re-auth. *Mitigation:* prefer the independent headless login
  (Approach 3); if seeding, treat it as one-shot bootstrap and re-login `rog`
  afterward, and never use the same token concurrently.
- **`HTTPS_PROXY` is process-global**: it tunnels *all* OpenCode HTTPS through
  `rog` (models.dev, other providers, plugins), adding latency and coupling
  `mact2`'s availability to `rog`. `NO_PROXY` only excludes hosts, so scoping to
  OpenAI-only is awkward. *Mitigation:* accept global proxy for `mact2`, or
  populate `NO_PROXY` with the other providers' hosts.
- **Session refresh behavior**: OpenCode refreshes lazily before each call and
  single-flights within a process; there is no cross-process lock (see
  `openai/codex#10332`). Two OpenCode processes sharing one token on the same
  machine can race. *Mitigation:* one OpenCode runtime per credential.
- **Egress reachability**: the original failure was `Forbidden: blocked by a
  gateway or proxy`. The WireGuard tunnel should bypass the macOS egress filter
  (traffic to `10.13.13.1` is tunnel-local), but this must be confirmed: does
  `mact2 → 10.13.13.1:3128` CONNECT succeed, and is `rog`'s OpenAI egress clean?
- **CONNECT port/CDN scope**: `chatgpt.com`/`auth.openai.com` may resolve to
  varying CDN hosts; an over-tight tinyproxy filter/`ConnectPort` allowlist
  could block refreshes. *Mitigation:* allowlist `443` broadly, filter by domain
  if needed, and verify with a real refresh.

### Ready for Proposal

Yes. The orchestrator should: (1) confirm `mact2 → 10.13.13.1` (WireGuard)
CONNECT reachability and `rog`'s clean OpenAI egress before proposing; (2)
confirm the user accepts process-global `HTTPS_PROXY` on `mact2` (vs. a
`NO_PROXY` list for other providers); (3) confirm the bootstrap preference —
independent headless login vs. seed-with-re-login — since this determines how
much of the seed machinery survives; (4) re-scope the spec from
`opencode-runtime-proxy` (API gateway) to a transport-proxy capability and
archive/supersede the old change.
