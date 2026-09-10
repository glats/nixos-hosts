# Proposal: OnePlus 5 Wi-Fi Watchdog

## Why

WCN3990 crashes can leave the OnePlus 5 LAN DNS server unable to scan after driver recovery. On 2026-09-09 this caused a ten-minute outage requiring forced reboot. It needs bounded automatic recovery.

## What Changes

- Add a watchdog script, oneshot, and 60-second timer.
- Detect Wi-Fi health and ath10k crashes, then recover.
- Document operation and rollback.

## Scope Boundaries

### In Scope

- OnePlus 5 only: `wlan0`, `JICS`, `ath10k_snoc`, and systemd.
- Recovery ladder: NetworkManager reconnect, platform unbind/bind, then guarded reboot.
- Reuse `ath10k-crash-watch.service` journal signatures without changing its process.
- Persist escalation state and action logs.

### Out of Scope

- NixOS/darwin hosts, flakes, and `pkgs/nixos-scripts/`.
- AdGuard Home, TVs, and router configuration.
- Kernel/firmware upgrades or dispatcher hooks.
- Phone mutation before apply.

## Capabilities

### New Capabilities

- `oneplus5-wifi-watchdog`: Recover zombie Wi-Fi with bounded escalation and evidence.

### Modified Capabilities

None.

## Approach

Version the shell, units, and runbook under the stated `docs/` paths. A timer checks health. Ordinary failures start with `nmcli device connect wlan0` or `nmcli connection up JICS`; recent crashes skip to platform rebind. Rebind is timed and polls for `wlan0`. Failure escalates to guarded `systemctl reboot`. Apply runs one controlled rebind test.

## Impact

| Area | Impact | Description |
|---|---|---|
| `docs/oneplus5-wifi-watchdog/` | New | Script and units |
| `docs/oneplus5-wifi-watchdog.md` | New | Operations runbook |
| OnePlus 5 runtime | Modified | Watchdog and recovery state |
| NixOS/darwin hosts | None | No Nix or host configuration changes |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Rebind hangs or fails | Medium | Timeouts, interface polling, reboot fallback |
| Reboot loop | Medium | Cooldown, escalation cap, and backoff |
| Transient disconnect triggers recovery | Medium | Threshold and staged escalation |
| Lost crash evidence | Low | Preserve dump collector; journal actions |

## Rollback Plan

Disable and remove watchdog units, script, and state, then reload systemd. Leave crash collection, NetworkManager, DNS, and router unchanged; manual reboot remains available.

## Dependencies

- Phone systemd, `nmcli`, `iw`, journal, and root privileges.
- Writable bind/unbind for `18800000.wifi` and existing crash signatures.
- Existing `172.16.0.12` DHCP reservation.

## Success Criteria

- [ ] Sustained loss is detected within the defined threshold.
- [ ] Ordinary failures attempt NetworkManager recovery; recent firmware crashes skip to rebind.
- [ ] Each rung is bounded, verified, logged, and escalates on failure.
- [ ] Reboot escalation cannot create an unbounded reboot loop.
- [ ] Apply tests whether rebind restores scanning.
- [ ] Deployment and rollback are reproducible without Nix or DNS changes.
