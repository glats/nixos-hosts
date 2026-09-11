# Delta for OnePlus 5 Power Monitor

## ADDED Requirements

### Requirement: 1. Periodic Power Sampling

Every 60 seconds the monitor MUST read `bq27411-0` status and capacity, and MAY corroborate with `pmi8998_charger` status. Sampling MUST NOT require root.

#### Scenario: Timer cadence [OnePlus 5]

- GIVEN the monitor timer is enabled
- WHEN 60 seconds elapse
- THEN a sample MUST have been taken and evaluated against the state machine

### Requirement: 2. Charger-Loss Alert (Once)

When status transitions to `Discharging` after having been plugged (`Charging`/`Full`/`Not charging` without a prior unresolved alert), the monitor MUST send exactly one Telegram alert and persist the flag until the phone is plugged back. Repeated Discharging samples MUST NOT re-alert.

#### Scenario: Charger kicked while alive [OnePlus 5]

- GIVEN the battery was charging or full
- WHEN status becomes `Discharging`
- THEN exactly one "charger lost" alert MUST be sent
- AND the alert MUST NOT repeat while Discharging continues

### Requirement: 3. Low-Capacity Reminder with Cooldown

While discharging with capacity <=15%, the monitor MAY remind; reminders MUST respect a cooldown (default 30 minutes) and MUST NOT fire per-sample.

#### Scenario: Drain reaches threshold [OnePlus 5]

- GIVEN the battery is Discharging and capacity <=15%
- WHEN the cooldown has expired
- THEN one reminder MUST be sent and the cooldown MUST restart

#### Scenario: Reminder silence inside cooldown [OnePlus 5]

- GIVEN a reminder was sent less than the cooldown ago
- WHEN further Discharging samples with capacity <=15% arrive
- THEN no additional reminder MUST be sent

### Requirement: 4. Plugged-Back Closure

When status returns to `Charging` (or `Full`/`Not charging` with charger online) after a charger-loss alert, the monitor MUST send exactly one closure alert and clear the warned flags.

#### Scenario: Replugged [OnePlus 5]

- GIVEN an unresolved charger-loss alert exists
- WHEN status becomes `Charging`/`Full`
- THEN exactly one "plugged back" alert MUST be sent
- AND the warned flags MUST be cleared

### Requirement: 5. Credential Handling (Runtime-Only)

The bot token MUST be sourced at runtime from the existing bot EnvironmentFile (`/home/glats/Work/don-bot/.env`, key `TELEGRAM_TOKEN`) and MUST NEVER be logged, printed, or embedded in artifacts. The chat id MUST come from the plain non-secret config `/etc/oneplus5-notify.conf` (`CHAT_ID=`); key probing of configuration files may read key NAMES only.

#### Scenario: Secrets stay in place [OnePlus 5]

- GIVEN the monitor runs
- WHEN it composes a notification
- THEN the token MUST be read at runtime from the bot EnvironmentFile
- AND no token value MUST appear in journal, state, config, or artifacts

### Requirement: 6. Degraded Mode

If the chat id is absent, the token file is unreadable, or Telegram is unreachable, the monitor MUST log degraded mode to the journal, PRESERVE its state (no alert flags reset), and retry on the next cycle. Missing-credential MUST NOT wipe or disable the state machine.

#### Scenario: Telegram unreachable [OnePlus 5]

- GIVEN an alert is due
- WHEN the sendMessage call fails
- THEN the alert condition MUST remain pending in state
- AND the next successful attempt MUST send it without duplicating later alerts

### Requirement: 7. Strict Non-Interference

The monitor MUST NOT perform any power/system action (no shutdown, suspend, reboot, process control) and MUST NOT touch the Wi-Fi watchdog, AdGuard, NetworkManager, or NetworkManager profiles. Its phone footprint is limited to its script, units, state dir, config file, and journal entries.

#### Scenario: Independent operation [OnePlus 5]

- GIVEN the monitor runs in any state
- WHEN it detects any battery condition
- THEN it MUST only log, persist its own state, and send notifications
- AND adjacent services MUST be unaffected

### Requirement: 8. Versioned Source of Truth and Redeploy

Repository artifacts (`docs/oneplus5-power-monitor/`) MUST be canonical; the runbook MUST document copy-based deployment, drift correction, and a manual single-cycle invocation for testing.

#### Scenario: Redeploy corrects drift [OnePlus 5, repository]

- GIVEN live script/units drifted from the repository
- WHEN the runbook redeploy is performed
- THEN the phone state MUST match the repository byte-for-byte

### Requirement: 9. Complete Rollback

Rollback MUST disable the timer, remove units, script, state dir, and `/etc/oneplus5-notify.conf`, then daemon-reload — touching nothing else.

#### Scenario: Full removal [OnePlus 5]

- GIVEN the rollback procedure runs
- WHEN it completes
- THEN no monitor artifacts remain on the phone
- AND watchod/others/AdGuard/bot MUST be unaffected

### Requirement: 10. Nix Repository Invariance

Only `docs/oneplus5-power-monitor*` artifacts MUST change in the repository; `nix flake check --no-build` MUST remain green.

#### Scenario: Repository gate [Repository]

- GIVEN only the monitor artifacts changed
- WHEN `format-nix && nix flake check --no-build` runs
- THEN they MUST pass without change-specific failures
