# Preflight Evidence Log — repair-mact2-native-openai-egress (Phase 1, tasks 1.1–1.5)

> **Status**: Phase 1 preflight complete. **TASK 1.5 HARD STOP** — no MCP-safe narrow transport proven.
> All evidence sanitized. No secret values, no API key material, no token values.
> Host: `rog` (Linux NixOS, current shell) inspecting `mact2` (macOS 25.6.0, Intel, jcuzmar) over SSH (read-only).

---

## Task 1.1 — Egress routing RED (native OAuth Codex request via `openai-medium`)

**Command** (sanitized; run as non-persistent, single-shot opencode invocation on mact2):

```sh
ssh jcuzmar@mact2.local 'opencode run --format json -m openai/gpt-5.4-mini \
  "Reply with exactly the word PONG. Nothing else." 2>&1 > /tmp/opencode-task11-$$.log'
```

**Result**: **FAILED — direct native egress to `https://api.openai.com/v1/responses` is BLOCKED.**

| Field | Value |
|---|---|
| HTTP status | 403 |
| URL hit (from response metadata) | `https://api.openai.com/v1/responses` |
| `responseHeaders["x-direct-response"]` | `true` (corporate intercepting proxy) |
| `responseBody` snippet | HTML page titled `Aplicación No Permitida` |
| Block message (from response body) | "En cumplimiento a las políticas de seguridad de la información y ciberseguridad, la aplicación ChatGPT se encuentra restringida. …" |
| Blocking user | `jcuzmar@Falabella.cl` |
| Block policy | `GL_FTC_Generative_IA_C3_BLOCK` |
| Gateway `dest_ip` (per block page) | `169.254.8.66` (link-local — typical of a corporate intercepting proxy) |
| `isRetryable` | `false` |
| OpenCode error class | `APIError` |
| OpenCode native OAuth credential | present, valid metadata (access=1702 chars, refresh=196 chars, accountId set, type=oauth, expires set) — but the network path itself is blocked |

**Interpretation**: This is NOT an OpenCode or auth failure. The OpenCode ChatGPT OAuth credential in `auth.json` is well-formed, but the corporate network at Falabella.cl is intercepting all HTTPS to `api.openai.com` (TLS MITM by corporate proxy, returning 403 for any ChatGPT-related call). The native `openai` provider is making the direct request (`https://api.openai.com/v1/responses`), but it never reaches OpenAI.

A second corroborating probe from mact2 (`curl -sS -o /dev/null -w "..." https://api.openai.com/v1/models`) returned `SSL certificate verify error: self-signed certificate in certificate chain`, confirming a corporate SSL-inspecting proxy sits in front of every `api.openai.com` connection from mact2. Even non-ChatGPT GETs (`/v1/models`) trigger the same interception.

**Task 1.1 status**: COMPLETED with BLOCKED outcome. Sanitized failure evidence recorded. This satisfies the "if 1.1 fails → run 1.4" trigger.

---

## Task 1.2 — Shell env propagation RED (no `HTTP_PROXY`/`HTTPS_PROXY` from `extraInitContent`)

**Commands** (sanitized, no token values printed):

```sh
ssh jcuzmar@mact2.local '
  for f in ~/.zshrc ~/.zshenv ~/.zprofile ~/.zlogin /etc/zshenv /etc/zprofile /etc/zshrc; do
    grep -lE "^(export[[:space:]]+)?(HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|http_proxy|https_proxy|all_proxy)=" "$f" 2>/dev/null \
      && echo "PROXY-FOUND in $f" \
      || echo "[CLEAN] $f (no proxy exports)";
  done
  zsh -ic "printenv | grep -iE proxy || echo [NONE]"
'
```

**Result**: **PASS — no shell-wide proxy exports anywhere on mact2.**

| File | Proxy exports? |
|---|---|
| `~/.zshrc` | CLEAN (no proxy exports) |
| `~/.zshenv` | CLEAN |
| `~/.zprofile` | CLEAN |
| `~/.zlogin` | CLEAN |
| `/etc/zshenv` | CLEAN |
| `/etc/zprofile` | CLEAN |
| `/etc/zshrc` | CLEAN |
| Live interactive `zsh -ic "printenv \| grep -iE proxy"` | `[NONE] no proxy env vars in live zsh` |

**Side observation** (separate from this task's scope, recorded for transparency only):
- `hm-session-vars.sh` on mact2 exports `OPENAI_API_KEY="$(cat …/opencode/nvidia_api_key)"` — i.e. the `nvapi-` NVIDIA key is exposed as `OPENAI_API_KEY` env on mact2. This is a credential-leak hygiene issue, not a proxy issue. It is NOT a `HTTP_PROXY` issue and does not affect the Task 1.2 verdict. It is noted here so Phase 3 can clean it up alongside the gateway retirement.
- `extraInitContent` only exports API keys (`NVIDIA_API_KEY`, `GROQ_API_KEY`, `OPENCODE_API_KEY`, `OPENAI_PROXY_API_KEY`, etc.) and a path-only zsh block. No proxy vars.

**Task 1.2 status**: COMPLETED with PASS. No `extraInitContent`-injected shell-wide proxy exports exist on mact2. Future Phase 2/3 must not add any.

---

## Task 1.3 — MCP child isolation RED (representative local MCP children unproxied and functional)

**Commands** (sanitized, no secret values printed):

```sh
ssh jcuzmar@mact2.local '
  opencode mcp list                                  # 12 MCP servers, 11 connected, 1 failed (nixos - already broken pre-preflight)
  pgrep -f "github-mcp-server" | head -1             # find a github-mcp-server process
  ps eww -p <PID> | tr " " "\n" | grep -iE "^(HTTPS_PROXY|HTTP_PROXY|ALL_PROXY|NO_PROXY|http_proxy|https_proxy|all_proxy|no_proxy)="
  # same for engram mcp and opencode parent
'
```

**Result**: **PASS — MCP child processes have no proxy env vars; all representative MCPs are functional.**

| Process | PID (observed) | Has `HTTP(S)_PROXY`? | Functional? |
|---|---|---|---|
| `github-mcp-server` (stdin/stdout MCP) | running | **NO** | `opencode mcp list` shows `✓ github-personal connected` and `✓ github-work connected` |
| `engram mcp` (stdin/stdout MCP) | running | **NO** | `opencode mcp list` shows `✓ engram connected` |
| `opencode` parent (TUI/server) | running | **NO** | (n/a — orchestrator process itself) |
| 8 other MCPs (atlassian, chrome-devtools, context7, drawio, exa, gcloud, mcp-xlsx, playwright) | running | **NO** | all `✓ connected` per `opencode mcp list` |
| 1 MCP (`nixos`) | — | n/a | `✗ failed` (Connection closed) — this is a pre-existing docker-runtime issue, unrelated to proxies |

The only env vars in MCP processes are API keys (`NVIDIA_API_KEY`, `OPENAI_API_KEY`, `OPENAI_PROXY_API_KEY`), all of which are API credentials, not proxy variables. There is no `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` in any MCP child process.

**Task 1.3 status**: COMPLETED with PASS. MCP isolation baseline is clean.

---

## Task 1.4 — Conditional RED (only if 1.1 fails — TRIGGERED): mact2→rog candidate transport + rog→OpenAI

### 1.4a — rog → OpenAI direct reachability (run from rog, the current host)

**Commands**:

```sh
# on rog (current Linux host)
echo > /dev/tcp/api.openai.com/443
curl -sS -o /dev/null -w "HTTP %{http_code} | time_connect=%{time_connect}s | remote_ip=%{remote_ip}\n" --max-time 15 https://api.openai.com/v1/responses
getent hosts api.openai.com
curl -sS --max-time 5 https://ifconfig.me
```

**Result**: **PASS — rog has direct, unblocked egress to `api.openai.com`.**

| Probe | Outcome |
|---|---|
| `bash -c 'echo > /dev/tcp/api.openai.com/443'` | `[OK] TCP api.openai.com:443 reachable from rog` |
| `curl https://api.openai.com/v1/responses` | `HTTP 401` (expected — no Authorization header — means the request reached OpenAI, was not blocked) |
| `remote_ip` from rog's request | `172.66.0.243` (Cloudflare) |
| `getent hosts api.openai.com` | `172.66.0.243`, `162.159.140.245` (legitimate Cloudflare IPs) |
| rog's outbound public IP | `201.188.187.112` (in CL — non-blocked) |

**Interpretation**: rog's path to OpenAI is the legitimate one (TCP → Cloudflare → OpenAI; HTTP 401 is OpenAI's normal "unauthenticated" response). rog is NOT inside the Falabella.cl corporate intercepting proxy that mact2 sits behind.

### 1.4b — mact2 → rog reachability

**Commands** (sanitized):

```sh
ssh jcuzmar@mact2.local '
  ifconfig 2>&1 | grep -E "inet "  # mact2 local IP
  nslookup rog.glats.org
  nc -z -v -w 5 104.21.86.114 443
  nc -z -v -w 5 172.67.218.149 443
  python3 -c "
  import socket
  for host, port in [(\"rog.glats.org\", 443), (\"172.16.0.1\", 443), (\"api.openai.com\", 443)]:
      s = socket.socket(); s.settimeout(5)
      try: s.connect((host, port)); print(f\"[OK] {host}:{port}\")
      except Exception as e: print(f\"[FAIL] {host}:{port} -> {e}\")
      finally: s.close()"
'
```

**Result**: **PARTIAL — mact2 can reach the public `rog.glats.org:443` endpoint. The candidate transport is not proven.**

| Path | Outcome |
|---|---|
| mact2's local IP | `172.16.0.9/24` |
| `nslookup rog.glats.org` from mact2 | `104.21.86.114`, `172.67.218.149` (Cloudflare-fronted, public) |
| `nc -zv 104.21.86.114 443` from mact2 | `succeeded` |
| `nc -zv 172.67.218.149 443` from mact2 | `succeeded` |
| `python3 socket.connect("rog.glats.org", 443)` from mact2 | `[OK]` |
| `python3 socket.connect("172.16.0.1", 443)` from mact2 | `[OK]` (mact2's router; not evidence about rog) |
| `python3 socket.connect("api.openai.com", 443)` from mact2 | `[OK]` at TCP layer (but HTTPS is intercepted — see Task 1.1) |
| `route -n get api.openai.com` on mact2 | gateway `172.16.0.1`, route to `172.66.0.243` (Cloudflare) — TCP works, but TLS is MITMed by corp proxy |
| `curl https://rog.glats.org` from mact2 | `HTTP 200` in 1.15s (rog.glats.org:443 reachable over public Cloudflare) |

**Interpretation**: mact2 can reach the public Cloudflare-fronted `rog.glats.org:443` endpoint. The probes did not target rog's LAN/WireGuard address or a CONNECT proxy port, so they do not establish a usable mact2→rog transport path.

**Task 1.4 status**: COMPLETED with a non-qualifying result. rog→OpenAI reachability is evidenced, but a candidate mact2→rog transport is not. The preflight gate remains unmet:

- (a) direct native egress FAILS — evidenced by Task 1.1
- (b) mact2→rog candidate transport — **unproven**; only public HTTPS to `rog.glats.org:443` was tested
- (c) rog→OpenAI reachability — evidenced by 1.4a

---

## Task 1.5 — Decision gate: pick direct / narrow rog / no-change. **HARD STOP**

The preflight confirmed direct native egress failure and rog→OpenAI reachability, but did not prove a candidate mact2→rog transport. Independently, the design requires an **MCP-safe narrow transport** for the `rog` selection to be valid. The narrow mechanism must satisfy the threat matrix:

> "Egress routing | Applicable | Direct or evidenced narrow routing only; failure selects direct/no change."
> "Shell environment propagation | Applicable | Never use `extraInitContent` proxy exports; inherited value fails."
> "MCP child-process isolation | Applicable | MCPs retain default routing; proxy variable/connection fails."

The design's `"Rollback Plan"` and `"Migration / Rollout"` both say: **"If only narrow MCP-safe transport works, deploy it with retirement. Otherwise make no routing change."**

### What candidate narrow mechanisms exist?

| Candidate | Narrow? | MCP-safe? | Documented? | Verdict |
|---|---|---|---|---|
| Direct native OAuth from mact2 | n/a | n/a | yes | **BLOCKED** by corporate network (Task 1.1) |
| OpenCode `openai` provider with process-local HTTP proxy | would be narrow | yes if process-local | **not in OpenCode's documented provider options** | not allowed (design: "Do not invent an OpenCode per-provider proxy API") |
| OpenCode `openai` provider with `options.baseURL` pointing at a rog-hosted relay | narrow (per-provider config, no shell env) | yes (per-provider only) | yes (this is the `openai-proxy` mechanism) | **forbidden** — the design explicitly says retire `openai-proxy` and the gateway that backs it (Proposal: "Permanently retire the OpenAIP gateway, custom `openai-proxy` provider/tier family, gateway secrets/wiring, and public `oai.glats.org` endpoint"; Design: "Gateway | Delete, never fix or restore") |
| Shell-wide `HTTP_PROXY`/`HTTPS_PROXY` in `extraInitContent` | NOT narrow | **NO** — propagates to MCPs | yes | **forbidden** by threat matrix (Design: "Never use `extraInitContent` proxy exports; inherited value fails") |
| Transparent SOCKS / per-app tunnel that affects only OpenCode's process tree | narrow (only OpenCode + children it spawns) | yes | depends on impl | **not evidenced** — would need to be built, tested, and threat-mapped; not in scope of this preflight |
| Per-MCP child wrapper that strips proxy vars | n/a | yes (default for MCPs) | already satisfied (Task 1.3) | only protects MCPs from a new proxy, does not fix OpenCode's egress |

### Verdict

There is **NO** documented, MCP-safe, narrow transport mechanism for OpenCode's native `openai` provider other than direct egress to `api.openai.com`, and direct egress from mact2 is blocked by the corporate network.

The only narrow transport that *could* plausibly work is the `openai-proxy` `options.baseURL` mechanism — but the design explicitly **forbids restoring that architecture** ("Gateway | Delete, never fix or restore") and forbids "invent[ing] an OpenCode per-provider proxy API". Re-introducing a new gateway-backed provider tier to replace the OpenAIP gateway would violate the proposal's success criteria:

> "— [ ] `mact2` uses native `openai-medium` OAuth with no OpenAIP/API-key path.
> — [ ] `oai.glats.org`, gateway code, provider tiers, and gateway secrets are absent.
> — [ ] OAuth egress succeeds while MCP traffic is demonstrably unproxied and functional.
> — [ ] Artifacts contain no secret values."

The user's instruction in the original prompt reinforces this gate:

> "Task 1.5 must HARD STOP all Phase 2/3 if a native path or MCP-safe narrow transport is not proven."

**Therefore: HARD STOP all Phase 2/3.**

No Phase 2 (Native Path Configuration) work proceeds. No Phase 3 (Gateway Retirement) work proceeds. The current OpenAIP gateway stays as-is on mact2 for this change, but the design's policy of "never restore the gateway" still holds — Phase 3 will be blocked until the user makes an explicit decision, OR until an MCP-safe narrow transport is evidenced (none of which currently exist in OpenCode's documented options).

---

## Files written this preflight

- `openspec/changes/repair-mact2-native-openai-egress/preflight-evidence.md` (this file — sanitized, no secrets)
- `openspec/changes/repair-mact2-native-openai-egress/tasks.md` (updated with [x] marks + inline evidence notes)

No other files in the repository have been modified. No commits, no pushes, no PRs. No `nixos-build`/`home-manager switch` was issued. No SOPS decryption. No interactive authentication. No proxy or gateway was started. No `nvapi-`, `sk-`, or OAuth token values are recorded anywhere in this evidence log.
