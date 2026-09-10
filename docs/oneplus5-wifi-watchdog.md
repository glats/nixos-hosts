# OnePlus 5 Wi-Fi Watchdog

This watchdog is a versioned, phone-local recovery tool for the OnePlus 5. It changes only `wlan0`, its own state, and its own journal messages. It does not modify AdGuard Home, `ath10k-crash-watch`, nftables, router settings, crash dumps, or Nix configuration.

## Prerequisites

The external phone must be reachable as `glats@172.16.0.12` using `~/.ssh/oneplus5`, with passwordless sudo. It must provide systemd, NetworkManager (`nmcli`), `iw`, `ip`, `journalctl`, `timeout`, and the `ath10k_snoc` platform driver. Review the canonical files in `docs/oneplus5-wifi-watchdog/` before every deployment.

## Deploy or correct drift

From the repository, copy to temporary phone storage, then install with root ownership. Never start the service manually; the timer controls production runs.

```sh
scp -i ~/.ssh/oneplus5 docs/oneplus5-wifi-watchdog/* glats@172.16.0.12:/tmp/
ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 'sudo install -d -o root -g root -m 0700 /var/lib/wifi-watchdog && sudo install -o root -g root -m 0755 /tmp/wifi-watchdog.sh /usr/local/sbin/wifi-watchdog.sh && sudo install -o root -g root -m 0644 /tmp/oneplus5-wifi-watchdog.service /tmp/oneplus5-wifi-watchdog.timer /etc/systemd/system/ && sudo systemd-analyze verify /etc/systemd/system/oneplus5-wifi-watchdog.service /etc/systemd/system/oneplus5-wifi-watchdog.timer && sudo systemctl daemon-reload && sudo systemctl enable --now oneplus5-wifi-watchdog.timer'
```

Check `sha256sum` on both copies and correct any drift by repeating the copy/install. Confirm `systemctl is-active oneplus5-wifi-watchdog.timer` and inspect the first scheduled cycle with `journalctl -u oneplus5-wifi-watchdog.service`.

## Thresholds and ladder

The timer checks every 60 seconds. Association requires both NetworkManager state `100` and `iw` output `Connected to`; health additionally requires the `172.16.0.12/` address on `wlan0`. One loss is persisted and deferred. The second sustained loss starts rung 0, unless a matching `ath10k_snoc ... firmware crashed!` or `qcom-q6v5-mss ... fatal error received` event occurred in the last 10 minutes, which starts rung 1.

Rung 0 reconnects through NetworkManager and verifies for up to 15 seconds. Rung 1 unbinds and polls for removal, binds `18800000.wifi` through `ath10k_snoc`, polls for `wlan0`, raises `JICS`, and verifies health. Each rung is attempted once per activation; failures advance on the next minute. Rung 2 is a guarded reboot, limited to one attempt per six hours; suppression is persisted and logged.

## 2026-09-09 incident

The phone's ath10k recovery reported a firmware event while scanning remained dead. This watchdog deliberately requires two checks before recovery and uses the recent crash signature only to skip NetworkManager rung 0. Crash dumps and `ath10k-crash-watch` remain untouched. During a controlled rebind, the expected Wi-Fi interruption is about two minutes; AdGuard outage is absorbed by router DNS fallback.

## Controlled rebind test

Stop the timer, then run exactly one detached transient test so SSH loss cannot kill it. The test never writes escalation state, reboots, or repeats. Start from the healthy association and do NOT run `nmcli device disconnect` first — invoking `--test-rung1` performs a cold unbind directly (a graceful disconnect was observed to trigger the ath10k firmware hang before unbind; see the incident note below). Observe up to five minutes for scanning, reassociation, and the `.12` lease. Re-enable the timer afterward. If rung 1 fails or hangs, do not repeat it: report the failure and use a manual reboot as the escape hatch.

```sh
sudo systemctl stop oneplus5-wifi-watchdog.timer
sudo systemd-run --unit=wifi-watchdog-rebind-test --collect --property=TimeoutStartSec=55 /usr/local/sbin/wifi-watchdog.sh --test-rung1
journalctl -u wifi-watchdog-rebind-test --no-pager
sudo systemctl enable --now oneplus5-wifi-watchdog.timer
```

The test starts from a healthy association and must not run `nmcli device disconnect`; that action was observed to trigger the ath10k firmware hang before unbind (12:04:09, followed by vdev-delete timeouts at 12:04:15 and 12:04:21).

## Manual cycle and inspection

Run one production cycle only when diagnosing: `sudo /usr/local/sbin/wifi-watchdog.sh`. Inspect state with `sudo cat /var/lib/wifi-watchdog/state` and logs with `sudo journalctl -u oneplus5-wifi-watchdog.service --since today`. The named-key state is root-only and atomically replaced; do not source it.

## Rollback and troubleshooting

Rollback disables the timer, removes both units, removes the script and `/var/lib/wifi-watchdog`, then reloads systemd. It must not touch adjacent services. If recovery fails, inspect `iw dev wlan0 link`, `nmcli device show wlan0`, the address on `wlan0`, and the kernel journal. A six-hour guard is intentional; inspect the `last_reboot` field in `/var/lib/wifi-watchdog/state` before taking action. Preserve crash evidence and contact the operator before any manual reboot.
