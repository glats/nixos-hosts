# Home Evidence-Gate Run: mact2 OpenAI TLS tunnel via rog

| Field | Value |
|---|---|
| Run date | 2026-08-28, 20:50–21:05 (rog local time, America/Santiago) |
| Executor | sdd-apply (Phase 4 home evidence-gate run, tasks 4.1/4.2) |
| Branch (both hosts) | `tunnel/sing-box-transport` |
| HEAD rog | `7e8d1b3` (clean working tree before and after run) |
| HEAD mact2 | `7e8d1b3` (`~/.config/nix`) |
| sing-box rog (server) | 1.13.19 (`/nix/store/0f0np2...-sing-box-1.13.19`) |
| sing-box mact2 (client) | 1.13.19 (`/nix/store/1cydpa6...-sing-box-1.13.19`) |
| Constraints honored | Read-only probes only; no config edits, no kickstart, no rebuilds, no sops decrypt, no commits/push; no long-running processes started on mact2 |

Context: the mact2 daemon (`org.nixos.sing-box-tunnel`, pid 15611) was kickstart-restarted at **20:48:40** with the current config (Netskope 163.116.0.0/16 exclusion, ICMP→direct, urltest fallback, uTLS chrome). Several gate windows are therefore evaluated **post-restart** and the pre/post boundary is noted where relevant.

## Results Table

| Gate | Verdict | Evidence (≤3 lines) |
|---|---|---|
| G1 Server transport live | **PASS** | `systemctl is-active sing-box` → `active`; `ss -tln` → `LISTEN 127.0.0.1:4011`; `curl -w %{http_code} https://tun.glats.org/` → `200`; WS path GET without upgrade → `400` (not 502 — nginx→sing-box path intact) |
| G2 Per-device auth (server logs) | **PASS** | `journalctl -u sing-box --since "1 hour ago"`: `[mact2] inbound connection to 2.20.53.106:443` (20:53:18) and `... 17.253.10.204:443` (20:53:20); `[phone] inbound connection to www.gstatic.com:443` (20:45:42) and (20:48:01) — both named users authenticate |
| G3 Full-tunnel active (mact2) | **PASS** | `launchctl print system/org.nixos.sing-box-tunnel` → `state = running`, `pid = 15611`; `ifconfig` → `utun4 ... inet 172.19.0.1 netmask 0xfffffffc` (/30); `netstat -rn` (no sudo) → covering routes `1`, `2/7`, `4/6` → `172.19.0.1 utun4` (sing-box macOS auto_route pattern; default route intentionally left on en0). Cross-check: IP-echo from mact2 → `201.188.187.112` = rog egress IP (identical) |
| G4 urltest probe proof | **PASS** | rog `journalctl --since "15 min"`: `inbound/vless[0]: [mact2] inbound connection to www.gstatic.com:443` at 20:48:42 (2 s after daemon restart — startup urltest probe through the tunnel) |
| G5 Netskope exclusion (163.116.0.0/16) | **PASS** | Pre-restart window (≤20:48:25): 28 `163.116.` tunnel entries (13 from `[mact2]`, e.g. `163.116.131.88:443` at 20:48:25) — timing artifact, predates the 20:48:40 restart. **Post-restart window 20:48:40→20:55:38: 0 entries** while tunnel demonstrably alive (mact2 traffic at 20:55:36). Client-side: `curl https://www.netskope.com/` from mact2 → `200` |
| G6 Private-range exclusion | **PASS** | mact2 `ping -c1 -t3 172.16.0.5` (rog LAN) → `1 packets transmitted, 1 packets received` RTT 2.9 ms (LAN-direct); rog log since 20:56:10 → **0** `[mact2]` entries for `172.16.` |
| G7 ICMP direct | **PASS** | mact2 `ping -c1 -t3 1.1.1.1` → success RTT 22.8 ms; rog log since 20:56:10 → **0** `icmp` warnings; tunnel alive in same window (sanity: `[mact2]` TCP entries present) |
| G8 Self-loop protection | **PASS** | mact2 `dig +short tun.glats.org` with tunnel up → `104.21.86.114`, `172.67.218.149` (Cloudflare orange-cloud); endpoint resolvable and reachable (G1 cover 200) with no recursion |
| G9 Scoped-mode flip | **DEFERRED** (shape validated) | Scoped shape verified in source: `darwin/system/sing-box-tunnel.nix:84-86` — `domain_suffix ["chatgpt.com" "auth.openai.com"] → tunnel-out`, `final → direct`; tasks 2.2 records `sing-box check` PASS on client-scoped config with sing-box 1.13.19 (apply report). Runtime flip+flip-back deferred — requires rebuild and would disrupt the running full tunnel (procedure below) |
| G10 Hygiene | **PASS** | `grep -rn "openai-proxy\|OPENAI_PROXY_API_KEY\|oai\.glats\.org" --include="*.nix" .` → **zero**; `git grep -i uuid -- '*.nix'` (minus `_secret`/`placeholder`) → only sops key names, comments, and Linux disk `by-uuid` device paths (not credentials); `format-nix --check` → exit 0, `git status` clean (idempotent, no files modified) |
| G11 MCP env cleanliness | **PASS** (ran live) | Active opencode session on mact2 (pid 23112) with 5 MCP children (23685–23689: mcp-atlassian-wrapper, chrome-devtools-mcp, engram, gcloud-mcp, github-mcp-server); `ps eww -p <pid>` on each → **zero** `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` in any child environment |
| G12 Cover page stealth | **FAIL** (status OK, body leaks) | `GET /` → 200 static HTML page (1602 bytes, `<!DOCTYPE HTML>`) — cover page itself good. `GET /<ws-path>` without upgrade → 400 but body = sing-box error string `handshake error: bad "Upgrade" header` (tell-tale tunnel error, spec requires cover-page behavior). `GET /not-a-tunnel-path` → bare nginx `404 Not Found` page (tasks 1.5: non-WS paths should serve the page, no bare 404) |

### Supplementary probes (tasks 4.1 items)

| Probe | Verdict | Evidence |
|---|---|---|
| IP-echo full-tunnel proof | **PASS** | mact2 `curl https://ipinfo.io/ip` → `201.188.187.112`; rog egress → `201.188.187.112` (identical — mact2 exits via rog) |
| TLS-through-tunnel cert stealth (Home Transport Proof) | **FAIL** | mact2 `curl -sIv https://chatgpt.com/` → `subject: CN=chatgpt.com` but `issuer: ... CN=ca.grupofalabella.goskope.com` (Netskope TLS interception); same goskope issuer on `auth.openai.com`. Spec/tasks 2.5 require Cloudflare cert, NOT the goskope CA. TLSv1.3 handshakes complete (Netskope CA is trust-pinned on the Mac), and transport is proven independently by IP-echo — but the end-to-end cert-identity stealth gate fails: the Netskope steering client on mact2 is intercepting TLS **at home**, before traffic enters the TUN |
| Superseded secret file (6.7 record) | **PASS** (no-op) | `git log --oneline --all -- secrets/shared/openai-tunnel.yaml` → empty (never committed); file absent on disk. Live secret remains `secrets/shared/opencode-tunnel.yaml` |

### Secret-boundary evidence (task 4.2 hygiene items)

| Check | Verdict | Evidence |
|---|---|---|
| rog UUID runtime files | **PASS** | `stat -c '%a %U:%G' /run/secrets/opencode-tunnel/uuid_mact2 uuid_phone` → `400 sing-box:sing-box` (mode 0400, service-user ownership per tasks 1.2 declaration so the sing-box service can read them) |
| mact2 rendered config file | **PASS** | `stat -f "%Sp %Su" /run/secrets/rendered/sing-box-tunnel.json` → `-r-------- root` (0400, root-owned; unreadable to the ssh user by design) |
| No UUID value in Nix store | **PASS** (store-side definitive) | rog pre-start script `/nix/store/5syshch...-sing-box-pre-start` shows the store config carries `{"_secret": "/run/secrets/opencode-tunnel/uuid_mact2"}` placeholders; UUIDs are injected at activation via env→jq into `/run/sing-box/config.json` — no literal UUID exists in the store |
| `/run/sing-box/config.json` content check | **SUDO-DEFERRED** | Directory is root-only (correct); exact command for user: `sudo grep -oE '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}' /run/sing-box/config.json` (expected: the two UUIDs, legitimately present only at runtime) |

## Deferred Items

1. **G9 runtime scoped flip + flip-back** — requires rebuild and would disrupt the running full tunnel. Procedure: edit `tunnel.mode = "scoped"` in `hosts/mact2/default.nix` → `nixos-build` on mact2 → verify `route -n get <chatgpt.com-ip>` via `utun4` and non-OpenAI dest direct → flip back to `"full"` → redeploy → verify IP-echo returns rog IP. Shape already validated (source + `sing-box check`, tasks 2.2).
2. **SUDO-DEFERRED route/config checks** — `sudo grep -oE '<uuid-regex>' /run/sing-box/config.json` (rog, UUID-at-runtime confirmation) and optional `sudo route -n get default` on mact2 (default-route stability under auto_route; covering-route evidence already captured without sudo).
3. **Phone revocation test (2.5.2)** — USER-RUN: phone import/revoke/restore cycle; left untouched in tasks.md. Phone connectivity itself is evidenced (G2 `[phone]` handshakes).
4. **Native PONG + post-1h refresh (3.1/3.2)** — NOT-RUNNABLE this run: gated on the USER-RUN headless device-flow bootstrap (browser interaction, task 3.1 still open). This file is the transport-slice portion of the Phase 3 gate evidence; auth gates must be appended after 3.1/3.2 execute.
5. **TLS-through-tunnel cert stealth (FAIL — fix required)** — Netskope steering client on mact2 intercepts TLS to OpenAI hosts at home (`ca.grupofalabella.goskope.com` issuer on both `chatgpt.com` and `auth.openai.com`). Not fixed per run constraints; options for the fix dispatch include excluding Netskope interception for OpenAI domains, or re-scoping the gate to the office network where the corporate profile is authoritative. Office gates (5.1) must account for this behavior.

## Conclusion

The transport slice is **home-verified**: the rog server serves the cover page and proxies the fixed WS path (G1), both named devices authenticate (G2), mact2 runs the root full-tunnel daemon with the TUN up and rog-identical egress (G3 + IP-echo), the urltest probe traverses the tunnel (G4), Netskope CIDR / private-range / ICMP exclusions route direct (G5–G7), endpoint resolution survives the tunnel (G8), hygiene is clean with no legacy proxy references and no UUIDs in the Nix store (G10, secret boundaries), and live MCP children carry no proxy environment variables (G11). Two stealth findings are recorded as FAILs for a separate fix dispatch: the WS-path-without-upgrade response leaks a sing-box error string and unknown paths return a bare nginx 404 (G12), and the Netskope steering client intercepts OpenAI TLS on mact2 at home, defeating the Cloudflare-cert requirement of the Home Transport Proof. The scoped-mode runtime flip remains deferred (shape validated). Office gates (Phase 5) are pending and explicitly out of scope for this run.
