# Exploration: oneplus5-wifi-watchdog

## Current State

The OnePlus 5 (`172.16.0.12`, postmarketOS edge, systemd 261, aarch64) is the always-on LAN DNS server (AdGuard Home) for the home network. Its only uplink is Wi-Fi over `wlan0` (NM profile `JICS`, WPA-PSK, MAC pinned `EE:03:CD:B0:51:74`). On 2026-09-09 22:53 a beacon loss → WPA rekey during reassociation triggered a WCN3990 firmware crash (`ath10k_snoc 18800000.wifi: firmware crashed!`, fw ver 1.0.0.483). The driver's own firmware auto-recovery completed at 22:53:48 (`device successfully recovered`), but the scan engine stayed broken afterward — a 9-minute `CTRL-EVENT-SCAN-FAILED ret=-100` loop that the phone never self-healed. The user had to force-reboot (~90s to back serving). The whole LAN lost its DNS server for the outage window. There is **no auto-recovery today**: `ath10k-crash-watch.service` only saves devcoredumps, it never restores the link.

**Critical verdict — module vs builtin (answers the top investigation question):**

`ath10k_snoc` is a **LOADABLE MODULE**, not built-in:

- `lsmod` shows `ath10k_snoc` (refcount 0) with `ath10k_core` (refcount 1, used by ath10k_snoc) and `ath`/`mac80211`/`cfg80211` beneath it. `qmi_helpers`/`qcom_common` are shared deps.
- `/lib/modules/6.0.0/kernel/drivers/net/wireless/ath/ath10k/` contains `ath10k_snoc.ko.xz` and `ath10k_core.ko.xz` (no `/proc/config.gz` on this kernel, but the `.ko.xz` files are conclusive).
- `modinfo ath10k_snoc` → `depends: ath10k_core,qmi_helpers,qcom_common`.
- The device binds on the platform bus: `/sys/bus/platform/drivers/ath10k_snoc/` has writable `bind`/`unbind`, device node `18800000.wifi` (`driver -> ath10k_snoc`, `modalias = of:NwifiT(null)Cqcom,wcn3990-wifi`).

Consequence: **both** recovery rungs are mechanically available — `modprobe -r ath10k_snoc && modprobe ath10k_snoc` (module reload) and `echo 18800000.wifi > .../ath10k_snoc/{unbind,bind}` (platform driver rebind). The historical blocker for unbind/bind on WCN3990 — the IRQ-type mismatch (`irq: type mismatch, failed to map hwirq-446 … IRQ index 0 not found`) fixed by upstream commit `1ee6c5abebd3` "ath10k: do not enforce interrupt trigger type" — **is already in this kernel**: the fix landed in 5.19 stable (Patchew `5.19 0315/1157`, Aug 2022), and the phone runs 6.0.0. So rebind should re-probe cleanly. Reboot remains the guaranteed hard reset.

**Root cause is a known, chronic WCN3990-on-mainline issue (MCP-verified, not a one-off):**

- The msm8998-mainline tree (JamiKettunen, the source of this device's mainline support) documents Wi-Fi via `ath10k_snoc` as "somewhat unstable; FW keeps crashing without diag-router and on any type of network disconnect", and "with `ath10k_snoc` probed the shutdown is additionally hung by some amount due to the remoteproc refusing to shutdown cleanly".
- The post-recovery scan-hang matches an upstream ath10k bug fixed *after* this kernel: "[PATCH] wifi: ath10k: Trigger STA disconnect after reconfig complete on hardware restart" (May 2023, `Fixes: 2c3fc50591ff`) — "on WCN3990, the station disconnect after hardware recovery is not working as expected". The 6.0.0 kernel predates the fix, so after firmware recovery the STA is left in a state where scans fail and the phone cannot reassociate. The recovery ladder below exists precisely because the in-driver recovery is insufficient on this kernel.
- A separate 2020 report (aarch64-laptops#51) confirms the failure mode: firmware crash → `ieee80211_restart_work called with hardware scan in progress` warning loop → connection unusable and shutdown/reboot hangs on network daemons.

## Affected Areas

- `openspec/changes/oneplus5-wifi-watchdog/` — this change's artifacts.
- `docs/oneplus5-wifi-watchdog/` (proposed) — versioned device artifacts (watchdog script + systemd unit + timer), matching the existing `docs/oneplus5-adguard-dns/` convention (that change ships `adguardhome.service` + `AdGuardHome.yaml` under a `docs/<change>/` dir + a `docs/<change>.md` runbook).
- `docs/oneplus5-wifi-watchdog.md` (proposed) — operational runbook (deploy, verify, manual-trigger, rollback).
- On-phone (existing, read-only during this phase): `/etc/systemd/system/ath10k-crash-watch.service`, `/usr/local/sbin/{scan,save}-devcoredump.sh` (crash-dump pipeline to reuse signatures from), `/etc/systemd/system/{scan-devcoredump.timer,scan-devcoredump.service,wol-rog.timer}` (the established timer+oneshot idiom this change copies).
- `pkgs/nixos-scripts/` — **NOT touched** (see Go-vs-shell in Recommendation). No Nix build/eval impact: the phone is an external postmarketOS device, not a `flake.nix` host, so `nix flake check --no-build` is unaffected (same reasoning as the adguard change).

## Approaches

1. **Shell script + systemd timer on the phone, artifacts versioned in `docs/oneplus5-wifi-watchdog/`** (recommended)
   - A `wifi-watchdog.timer` (e.g. every 60s) fires a `oneshot` `wifi-watchdog.service` running `/usr/local/sbin/wifi-watchdog.sh`. The script (a) checks health (`iw dev wlan0 link` / `nmcli -t -f GENERAL.STATE device show wlan0`), (b) detects a *recent* crash via the same journal signature `ath10k-crash-watch` already uses (`firmware crashed!` / `qcom-q6v5-mss … fatal error received`), and (c) walks a recovery ladder — soft NM reconnect (no recent crash) → driver rebind (recent crash) → `systemctl reboot` (ladder exhausted) — tracking rung state in a small state file under `/var/lib/wifi-watchdog/`.
   - Pros: matches every existing convention on this device (the phone's crash pipeline is already shell in `/usr/local/sbin/`; the timer+oneshot shape is already used by `scan-devcoredump.timer` and `wol-rog.timer`); reuses the crash signature instead of duplicating it; naturally rate-limited; trivially versioned/deployed the same way the adguard artifacts were.
   - Cons: another shell artifact on the phone; the script is stateful (ladder position) so it needs a tiny state file and careful idempotency.
   - Effort: **Low–Medium**.

2. **Go helper in `pkgs/nixos-scripts` shipped to the phone**
   - A `cmd/oneplus5-wifi-watchdog/main.go` binary, Nix-built, that the phone's timer invokes.
   - Pros: satisfies the repo's "operational scripts are Go, never bash" rule in the most literal reading; compiled + unit-tested.
   - Cons: the phone is **not** a NixOS host — the flake's `pkgs/nixos-scripts` binaries land in `/run/current-system/sw/bin/` on rog/t14/mact2, not on the phone; there is no deployment path from the flake to the phone today (the adguard artifacts deploy via `scp`, not `nixos-build`); cross-compiling/scp-ing a static aarch64 binary for a 60-line recovery ladder is disproportionate (YAGNI); the watchdog is device-internal, not operator-facing.
   - Effort: **Medium** (and mostly plumbing that buys nothing operationally).

3. **systemd-native only (no script): timer + OnFailure hooks + extend `ath10k-crash-watch`**
   - A `.timer` for a `nmcli` health `oneshot`, plus `OnFailure=`/`OnUnitActiveSec=` chains, with recovery expressed purely as `ExecStart=` lines; optionally adding an `ExecStopPost=`/extra line to `ath10k-crash-watch` to kick a rebind.
   - Pros: zero custom code; idiomatic systemd; leverages `ath10k-crash-watch` directly.
   - Cons: the recovery *ladder* (soft reconnect → rebind → reboot, with per-rung verification and escalation) does not express cleanly as static `ExecStart=` lines — you need branching, a "which rung did I last try" memory, and per-rung timing; overloading `ath10k-crash-watch` (a crash-*dump* collector) with recovery responsibilities muddies its single purpose; the result is either a fragile chain of systemd units or effectively a shell one-liner hidden in `ExecStart=` anyway.
   - Effort: **Medium** (high unit-file complexity, low clarity).

4. **NetworkManager dispatcher hook (secondary trigger, not a standalone solution)**
   - A `/etc/NetworkManager/dispatcher.d/` script reacting to `down`/`connectivity-change` events to kick a recovery attempt.
   - Pros: event-driven, fires the instant the link drops (before the timer polls).
   - Cons: a dispatcher hook fires on *every* disconnect, including intentional ones and transient AP blips — it cannot distinguish a zombi from a normal re-association; it would still need the same ladder logic, so it only *augments* (not replaces) Approach 1 as a faster trigger. Not recommended as the primary mechanism; note it as an optional accelerator.
   - Effort: **Low** (as an add-on).

## Recommendation

**Approach 1 — a versioned shell script + systemd timer on the phone**, with a three-rung recovery ladder, shipped as device artifacts under `docs/oneplus5-wifi-watchdog/` plus a runbook (exactly the adguard change's artifact pattern).

Rationale on the recovery ladder (from verified evidence):

- **Rung 0 — soft NM reconnect** (`nmcli device disconnect wlan0 && nmcli device connect wlan0`, or `nmcli connection up JICS`): correct and cheap when the link dropped without a firmware crash. `nmcli device` has **no `reconnect` subcommand** (verified from `nmcli device --help`: subcommands are `status/show/set/connect/reapply/modify/disconnect/delete/monitor/wifi/llpd`), so `nmcli device connect wlan0` / `nmcli connection up JICS` are the correct primitives.
- **Rung 1 — driver rebind** (`echo 18800000.wifi > /sys/bus/platform/drivers/ath10k_snoc/unbind` then `bind`, or `modprobe -r ath10k_snoc && modprobe ath10k_snoc`): the real "soft reset". Because the scan-hang is the missing post-reconfig STA-disconnect fix in 6.0.0, the in-driver firmware recovery alone will not fix scanning — a full driver teardown/re-probe is required to rebuild the wiphy. The IRQ rebind bug that historically broke this is fixed in 6.0.0, so rebind should re-probe cleanly; the script must wait for `wlan0` to reappear and then let NM re-activate (autoconnect is already `yes`). Prefer unbind/bind over rmmod: it is the documented recovery for this device class (the upstream patch's own test case) and avoids touching module refcounts; rmmod additionally risks the "remoteproc refuses clean shutdown" hang.
- **Rung 2 — `systemctl reboot`**: the guaranteed hard reset (~90s boot-to-serving, verified). Keep it as the terminal rung with a max-escalation guard (e.g. never reboot more than once per N minutes, and back off if reboots don't stabilize) so a crash-loop doesn't turn into a reboot-loop.

Crash-signature reuse vs duplication: keep `ath10k-crash-watch` exactly as-is (its single job is dump collection) and have the watchdog read the **same journal signature** for the "was there a recent crash" decision — this reuses the detection string without coupling the two services' lifecycles. A recent crash means skip rung 0 and go straight to rung 1, because soft reconnect is known-broken after a firmware crash.

**Go vs shell (the policy question).** The AGENTS.md Go-only rule governs *this repo's operational scripts* (`pkgs/nixos-scripts/`, operator-facing CLIs shipped to NixOS hosts). The watchdog is **device-internal**: it runs on the phone, an external postmarketOS device that the flake neither builds nor provisions, and its recovery pipeline there is already shell (`scan-devcoredump.sh`, `save-devcoredump.sh`, `ath10k-crash-watch.service`). There is no operator-facing command to wrap — the deploy is a one-time `scp` + `install`, already documented in the adguard runbook pattern. Therefore **device-internal shell is acceptable and correct**; a Go binary is unwarranted (YAGNI). If a future operator-facing need appears (e.g. a `oneplus5-wifi-recover` command on rog to trigger recovery over SSH), that would be a Go binary under `pkgs/nixos-scripts/cmd/` — out of scope now.

**One empirical unknown (flag for apply, not a proposal blocker):** whether unbind/bind actually restores scanning on *this* firmware (1.0.0.483 / HL1.0) as the research suggests it does on HL2.0/HL3.2 hardware, or whether reboot is the only effective rung. The ladder handles both: rung 1 is attempted, verified, and escalates to rung 2 if it fails — so the design is correct regardless of the answer, but apply should run a single controlled `unbind`/`bind` test (a device mutation, out of scope for this read-only phase) to confirm rung 1 before the ladder is locked in.

## Risks

- **Rebind/rmmod hang**: JamiKettunen's note ("remoteproc refusing to shutdown cleanly" on shutdown) is a risk that a driver teardown under load may hang; mitigation is a `TimeoutStartSec`/`timeout` around rung 1 and an explicit reboot fallback.
- **Reboot-loop on persistent crash-loop**: the incident window showed *three* firmware crashes in ~15s (guids d1adea8b, 2b0cd12c, 8c8e9b4f); a naive "crash → reboot" policy could thrash. Mitigation: max-escalation guard + exponential backoff in the state file.
- **NetworkManager race on rebind**: unbind removes `wlan0`; NM may briefly mark the device unmanaged. The script must poll for `wlan0` reappearance and issue `nmcli connection up JICS` (or rely on autoconnect) rather than assume the interface is immediately ready.
- **DHCP lease / address**: reconnection is DHCP (`ipv4.method=auto`); the runbook's DHCP reservation for `172.16.0.12` (from the adguard change) keeps the DNS bind stable across reconnects — no watchdog change, but the address-gate assumption must keep holding.
- **Detection latency**: a 60s timer means up to 60s of DNS outage before recovery starts; acceptable for a home LAN but worth stating. A dispatcher hook (Approach 4) could close that gap later if it matters.
- **devcoredump disk pressure**: the crash produced a 116 MB dump; `save-devcoredump.sh` already caps storage (MAX_ATH10K=3, MAX_ELF=1, MAX_SIZE_MB=500), but a crash-loop generating dumps while the watchdog reboots is worth a disk guard (already bounded, so low residual risk).

## Ready for Proposal

**Yes.** Tell the orchestrator/user: (1) `ath10k_snoc` is a **loadable module**, and the IRQ-rebind fix is present in 6.0.0, so both a driver rebind and a full reboot are viable recovery rungs — the watchdog can self-heal *without* a reboot in the common case; (2) the incident is a **known, chronic WCN3990-on-mainline bug**, and the post-recovery scan-hang specifically is a bug fixed only *after* this 6.0.0 kernel, which is exactly why the in-driver recovery alone was insufficient; (3) the recommended shape is a versioned shell script + systemd timer on the phone (matching the existing `scan-devcoredump`/`wol-rog` timer idiom), reusing `ath10k-crash-watch`'s crash signature but not its process; (4) the Go-only policy does **not** require a Go binary here — the watchdog is device-internal shell on an external device, not an operator-facing repo script; (5) one empirical question (does rebind alone restore scanning on HL1.0 firmware, or is reboot required) is deferred to a single controlled test in apply — the ladder is correct either way.
