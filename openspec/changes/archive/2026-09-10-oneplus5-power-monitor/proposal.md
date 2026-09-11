# Proposal: OnePlus 5 Power Monitor

## Why

Two real incidents (2026-09-09, 2026-09-10) where the phone silently died from charger loss. The LAN keeps resolving via the router fallback, but the DNS/audit service vanishes with zero warning. Power death is undetectable locally; the monitor's value is firing at the exact charger-kick moment (sysfs status flips to Discharging while the phone is still alive) and reminding during drain, so the operator can re-plug before 0%.

## What Changes

- Add a power monitor: versioned shell script + systemd 60s timer for the phone, deployed like the wifi-watchdog artifacts (copy-based, no scripts wired in Nix).
- States: charger-lost alert (once), low-capacity reminder (<=15%, cooldown'd), plugged-back closure alert.
- Telegram notification reuses the running bot's credentials at runtime (source `/home/glats/Work/don-bot/.env` `TELEGRAM_TOKEN` only at runtime — the agent never reads secret values); target chat id from a plain non-secret config file.
- Runbook documenting semantics, degraded mode, and rollback.

## Scope Boundaries

### In Scope

- Phone-only: sysfs reads of `bq27411-0` + `pmi8998_charger`, state file, journald logging, Telegram sendMessage.
- De-duplication (no alert storms) and degraded journal-only mode when chat id is absent or Telegram is unreachable.
- Versioned artifacts in `docs/oneplus5-power-monitor/` + `docs/oneplus5-power-monitor.md`.

### Out of Scope

- Any power/system action (no shutdown, suspend, reboot, DNS-service interference).
- Detecting abrupt power death after the fact (physically undetectable locally).
- Changes to link-grabber-bot code, NixOS/darwin hosts, `pkgs/nixos-scripts`, router, TVs.
- Battery health diagnostics/reporting.

## Capabilities

### New Capabilities

- `oneplus5-power-monitor`: Warn about charger loss and drain while alive; never act on power.

### Modified Capabilities

None (wifi-watchdog and AdGuard remain independent).

## Approach

Versioned shell script + timer under `docs/`; 60s oneshot polls sysfs; a small state machine (previous status, warned flags, cooldown) produces at most one immediate "charger lost" alert, cooldowned "<=15%" reminders while discharging, and one "plugged back" closure. Notification target: chat id from `/etc/oneplus5-notify.conf` (`CHAT_ID=`), token sourced at runtime from the bot's EnvironmentFile; missing credentials → log degraded mode and retry next cycle without deleting state.

## Impact

| Area | Impact | Description |
|------|--------|-------------|
| `docs/oneplus5-power-monitor/` | New | Script + service + timer |
| `docs/oneplus5-power-monitor.md` | New | Runbook |
| Phone runtime | Modified | Monitor service + state dir |
| NixOS/darwin hosts | None | No flake/host changes |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Transient/Unknown status causes false alerts | Medium | Debounce: alert on transition confirmed by consecutive logic + persist warned flags |
| Notification spam | Medium | One-shot alert flags + cooldown on low-capacity reminders |
| Telegram/Wi-Fi down during charger loss | Low | Degraded journal-only, retry next cycle with dedup |
| Secret handling | Low | Runtime-only sourcing; agents never print/token values; chat id is non-secret config |

## Rollback Plan

Disable timer, remove units + script + state dir + notify config, daemon-reload. Nothing else touched.

## Dependencies

- Readable `/sys/class/power_supply/bq27411-0` (`status`, `capacity`) and `/sys/class/power_supply/pmi8998_charger`.
- `/home/glats/Work/don-bot/.env` readable at runtime by the monitor user (owner: glats — run monitor as glats).
- `curl` to `api.telegram.org` (existing service already reaches it).

## Success Criteria

- [ ] Charger loss (while alive) produces exactly one Telegram alert; re-plug produces one closure alert.
- [ ] Capacity <=15% while discharging reminds with cooldown, not per-minute spam.
- [ ] With chat id absent or Telegram unreachable: journal-only degraded mode, no errors killing the timer.
- [ ] Hard power death remains silent by design (documented).
- [ ] `format-nix && nix flake check --no-build` stays green; only `docs/oneplus5-power-monitor*` artifacts change in the repo.
