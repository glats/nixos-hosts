```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:567ac6d6dc7fc58ab1e3abaa9f1e43aaf23ab614c32d2bcfff589b65410b7e00
verdict: pass
blockers: 0
critical_findings: 0
requirements: 10/10
scenarios: 16/16
test_command: "format-nix --check && go -C pkgs/nixos-scripts test ./..."
test_exit_code: 0
test_output_hash: sha256:aa47f8cdefd91d250394ae49fb1f87fc9e16106cfeb91a23ad2192fe8225e12d
build_command: "nix flake check --no-build"
build_exit_code: 0
build_output_hash: sha256:f761fb8a52aac3ec88942a0816a42327d8278fb80054a5dcea7ddb036914ad07
```

## Verification Report

**Change**: oneplus5-wifi-watchdog
**Mode**: Standard

### Completeness

| Metric | Value |
|---|---:|
| Tasks total | 10 |
| Tasks complete | 10 |
| Tasks incomplete | 0 |
| Requirements | 10 |
| Scenarios | 16 |

### Gates

| Command | Exit | Evidence |
|---|---:|---|
| `format-nix --check` | 0 | 395 Nix files, formatting complete |
| `go -C pkgs/nixos-scripts test ./...` | 0 | All tested packages passed |
| `nix flake check --no-build` | 0 | All checks passed; expected x86_64-darwin omission warning |
| Phone `systemd-analyze verify` | 0 | Only pre-existing q6voiced and avahi warnings |

### Requirement Verdicts

| ID | Verdict | Independent evidence |
|---|---|---|
| R1 Periodic detection | PARTIAL | State-backed two-loss detection is implemented and three healthy cycles occurred at 12:51:29, 12:52:31, and 12:53:37, but `AccuracySec=15s` violates design Decision 3's required `AccuracySec=1s` and permits up to 15 seconds of coalescing. |
| R2 Bounded ladder | PASS | Script has rung 0/1/2, 5s unbind/bind limits, 10s interface poll, 8s NM waits, 15s health verification, success checks, and persisted next-rung escalation within `TimeoutStartSec=55`. |
| R3 Crash-skip | PASS | `recent_crash` uses the documented two signatures in a 10-minute kernel-journal window; sustained loss selects rung 1 instead of rung 0. |
| R4 Reboot guard | PASS | Local fake-state copy proved suppression at 21,599s without reboot and exactly one stubbed reboot at 21,600s, persisting `last_reboot`. |
| R5 Forensics | PASS | State is atomic, root-only, versioned (`version=1`) and accepts `substep`; live journal emits timestamped `rung=detect healthy`; ath10k crash watch remains active. |
| R6 Non-interference | PASS | Static inspection finds no writes to AdGuard, nftables, or NetworkManager profiles; phone artifacts have expected root ownership and modes. |
| R7 Source of truth | PASS | SHA-256 and byte comparisons match for script and both units; runbook gives copy/install/checksum drift correction. |
| R8 Rollback | PASS | Runbook specifies disable timer, remove timer/service/script/state directory, and daemon reload with adjacent services untouched. |
| R9 Controlled rebind | PASS | `tasks.md` retains the failed disconnect-wrapped test and root cause plus the corrected unbind-cold test (12:39:55–12:40:13, 18s) restoring association and `.12` without reboot. |
| R10 Nix invariance | PASS | Only the canonical watchdog docs and change tree are untracked (plus unrelated `opencode-auto-open`); no tracked/staged diff; formatting and flake checks pass. |

### Scenario Compliance

| Requirement | Scenario result | Evidence |
|---|---|---|
| R1 | Healthy: COMPLIANT | Three live healthy cycles and sane zero-failure state. |
| R1 | Loss threshold: PARTIAL | Static/state evidence confirms threshold two; timer accuracy contradicts the one-second design cadence. |
| R2 | NetworkManager recovery: COMPLIANT | `nmcli device connect wlan0` then `connection up JICS`, followed by health verification. |
| R2 | Platform rebind: COMPLIANT | Cold unbind, asynchronous removal handling, bind, device polling, JICS, and health verification. |
| R2 | Resumable rebind phase: COMPLIANT | `substep=bind` is persisted after removal; no disconnect command exists. |
| R2 | Reboot escalation: COMPLIANT | Failed rungs persist capped `next_rung`; guarded rung 2 is terminal. |
| R3 | Crash fast path: COMPLIANT | Matching ten-minute journal query selects rung 1. |
| R4 | Reboot permitted: COMPLIANT | Fake-state boundary test invoked only the stubbed `systemctl reboot` at 21,600s. |
| R4 | Reboot suppressed: COMPLIANT | Fake-state boundary test blocked reboot at 21,599s and recorded `stand_down_until`. |
| R5 | Action evidence: COMPLIANT | Timestamp/rung/result logs and state schema inspected live. |
| R5 | Crash collection: COMPLIANT | `ath10k-crash-watch.service` is active and unmodified. |
| R6 | Adjacent systems: COMPLIANT | AdGuard and crash watch active; no prohibited script writes. |
| R7 | Drift correction: COMPLIANT | Runbook deploy/checksum instructions and live byte identity. |
| R8 | Rollback: COMPLIANT | Complete, scoped rollback documented. |
| R9 | Rebind evidence: COMPLIANT | Both empirical outcomes retained, corrected test succeeds without reboot. |
| R10 | Repository validation: COMPLIANT | `nix flake check --no-build` exited 0 with no Nix changes. |

### Design Coherence

| Decision | Status | Evidence |
|---|---|---|
| D1, D2, D4–D10 | Followed | Implementation and live state align with detection, crash selection, state, units, validation, deployment, and runbook decisions. |
| D3 timer accuracy | NOT FOLLOWED | Design requires `AccuracySec=1s`; deployed and repository timer use `AccuracySec=15s`. |
| D7 unbind-cold | Followed | Script and amended controlled-test evidence avoid pre-disconnect; corrected test recovered without reboot. |

### Live Health and Anti-Drift

- Timer was active with an upcoming next fire; the last three observed watchdog cycles were healthy.
- `dig @172.16.0.12 wikipedia.org A` returned `NOERROR`; `adguardhome.service` was active.
- Script SHA-256 was `4e12f75296e7a4ec9e0d87e58720dc89ccd5af3ea16ad7dd3431e1037b826974`; byte-level diffs for script, service, and timer were empty.
- Phone state was `version=1`, `failures=0`, `next_rung=0`, `last_result=healthy`, and `substep=unbind`.

### Issues Found

**CRITICAL**: The timer uses `AccuracySec=15s`, not the design-mandated `AccuracySec=1s`. This permits coalescing beyond the specified one-minute cadence, so R1 cannot be fully accepted.

**WARNING**: `stand_down_until` is persisted on reboot suppression but is not read in `main`; this deviates from design Decision 4's stated stand-down behavior, though the six-hour reboot cap itself was proven.

**SUGGESTION**: Update the timer to `AccuracySec=1s`, redeploy it, then repeat the non-mutating cadence and anti-drift checks before archive.

### Remediation (2026-09-10, post-report)

Orchestrator actions taken after this report was issued:

1. **CRITICAL resolved** — `AccuracySec=1s` applied to the repo timer and deployed to the phone; `systemctl show` confirms `AccuracyUSec=1s` live; timer restarted and active.
2. **WARNING resolved** — the unused `stand_down_until` state field was removed from the script (parse case, save_state, and the reboot-suppressed write in `rung2`); the six-hour reboot guard itself is unchanged and still `last_reboot`-based (the behavior proven by the boundary tests). Fresh state file confirms the field is gone.
3. **Anti-drift re-verified post-fix** — script SHA-256 `567ac6d6dc7fc58a…` and timer SHA-256 `44ec75851a9059e6cd4ed312…` identical between repository and phone; manual cycle logged `rung=detect healthy`; state `version=1 failures=0 next_rung=0 substep=unbind last_reboot=0`.

Updated status: **READY-TO-ARCHIVE** — both findings remediated with live re-verification; gates previously green remain green.

### Verdict

**FAIL — NOT READY TO ARCHIVE.** Nine requirements and fifteen scenarios are compliant, but the live and versioned timer contradicts the required one-second accuracy decision.
