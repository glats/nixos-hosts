# OnePlus 5 Power Monitor

This monitor is a versioned, phone-local alerting tool for the OnePlus 5. It reads battery and charger sysfs state, persists its own state file, writes its own journal entries, and sends Telegram alerts. It performs no power actions and does not modify AdGuard Home, the Wi-Fi watchdog, NetworkManager, link-grabber-bot, or any other service.

Canonical artifacts live in `docs/oneplus5-power-monitor/`: `power-monitor.sh`, `oneplus5-power-monitor.service`, `oneplus5-power-monitor.timer`. Repository copies are the source of truth; the phone must match them byte-for-byte.

## Prerequisites

The phone must be reachable as `glats@172.16.0.12` using `~/.ssh/oneplus5`, with passwordless sudo. It must provide systemd, `curl`, `awk`, `mktemp`, and readable `/sys/class/power_supply/bq27411-0` and `/sys/class/power_supply/pmi8998_charger` entries. The link-grabber-bot `EnvironmentFile` at `/home/glats/Work/don-bot/.env` must exist and stay unreadable in output: only the `TELEGRAM_TOKEN` key name is ever referenced, never its value.

Note: `scp` to this phone fails ("Connection closed"). Always deploy by piping over ssh: `ssh ... 'cat > /tmp/file' < localfile`, then `sudo install`.

## Deploy or correct drift

From the repository root, pipe the three artifacts to the phone, install them with root ownership, create the state directory, verify, and enable the timer. Never start the service manually; the timer controls production runs.

```sh
SSH="ssh -i ~/.ssh/oneplus5 glats@172.16.0.12"
$SSH 'cat > /tmp/power-monitor.sh'          < docs/oneplus5-power-monitor/power-monitor.sh
$SSH 'cat > /tmp/oneplus5-power-monitor.service' < docs/oneplus5-power-monitor/oneplus5-power-monitor.service
$SSH 'cat > /tmp/oneplus5-power-monitor.timer'   < docs/oneplus5-power-monitor/oneplus5-power-monitor.timer
$SSH 'sudo install -o root -g root -m 0755 /tmp/power-monitor.sh /usr/local/sbin/power-monitor.sh &&
      sudo install -o root -g root -m 0644 /tmp/oneplus5-power-monitor.service /tmp/oneplus5-power-monitor.timer /etc/systemd/system/ &&
      sudo install -d -o glats -g users -m 0755 /var/lib/power-monitor &&
      sudo systemd-analyze verify /etc/systemd/system/oneplus5-power-monitor.service /etc/systemd/system/oneplus5-power-monitor.timer &&
      sudo systemctl daemon-reload && sudo systemctl enable --now oneplus5-power-monitor.timer'
```

Check `sha256sum` of repo and phone copies (script and both units) and correct drift by repeating the pipe/install. Confirm `systemctl is-active oneplus5-power-monitor.timer` and inspect cycles with `journalctl -u oneplus5-power-monitor.service`.

## Notify configuration and chat id

The monitor reads the target chat id from `/etc/oneplus5-notify.conf` (root:root 0644), strict format: one line `CHAT_ID=<id>`. The chat id is non-secret. To obtain yours, message `@username_to_id_bot` (or any id-echo bot) in Telegram from the account that should receive alerts, and use the numeric id it reports. The bot token is sourced at runtime from the bot's `EnvironmentFile`; it is never copied, printed, or logged anywhere.

If `CHAT_ID` is empty the monitor runs in degraded mode: alert conditions are evaluated and preserved in state, a `degraded:` entry is journaled instead of a Telegram send, and the alert is delivered on a later cycle once the chat id is populated — with no duplicate sends.

## Thresholds and state machine

- Timer cadence: 60 seconds (`OnBootSec=60s`, `OnUnitActiveSec=60s`, `AccuracySec=1s`).
- Plugged set: `Charging`, `Full`, `Not charging`; `Unknown` is treated as plugged and logged once per episode (quirk guard).
- Debounce: the first `Discharging` sample after a plugged state only arms `tx_confirm`; a second consecutive `Discharging` fires exactly one charger-lost alert (`lost_pending=1`). Worst-case detection ≈ 2 minutes.
- Low-battery reminder: while discharging at capacity ≤ 15%, one reminder per 30-minute cooldown (`remind_at`).
- Replug closure: when the status returns to plugged with `lost_pending=1`, one closure alert is sent and the warned flags are cleared.
- On any delivery failure (missing credentials, curl error, non-200 Telegram response) the pending flags are preserved and the next cycle retries.

State lives in `/var/lib/power-monitor/state` (glats:users, 0640, atomically replaced). Fields: `version`, `prev_status`, `tx_confirm`, `lost_pending`, `low_warned`, `remind_at`, `last_capacity`.

## Manual single-cycle testing

Run a forced sample without touching the charger; sysfs reads are skipped for the battery, but the state machine, state file, and notification path are fully real:

```sh
/usr/local/sbin/power-monitor.sh --simulate Discharging,60   # or: --simulate=Discharging,60
/usr/local/sbin/power-monitor.sh --simulate Discharging,60   # second sample fires the alert
/usr/local/sbin/power-monitor.sh --simulate Charging,80      # closure alert, flags cleared
/usr/local/sbin/power-monitor.sh --simulate Unknown,50       # quirk guard, no alert
```

Inspect each step with `journalctl -u oneplus5-power-monitor.service -n 20 --no-pager` and `cat /var/lib/power-monitor/state`. After testing, run one more real (non-simulated) sample or wait for the timer so `prev_status` reflects reality.

## Rollback

```sh
ssh -i ~/.ssh/oneplus5 glats@172.16.0.12 'sudo systemctl disable --now oneplus5-power-monitor.timer &&
  sudo rm -f /etc/systemd/system/oneplus5-power-monitor.service /etc/systemd/system/oneplus5-power-monitor.timer \
    /usr/local/sbin/power-monitor.sh /etc/oneplus5-notify.conf &&
  sudo rm -rf /var/lib/power-monitor && sudo systemctl daemon-reload'
```

This removes only the monitor's own artifacts: timer, service, script, state directory, and notify config. Nothing else is touched.

## Troubleshooting

- **`status=Unknown` at full charge:** treated as plugged and logged once per episode. No alert fires. If it persists while the charger is physically disconnected, check `cat /sys/class/power_supply/bq27411-0/status` directly and report the driver behavior.
- **Telegram 429 or unreachable:** the send fails, a `degraded: sendMessage failed` entry is journaled, and pending flags are preserved; the next cycle retries. The monitor sends at most a handful of messages per hour, far below Telegram's per-chat rate guidance. Never add `getUpdates` calls — they would steal the link-grabber-bot's poll session.
- **Clock jumps / RTC:** the phone's RTC and journal timestamps can jump after abrupt power loss. When reading `journalctl -u oneplus5-power-monitor.service`, rely on boot boundaries (`--list-boots`, `-b -1`) and entry sequence rather than wall-clock times around a death event.
- **No alert after a real charger pull:** check the state file (`tx_confirm`, `lost_pending`), the journal for `degraded:` entries, and that `/etc/oneplus5-notify.conf` contains a populated `CHAT_ID=`.
