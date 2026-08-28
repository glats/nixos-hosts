# Tasks: Repair mact2 Native OpenAI Egress

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~500–650 (mostly deletions) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 evidence+config → PR 2 retirement → PR 3 verification |
| Delivery strategy | auto-chain |
| Chain strategy | feature-branch-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Preflight evidence + native `openai-medium` selection | PR 1 (base: tracker) | sanitized native OAuth Codex request + MCP isolation probe on mact2 | `nix build .#homeConfigurations.jcuzmar@mact2.activationPackage` | revert `activeProviderName` + `flake.nix` override |
| 2 | Gateway, provider, secret, nginx retirement | PR 2 (base: PR 1) | `rg -n "openai-proxy\|oai\.glats\.org\|openai_proxy"` → 0 hits | `nix flake check --no-build` + rog build | `git revert` commit; never restore gateway |
| 3 | Runtime verification + seed hardening | PR 3 (base: PR 2) | native OAuth request + github/engram MCP regression probe | mact2 `opencode run` + child env assert | revert seed changes only |

## Phase 1: Preflight Evidence (RED — threat matrix)

- [x] 1.1 Egress routing RED: on mact2, run sanitized native OAuth login + Codex request via `openai-medium`; record sanitized success/failure (no tokens). — **COMPLETED with BLOCKED outcome**. Direct native egress to `https://api.openai.com/v1/responses` from mact2 returns HTTP 403 with `x-direct-response: true` and a Falabella.cl block page ("Aplicación No Permitida", policy `GL_FTC_Generative_IA_C3_BLOCK`, gateway dest_ip `169.254.8.66`). OpenCode native `openai` ChatGPT OAuth credential in `auth.json` is well-formed (access 1702 chars, refresh 196 chars, accountId set, expires set) — block is at the corporate TLS-MITM layer, not the auth layer. See `preflight-evidence.md` § 1.1.
- [x] 1.2 Shell env propagation RED: launch opencode zsh parent; assert no `HTTP_PROXY`/`HTTPS_PROXY` from `extraInitContent`, none inherited by children. — **COMPLETED with PASS**. `~/.zshrc`, `~/.zshenv`, `~/.zprofile`, `~/.zlogin`, `/etc/zshenv`, `/etc/zprofile`, `/etc/zshrc` all CLEAN of `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY`/lowercase equivalents. Live `zsh -ic "printenv | grep -iE proxy"` returns nothing. `extraInitContent` only exports API keys. See `preflight-evidence.md` § 1.2. (Side note, not blocking: `hm-session-vars.sh` exposes the `nvapi-` NVIDIA key as `OPENAI_API_KEY` env — credential-leak hygiene issue, not a proxy issue, captured for Phase 3 to clean up.)
- [x] 1.3 MCP child isolation RED: launch `github-mcp-server-personal`, `github-mcp-server-work`, `engram` children; assert no proxy vars and connections succeed. — **COMPLETED with PASS**. `opencode mcp list` shows 11/12 connected (the 12th `nixos` MCP is a pre-existing docker-runtime failure unrelated to proxies). `ps eww` on the running `github-mcp-server`, `engram mcp`, and `opencode` parent processes shows no `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` env vars — only API key env vars. MCP isolation baseline is clean. See `preflight-evidence.md` § 1.3.
- [x] 1.4 Conditional RED (only if 1.1 fails) — **TRIGGERED because 1.1 failed**. Candidate mact2→rog transport + rog→OpenAI probes. — **COMPLETED with a non-qualifying result**. (a) rog → OpenAI: `bash -c 'echo > /dev/tcp/api.openai.com/443'` succeeds; `curl https://api.openai.com/v1/responses` returns HTTP 401 (reached OpenAI, not blocked), remote_ip `172.66.0.243` (Cloudflare). (b) mact2 can reach only the public Cloudflare-fronted `rog.glats.org:443` endpoint: `nc -zv 104.21.86.114 443`, `nc -zv 172.67.218.149 443`, `python3 socket.connect("rog.glats.org", 443)`, and `curl https://rog.glats.org` succeed. This does **not** prove a connection to rog's LAN/WireGuard address or a CONNECT proxy port; tinyproxy is inactive. See `preflight-evidence.md` § 1.4.
- [x] 1.5 Decision gate: pick direct / narrow rog / no-change. **HARD STOP — no transport config unless 1.1–1.4 prove an MCP-safe mechanism.** — **COMPLETED with HARD STOP**. Direct native egress failed (1.1); rog→OpenAI succeeded (1.4a); the candidate mact2→rog transport is unproven (1.4b). Separately, **no documented MCP-safe narrow transport exists for OpenCode's native `openai` provider other than direct egress**. The `openai-proxy` `options.baseURL` mechanism is the only documented narrow channel, and the design explicitly **forbids restoring it** ("Gateway | Delete, never fix or restore"; success criteria require `oai.glats.org`, gateway code, provider tiers, and gateway secrets to be absent). Shell-wide `HTTP_PROXY`/`HTTPS_PROXY` is forbidden by the threat matrix ("Never use `extraInitContent` proxy exports; inherited value fails"). No per-provider proxy option exists in OpenCode's `openai` provider schema. **Therefore: no Phase 2/3 work proceeds.** The mact2 OpenCode instance stays on `openai-medium-proxy` for this change; the design's "never restore the gateway" policy still holds and Phase 3 remains blocked pending an explicit user decision or the discovery of an MCP-safe narrow transport not currently in OpenCode's documented options. See `preflight-evidence.md` § 1.5.

## Phase 2: Native Path Configuration (gated on 1.5)

- [ ] 2.1 `hosts/mact2/default.nix`: set `home.opencode.activeProviderName = "openai-medium"`; drop proxy comment.
- [ ] 2.2 `flake.nix` (~299): remove `openai-medium-proxy` homeConfigurations override; default native.
- [ ] 2.3 Conditional only if rog selected: add evidenced narrow mact2→rog transport, no proxy exports.
- [ ] 2.4 Run `format-nix` + `nix flake check --no-build`; fix errors.

## Phase 3: Gateway Retirement (gated on proven native path)

- [ ] 3.1 `shared/opencode/providers-base.nix`: remove `openaiProxyProvider`, `openai-{full,medium,light}-proxy` tiers, its export; keep native `openai` tiers.
- [ ] 3.2 `shared/opencode.nix`: remove `OPENAI_PROXY_API_KEY` export (lines ~106–110).
- [ ] 3.3 `hosts/rog/default.nix`: remove import (67), `TimeoutStartSec` override (193), `services.opencodeProxy` (~214–221).
- [ ] 3.4 Delete `linux/system/services/web/opencode-proxy.nix`.
- [ ] 3.5 `linux/system/services/web/nginx.nix`: delete `oai.glats.org` vhost (~589+).
- [ ] 3.6 `darwin/home/sops.nix` (~37) + `hosts/rog/secrets.nix` (~86–96): remove `openai_proxy/*` secrets.
- [ ] 3.7 `.sops.yaml`: remove `secrets/host/rog/openai-proxy.yaml` path_regex.
- [ ] 3.8 Delete encrypted `secrets/host/rog/openai-proxy.yaml` (never decrypt; no API-key replacement).
- [ ] 3.9 `bin/install-opencode-auth-seed` (if retained): restrict merge to native `openai` OAuth object; backup before merge; reject API-key-like data.
- [ ] 3.10 Run `format-nix` + `nix flake check --no-build`; confirm unrelated hosts/tiers untouched.

## Phase 4: Verification & Cleanup

- [ ] 4.1 `rg -n "openai-proxy|oai\.glats\.org|openai_proxy|OpenAIP"` → 0 hits outside `openspec/changes/archive`.
- [ ] 4.2 Runtime: native OAuth Codex request on mact2 succeeds via `openai-medium`.
- [ ] 4.3 Runtime: re-run MCP isolation probe; github/engram children unproxied and functional.
- [ ] 4.4 Scan diff/artifacts: no secret values, no `sk-`/API-key data; all evidence sanitized.
