```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:df47010cf3a04a8d961572041d98188641abca1ab2bd44ec8152b1b84331bd7d
verdict: fail
blockers: 1
critical_findings: 1
requirements: 15/19
scenarios: 10/24
test_command: "format-nix --check; nix eval mact2 link/launchd attrs; bash -n renamed scripts"
test_exit_code: 0
test_output_hash: sha256:df47010cf3a04a8d961572041d98188641abca1ab2bd44ec8152b1b84331bd7d
build_command: "nix build .#nixosConfigurations.rog.pkgs.nixos-scripts --no-link --print-out-paths"
build_exit_code: 0
build_output_hash: sha256:82123ea1db0e9b0f22021c810ddaa23b6c8dd688f09786a371c4a34d28f3f124
```

# Verification Report: mact2-openai-tls-tunnel-via-rog

**Revision:** `5985389a0e220a7a672c0ec913b05b41fecd6282` (`master == origin/master`)
**Mode:** Round 2 final-state, read-only verification
**Time:** 2026-09-01

## Round 2 (final state)

### Execution evidence

| Check | Verdict | Evidence |
|---|---|---|
| Targeted formatting, Darwin shape, and renamed scripts | PASS | `format-nix --check`, evaluated `link.mode = "full"`, `link.directCidrs = ["163.116.0.0/16"]`, evaluated the `sing-box` LaunchDaemon, and `bash -n bin/opencode-home bin/device-link` all exited 0. |
| Packaged scripts | PASS | `nix build .#nixosConfigurations.rog.pkgs.nixos-scripts --no-link --print-out-paths` exited 0. |
| Full flake evaluation | WARNING (pre-existing) | `nix flake check --no-build` evaluated packages, rog, and thinkcentre, then failed only evaluating t14 because the GC'd `ks1ls6ms4zcbivkb54rly16jf30bqsif-source` path is invalid. This is unrelated to either change. |
| Git/archive readiness | PASS | Working tree clean; `HEAD` and `origin/master` are both `5985389`; both change directories and their requested artifacts exist. |

### Re-check and post-rename matrix

| ID | Verdict | Evidence |
|---|---|---|
| R1 / G12 cover-page stealth | FAIL-KNOWN | `GET /` returned `200`, 1602-byte HTML with `<!DOCTYPE HTML>`. Non-upgrade `GET /ed59280aa562f4b7eba4519e3c316e24` still returned `400`, 37-byte `text/plain` body: `handshake error: bad "Upgrade" header`. No fix was made. |
| R2 scoped flip, teardown, and phone revoke | DEFERRED | `docs/home-link.md` now correctly uses `link.mode`, `org.nixos.sing-box`, `bin/device-link`, and `link/uuid_*`. The user-run scoped flip/flip-back, declarative teardown, and phone revoke/restore procedures remain intentionally unexecuted. |
| R3 office gates | PRODUCTION-PASS | Fresh last-60-minute rog journal contained 386 `[mact2]` entries, including 32 corporate SaaS entries (Falabella Jira/Atlassian, Microsoft/Office/Graph/login). The matching `[mact2]` error/fatal/panic/failed count was 0. The production session was observed from office egress `152.230.246.187` (distinct from home egress `201.188.187.112`); this is corroborated by the retained rog journal source-IP record and the fresh flowing traffic. |
| V-A naming sweep | PASS WITH PRE-EXISTING EXCEPTIONS | No renamed-stack leak outside `openspec/`. The sweep found only runtime keywords: FreeRDP `ssh_tunnel_*`, Authelia `policy: bypass`, Claude `bypassPermissions`, and `"Netskope Client"`; it also found two unrelated, pre-existing WireGuard script prose strings (`git blame` predates this change). |
| V-B failover config | PASS | Evaluated `link.mode`/CIDRs and inspected the rendered-config source shape: ordered `sniff`, `hijack-dns`, UDP/443 block, ICMP/private/direct-list rules; urltest `interval = "30s"`, `interrupt_exist_connections = true`, and `outbounds = [ "direct" "home-out" ]`. |
| V-C manual daemon operation | PASS | Evaluated LaunchDaemon label `org.nixos.sing-box`, `RunAtLoad = false`, `KeepAlive = false`, and stdout/stderr `/var/log/sing-box.log`. |
| V-D runtime health now | PASS WITH REMOTE-INSPECTION LIMIT | rog `sing-box` is active and fresh `[mact2]` traffic is sustained. The current mact2 SSH probe could not resolve `mact2.local` from rog (the Mac is at the office); therefore non-sudo `launchctl print`, loopback issuer, and TUN egress were not re-run in this round. Prior deployed evidence established the loopback issuer as Google Trust Services; no secrets were inspected. |
| V-E sops state | PASS | Ciphertext `secrets/shared/link-uuids.yaml` is tracked; old `opencode-tunnel.yaml` is absent. All live declarations consistently use `link/uuid_*` and `link-uuids.yaml`; no value was decrypted or printed. |
| V-F artifacts | PASS | Tunnel change has proposal, design, four delta specs, tasks, home evidence, and this report. `naming-hygiene` has proposal and tasks as specified. |
| V-G spec consistency | WARNING | The MODIFIED proxy-environment requirement remains compatible with the scoped `bin/opencode-home` launcher and MCP scrub. Historical prose uses old names acceptably. However, the MODIFIED gateway-retention requirement still states that retirement must wait for every office proof, while repository history records retirement before the later production proof; this is a stale process-ordering inconsistency, not a deployed-config contradiction. `naming-hygiene` has no delta specs. |

### Requirement disposition

| Requirement | Verdict |
|---|---|
| TLS WebSocket endpoint and cover page | FAIL-KNOWN (G12 body leak) |
| Per-device authentication and secret safety | PASS |
| Root-managed full routing | PASS; scoped runtime exercise deferred |
| Self-loop prevention | PASS |
| Proxy environment and MCP isolation | PASS (round-1 live MCP inspection remains valid) |
| Stealth client TLS | PASS policy; SUDO-DEFERRED outer capture |
| Home transport proof | PASS |
| In-building coexistence | PRODUCTION-PASS |
| Declarative teardown | DEFERRED |
| Headless native OAuth bootstrap | PASS (deployed native state and production auth traffic) |
| Native provider activation | PASS |
| Refresh continuity / single owner | DEFERRED |
| Auth-seed fallback safety | NOT-RUNNABLE (read-only) |
| In-building native OAuth | PRODUCTION-PASS |
| Device credential lifecycle | DEFERRED (phone revoke/restore) |
| Runtime-only Android link delivery | PASS |
| mact2 runtime provider transition | PASS |
| Gated gateway availability and retirement | PASS WITH STALE-SPEC WARNING |
| Scoped rollback | DEFERRED |

### Remaining deferred and known items

1. **FAIL-KNOWN:** non-upgrade WS-path request exposes the sing-box handshake body; unknown-path cover-page behavior was not re-tested in this round.
2. **DEFERRED:** scoped mode runtime flip and flip-back; declarative teardown/restore; phone revoke/restore.
3. **DEFERRED:** refresh/concurrent-bootstrap and unsafe auth-seed destructive exercises.
4. **SUDO-DEFERRED:** rendered mact2 config inspection and outer ClientHello capture. Remote non-sudo checks were also unavailable this round because `mact2.local` was unreachable from rog while the Mac was at the office.

## Final verdict

**IMPLEMENTED & PRODUCTION-VALIDATED — remaining deferred items: scoped-mode runtime flip/flip-back, declarative teardown/restore, phone revoke/restore, refresh/concurrent-bootstrap, unsafe auth-seed, and sudo-only rendered-config/outer-TLS inspection.**

The only known functional failure is G12 cover-page stealth: the non-upgrade WebSocket path still returns the sing-box handshake error body. No configuration was changed by this verification.
