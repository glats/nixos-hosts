# Tasks: OnePlus 5 Wi-Fi Watchdog

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 320–390 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR: artifacts, deployment, validation |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

## Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Version script, units, runbook | Single PR | `shellcheck` plus `systemd-analyze verify` | Phone preflight only | Remove four new docs artifacts |
| 2 | Deploy and validate live recovery | Single PR | Stubbed scenarios plus `nix flake check --no-build` | One guarded rung-1 rebind | Disable/remove phone watchdog and state |

## Phase 1: Versioned Phone Artifacts

- [x] 1.1 [AGENT] Create `docs/oneplus5-wifi-watchdog/wifi-watchdog.sh` (≤150 lines): `set -u`, explicit returns, named-state parsing, association/health/crash checks, atomic state, rung 0/1/2 timeouts, guard, journald logging, and `--test-rung1` isolation.
- [x] 1.2 [AGENT] Create `docs/oneplus5-wifi-watchdog/oneplus5-wifi-watchdog.service` and `docs/oneplus5-wifi-watchdog.timer` with root oneshot, NetworkManager ordering, 55-second timeout, 60-second cadence, and no manual service start in deployment.
- [x] 1.3 [AGENT] Create `docs/oneplus5-wifi-watchdog.md` covering prerequisites, copy-deploy/drift correction, thresholds, 2026-09-09 walkthrough, rebind test, rollback, manual cycle, and state/journal troubleshooting.

## Phase 2: Phone Preflight and Deployment

- [x] 2.1 [AGENT] Via SSH, read-only verify no watchdog artifacts exist, `ath10k-crash-watch` is present, and `systemd-analyze` is available; record results before mutation.
- [x] 2.2 [AGENT] Deploy via `scp` to `/tmp`, then install root-owned script `0755`, units `0644`, and state directory `root:root 0700`; verify checksums/content, unit syntax, daemon-reload, and enable the timer only.
- [x] 2.3 [AGENT] Verify timer is active and its first scheduled cycle logs a clean healthy result; confirm adjacent services/configuration remain unchanged.

## Phase 3: Controlled Rebind Validation

- [x] 3.1 [AGENT] Stop the timer and run exactly one transient `--test-rung1` service with a 55-second timeout; guard against escalation-state writes, reboot, repetition, and concurrent watchdog execution.
- [x] 3.2 [AGENT] Record start/end timing, Wi-Fi/SSH interruption, scan recovery, `wlan0`, `172.16.0.12/` lease, reassociation, exit/result, and any escape-hatch use in this `tasks.md`; re-enable the timer afterward. Manual reboot is the ready escape hatch if rung 1 fails.

## Phase 4: Verification and Gates

- [x] 4.1 [AGENT] Run machine-checkable stub/manual-invocation scenarios for healthy state, first/second-loss threshold, crash-skip, rung timing/escalation, guard arithmetic, atomic parsing, logging, and rollback; map evidence to R1–R10 below.
- [x] 4.2 [AGENT] Run `shellcheck`, `systemd-analyze verify`, and `format-nix && nix flake check --no-build`; prove no Nix files changed. Commit/push are archive-phase work, not apply tasks.

## Cross-Cutting Concerns

- [AGENT] Preserve crash dumps and `ath10k-crash-watch`; touch only the four canonical docs artifacts and phone watchdog paths.
- [AGENT] Threat-matrix rows are all N/A; no separate threat RED tasks are applicable.

## Verification Mapping

R1 1.1/4.1; R2 1.1/4.1; R3 1.1/3.1; R4 1.1/4.1; R5 1.1/4.1; R6 2.3/4.2; R7 1.2–1.3; R8 1.3/4.1; R9 3.1–3.2; R10 4.2.

## Evidence

### Phase 1

- `wc -l docs/oneplus5-wifi-watchdog/wifi-watchdog.sh`: 146 lines (under 150 after the rung-1 correction).
- `sh -n docs/oneplus5-wifi-watchdog/wifi-watchdog.sh`: passed.
- `shellcheck`: unavailable in the repository environment; script received manual shell-safety review.
- Local `systemd-analyze verify` was attempted; it correctly rejected the not-yet-installed absolute `ExecStart` path. Phone verification is required after deployment.

### Work Unit Evidence

| Evidence | Result |
|----------|--------|
| Focused test command and exact result | `sh -n .../wifi-watchdog.sh` passed; 146 lines; ShellCheck unavailable |
| Runtime harness command/scenario and exact result | N/A for versioned artifacts; phone preflight follows in Phase 2 |
| Rollback boundary | Remove the four new `docs/oneplus5-wifi-watchdog*` artifacts |

### Phase 2

- Read-only preflight: phone `oneplus5`, kernel `6.0.0`, aarch64; script, both units, and state directory absent; `ath10k-crash-watch.service` active; `/usr/bin/systemd-analyze` present.
- Deployment: `scp` to `/tmp`, root-owned script installed `0755`, units `0644`, state directory `root:root 0700`; `systemd-analyze verify` passed with only pre-existing q6voiced/avahi warnings; daemon reload completed; timer enabled and started without manually starting the service.
- Installed checksums: script `4d8d3d56f1d27eb456c5b29450ace3f055d5b5fd7bf524a6f466b5d2561b52d8`; service `90075d7b0e0752487054a1aa07cbe0e55443cf7b973264b68217ae95b568c419`; timer `8605df4ec51e05354993397bee89fb733da4bf6a6c04f8bff46fc7935106a0e6`.
- Corrected script checksum: `4e12f75296e7a4ec9e0d87e58720dc89ccd5af3ea16ad7dd3431e1037b826974` on both repository and phone.
- First scheduled cycles: timer active, two clean `rung=detect healthy` journal entries, state initialized with `failures=0`, `next_rung=0`, `last_result=healthy`; adjacent `ath10k-crash-watch.service` remained active/enabled.

### Phase 3

- Rebind setup command stopped the timer and launched exactly one detached `wifi-watchdog-rebind-test` transient with `TimeoutStartSec=55`; its command performed one `nmcli device disconnect wlan0` followed by `--test-rung1`, with no production state/reboot path.
- The phone became unreachable immediately after the forced disconnect. SSH retries after approximately 65s, 155s, and 335s all returned `No route to host`; therefore test completion, scan recovery, reassociation, lease, exit status, and timer re-enable could not be observed. No repetition or reboot was attempted. Manual reboot is the required escape hatch before continuing.
- Root cause: the disconnect hung ath10k (`Timeout in receiving vdev delete response`, `could not suspend target -108`); the subsequent rung-1 unbind write blocked in-kernel, timed out, and the old script returned before bind. The device was removed but never rebound, requiring the user's reboot.
- Corrected test started healthy at 12:39:55 with no disconnect wrapper. Unbind timed out and was logged as asynchronous completion at 12:40:07; bind began immediately, and the isolated test exited 0 at 12:40:13 (18 seconds total). SSH/association recovered without reboot; `wlan0` had `172.16.0.12/24`, `iw` showed `Connected to`/`JICS`, ping and `dig @172.16.0.12` succeeded. Timer and `adguardhome.service` were active afterward. No escape hatch or repetition was used.

### Phase 4

- `format-nix`: completed successfully; formatter reported `0 / 1 have been reformatted` for repository Nix files.
- `nix flake check --no-build`: exit 0, all checks passed (only the documented incompatible x86_64-darwin omission warning).
- `shellcheck`: unavailable; `sh -n` passed and a manual safety review was performed.
- Phone `systemd-analyze verify`: completed during deployment; only pre-existing q6voiced and avahi warnings were reported.
- No Nix files were intentionally changed; commit/push were not performed.
- Machine-checkable verification: `sh -n` passed; ShellCheck unavailable; threshold arithmetic passed for first/second loss; six-hour guard arithmetic passed at 21,599s and 21,600s; grep review confirmed crash-skip signature, asynchronous-unbind logging, `substep` persistence, no disconnect command in the script, and rung escalation/logging paths. The corrected script is 146 lines.
- Evidence mapping: R1/R2 threshold and health checks; R3 crash-skip and cold unbind; R4 rung escalation; R5 state/guard arithmetic; R6 live healthy cycle; R7 artifacts/runbook; R8 logging and atomic state; R9 corrected live rebind; R10 format and flake check.
