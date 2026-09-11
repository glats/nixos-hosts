# Design: OnePlus 5 Power Monitor

## Context

Phone: OnePlus 5, pmOS edge (systemd 261), always-on LAN DNS (AdGuard, 172.16.0.12). Power death is instant and undetectable; the monitor warns at the charger-kick moment while still alive. sysfs verified: `/sys/class/power_supply/bq27411-0` (status/capacity/voltage_now/current_now/temp) and `/sys/class/power_supply/pmi8998_charger` (status/health/online?/voltage/current). Telegram reuse: link-grabber-bot binary `/home/glats/Work/don-bot/bin/link-grabber-bot`, EnvironmentFile `/home/glats/Work/don-bot/.env` (key `TELEGRAM_TOKEN`; never print values). No chat-id mechanism in the bot tree → operator-provided plain config.

## Goals

Alert within ≤60s of charger kick and during drain to 0%; zero alert storms; zero interference with any other service.

## Non-Goals

Death detection (impossible), power actions, battery analytics.

## Decisions

| # | Decision | Rationale / rejected |
|---|----------|----------------------|
| 1 | Shell script `/usr/local/sbin/power-monitor.sh` (≤120 lines, `set -u` no `set -e`, English comments — user-facing alert texts in Spanish) + oneshot `power-monitor.service` + `power-monitor.timer` (OnBootSec=60s, OnUnitActiveSec=60s, AccuracySec=1s). Runs as `User=glats, Group=users` (reads own `.env`; sysfs world-readable). TimeoutStartSec=30s. | Matches wifi-watchdog idioms; root unnecessary — rejected root synthesis: looser security for no need. |
| 2 | State: `/var/lib/power-monitor/state` (dir created at deploy, owned glats:users 0755, file 0640). Schema: `version=1`, `prev_status`, `tx_confirm` (0/1 — provisional transition awaiting second sample), `lost_pending` (0/1), `low_warned` (0/1), `remind_at` (epoch), `last_capacity`. Written atomically (mktemp + mv), 0640. | Same resumable pattern as wifi-watchdog. |
| 3 | Semantics: plugged set = `Charging|Full|Not charging`; `Discharging` = on battery; `Unknown` treated as plugged (logged once, no alert — quirk guard). **Debounce**: plugged→Discharging sets `tx_confirm=1` (no alert yet); a SECOND consecutive Discharging sample fires the charger-lost alert (bounded worst-case detection ≈2min). | Kills false alarms from micro-drift; bounded latency acceptable (router fallback absorbs years... minutes). |
| 4 | Alerts: (a) charger lost → sendMessage once, `lost_pending=1`, `tx_confirm=0`; (b) discharging + capacity ≤15% + `remind_at` expired → reminder, `remind_at=now+1800`; replug (Discharging→plugged) with `lost_pending=1` → closure alert, clear `lost_pending`/`low_warned`/`remind_at`. | Matches spec R2–R4. |
| 5 | Credentials: `TOKEN=$(source /home/glats/Work/don-bot/.env; echo $TELEGRAM_TOKEN)`? — NO: never eval/export. Implementation reads ONLY the token line one time via awk in a subshell assigned into a local var without echoing (strict: `TOKEN="$(awk -F= '/^TELEGRAM_TOKEN=/{print $2}' "$ENV_FILE")"` — value stays in-process; NEVER echo/log `$TOKEN`; compile URL at runtime with it). `CHAT_ID` read from `/etc/oneplus5-notify.conf` (`CHAT_ID=` key; parser names-only tolerant, user-comment lines preserved?). Keep parser strict+simple: exact `CHAT_ID=` line. | Spec R5; OS-level: file owned root:root 0644 (value is non-secret). |
| 6 | Delivery: `curl -m 10 -sS` POST `https://api.telegram.org/bot<token>/sendMessage` with `chat_id` + `text` (pagination-safe: one message ≪ limits; never call `getUpdates`). On failure → exit code path leaves pending flags untouched (degraded: journal `notify failed`, next cycle retries). Alert texts (Spanish, user-facing): `"⚠️ OnePlus 5: cargador desconectado — batería al ${capacity}%"`, `"🔋 OnePlus 5: batería baja — ${capacity}%"`, `"✅ OnePlus 5: cargador conectado de nuevo (batería al ${capacity}%)"`. | Spec R6; avoid duplicate sends via state flags (idempotent per state). |
| 7 | Units: service `Type=oneshot`, `User=glats Group=users NoNewPrivileges=yes`, `ExecStart=/usr/local/sbin/power-monitor.sh`, `After=NetworkManager.service network-online.target` + `Wants=network-online.target`, `TimeoutStartSec=30s`. Timer per decision 1 (AccuracySec=1s — lesson from the watchdog verify round). Pragmatic hardening only: read-only inputs, no capabilities needed. Matches the box's existing unit conventions. | Root unnecessary; over-hardening risks breaking the curl/Télégram path for no gain. |
| 8 | Test/validation hooks: `--simulate(status,capacity)` forces the SAMPLE values (real sysfs ignored for that invocation; state + notification paths fully exercised WITHOUT touching the charger); plus degraded test (CHAT_ID missing → journal-only). | Validates R2–R6 empirically at apply in minutes without battery risk. |
| 9 | Apply-time validation sequence: (1) syntax `sh -n` + `systemd-analyze verify`; (2) deploy via `ssh 'cat >'` piping (scp fails on this phone — known); (3) timer enable, watch first cycles sample/healthy; (4) `--simulate(Discharging,60)` ×2 cycles → 1 alert pending (delivery subject to CHAT_ID; degraded journal-only if unset); (5) swapped `--simulate(Charging,60)` → closure; (6) CHAT_ID absent → degraded assertions. Record evidence in tasks.md. `format-nix --check` + `nix flake check --no-build` at the end. Chat id: apply agent may KEY-PROBE `/home/glats/Work/don-bot/.env` and don-bot config for NON-SECRET chat keys (print key NAMES only, never values) — if found, populate `/etc/oneplus5-notify.conf`; else leave empty (degraded) and flag to orchestrator. | |
| 10 | Runbook outline: prereqs; install; notify config (CHAT_ID how to obtain — t.me/@username_to_id_bot / user's own id), thresholds (15%, 30min cooldown, 2-sample debounce), degraded mode explanation, manual single-cycle `--simulate` commands, drift correction, rollback, troubleshooting (`Unknown` status, Telegram 429, clock jumps with RTC — journal reading caveats). | |

## Flow

```
timer 60s → onehot sample → decide()
  prev=plugged, now=Discharging → tx_confirm=1 → (next sample same) → ADDRT alert(lost)
  discharging + cap<=15 + cooldown expired → reminder
  lost_pending=1 && now=plugged → closure alert
  delivery fail → flags stay, retry next cycle
```

## Risks / Trade-offs

- Two-sample debounce adds ≤60s to detection — accepted (false positive control).
- If Telegram is unreachable AND journal is where you look — degraded mode still leaves a journal trail; no SMS/local fallback (acceptable — operator uses Telegram daily).
- Battery capacity quirks (Unknown at 100%) unverified live — logged and treated as plugged; apply observes one full-charge sample if the phone is charging.

## Open Questions

None binding: chat id source decided (plain config; probe allowed; else degraded + orchestrator asks user).
