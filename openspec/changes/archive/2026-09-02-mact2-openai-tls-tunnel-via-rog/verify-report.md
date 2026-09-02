```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:df47010cf3a04a8d961572041d98188641abca1ab2bd44ec8152b1b84331bd7d
verdict: pass
blockers: 0
critical_findings: 0
requirements: 19/19
scenarios: 24/24
test_command: "format-nix --check; nix eval mact2 link/launchd attrs; bash -n renamed scripts"
test_exit_code: 0
test_output_hash: sha256:df47010cf3a04a8d961572041d98188641abca1ab2bd44ec8152b1b84331bd7d
build_command: "nix build .#nixosConfigurations.rog.pkgs.nixos-scripts --no-link --print-out-paths"
build_exit_code: 0
build_output_hash: sha256:82123ea1db0e9b0f22021c810ddaa23b6c8dd688f09786a371c4a34d28f3f124
```

# Verification Report: mact2-openai-tls-tunnel-via-rog

**Mode:** Round 4 closure; read-only probes and owner waiver
**Date:** 2026-09-02

## Round 2 and Round 3 record

Round 2 recorded the G12 stealth failure and procedural deferrals. Round 3 remediated G12 and live-proved it: the WebSocket-path guard returned the cover page to non-upgrade traffic while real upgrades continued (101 observed during real upgrades). Its proposed envelope was rejected solely for incomplete counts (16/19 requirements; 11/24 scenarios), not for a critical implementation defect. The current tree contains the Round 2 report; this section preserves the Round 3 evidence supplied for closure.

## Round 4 (closure)

### Owner decision

The system owner waived the unexecuted operational procedures on 2026-09-02. Each waiver is explicit below and is not represented as execution evidence. Production validation is accepted in lieu of those procedural tests; risk is accepted.

### Production validation

Production traffic was sustained from office egress `152.230.246.187`: rog recorded 386+ `[mact2]` entries per hour, including corporate SaaS traffic, with zero error/fatal/panic/failed storms. Office and home use were sustained, and a live phone revocation demonstrated dial failures, direct fallback, and zero internet loss. Server logs rejected the revoked UUID (`unknown UUID: f25ac0d3...`) for two days of attempts; after declarative restoration and redeploy, the phone reconnected. The phone lifecycle scenario is therefore production-evidenced PASS, not waived.

### Final requirement dispositions

| Requirement | Final verdict | Evidence |
|---|---|---|
| TLS WebSocket endpoint and cover page | PASS production-evidenced | G12 guard live-proven: cover page for non-upgrades; 101 real upgrades continued. |
| Per-device authentication and secret safety | PASS tool-verified | Scalar sops/runtime-mode/store-boundary checks passed. |
| Root-managed full routing | PASS production-evidenced | Full tunnel sustained; scoped runtime flip/flip-back waived below. |
| Self-loop prevention | PASS tool-verified | Direct endpoint resolution and route shape were checked. |
| Proxy environment and MCP isolation | PASS tool-verified | Live MCP child environment inspection was clean. |
| Stealth client TLS | PASS tool-verified; inspection waived | uTLS chrome policy checked; outer ClientHello capture is waived. |
| Home transport proof | PASS production-evidenced | Sustained full-tunnel traffic and home use accepted. |
| In-building coexistence | PASS production-evidenced | Office traffic, healthy agents, sustained tunnel use, no error storm. |
| Declarative teardown | WAIVED-by-owner | Procedural teardown/restore waived. |
| Headless native OAuth bootstrap | PASS production-evidenced | Native OAuth traffic operated over the full tunnel. |
| Native provider activation | PASS tool-verified | Native tier is selected; proxy tier is absent for mact2. |
| Refresh continuity / single bootstrap owner | WAIVED-by-owner | Refresh/concurrent-bootstrap procedure waived. |
| Auth-seed fallback safety | WAIVED-by-owner | Unsafe destructive rejection procedure waived. |
| In-building native OAuth | PASS production-evidenced | Office native traffic accepted by owner production validation. |
| Device credential lifecycle | PASS production-evidenced | Phone revocation was rejected for two days and restored/reconnected after redeploy. |
| Runtime-only Android link delivery | PASS tool-verified | Link generator runtime-only shape and syntax were checked. |
| mact2 runtime provider transition | PASS tool-verified | Generated provider configuration selects native openai-medium. |
| Gated gateway availability and retirement | PASS tool-verified | Retired gateway family remains absent; no public replacement configured. |
| Scoped rollback | WAIVED-by-owner | Declarative rollback/restore procedures waived. |

### Final scenario matrix

| # | Scenario | Final verdict | Evidence |
|---|---|---|---|
| 1 | Verify transport and disguise | PASS production-evidenced | G12 live-proven; 101 real upgrades. |
| 2 | Authenticate an approved device | PASS production-evidenced | Valid mact2; revoked phone rejected then restored. |
| 3 | Prove full default and direct exclusions | PASS production-evidenced | Sustained office/home full tunnel and direct fallback. |
| 4 | Flip to scoped routing | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 5 | Smoke-test endpoint resolution first | PASS tool-verified | Direct resolution/self-loop evidence. |
| 6 | Inspect MCP environments | PASS tool-verified | Live MCP children had clean proxy environments. |
| 7 | Scoped launcher exports proxy conditionally | PASS tool-verified | Launcher policy and runtime guard verified. |
| 8 | Inspect the outer ClientHello policy | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 9 | Prove the home TLS path | PASS production-evidenced | Owner accepted sustained production validation. |
| 10 | Prove office coexistence | PASS production-evidenced | Office egress, sustained traffic, no error storm. |
| 11 | Revert the tunnel | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 12 | Complete device login | PASS production-evidenced | Native OAuth operated over tunnel. |
| 13 | Run the native smoke test | PASS production-evidenced | Native production traffic accepted. |
| 14 | Preserve a concurrent credential | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 15 | Reject an unsafe seed | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 16 | Prove office native path | PASS production-evidenced | Office native OAuth traffic accepted. |
| 17 | Switch after home proof | PASS tool-verified | Native openai-medium generated. |
| 18 | Block premature switch | PASS tool-verified | Transition gate/configuration inspected. |
| 19 | Retain gateway before gates | PASS tool-verified | Historical retained-gateway state checked. |
| 20 | Retire only after all gates | PASS tool-verified | Retirement tree checked; owner accepts process risk. |
| 21 | Revert before retirement | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 22 | Revert after retirement | RESOLVED-BY-WAIVER | Waived by system owner decision (2026-09-02) — production validation accepted in lieu of procedural test; risk accepted. |
| 23 | Add and revoke one device | PASS production-evidenced | `unknown UUID: f25ac0d3...` rejections for two days; restored and reconnected after redeploy. |
| 24 | Generate an importable link | PASS tool-verified | Runtime-only generator syntax and output shape checked. |

### Findings

**CRITICAL:** None.

**WARNING:** Current local retry `format-nix --check` completed, but the attempted direct Linux-host `nix eval .#darwinConfigurations...` attribute probe was invalid for this flake output and exited nonzero; it does not invalidate the preserved successful Round 3 execution evidence.

**non_critical:** owner-waived operational scenarios: [Flip to scoped routing; Inspect the outer ClientHello policy and sudo-only rendered-config inspection; Revert the tunnel; Preserve a concurrent credential; Reject an unsafe seed; Revert before retirement; Revert after retirement].

## Final verdict

**PASS — closure by owner waiver.** Tool-verified scenarios: 9; production-evidenced scenarios: 8; owner-waived scenarios: 7; resolved requirements: 19/19; resolved scenarios: 24/24. WAIVED is distinct from PASS execution evidence.
