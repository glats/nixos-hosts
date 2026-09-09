# Delta for OnePlus 5 AdGuard DNS

## ADDED Requirements

### Requirement: 1. Stable Addressing Gate

Deployment MUST NOT begin until `172.16.0.12` is reserved or verified outside DHCP.

#### Scenario: Address validated [OnePlus 5, Xiaomi router]

- GIVEN the reservation or exclusion is validated
- WHEN the operator starts deployment
- THEN deployment MAY proceed

#### Scenario: Address not validated [OnePlus 5, Xiaomi router]

- GIVEN neither safety method is validated
- WHEN deployment is requested
- THEN deployment MUST halt

### Requirement: 2. Service Installation and Operation

The phone MUST install `adguardhome`, deploy YAML at `/etc/adguardhome/AdGuardHome.yaml`, and enable its unit. DNS MUST listen only on `172.16.0.12:53`; the web UI MUST use a LAN-restricted bind chosen in design, never wildcard or Tailscale.

#### Scenario: Service installed [OnePlus 5]

- GIVEN the address gate passed and artifacts are deployed
- WHEN the unit is enabled and started
- THEN DNS MUST answer on `172.16.0.12:53`
- AND the web UI MUST use only its LAN-restricted bind

#### Scenario: Service survives reboot [OnePlus 5]

- GIVEN the service is enabled
- WHEN the phone reboots
- THEN it MUST become active and answer on port 53

### Requirement: 3. Manual TV Enrollment

Each TV MUST use manual DNS `172.16.0.12`; router and AdGuard Home DHCP MUST NOT change.

#### Scenario: Enrolled TV is identified [TV, OnePlus 5]

- GIVEN a named TV uses `172.16.0.12` as DNS
- WHEN it resolves a domain
- THEN the query MUST traverse the phone and appear under its name

### Requirement: 4. Log-Only Baseline

A fresh deployment MUST enable logging, disable filtering, and have zero active filters or blocklists.

#### Scenario: Logging without filtering [TV, OnePlus 5]

- GIVEN the baseline was freshly deployed
- WHEN an enrolled TV makes a DNS query
- THEN the query MUST be logged and MUST NOT be filtered

### Requirement: 5. Query-Log Retention

Query-log retention MUST default to 7 days and MAY use supported intervals up to 90 days.

#### Scenario: Default retention [OnePlus 5]

- GIVEN no retention override exists
- WHEN the baseline is deployed
- THEN query-log retention MUST be 7 days

#### Scenario: Maximum retention [OnePlus 5]

- GIVEN the operator selects 90 days
- WHEN the setting is applied
- THEN retention MUST be 90 days

### Requirement: 6. Operator-Controlled Hagezi Opt-In

Hagezi Samsung, LG webOS, Roku, Amazon, and Apple TV lists MUST remain inactive until the operator enables selected lists through the runbook.

#### Scenario: Selected vendor list blocks telemetry [TV, OnePlus 5]

- GIVEN an enrolled TV and its enabled vendor list
- WHEN it queries a listed telemetry domain
- THEN the domain MUST be blocked, including by `0.0.0.0` response

#### Scenario: Non-enrolled clients remain unaffected [LAN client]

- GIVEN a client does not use `172.16.0.12` as DNS
- WHEN a vendor list is enabled on the phone
- THEN its DNS path and responses MUST remain unchanged

### Requirement: 7. Repository Source of Truth

Repository YAML and unit MUST be canonical; the runbook MUST document redeployment and drift correction.

#### Scenario: Redeployment corrects drift [OnePlus 5, repository]

- GIVEN live configuration drifted manually
- WHEN the runbook's redeployment is performed
- THEN live state MUST match repository artifacts

### Requirement: 8. Complete Rollback

Rollback MUST restore TVs to automatic/router DNS before service, unit, configuration, and package removal.

#### Scenario: TV works after rollback [TV, OnePlus 5]

- GIVEN a TV was restored to automatic/router DNS
- WHEN the phone service is stopped and removed
- THEN the TV MUST resolve through the router and retain internet access

### Requirement: 9. Nix Repository Invariance

Implementation MUST NOT alter NixOS host or flake configuration. The only permitted repository changes are the three `docs/` artifacts plus the approved operator UI access helper (Requirement 10): `pkgs/nixos-scripts/cmd/adguard-tunnel/`, its `internal/` support package and tests, and the `subPackages` registration in `pkgs/nixos-scripts/default.nix`. DHCP MUST NOT change.

#### Scenario: Repository gate remains green [Repository, NixOS/darwin hosts]

- GIVEN only the three `docs/` artifacts and the Requirement 10 helper changed
- WHEN `nix flake check --no-build` is run
- THEN it MUST pass without change-specific failures

### Requirement: 10. Operator UI Access Helper (approved scope addition)

The repository MUST ship a self-explanatory Go helper (`adguard-tunnel`, under `pkgs/nixos-scripts/cmd/`) that gives the operator UI access to AdGuard Home by opening an SSH local port-forward to `172.16.0.12:3000` over SSH with the dedicated key, because the phone's firewall intentionally blocks `:3000` from the LAN. The helper MUST be wired as a permanent operational binary (subPackages + runbook) and follow the Go-only operational scripts policy.

#### Scenario: Tunnel up and URL printed [operator host, OnePlus 5]

- GIVEN the operator runs `adguard-tunnel` with the default flags
- WHEN SSH establishes a local forward from a local port to `172.16.0.12:3000`
- THEN the helper MUST print the resolved local UI URL to stdout
- AND the forward MUST remain up until the helper is interrupted

#### Scenario: Clean shutdown [operator host, OnePlus 5]

- GIVEN the tunnel is running
- WHEN SIGINT or SIGTERM is received
- THEN the helper MUST exit cleanly (status 0) with the SSH forward torn down
- AND MUST NOT leave an orphaned `ssh` process

#### Scenario: Local port already busy [operator host]

- GIVEN the requested local port is already in use
- WHEN the helper starts
- THEN it MUST either refuse with a clear message or auto-select an alternative port and explicitly say so on stdout

#### Scenario: Unreachable host [operator host, OnePlus 5]

- GIVEN the phone is unreachable or SSH fails
- WHEN the helper attempts to connect
- THEN it MUST print a clear error and exit with a non-zero status
