# Proposal: OnePlus 5 AdGuard DNS

## Why

Smart TVs need per-device DNS-query visibility without moving DHCP away from the Xiaomi router. The always-on OnePlus 5 can provide a reversible AdGuard Home service without affecting NixOS hosts.

## What Changes

- Add `docs/oneplus5-adguard-dns.md` covering installation, stable addressing, manual TV enrollment, query logs, Hagezi opt-in, maintenance, and rollback.
- Add a versioned log-only `docs/oneplus5-adguard-dns/AdGuardHome.yaml` with no active blocklists.
- Add `docs/oneplus5-adguard-dns/adguardhome.service` to run the package as its dedicated user.

## Scope Boundaries

### In Scope

- OnePlus 5 as LAN-bound DNS for manually configured TVs only.
- Initial query logging and per-TV client identification without filtering.
- Instructions for optionally enabling Hagezi Samsung, LG webOS, Roku, Amazon, and Apple TV lists later.
- Copy-based deployment with the repository artifacts treated as source of truth.

### Out of Scope

- Router DHCP DNS changes or LAN-wide client migration.
- AdGuard Home DHCP; the runbook may mention it only as future opt-in work.
- Install-time blocklists, automatic activation, containers, deployment scripts, Nix changes, or phone changes during artifact development.

## Capabilities

### New Capabilities

- `oneplus5-adguard-dns`: Operate log-first DNS for manually enrolled TVs, with opt-in filtering and rollback.

### Modified Capabilities

None.

## Approach

Install Alpine's package, deploy the YAML and systemd unit, bind DNS to the stable LAN address, and enroll TVs manually. Keep filters disabled until explicitly enabled.

## Impact

| Area | Impact | Description |
|------|--------|-------------|
| `docs/oneplus5-adguard-dns.md` | New | Operator runbook and safety procedures |
| `docs/oneplus5-adguard-dns/AdGuardHome.yaml` | New | Versioned log-only baseline |
| `docs/oneplus5-adguard-dns/adguardhome.service` | New | Device systemd service |
| NixOS/darwin hosts | None | No flake or host configuration changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Static-address collision | Medium | Require reservation/pool validation before deployment |
| Phone Wi-Fi or service outage breaks enrolled-TV DNS | Medium | Enroll manually and document immediate per-TV rollback |
| Live configuration drifts from repository | Medium | Define repository source-of-truth and redeployment workflow |

## Rollback Plan

Restore each TV to automatic/router DNS, then disable AdGuard Home. Remove the unit, config, and package after no clients depend on the phone.

## Dependencies

- Router access to validate the DHCP pool or create a reservation.
- postmarketOS edge `adguardhome` package and stable `wlan0` connectivity.

## Success Criteria

- [ ] A manually enrolled TV resolves DNS through `172.16.0.12` and appears by name in query logs.
- [ ] Initial operation has no active filters or blocklists.
- [ ] Other LAN clients and all NixOS/darwin configurations remain unchanged.
- [ ] Hagezi activation and per-TV/service rollback are documented and operator-controlled.
