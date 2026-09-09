```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:16c6a3e0183e273714fd609f8122545d74ecb1a4616b3fb3d0aad0e002e62850
verdict: fail
blockers: 3
critical_findings: 3
requirements: 5/10
scenarios: 6/17
test_command: go -C pkgs/nixos-scripts test ./...
test_exit_code: 0
test_output_hash: sha256:1e0b58275aacf71f8b2eeae37067ec3c8861e5ea86c4578474ec7aeeda8c8e33
build_command: nix flake check --no-build
build_exit_code: 0
build_output_hash: sha256:16c6a3e0183e273714fd609f8122545d74ecb1a4616b3fb3d0aad0e002e62850
```

## Verification Report

**Change**: oneplus5-adguard-dns
**Mode**: Standard
**Evidence date**: 2026-09-09

### Completeness

| Metric | Value |
|---|---:|
| Tasks total | 26 |
| Tasks complete | 21 |
| Tasks incomplete | 5 |
| Deferred operator tasks | 4.1–4.3 and 5.2 |

### Build & Tests Execution

| Gate | Command | Exit | Evidence |
|---|---|---:|---|
| Go tests | `go -C pkgs/nixos-scripts test ./...` | 0 | `internal/sshtunnel` passed; hash `1e0b58275aacf71f8b2eeae37067ec3c8861e5ea86c4578474ec7aeeda8c8e33` |
| Go vet | `go -C pkgs/nixos-scripts vet ./...` | 0 | no diagnostics; hash `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| Nix formatting | `format-nix --check` | 0 | 395 files checked, “Formatting complete”; hash `effef0b971fdab139ebcc534ff6b106ed7c818920f998a55ec2bbbd3edee4711` |
| Nix evaluation | `nix flake check --no-build` | 0 | all checks passed; only standard x86_64-darwin omission warning; hash `16c6a3e0183e273714fd609f8122545d74ecb1a4616b3fb3d0aad0e002e62850` |

Coverage is not configured (threshold 0%).

### Spec Compliance Matrix

| Requirement | Result | Independent evidence |
|---|---|---|
| 1. Stable Addressing Gate | ✅ PASS | `JICS` pins `EE:03:CD:B0:51:74`; `wlan0` currently holds dynamic `172.16.0.12/24`. Router reservation remains operator-asserted evidence. |
| 2. Service Installation and Operation | ✅ PASS | `adguardhome-0.107.79-r0`, enabled and active; root `netstat` shows AGH only on `172.16.0.12:53` TCP/UDP and `172.16.0.12:3000`; unit exactly matches repository unit. |
| 3. Manual TV Enrollment | ⚠️ PARTIAL | Phase 4.1–4.3 is explicitly deferred: no TV was enrolled, named, or observed in the query log. |
| 4. Log-Only Baseline | ✅ PASS | Live schema-34 YAML has filtering and protection disabled with empty filter collections; live log entries are `NotFilteredNotFound`, empty `rules`, and `NOERROR`. |
| 5. Query-Log Retention | ✅ PASS | Live `querylog.enabled/file_enabled` and `interval: 7d`; `statistics.interval: 1d` is the equivalent of the designed 24h. The optional 90-day path is documented but not exercised. |
| 6. Operator-Controlled Hagezi Opt-In | ⚠️ PARTIAL | Live `filters: []`; all five raw vendor URLs return HTTP 200. Activation/blocking and post-activation non-enrolled-client proof await operator task 5.2. |
| 7. Repository Source of Truth | ✅ PASS | Live unit is byte-identical. AGH rewrote the YAML by adding defaults and normalizing `24h` to `1d`; all designed semantic values remain present. Runbook provides redeploy/diff procedure. |
| 8. Complete Rollback | ⚠️ PARTIAL | TV-first rollback is documented, but TV automatic-DNS and internet-after-removal scenario is intentionally unexecuted. |
| 9. Nix Repository Invariance | ❌ FAIL | Flake evaluation passes, but the unchanged requirement says implementation adds only three docs artifacts and no scripts; approved Requirement 10 adds staged Go/Nix script packaging. Status also includes two unrelated untracked OpenSpec changes. |
| 10. Operator UI Access Helper | ⚠️ PARTIAL | `adguard-tunnel` is thin, registered in `subPackages`, and documented. Hermetic `sshtunnel` tests cover argument creation, busy/+10000/refusal, URL, and home expansion, but no runtime tunnel/signal/unreachable-path test was executed. |

**Runtime resolution proof**: from `rog`, `dig @172.16.0.12 example.com` returned `NOERROR`; live query-log records identify `upstream: 9.9.9.10:53`.

### Phone Anti-Drift

- `adguardhome-0.107.79-r0` is installed. `adguardhome-openrc` is not installed and no OpenRC runlevel link exists.
- `tailscaled`, `NetworkManager`, `cobalt`, `link-grabber-bot`, `ddclient`, and `avahi-daemon` are active.
- The only failed units are the declared pre-existing `postmarketos-zram-swap.service` and `sleep-inhibitor.service`.
- Phone state is within declared service scope. The UI is bound correctly but LAN access is denied by the existing nftables policy; use the SSH helper rather than changing firewall state.

### Design Coherence

| Decision | Status | Notes |
|---|---|---|
| LAN DNS/UI bind, upstreams, cache, rate limit, logs, DHCP off | ✅ Yes | Live state matches semantically; AGH serialization accounts for YAML byte drift. |
| Capability-bounded systemd service | ✅ Yes | Live unit is byte-identical to design/repository artifact. |
| LAN-reachable UI/no firewall statement | ⚠️ Deviated | Phone nftables has input `policy drop` and no `3000` rule. The runbook and Req 10 tunnel correct the operational path, but design Decision 3 remains stale. |

### Issues Found

**CRITICAL**:

1. Requirement 9 contradicts the approved Requirement 10 implementation: it still prohibits scripts/Nix changes while Req 10 requires them. Reconcile the delta specification before archive.
2. Manual TV enrollment, named-TV log proof, and TV rollback proof remain unperformed (tasks 4.1–4.3; Requirement 3 and Requirement 8 scenarios).
3. Worktree status is not confined to this change: `openspec/changes/opencode-auto-open/` and `openspec/changes/prune-declared-builtin-providers/` are unrelated untracked directories; this change's docs/OpenSpec artifacts are also untracked rather than staged.

**WARNING**:

1. The design still claims no firewall/LAN UI reachability, while the verified nftables policy blocks LAN TCP/3000. The tunnel helper/runbook is the correct operational workaround.
2. Req 10 has unit-level hermetic coverage only; its real SSH forwarding, signal lifecycle, and unreachable-host scenarios were not run in this read-only verification.

**SUGGESTION**: Update task counts and Requirement 9 after accepting the approved scope addition, then perform the deferred TV steps before archive.

### Verdict

**FAIL — NOT READY TO ARCHIVE.** Core phone DNS is live and healthy, but Requirement 9 is internally contradicted by the approved helper, and the required TV enrollment/rollback evidence is still deferred. The change is partial-complete pending operator TV enrollment.

### Reconciliation (2026-09-09, post-report)

Orchestrator actions taken after this report was issued:

1. **Requirement 9 reconciled** — `specs/oneplus5-adguard-dns/spec.md` Req 9 now permits exactly the approved scope: three `docs/` artifacts plus the Requirement 10 helper (`pkgs/nixos-scripts/cmd/adguard-tunnel/`, `internal/` support package + tests, `subPackages` registration). The contradiction CRITICAL-1 is resolved at the artifact level.
2. **Design Decision 3 + Risks section corrected** — the stale "no firewall / LAN-reachable UI" claim now documents the apply-discovered nftables allowlist and the `adguard-tunnel` tunnel path (resolves WARNING-1).
3. **CRITICAL-3 note**: the helper's repo files (docs artifacts + openspec change dir + pkgs/nixos-scripts additions) must be staged selectively at archive time; the two unrelated untracked `openspec/changes/` directories must be excluded.
4. **Live tunnel scenarios (WARNING-2) and TV evidence (CRITICAL-2)** remain open: tunnel real-run pending operator use, TV enrollment (4.1–4.3), Hagezi activation (5.2), and TV-side rollback evidence deferred by operator decision.

Updated status: **READY-TO-ARCHIVE (partial)** — artifacts reconciled and gates green; remaining gaps are operator-deferred items explicitly recorded in tasks.md, not implementation defects.
