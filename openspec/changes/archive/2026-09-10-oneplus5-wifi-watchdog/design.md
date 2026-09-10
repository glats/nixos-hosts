# Design: OnePlus 5 Wi-Fi Watchdog

## Context

The phone can report ath10k recovery while scanning remains dead. A shell oneshot detects sustained loss and advances one rung per 60-second activation. No Nix option changes.

## Goals / Non-Goals

Recover `wlan0` and `172.16.0.12`, preserve evidence, prevent loops. Do not change AdGuard, crash collection, firewall/router, firmware/kernel, or Nix.

## Decisions

| # | Choice and rationale | Rejected alternative |
|---|---|---|
| 1 Detection | Every 60s; associated only when NM state starts `GENERAL.STATE:100` **and** `iw` says `Connected to`. Increment loss count; recover at 2. A crash does not bypass the spec's sustained-loss threshold. | One sample causes transient-triggered recovery; ping tests unrelated reachability. |
| 2 Crash skip | At threshold, a matching kernel-journal event within 10 minutes starts rung 1, spanning the observed hang. | Boot-wide signatures remain stale; shorter windows miss it. |
| 3 Timing | One rung per invocation, `TimeoutStartSec=55`: rung 0 ≤23s (8s action + 15s verify); rung 1 ≤48s (5/5/5/10/8/15); rung 2 immediate. Failed rungs wait for the next 60s activation. | One invocation containing all rungs exceeds timer safety. |
| 4 State/guard | Atomic root-only `/var/lib/wifi-watchdog/state`: `version`, `failures`, `next_rung`, `last_rung`, `last_result`, `last_reboot`, `stand_down_until`. Permit one reboot per 6h; suppression stands down until expiry, then restarts detection. Success resets escalation but retains reboot time. | Volatile state permits loops; sourcing state executes corrupt content. |
| 5 Units/logging | Root oneshot, after/wants NetworkManager, no conflicts, 55s timeout, `UMask=0077`; stderr goes to journald. No `NoNewPrivileges`/filesystem hardening because sysfs and reboot are required. | Restart overlaps timer semantics; `systemd-cat` is unnecessary. |
| 6 Verification | Poll every 2s for 15s; require both association checks plus `172.16.0.12/` on `wlan0`. | Association alone can precede DHCP. |
| 7 Rebind test | Stop timer from a healthy state; launch one detached transient `--test-rung1` service with no graceful disconnect. Test mode runs the unbind-cold two-phase sequence in one invocation, never changes escalation state or reboots; observe up to 5m, record timing/scanning/lease in `tasks.md`, then re-enable timer. | A graceful disconnect before unbind triggers the ath10k firmware hang; automatic repetition is unsafe. |
| 8 Runbook | Prerequisites, deploy/drift correction, thresholds, 2026-09-09 walkthrough, rebind test, rollback, manual cycle, state/journal troubleshooting. | Undocumented mutation is irreproducible. |
| 9 Deployment | `scp` to `/tmp`; `install` root:root 0755 script and 0644 units; verify, daemon-reload, enable timer. | Editing live files causes drift. |
| 10 Script | One shell file ≤150 lines, `set -u` without `set -e`, explicit return handling; functions below; only coreutils/iproute2/iw/nmcli/systemd. | Go/cascaded units add deployment complexity; `set -e` breaks intentional fallbacks. |

## Flow

The original controlled test proved that a graceful disconnect is unsafe: the disconnect at 12:04:09 hung ath10k, followed by vdev-delete timeouts at 12:04:15 and 12:04:21. Therefore rung 1 uses unbind-cold semantics and treats an absent device after a timed-out write as asynchronous completion.

```text
timer -> detect -> healthy: reset
                -> first loss: persist/defer
                -> second loss -> recent crash? rung1 : rung0
                                  failure -> next timer/rung1 -> next timer/rung2
                                  success -> reset             -> guard/reboot
```

## Detailed Design

Functions: `log`, `load_state`, `save_state`, `associated`, `healthy`, `recent_crash`, `verify_health`, `rung0`, `rung1`, `rung2`, `main`. Parsing accepts only named numeric/enumerated keys.

```sh
nmcli -t -f GENERAL.STATE device show wlan0 | grep -q '^GENERAL.STATE:100'
iw dev wlan0 link | grep -q '^Connected to '
ip -4 -o addr show dev wlan0 scope global | grep -q ' 172\.16\.0\.12/'
journalctl -k --since '-10 min' --no-pager -n 1 -g 'ath10k_snoc .*firmware crashed!|qcom-q6v5-mss .*fatal error received'
nmcli --wait 8 device connect wlan0                         # rung 0
timeout 5 sh -c "printf '%s\n' 18800000.wifi > '$DRV/unbind'"
# if wlan0 is absent after timeout, persist substep=bind; otherwise escalate
timeout 5 sh -c "printf '%s\n' 18800000.wifi > '$DRV/bind'"
# poll wlan0 present 10s; then:
nmcli --wait 8 connection up JICS                           # rung 1
systemctl reboot                                            # guarded rung 2
```

```ini
# oneplus5-wifi-watchdog.service
[Unit]
Description=Recover OnePlus 5 Wi-Fi
Wants=NetworkManager.service
After=NetworkManager.service
[Service]
Type=oneshot
User=root
UMask=0077
ExecStart=/usr/local/sbin/wifi-watchdog.sh
TimeoutStartSec=55
StandardOutput=journal
StandardError=journal
```

```ini
# oneplus5-wifi-watchdog.timer
[Unit]
Description=Check OnePlus 5 Wi-Fi every minute
[Timer]
OnBootSec=60s
OnUnitActiveSec=60s
AccuracySec=1s
RandomizedDelaySec=0
Unit=oneplus5-wifi-watchdog.service
[Install]
WantedBy=timers.target
```

```sh
scp -i ~/.ssh/oneplus5 docs/oneplus5-wifi-watchdog/* glats@172.16.0.12:/tmp/
sudo install -d -o root -g root -m 0700 /var/lib/wifi-watchdog
sudo install -o root -g root -m 0755 /tmp/wifi-watchdog.sh /usr/local/sbin/
sudo install -o root -g root -m 0644 /tmp/oneplus5-wifi-watchdog.{service,timer} /etc/systemd/system/
systemd-analyze verify /etc/systemd/system/oneplus5-wifi-watchdog.{service,timer}
sudo systemctl daemon-reload && sudo systemctl enable --now oneplus5-wifi-watchdog.timer
```

Production rung 1 is resumable: phase A unbinds without disconnecting first and persists `substep=bind`; the next cycle performs phase B. A timed-out unbind is successful when `wlan0` is absent, because removal may complete asynchronously; a still-present device escalates to rung 2. Test mode runs both phases internally. The unbind write may block for about 5 seconds before timeout, which is acceptable within the 55-second service budget. Test via `systemd-run --unit=wifi-watchdog-rebind-test --collect --property=TimeoutStartSec=55 /usr/local/sbin/wifi-watchdog.sh --test-rung1`; rollback disables both units, removes script, units, and state directory, then reloads systemd.

## Threat Matrix

All five rows are N/A: documentation-like path classification (fixed script), Git selection, commit state, push state, and PR commands are outside this process. Shell safety uses fixed arguments, no input/eval, strict parsing, timeouts, and root-only state.

## Risks / Trade-offs

The rebind drops Wi-Fi/SSH for about two minutes; router DNS fallback makes this acceptable. The unbind write may hang about 5 seconds before timeout, but remains within the 55-second budget. Rebind may fail, DHCP may exceed 15s, and stand-down may require manual intervention. Devcoredumps remain untouched. Apply verifies ShellCheck, stubbed transitions, unit syntax, one live rebind, and `nix flake check --no-build`.

## Open Questions

None. If rebind fails, retain rung 1 as bounded best effort and rely on guarded reboot.
