# Tasks: oneplus5-power-monitor

All tasks are `[AGENT]`-executable (SSH + sudo + repo access). No operator tasks except the optional chat id confirmation (see cross-cutting).

## Phase 1 — Repository artifacts

- [x] 1.1 `[AGENT]` Write `docs/oneplus5-power-monitor/power-monitor.sh`: ≤120 lines, `set -u` (no `set -e`), English comments (user-facing alert texts in Spanish per design D6), functions: `sample()` (sysfs reads, `--simulate(status,capacity)` override), `decide()` (state machine per design D3–D4: plugged set = Charging|Full|Not charging; Unknown = plugged + log; two-sample debounce via `tx_confirm`; charger-lost alert once; ≤15% reminder with 1800s cooldown via `remind_at`; replug closure), `notify()` (curl -m 10 sendMessage, token read runtime-only via awk single-key extraction — never echoed/logged; on failure leave pending flags). State helpers per D2 (atomic write, depth: /var/lib/power-monitor). Acceptance: `sh -n` passes; no token value printed anywhere; grep confirms no `getUpdates`.
  - **Evidence (2026-09-10):** 119 lines (`wc -l`), `sh -n` → OK, `grep -c getUpdates` → 0. Token read via `awk -F= '/^TELEGRAM_TOKEN=/{print $2; exit}'` into a local var; curl gets it through a `mktemp` config file (`-K`), so the token never appears in ps args, journal, or state. Spanish alert texts exact per D6. Deviation: unit files named `oneplus5-power-monitor.{service,timer}` (repo convention from wifi-watchdog + operator enable command) instead of `power-monitor.{service,timer}`.
- [x] 1.2 `[AGENT]` Write `docs/oneplus5-power-monitor/oneplus5-power-monitor.service` (Type=oneshot, User=glats Group=users NoNewPrivileges=yes, After=NetworkManager.service network-online.target, Wants=network-online.target, TimeoutStartSec=30s) and `docs/oneplus5-power-monitor/oneplus5-power-monitor.timer` (OnBootSec=60s, OnUnitActiveSec=60s, AccuracySec=1s, RandomizedDelaySec=0, WantedBy=timers.target). Acceptance: design D1/D7 values exact.
  - **Evidence:** both files written with exactly the D1/D7 values; `systemd-analyze verify` on the phone passed (only pre-existing warnings for unrelated units q6voiced/avahi).
- [x] 1.3 `[AGENT]` Write `docs/oneplus5-power-monitor.md` runbook per design D10 (prereqs, install, CHAT_ID obtention, thresholds: 15% / 30min cooldown / 2-sample debounce, degraded mode, manual single-cycle `--simulate` commands, drift correction, rollback, troubleshooting: Unknown status, Telegram 429, RTC clock-jump journal reading).
  - **Evidence:** runbook written covering every D10 element, including the phone-specific "scp fails — pipe over ssh stdin" deployment method and rollback that removes exactly the monitor's own artifacts.

## Phase 2 — Deploy on phone

- [x] 2.1 `[AGENT]` Pre-state check (read-only): no existing /usr/local/sbin/power-monitor.sh, no monitor units, jq+curl present, /sys/class/power_supply/bq27411-0 readable by glats, .env owner glats.
  - **Evidence (2026-09-10):** all seven target paths absent; no `*power-monitor*` units registered; jq/curl/awk/mktemp present; `bq27411-0` read as glats → `Charging` / `100`; `.env` = `glats:glats 644`; systemd 261.
- [x] 2.2 `[AGENT]` Deploy via ssh stdin piping (scp fails on this phone — known): script → /tmp → `install -m 755 root:root /usr/local/sbin/power-monitor.sh`; units → /etc/systemd/system/ (644) → `systemd-analyze verify` → daemon-reload → enable --now TIMER (never start service manually). Verify: timer active, first two cycles sampled + logged, state file created with correct ownership.
  - **Evidence:** 3 files piped `ssh 'cat > /tmp/...'`, installed 755 root:root (script) + 644 root:root (units); `install -d -o glats -g users -m 0755 /var/lib/power-monitor`; verify OK; `enable --now oneplus5-power-monitor.timer` → symlink created. Two real cycles at 22:39:56 and 22:40:57 both logged `sample: battery=Charging 100% charger=Charging`; state file `glats:users 0640` with `prev_status=Charging last_capacity=100`.
- [x] 2.3 `[AGENT]` Notify config: KEY-PROBE (names only, NEVER values) /home/glats/Work/don-bot/.env + don-bot config for a non-secret CHAT id key; if found populate `/etc/oneplus5-notify.conf` (root:root 0644, `CHAT_ID=...`), else create it with empty `CHAT_ID=` and note degraded mode to report. Acceptance: file exists; no secret values printed anywhere in the session output.
  - **Evidence:** `.env` key NAMES probed → `TELEGRAM_TOKEN PORT LOG_COLOR LOG_LEVEL ORIG_URL_AUDIO CHROME_EXE PPROF_ENABLED PPROF_PORT INSTAGRAM_DOWNLOAD_TIMEOUT INSTAGRAM_AUTH_ENABLED` — no CHAT key; `env.dist` identical; tree-wide grep for `*CHAT*` identifiers → none. **Chat id NOT found → degraded mode.** `/etc/oneplus5-notify.conf` created root:root 0644 with empty `CHAT_ID=`. No secret value was read or printed at any point.

## Phase 3 — Simulated validation (no charger manipulation)

- [x] 3.1 `[AGENT]` Alert-lifecycle test with `--simulate`: run `--simulate(Discharging,60)` ×2 sequential invocations → after 2nd: charger-lost alert pending/sent (subject to CHAT_ID: real send if set, degraded journal-only if empty) + state `lost_pending=1`; a third Discharging sample MUST NOT re-alert; then `--simulate(Charging,80)` → closure alert + flags cleared. Record evidence in tasks.md.
  - **Evidence (timer stopped during sims, all runs via `systemd-run --collect` as glats:users so entries land in the journal; CHAT_ID empty ⇒ degraded journal-only):**
    - SIM 1 `Discharging,60`: journal `plugged->Discharging: first sample, awaiting confirmation`; state `tx_confirm=1 lost_pending=0` — debounce arm, NO alert. ✓
    - SIM 2 `Discharging,60`: journal `degraded: token or CHAT_ID missing; alert stays pending: ⚠️ OnePlus 5: cargador desconectado — batería al 60%`; state `tx_confirm=1 lost_pending=0` — alert DUE after 2nd sample, delivery degraded, flags preserved for retry (R6). ✓
    - SIM 3 `Discharging,60`: journal shows the same single pending condition retried (R6); no new alert condition created; nothing sent. ✓ (no duplicate delivery possible in any mode: once delivered, `lost_pending=1` blocks re-alert — proven in SIM 5b.)
    - SIM 4 `Charging,80`: debounce reset (`tx_confirm=0`); no closure fired because the lost alert was never delivered (`lost_pending=0`) — pending stale alert correctly dropped on replug. ✓
    - Seeded `lost_pending=1` (models a delivered alert), SIM 5a `Discharging,50` → arm; SIM 5b `Discharging,50` → **journal shows NO alert/degraded entry** (R2 re-alert suppression proven empirically), `lost_pending=1` intact. ✓
    - SIM 6 `Charging,80` with `lost_pending=1`: closure path fires → `degraded: ... ✅ OnePlus 5: cargador conectado de nuevo (batería al 80%)`; flags PRESERVED because delivery failed (R6); flag-clearing on success verified by code path (`notify` success ⇒ `lost_pending=0 low_warned=0 remind_at=0`) — real delivery requires operator CHAT_ID. ✓
- [x] 3.2 `[AGENT]` Degraded test: temporarily point config away or empty CHAT_ID backup → due alert leaves state preserved + journal degraded entry; restore. Also `--simulate(Unknown,50)` → treated as plugged, no alert (quirk guard). Record evidence.
  - **Evidence:**
    - SIM 7a `Discharging,10` with `remind_at=0`: reminder DUE → `degraded: ... 🔋 OnePlus 5: batería baja — 10%`; `remind_at` NOT advanced (retry next cycle). SIM 7b with `remind_at=now+1800`: journal shows sample line only — cooldown suppression proven (R3). ✓
    - SIM 8a `Unknown,50` from clean plugged state: `status Unknown; treated as plugged (quirk guard)`, no alert; SIM 8b second `Unknown,50`: quirk log NOT repeated (one-time logging), no alert, `tx_confirm=0 lost_pending=0`. ✓
    - SIM 9 with `/etc/oneplus5-notify.conf` temporarily renamed away: due alert → `degraded: token or CHAT_ID missing; alert stays pending`, state preserved (`tx_confirm=1 lost_pending=0`); config restored root:root 0644. ✓
- [x] 3.3 `[AGENT]` Anti-drift: repo↔phone byte identity (script + units, sha256); timer still cycling; watchdog/adguard untouched (`systemctl is-active` sweep).
  - **Evidence:** sha256 repo == phone for all three artifacts: script `0826abaf…b66a`, service `33e7377e…2ff6`, timer `2e438e72…00d1`. State re-anchored to real sysfs (`prev_status=Charging last_capacity=100`), timer `active`. Sweep: `adguardhome active`, `oneplus5-wifi-watchdog.timer active`, `link-grabber-bot active`, `NetworkManager active`.

## Phase 4 — Gates and close-out

- [x] 4.1 `[AGENT]` Update tasks.md checkboxes + evidence; Engram save apply-progress (topic_key sdd/oneplus5-power-monitor/apply-progress).
  - **Evidence:** this file updated inline; Engram `mem_save` with topic_key `sdd/oneplus5-power-monitor/apply-progress` recorded 2026-09-10.
- [x] 4.2 `[AGENT]` Gates: `format-nix --check` (0 reformats) + `nix flake check --no-build` (exit 0). Do NOT stage or commit (archive phase handles git).
  - **Evidence:** `format-nix --check` → exit 0 ("Formatting complete", no changes); `nix flake check --no-build` → exit 0 ("all checks passed"). `git status` — all new files untracked, staged area empty (`git diff --cached` empty).

## Cross-cutting

- NEVER read/print secret values (token); KEY-PROBES print KEY NAMES only. — **Held:** only key names probed; token extracted by the script at runtime into a curl `-K` config fd; no value in session output, journal, state, or artifacts.
- NEVER call Telegram getUpdates; never send test messages to real chats unless CHAT_ID was legitimately populated (if so, ONE test message max, low-urgency wording). — **Held:** no `getUpdates` anywhere (grep-verified); zero Telegram sends performed (CHAT_ID empty → degraded journal-only).
- No power actions; no touching link-grabber-bot code/process; independent operation guaranteed (spec R7). — **Held:** script contains no power/process commands; bot untouched; adjacent services all active post-deploy.
- Commit/push = archive phase (orchestrator, with user OK). — **Held:** nothing staged or committed.

## Verification mapping

1.1–1.3 → spec R5, R8, R2–R4 semantics; 2.1–2.3 → R5 + R8; 3.1–3.3 → R2–R6 + R7; 4.2 → R10. R9 rollback documented in 1.3 runbook + validated logically (remove list exact).

## Apply outcome

**APPLY COMPLETE (delivery degraded pending operator chat id).** Monitor deployed, timer cycling, full state machine validated via `--simulate` (debounce, one-shot lost alert, R2 suppression, R3 cooldown, closure path, R6 degraded/preserve, Unknown quirk guard). The one remaining input is the operator's Telegram chat id for `/etc/oneplus5-notify.conf` — until then alerts are journal-only with state preserved and automatic retry (by design, R6).
