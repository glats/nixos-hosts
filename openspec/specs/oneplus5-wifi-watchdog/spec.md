# Delta for OnePlus 5 Wi-Fi Watchdog

## ADDED Requirements

### Requirement: Periodic Sustained-Loss Detection

The watchdog MUST check `wlan0` association every 60 seconds and require a design-defined sustained-loss threshold exceeding one check.

#### Scenario: [oneplus5] Healthy

- WHEN a scheduled check finds `wlan0` associated
- THEN it SHALL record healthy state without recovery

#### Scenario: [oneplus5] Loss threshold

- WHEN loss remains below the threshold
- THEN it MUST defer recovery
- WHEN the threshold is reached
- THEN it MUST start recovery

### Requirement: Bounded Recovery Ladder

Each recovery rung MUST be timeout-bounded, verify association plus `172.16.0.12`, log its result, and escalate on failure.

#### Scenario: [oneplus5] NetworkManager recovery

- WHEN rung 0 runs without a recent firmware crash
- THEN it SHALL use `nmcli device connect wlan0` or `nmcli connection up JICS`
- AND stop escalation only after verification succeeds

#### Scenario: [oneplus5] Platform rebind

- WHEN rung 1 runs
- THEN it SHALL attempt a cold unbind of `18800000.wifi` through `ath10k_snoc` without a graceful disconnect
- AND if the unbind write times out but `wlan0` is absent, it SHALL count removal as successful and resume at bind
- AND it SHALL bind `18800000.wifi` through `ath10k_snoc`
- AND poll within a timeout for `wlan0` and verified health

#### Scenario: [oneplus5] Resumable rebind phase

- WHEN phase A removes `wlan0`, including asynchronously after the unbind write timeout
- THEN it SHALL persist `substep=bind` and perform phase B on the next production cycle
- AND it MUST NOT issue a graceful disconnect before the rebind

#### Scenario: [oneplus5] Reboot escalation

- WHEN a rung times out or fails verification
- THEN it MUST log failure and advance
- AND rung 2 SHALL invoke `systemctl reboot` only as the last resort

### Requirement: Firmware-Crash Fast Path

The watchdog MUST recognize recent journaled ath10k crashes using the `ath10k-crash-watch` signature family.

#### Scenario: [oneplus5] Crash fast path

- WHEN sustained loss coincides with a recent matching crash signature
- THEN it MUST skip rung 0 and begin at rung 1

### Requirement: Persistent Reboot-Loop Guard

The watchdog MUST cap consecutive automatic reboots in a design-defined window and persist the guard across runs and reboots.

#### Scenario: [oneplus5] Reboot permitted

- WHEN rung 2 is reached below the configured cap
- THEN it MAY reboot and MUST persist the attempt

#### Scenario: [oneplus5] Reboot suppressed

- WHEN rung 2 is reached at the configured cap
- THEN it MUST NOT reboot
- AND MUST log suppression and await a later check

### Requirement: Forensic Evidence Preservation

The watchdog MUST journal timestamped actions and results, persist recovery state, and MUST NOT alter crash dumps.

#### Scenario: [oneplus5] Action evidence

- WHEN any watchdog action completes
- THEN its timestamp, rung, and result SHALL be journaled
- AND escalation state SHALL survive into the next run

#### Scenario: [oneplus5] Crash collection

- WHEN ath10k evidence appears during recovery
- THEN crash collection and retained dumps MUST remain untouched

### Requirement: Recovery Scope Isolation

The watchdog MUST touch only `wlan0` recovery and its own state and logs. Device-internal shell is allowed only on this external pmOS phone.

#### Scenario: [oneplus5] Adjacent systems

- WHEN the watchdog runs, deploys, or rolls back
- THEN AdGuard, `ath10k-crash-watch`, nftables, router configuration, and NixOS hosts MUST remain unchanged

### Requirement: Canonical Artifacts and Redeployment

The `docs/oneplus5-wifi-watchdog*` artifacts MUST be the versioned source of truth.

#### Scenario: [oneplus5] Drift correction

- WHEN phone files drift from repository versions
- THEN the runbook SHALL provide copy-deploy, verification, and correction steps

### Requirement: Complete Rollback

Rollback MUST disable both units, remove units, script, and state, and reload systemd without unrelated changes.

#### Scenario: [oneplus5] Rollback

- WHEN documented rollback completes
- THEN no watchdog schedule, executable, unit, or state SHALL remain
- AND the pre-existing phone services SHALL continue unchanged

### Requirement: Controlled Rebind Validation

Apply MUST perform one bounded rung-1 validation and record whether scanning and reassociation recover without reboot.

#### Scenario: [oneplus5] Rebind evidence

- WHEN apply performs the unbind-cold unbind/bind test from healthy state without a graceful disconnect
- THEN it MUST time out and MUST NOT repeat automatically
- AND scanning and reassociation results SHALL enter `tasks.md` evidence

### Requirement: Nix Repository Invariance

Implementation MUST change only `docs/oneplus5-wifi-watchdog/` and `docs/oneplus5-wifi-watchdog.md`, never Nix configuration.

#### Scenario: [NixOS-hosts] Repository validation

- WHEN `nix flake check --no-build` runs after implementation
- THEN it MUST succeed without NixOS or Darwin configuration changes
