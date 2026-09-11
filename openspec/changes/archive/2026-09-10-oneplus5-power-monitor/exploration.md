# Exploration: oneplus5-power-monitor

## Current State

The OnePlus 5 is running postmarketOS edge with systemd 261, kernel 6.0.0 (`#4-postmarketOS-qcom-msm8998`), and aarch64. It is the always-on LAN DNS host at `172.16.0.12`; abrupt charger loss is not observable after the kernel dies, but the pre-death transition is observable.

Read-only SSH verification on 2026-09-10 found `/sys/class/power_supply/bq27411-0` (`type=Battery`) with `status=Charging`, `capacity=100`, `voltage_now=4366000`, `current_now=134000`, and `temp=309`; and `/sys/class/power_supply/pmi8998_charger` (`type=USB`) with `status=Charging`, `health=Good`, `voltage_now=4980468`, and `current_now=359150`. The battery exposes capacity, status, voltage/current, temperature, charge counters, and capacity level; the USB charger exposes status, health, online, USB type, input current limit, and charge-control attributes. This is a usable signal; no “missing charging signal” blocker was found. Kernel power-supply documentation (Linux docs 7.3.0-rc2, applicable interface semantics) defines status as Charging/Discharging/Full/etc., capacity as percent, voltage/current in microvolts/microamps, and temperature in tenths of a degree Celsius. The observed positive current values while Charging establish the current sign convention for this device at this sample, but do not justify using current as the primary state signal. `status` should be primary, with battery capacity as the low-power signal and charger `online`/status as corroboration. Unknown-at-100% behavior and live refresh latency were not empirically tested because that would require waiting for or manipulating charger state; they remain apply-time observations.

`link-grabber-bot.service` is `/etc/systemd/system/link-grabber-bot.service`, running `/home/glats/Work/don-bot/bin/link-grabber-bot` as `glats`, with `WorkingDirectory=/home/glats/Work/don-bot`, `Restart=always`, and `EnvironmentFile=/home/glats/Work/don-bot/.env`. A metadata-only read showed `.env` contains `TELEGRAM_TOKEN` and no displayed values. Repository/source search on the phone found no separate chat-id configuration reference in the bot tree; the target chat id therefore needs to be obtained from the operator’s existing bot interaction/configuration mechanism during proposal/design, without reading secrets. A second process can source the same EnvironmentFile at runtime (never copy or print its values), read a separately configured target chat id, and POST `chat_id` and URL-encoded `text` to `https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage` using curl. Telegram’s current Bot API documentation confirms HTTPS method URLs, POST form parameters, JSON `ok` responses, and 429 behavior; the FAQ advises no more than one message per second in a single chat. The monitor must not poll `getUpdates`, avoiding competition with the existing long-polling bot.

The historical journal has boot boundaries around the incidents (`-2` ended 2026-09-10 12:25, `-1` ended 17:18, current boot began 17:19), consistent with abrupt power-loss/restart rather than a clean shutdown. The read-only journal query showed no shutdown trace or dedicated charger-loss event around the incident windows. The existing `oneplus5-wifi-watchdog.timer` is a 60-second timer running a root oneshot `/usr/local/sbin/wifi-watchdog.sh`; its normal log is `rung=detect healthy`. The watchdog checks NetworkManager and `wlan0`, but does not monitor battery and cannot infer power loss after death. The phone has no suspend support per prior verified exploration, so suspend is not the explanation for disappearance.

## Affected Areas

- `/home/glats/.nixos/openspec/changes/oneplus5-power-monitor/` — exploration artifact now; proposal/design/spec/tasks may follow.
- `/home/glats/.nixos/docs/oneplus5-power-monitor/` — likely future versioned phone-side script and systemd timer/service artifacts, matching the existing external-device convention.
- `/home/glats/.nixos/docs/oneplus5-power-monitor.md` — likely future deployment, verification, credential-mechanism, alarm-state, and rollback runbook.
- `/home/glats/.nixos/docs/oneplus5-wifi-watchdog/wifi-watchdog.sh` and `/home/glats/.nixos/docs/oneplus5-wifi-watchdog/oneplus5-wifi-watchdog.service` — existing timer/oneshot and explicit service-convention precedent; do not couple power monitoring to Wi-Fi recovery.
- On-phone `/etc/systemd/system/link-grabber-bot.service`, `/home/glats/Work/don-bot/.env` (path/mechanism only), `/sys/class/power_supply/bq27411-0`, and `/sys/class/power_supply/pmi8998_charger` — runtime integration points.
- No Nix or `pkgs/nixos-scripts` changes are indicated; this is device-internal pmOS tooling and the repository Go-only operational-CLI rule does not prohibit it.

## Approaches

1. **Shell monitor plus systemd timer/oneshot on the phone**
   - **Pros:** Direct sysfs reads, simple persistent state and cooldowns, matches `/etc/systemd/system/` and existing `User=`/`Group=`/`Restart=` conventions, easy to deploy as versioned `docs/` artifacts, and can source bot credentials only at runtime.
   - **Cons:** Polling latency depends on timer cadence; state-file corruption/permissions and Telegram curl error handling require care; charger refresh behavior needs apply-time confirmation.
   - **Effort:** **Low–Med**.

2. **udev/power-supply event-driven trigger with a small stateful notifier**
   - **Pros:** Can react closer to the kernel power-supply change than a coarse timer and reduce idle polling.
   - **Cons:** Still needs a long-lived/stateful process or event-to-service bridge, event semantics and duplicate events vary by driver, and it does not improve post-death detectability.
   - **Effort:** **Med**.

3. **Extend the existing Wi-Fi watchdog**
   - **Pros:** Reuses one timer and one deployment path.
   - **Cons:** Mixes unrelated recovery and notification responsibilities, makes battery alarms dependent on Wi-Fi watchdog cadence/failures, and complicates rollback and state semantics.
   - **Effort:** **Low–Med**, but poor isolation.

4. **Modify link-grabber-bot to own power notifications**
   - **Pros:** Reuses the bot’s already-loaded token and Telegram client/configuration directly.
   - **Cons:** Couples infrastructure health to bot releases, requires touching an external source tree not managed by this repo, risks exposing or broadening bot behavior, and still needs a battery trigger/state machine.
   - **Effort:** **Med–High**.

## Recommendation

Use Approach 1: a dedicated root-owned shell monitor invoked by a 30–60 second systemd timer, with a separate state file and no power actions. Read battery `status` and `capacity`; treat `Discharging` after a prior charging/plugged state as charger-loss, emit one immediate Telegram notification, and persist the alarm state. Emit a reminder at `capacity <= 15%` with a cooldown (for example, once per configured interval), emit a plugged-back closure when status returns to Charging/Full, and reset the relevant state only after successful notification or a clearly defined retry policy. Use the charger object’s `status`/`online` as corroboration, not as the sole signal. Source `/home/glats/Work/don-bot/.env` at runtime without printing it; keep target chat id in a separately permissioned, non-secret configuration or derive it through an explicitly documented existing mechanism. Use curl form POST to Telegram with bounded timeout, redact URLs/errors in journald, and never call `getUpdates`.

Do not attempt to detect actual death locally. The monitor’s contract is pre-death warning only; an external liveness monitor would be a separate future change. Do not test by unplugging the charger during apply unless the operator explicitly authorizes that device mutation. At apply time, verify status refresh by harmless repeated reads while observing a naturally occurring or operator-approved charger transition, and verify whether status ever reports `Unknown` at full charge.

## Risks

- **Actual death remains undetectable:** abrupt journal termination means no final Telegram alert is possible after battery exhaustion; mitigation is immediate Discharging notification and conservative low-capacity reminders.
- **Driver semantics may vary:** only one Charging sample was observed; current sign and Unknown-at-100% behavior were not fully characterized. Use status/capacity, log raw non-secret measurements, and validate transitions during apply.
- **False positives/transients:** debounce a single sample or require two consecutive Discharging reads, while preserving a short timer cadence; do not wait so long that the operator misses the recharge window.
- **Credential exposure:** reading or embedding `.env` values would violate security policy. Runtime sourcing, restrictive unit/script permissions, and no `set -x`/token logging are mandatory.
- **Chat-id ambiguity:** the service metadata identifies only `TELEGRAM_TOKEN`; no chat-id mechanism was verified from the available bot tree. Proposal must make chat-id acquisition/configuration explicit without retrieving secret values.
- **Telegram/API/network failure:** Wi-Fi or DNS may fail at the same time as charger loss. Retry with bounded backoff and journal failure locally, but do not spam; Telegram’s per-chat one-message-per-second guidance is comfortably met by the proposed alarms.
- **Concurrent bot use:** a second sender is safe in principle, but it must not use `getUpdates`; sending only via `sendMessage` avoids long-polling offset interference.
- **No shutdown action:** the monitor must never reboot, suspend, power off, or otherwise alter the DNS box’s behavior on battery.

## Ready for Proposal

**Yes — with one explicit design input required.** Tell the orchestrator/user that the phone exposes a reliable-enough `bq27411-0` battery `status`/`capacity` interface and `pmi8998_charger` USB status, so charger-loss and low-battery warnings are feasible, while actual abrupt death is fundamentally undetectable. Recommend a dedicated shell timer/oneshot with immediate one-shot Discharging alert, cooldowned `<=15%` reminders, plugged-back closure, runtime credential sourcing from `/home/glats/Work/don-bot/.env`, and no power actions. Ask the user/orchestrator to specify or approve the non-secret target-chat-id mechanism because the live service exposes `TELEGRAM_TOKEN` but no verified chat-id configuration path. Also state that live charger-transition refresh and Unknown-at-100% behavior remain apply-time verification items, not proposal blockers.
