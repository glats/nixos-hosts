# Design: On-Demand SSH Through rog

## Technical Approach

Approved Rust wstunnel11.0.0 replaces Chisel; authoritative exploration/#3688 stays unchanged.

## Architecture Decisions

| Option | Tradeoff | Decision and rationale |
|---|---|---|
| Rust wstunnel11.0.0 | Native protocol ACL; shutdown needed for revocation | Approved replacement: real Linux binary denied forbidden modes. |
| Chisel/frp tested modes | UDP/SOCKS or empty-auth fail-open | Rejected; no fork/general proxy. |
| Raw SSH443; visitors; TUN | Wrong transport or unnecessary access leg | Exclude: operator already runs on rog. |
| Manual launchagent | No root/TUN requirement; crash can leave degraded intent | Recommend juan-owned `org.nixos.ssh-relay`, RunAtLoad/KeepAlive=false, no demand triggers; reboot persistence unapproved. |

## Data Flow

```text
macm5 localhost:22 <- reverse tunnel <- rog 127.0.0.1:22220 <- operator SSH
macm5 publisher -> WSS443 relay.glats.org / -> nginx -> 127.0.0.1:4012 relay
on -> enabled intent -> bootstrap/kickstart -> one KeepAlive=false wstunnel job
off -> serialized disabled intent/bootout -> cancel native retries
```

nginx owns443/ACME; conditional vhost forwards Upgrade/Authorization without logging credentials. Dedicated unprivileged server: `server --restrict-config <runtime-policy> ws://127.0.0.1:4012`. Collisions fail without rebinding; no UDP/WebTransport/dashboard. Preserve tun/linkctl/LAN/routes.

## Interfaces / Contracts

Retain `relayctl on|off|status`, juan's `launchd.user.agents`/`~/Library/LaunchAgents`, RunAtLoad/KeepAlive=false, absolute argv,0700 state, generation/bootout locking and cleanup/cancellation tests. No supervisor/parallel retries. Stale intent is degraded, never boot-restored.

Replace Chisel argv with `client --tls-verify-certificate --http-headers-file <runtime-headers> -R tcp://127.0.0.1:22220:127.0.0.1:22 --reverse-tunnel-connection-retry-max-backoff 60s --connection-retry-max-backoff 20s --log-lvl off wss://relay.glats.org:443`. Verified11.0.0 source/help: reverse retries indefinitely,1s doubling to cap;30s reverse-reply deadline. Connection flag bounds pool acquisition, not process lifetime. Recovery≤90s remains a design target, not proof. Native outage/sleep, fatal exits and quiet logging require tests; KeepAlive=false does not restart crashes. Do not assume Chisel5s minimum or add supervision silently.

Design deadlines: on≤3s/off≤5s/status≤5s. Off disables/bootouts under lock even with malformed/unwritable state; success requires cessation. Later on gets new generation. Native relay cleanup remains gated.

Status separates intent/process/relay/SSH; remote evidence stays unknown. Probes share deadline; Mac-local SSH≠end-to-end. rog probe: `ssh -n -T macm5-relay true`, BatchMode/ConnectTimeout=3/ConnectionAttempts=1, no multiplexing/prompts.

Alias on rog only:127.0.0.1:22220, juan, existing `id_ed25519_lan`, IdentitiesOnly, HostKeyAlias=macm5, StrictHostKeyChecking=yes, publickey-only; reuse verified mesh host key unchanged.

Runtime0400 header/policy files owned by juan/service; no credential argv/environment/store/logs. Native headers carry Authorization; escaped anchored matcher authorizes per-host token. ONLY `!ReverseTunnel` protocol `[Tcp]`, port `['22220']`, CIDR `[127.0.0.1/32]`; no Any/Tunnel/empty capability defaults. Missing/bad policy prevents startup; `restrictions: []` denies all. Trusted Mac destination is fixed, not remotely attested.

Revocation/rotation transaction: STOP dedicated server and verify streams terminated BEFORE policy/secret changes; inhibit restart, atomically replace/validate current policy, START only on success. Failure stays stopped, never stale-policy fallback. No automatic secret reload before stop. Malformed hot reload retains old policy; valid hot reload preserves streams. Header rotation rereads on connections; restart client if necessary, retaining intent. Transaction remains an implementation gate.

Remove Chisel AUTH/JSON/keyFile/fingerprint interfaces. TLS identity now uses existing nginx persistent ACME key and explicit system-CA/hostname verification; no extra transport key. Sanitize keylog/proxy/debug environment; verify native Mac trust.

## File Changes

| Paths | Action |
|---|---|
| `hosts/{rog,macm5}/default.nix` | Preserve imports; migrate disabled settings |
| `linux/system/services/network/ssh-relay.nix`, `darwin/system/ssh-relay.nix` | Migrate enable/package/listenPort plus runtime restrictionsFile/headersFile; enable=false |
| `linux/system/services/web/nginx.nix`, `shared/ssh/lan-mesh.nix` | Preserve conditional vhost/strict alias |
| `pkgs/nixos-scripts/cmd/relay-client/main.go`, `pkgs/nixos-scripts/internal/sshrelay/{client.go,client_test.go}` | Replace transport argv/credential loading; retain controller fixes |
| `pkgs/wstunnel-relay/default.nix`, `overlays/{linux,darwin}.nix` | Pin and expose only the official precompiled Linux amd64 and Darwin arm64 release assets; remove the obsolete Chisel package |
| `pkgs/nixos-scripts/default.nix`, `.sops.yaml` | Preserve registration/corrected rule |
| `secrets/shared/ssh-relay.yaml`, `docs/rog-ssh-relay.md` | Future encrypted provisioning/runbook |

## Testing Strategy / Threat Matrix

Propagate applicable rows unchanged to tasks and RED tests before production edits.

| Boundary | Applicability; safe/failure behavior | RED cases |
|---|---|---|
| Documentation-like paths | N/A: no file classification/execution | None |
| Git repository selection | N/A: no Git execution | None |
| Commit state | N/A: no commits | None |
| Push state | N/A: no pushes | None |
| PR commands | N/A: no PR automation | None |
| Process integration | Applicable: fixed argv/owned children; fail closed | Injection, duplicate on, off/start/recovery races, stale generation, stuck child |
| Publication/identity | Applicable: native exact TCP policy/TLS/SSH; fail closed | Missing/empty/revoked token, UDP/SOCKS/HTTP/forward/other bind, bad/absent/last-rule policy, active revocation, stale reload, destination drift, TLS/SSH mismatch, leaks |
| Evidence/isolation | Applicable: bounded honest status; no global impact | Stalls, false-positive listener, nightly outage, sleep/wake, route/LAN/linkctl/vhost regressions |

Use table-driven temporary-directory/fake-clock Go tests; authorized native integration/E2E. Run Go suite, host/standalone evaluations, flake check; Linux evaluation cannot prove Darwin runtime.

## Migration / Rollout / Open Questions

Disabled/unprovisioned relay: migrate obsolete options, preserve useragent/off/SSH/YAML/nginx fixes. Redeploy via stop/change/start; preserve off. Rollback disables jobs/vhost, never rejected Chisel. No deployment/provisioning authorized.

Evidence: explorer/#3688 and `relay-gate-20261007/{results,ws-followup-results,ws-missing-header-results}.json`; [v11 config](https://github.com/erebe/wstunnel/blob/v11.0.0/wstunnel/src/config.rs)/client source and actual help confirm flags; Context7 cross-check. Rust tool≠catalog Haskell wstunnel.

Remaining gates: pinned/native Darwin package/execution, stop/update/start safety, exact443/nginx Authorization/WS coexistence, SSH and outage/sleep/cancellation. Reboot persistence unapproved; remote power/disconnected-session survival excluded.
