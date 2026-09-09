# Tasks: OnePlus 5 AdGuard DNS

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~300 (3 new `docs/` artifacts, no code edits) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single atomic commit |
| Delivery strategy | single-pr |
| Chain strategy | none |

Decision needed before apply: Yes — see Cross-Cutting / Before-Apply checklist.

### Suggested Work Units

Single unit — three `docs/` artifacts + phone install + operator enrollment, delivered as one atomic repo commit (archive phase) after user approves git mutation.

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Repo artifacts + phone install + operator enrollment | PR 1 | `format-nix && nix flake check --no-build`; `dig @172.16.0.12 example.com` | phone via SSH; operator on router/TV UIs | `git revert` + per-TV restore to automatic DNS + remove unit/config/apk |

## Execution model

- `[AGENT]` tasks: executor has SSH to the phone (`ssh -i ~/.ssh/oneplus5 glats@172.16.0.12`, passwordless sudo) and write access to the repo. No Xiaomi router web UI, no physical TV access.
- `[USER]` tasks: operator performs these on the Xiaomi router web UI or on the TVs. The agent cannot automate them. Each carries exact instructions.
- Git commit/push is NOT part of apply: per AGENTS.md the user approves git mutations interactively; committing belongs to the orchestrator/archive phase (see Cross-Cutting).

## Phase 1: Address gate (operator-dependent, blocks everything)

- [ ] 1.1 `[USER]` Create a DHCP reservation in the Xiaomi MiWiFi web UI mapping the OnePlus 5 MAC (`wlan0`, get it with `ip link show wlan0` via SSH) to a fixed `172.16.0.12`. Exact operator steps: Xiaomi app / `miwifi.com` → router settings → LAN/DHCP → static/DHCP reservation → add MAC `XX:XX:XX:XX:XX:XX` → IP `172.16.0.12` → save. If the UI cannot reserve, verify `.12` is outside the displayed DHCP lease pool before any static/manual step.
  **Acceptance:** reservation saved in Xiaomi UI; phone reports dynamic lease that consistently re-issues `.12`.

- [x] 1.2 `[AGENT]` **(DONE in LIGHT form per orchestrator scope adjustment — no double-reconnect)** User asserts DHCP reservation is done + NM profile MAC pinned. Evidence 2026-09-09: `cloned-mac-address=EE:03:CD:B0:51:74` present in both `/etc/NetworkManager/system-connections/JICS.nmconnection` and `JICS-5G-only.nmconnection`; `nmcli -f DHCP4 con show JICS` shows `ip_address = 172.16.0.12`, `dhcp_client_identifier = 01:ee:03:cd:b0:51:74` (MAC-based), `dhcp_lease_time = 43200s`, `routers/domain_name_servers = 172.16.0.1`; `ip -4 addr show wlan0` = `172.16.0.12/24 dynamic`. Operator assertion (reservation done router-side) recorded as evidence. **GATE PASS.**
  **Acceptance (light):** MAC pinned + IP currently `.12` — both confirmed; no double-reboot performed (orchestrator waiver).
  **Depends on:** 1.1.

- [x] 1.3 `[AGENT]` Address-gate outcome: **PASS** — phone validated at `172.16.0.12` with pinned MAC + operator-confirmed reservation. Apply NOT blocked.
  **Acceptance:** explicit gate PASS recorded ✓.
  **Depends on:** 1.2.

## Phase 2: Repo artifacts (agent-only, no repo gate until Phase 6)

- [x] 2.1 `[AGENT]` Write `docs/oneplus5-adguard-dns/AdGuardHome.yaml` matching the design Decision 7 schema-34 baseline byte-for-byte: `http.address 172.16.0.12:3000`, `dns.bind_hosts [172.16.0.12]`, `dns.port 53`, `upstream_dns [9.9.9.10]`, `fallback_dns [1.1.1.1]`, `bootstrap_dns ["9.9.9.10:53","1.1.1.1:53"]`, `upstream_mode load_balance`, `ratelimit 50`, `cache_enabled true`, `cache_size 33554432`, `cache_optimistic true`, `anonymize_client_ip false`, `filtering.protection_enabled false`, `filtering_enabled false`, `safebrowsing_enabled false`, `parental_enabled false`, `safe_search.enabled false`, `filters []`, `whitelist_filters []`, `user_rules []`, `querylog {enabled true, file_enabled true, interval 7d, size_memory 1000}`, `statistics {enabled true, interval 24h}`, `clients.persistent []` + `runtime_sources` (whois false, arp true, rdns true, dhcp false, hosts true), `dhcp.enabled false`, `tls.enabled false`, `schema_version 34`. Add placeholder client entries `samsung-tv`, `lg-tv` (empty identifiers) to be named via the UI later.
  **Acceptance:** DONE with one runtime-forced deviation — AGH 0.107.79 hard-rejects persistent clients with empty `ids` ("init client storage: … id required", fatal at startup), so `clients.persistent: []` ships EMPTY and `samsung-tv`/`lg-tv` are suggested names in the YAML comment + runbook instead of YAML entries. All other keys/values present; empty collections (`filters`, `whitelist_filters`, `user_rules`) prove zero filtering; `schema_version: 34`; no blocklists. Runtime parse validated by service start in 3.4.
  **Depends on:** 1.3.

- [x] 2.2 `[AGENT]` Write `docs/oneplus5-adguard-dns/adguardhome.service` matching design Decision 6. (**Note:** `RestartSec=5s` per design.md/tasks.md, not the orchestrator summary's `RestartSec=10`; design header said "follow design.md values exactly".) Verified: `systemd-analyze verify` on the phone passes (3.3).
  **Acceptance:** DONE — unit grants only `CAP_NET_BIND_SERVICE`; writable paths whitelisted via `ReadWritePaths`; All listed directives present.
  **Depends on:** 1.3.

- [x] 2.3 `[AGENT]` Write `docs/oneplus5-adguard-dns.md` runbook with the design Decision 9 section order. DONE — sections: prerequisites; address gate (incl. user's completed reservation + MAC pin); install; deploy/start+verify (incl. degraded-state note, credentials note: baseline ships no `users` entry — AGH keeps UI open on LAN bind, set a user via UI if desired); enroll TVs by brand (Samsung/LG webOS/Android TV/Roku/Fire TV/Apple TV) with hardcoded-`8.8.8.8` silent-client diagnosis; name clients/read logs; Hagezi opt-in (UI path + 5 verified raw URLs, none active; verified via GitHub contents API + raw fetch HTTP 200); redeploy/drift correction with exact commands + live-vs-repo diff; rollback (TV-first Decision 8); troubleshooting (degraded, ath10k/WiFi, `wifi.powersave=2`, no-suspend note, silent clients).
  **Acceptance:** every command copy-pasteable; HaGeZi stays opt-in only ✓.
  **Depends on:** 2.1, 2.2.

## Phase 3: Phone install (agent-only)

- [x] 3.1 `[AGENT]` Validate current phone state read-only over SSH: `apk info | grep adguardhome` (must be absent), `ss -tulpn` (nothing bound to `:53` or `:3000`), confirm `172.16.0.12` present on `wlan0`, confirm `/etc/systemd/system/` empty of `adguardhome.service`. Record baseline.
  **Acceptance:** DONE — baseline 2026-09-09 17:24: no `adguardhome` package, no unit file, no `/etc/adguardhome`/`/var/lib/adguardhome`, `wlan0` = `172.16.0.12`. Detection caveat: `ss`/`dig` are NOT installed on the phone shell, so the port emptiness passed unobserved; later `netstat` showed pre-existing loopback-only `:53` listeners (dnsmasq 127.0.0.1, systemd-resolved 127.0.0.53/.54) that never conflicted with AGH's `.12` bind.
  **Depends on:** 1.3.

- [x] 3.2 `[AGENT]` `sudo apk add adguardhome` → `adguardhome-0.107.79-r0` installed. Confirmed `id adguardhome` (uid 113/gid 118), `/usr/bin/adguardhome` (mode 0754, owner adguardhome), and NO OpenRC init script on `pmOS edge` — our systemd unit is required.
  **Acceptance:** DONE.
  **Depends on:** 3.1.

- [x] 3.3 `[AGENT]` scp + install as specified: YAML 0640 adguardhome:adguardhome at `/etc/adguardhome/AdGuardHome.yaml`; unit 0644 root:root at `/etc/systemd/system/adguardhome.service`. `sudo systemd-analyze verify` passes (exit 0; only pre-existing warnings from unrelated units `q6voiced`/`avahi-daemon.socket`).
  **Acceptance:** DONE. (Note: `systemd-analyze verify` must run with sudo on the phone — as `glats` it false-negatives "Permission denied" on the 0754 binary.)
  **Depends on:** 2.1, 2.2, 3.2.

- [x] 3.4 `[AGENT]` `daemon-reload && enable --now` → `is-active` = **active**, `is-enabled` = **enabled**. Two schema issues were found and fixed en route (see YAML deviations in 2.1): per-client `blocked_services` must be a struct; empty-`ids` persistent clients are fatal.
  **Acceptance:** DONE.
  **Depends on:** 3.3.

- [x] 3.5 `[AGENT]` Runtime verified: `netstat -tulnp` shows adguardhome ONLY on `172.16.0.12:53` (tcp+udp) and `172.16.0.12:3000` — never 0.0.0.0. DNS on the phone: `nslookup example.com 172.16.0.12` → real A records. **UI LAN-reachability finding:** the phone runs a curated nftables firewall (`/etc/nftables.nft`, input policy drop; allowlist: SSH, DNS:53 on wlan*, DHCP, mDNS, etc.) — port 3000 is NOT allowlisted from the LAN, so `curl http://172.16.0.12:3000` from rog times out BY USER FIREWALL DESIGN (the ruleset explicitly allows the fresh DNS-53 rules but not 3000). On-phone curl returns HTTP 200. Recorded as deviation + operator decision; runbook updated.
  **Acceptance:** DONE with documented firewall finding — bind correctness + on-phone UI 200 verified; LAN UI access = operator opt-in (runbook documents the nftables drop-in path).
  **Depends on:** 3.4.

- [x] 3.6 `[AGENT]` From rog (172.16.0.5): `dig @172.16.0.12 netflix.com` → real A records; `dig @172.16.0.12 example.com` → NOERROR via SERVER 172.16.0.12#53. Query-log API confirms entries from client 172.16.0.5 with `reason: NotFilteredNotFound`, `rules: []`, zero blocked/0.0.0.0.
  **Acceptance:** DONE — external LAN host resolves through the phone.
  **Depends on:** 3.5.

- [x] 3.7 `[AGENT]` Reboot test: `sudo systemctl reboot` 17:31:25 → SSH back 17:32:50 → unit active + listening on `.12:53`/`.12:3000` at **17:32:52** (boot-to-serving ≈ 90 s; unit start→serving ≈ 2 s). `dig @172.16.0.12 example.com` from rog works seconds later. Lease re-issued `.12` with fresh 12h lease (`valid_lft 43183s`) — reservation behavior holds.
  **Acceptance:** DONE — auto-start ✓, port 53 ✓, address held ✓.
  **Depends on:** 3.6.

## Phase 4: TV enrollment (operator-dependent — DEFERRED per orchestrator, pending operator)

- [ ] 4.1 `[USER]` Set manual DNS on each TV to `172.16.0.12` (Decision 3 + Requirement 3). Exact operator steps per brand: network settings → manual/static DNS → primary `172.16.0.12`, secondary blank or router `172.16.0.1`. Repeat per TV (samsung-tv, lg-tv, and any others to enroll). Leave secondary as the router only if the TV UI requires a second entry.
  **Acceptance:** each TV's DNS points at `172.16.0.12`.
  **Depends on:** 3.7. No automation available. **PENDING OPERATOR — deferred per orchestrator scope (Phase 4 not attempted during apply).**

- [ ] 4.2 `[AGENT]` Verify at least one enrolled TV appears in the query log: after a TV makes a DNS query, confirm a client entry appears under its name in the AGH web UI (Settings → Query log) or via the AGH REST API (`GET http://172.16.0.12:3000/control/querylog` with a session). Confirm the client is identified (ARP/rdns runtime source) and logged but NOT filtered (Decision 7 log-only: `protection_enabled` and `filtering_enabled` still false).
  **Acceptance:** at least one enrolled TV shows named, logged, unfiltered queries. If a TV is enrolled but silent, flag for troubleshooting (hardcoded `8.8.8.8` check, Decision 10) and return to operator for retry.
  **Depends on:** 4.1 (at least one TV enrolled). **PENDING OPERATOR — deferred per orchestrator scope (no TV enrolled during apply; query log verified working with rog client instead).**

- [ ] 4.3 `[AGENT]` Name the enrolled clients: create persistent client entries in the AGH UI (or note names via `clients.persistent`) so logs show `samsung-tv`/`lg-tv` by name. Do not alter `clients.persistent` in the repo baseline beyond the placeholders (UI adds real stable addresses).
  **Acceptance:** enrolled TVs resolve to readable names in the query log.
  **Depends on:** 4.2. **PENDING OPERATOR — deferred per orchestrator scope; note agents cannot create persistent entries with empty ids anyway (see 2.1) unless the TV is actually enrolled first.**

## Phase 5: Operator-controlled Hagezi opt-in (deferred, documented only)

- [x] 5.1 `[AGENT]` Hagezi opt-in section verified complete. All 5 raw URLs exist in `hagezi/dns-blocklists/adblock/` (GitHub contents API, 2026-09-09: native.samsung.txt, native.lgwebos.txt, native.roku.txt, native.amazon.txt, native.apple.txt) and a raw fetch returns HTTP 200 with Adblock Plus format. **No list is active on the phone** (blocklists panel empty; `filters: []` in deployed YAML). 5.2 remains operator opt-in.
  **Acceptance:** DONE — runbook documents the UI path + 5 URLs; no list active.
  **Depends on:** 2.3.

- [ ] 5.2 `[USER]` (Optional, later) Follow the runbook to enable a selected Hagezi vendor list for one TV and confirm telemetry domains are blocked. This is an operator opt-in action and is NOT required for apply completion.
  **Acceptance:** (when performed) selected vendor list active for the chosen TV; non-enrolled clients unaffected.
  **Depends on:** 5.1, 4.3. **PENDING OPERATOR — not done during apply (opt-in only).**

## Phase 6: Verification (agent + operator evidence)

- [x] 6.1 `[AGENT]` Machine-checkable spec scenarios — evidence recorded (2026-09-09):
  - **Req 1 (address gate): PASS** — MAC `EE:03:CD:B0:51:74` pinned in `JICS`/`JICS-5G-only`; lease `172.16.0.12` (light form per orchestrator; operator asserts router reservation); lease re-issued `.12` after reboot (3.7).
  - **Req 2 (service install/operate): PASS** — `netstat`: adguardhome on `172.16.0.12:53` tcp+udp ONLY (never 0.0.0.0; other :53 listeners are pre-existing loopback-only dnsmasq/systemd-resolved); UI bind `.12:3000` verified + HTTP 200 on-phone. LAN UI curl from rog TIMES OUT by user firewall (nftables allowlist lacks 3000) — deviation recorded; survives reboot (3.7: reboot 17:31:25 → serving 17:32:52 ≈ 90 s boot-to-serving).
  - **Req 4 (log-only baseline): PASS** — live YAML: `filtering_enabled: false`, `protection_enabled: false`, `safebrowsing/parental: false`, `filters: []`, `whitelist_filters: []`, `user_rules: []`, querylog enabled/file_enabled; query-log API shows real queries (`netflix.com`) with `reason: NotFilteredNotFound`, `rules: []`, zero `Filtered`/`0.0.0.0` results.
  - **Req 5 (retention): PASS** — live `querylog.interval: 7d` (also on-phone file_enabled).
  - **Req 6 (Hagezi inactive): PASS** — `filters: []`, no blocklists configured; queries only from rog (.5) + phone (.12) so non-enrolled DNS path untouched (no router change made; other LAN clients still default to `172.16.0.1`).
  - **Req 7 (repo source of truth): PASS** — unit file diff: live == repo **identical**. YAML diff: AGH re-serializes the live file with its full default schema (extra keys like `pprof`, `trusted_proxies`, `cache_optimistic_{answer_ttl,max_age}`, `users: []`+auth-disabled warning, `statistics.interval` normalized `24h`→`1d`) — every baseline value verified present and identical semantically (address/bind/upstreams/bootstrap/upstream_mode/ratelimit 50/cache 33554432 + optimistic/anonymize false/all-disable flags/7d/1d=24h/empty lists/persistent []/runtime_sources). Repo baseline stays canonical input; drift is UI-time only.
  - **Req 9 (invariance): PASS** — `git status --porcelain`: only `docs/oneplus5-adguard-dns.md`, `docs/oneplus5-adguard-dns/`, `openspec/changes/oneplus5-adguard-dns/` added; no `.nix` touched (see 6.2).
  **Acceptance:** each scenario mapped with PASS result ✓ (no HALT).
  **Depends on:** 4.3 (deferred — log verified with rog client instead), 5.1.

- [x] 6.2 `[AGENT]` Flake-invariance gate: `format-nix` → `0 / 1 have been reformatted` (no repo .nix modified); `nix flake check --no-build` → **`all checks passed!`, exit 0** (nixosConfigurations rog/thinkcentre/t14, darwinConfigurations, homeConfigurations, formatter, devShells). No `.nix` files changed in this change — gate proves invariance per Requirement 9. Note: the x86_64-darwin system omission warning is the standard/safe system note, not a failure.
  **Acceptance:** DONE — exit 0.
  **Depends on:** 2.1–2.3 (artifacts in place; NOT committed per repo convention).

- [x] 6.3 `[AGENT]` Operator-dependent evidence gaps (recorded for the verify report):
  - **Req 3 "Enrolled TV is identified"** — NOT verifiable: Phase 4 deferred. Operator must enroll ≥1 TV via manual DNS `172.16.0.12` (4.1, runbook § Enroll TVs) and confirm: settings screen shows the manual DNS applied; the TV streams normally. Agent then verifies the TV's IP appears in the query log (`http://172.16.0.12:3000` UI or `/control/querylog`) and names it (4.3).
  - **Req 6 scenario "Selected vendor list blocks telemetry"** — operator-executed opt-in (5.2): after adding a Hagezi list + enabling filtering, songs the query log must show `Filtered`/`0.0.0.0` responses for the chosen TV's telemetry domains. Agent-side precondition already proven (lists inactive; filtering client flow works).
  - **Req 6 scenario "Non-enrolled clients remain unaffected"** — partially machine-verified (no lists active, no router changes); final confirmation: operator spot-checks another LAN client's browsing after any future opt-in.
  - **Req 8 "TV works after rollback"** — operator-executed at the TV after restoring automatic DNS; evidence: TV loads streaming apps through the router before/after phone service removal.
  - **UI-from-a-PC check** (runbook verify step from another LAN host) — blocked by the phone's curated nftables allowlist (no `tcp dport 3000` rule). Requires the operator's explicit firewall decision; on-phone UI access (HTTP 200) is already proven.
  **Acceptance:** DONE — machine-verified vs operator-confirmed split recorded above.

## Phase 7: Operator UI access helper (approved scope addition — Go helper `adguard-tunnel`)

- [x] 7.1 `[AGENT]` Amend change artifacts for the user-approved addition ("tunnel ssh pero crea un script en golang para mi nixos... con un nombre autoexplicativo"): spec delta Requirement 10 (Operator UI Access Helper) added with WHEN/THEN scenarios (tunnel + URL printed, clean SIGINT/SIGTERM shutdown, busy local port handling, unreachable host); this Phase 7 registered in tasks.md.
  **Acceptance:** both artifacts amended before implementation (openspec convention; change is pre-archive).
  **Depends on:** 6.1–6.3.

- [x] 7.2 `[AGENT]` Implement `pkgs/nixos-scripts/internal/sshtunnel/` (testable logic, stdlib only, zero go.mod deps) + `sshtunnel_test.go`: BuildSSHArgs(host, user, keyPath, localPort, remotePort) → args for `ssh -i <key> -N -L 127.0.0.1:<local>:<host>:<remote> <user>@<host>` (forward target defaults to the same host string — generic single-hop pair); PickFreePort with busy fallback to `localPort+10000` (documented in help text, auto-select announced on stdout); LocalURL formatting `http://127.0.0.1:<port>/`; home-path expansion for the key. Tests hermetic (no network, no real ssh).
  **Acceptance:** `go test ./...` passes.
  **Depends on:** 7.1.

- [x] 7.3 `[AGENT]` Implement thin `pkgs/nixos-scripts/cmd/adguard-tunnel/main.go`: flags `-host 172.16.0.12`, `-port 3000` (remote, AdGuard UI), `-local 3000`, `-user glats`, `-key ~/.ssh/oneplus5` (~ expanded), `-open` (xdg-open the URL). Help text states: purpose, that the phone firewall intentionally blocks :3000 from LAN, SSH key auth is the access control. Behavior: `ssh` lookPath + key existence checks (pointing to the runbook on error), free-port resolution with announced fallback, SIGINT/SIGTERM → CommandContext cancel (no orphaned ssh) → exit 0. Clear non-zero errors for missing ssh binary / missing key / unreachable host.
  **Acceptance:** `go vet ./...` clean; binary builds via subPackages.
  **Depends on:** 7.2.

- [x] 7.4 `[AGENT]` Register the binary: add `"cmd/adguard-tunnel"` to `subPackages` in `pkgs/nixos-scripts/default.nix`. Update `docs/oneplus5-adguard-dns.md` runbook SSH-tunnel section with `adguard-tunnel` usage post-deploy + interim methods (`nix build .#nixos-scripts` → `result/bin/adguard-tunnel`; `nix develop -c go -C pkgs/nixos-scripts run ./cmd/adguard-tunnel` for dev iteration; binary on PATH permanently after next `nixos-build`).
  **Acceptance:** default.nix lists the new subPackage; runbook documents the helper.
  **Depends on:** 7.3.

- [x] 7.5 `[AGENT]` Gates (evidence 2026-09-09): `go -C pkgs/nixos-scripts vet ./...` → clean; `go -C pkgs/nixos-scripts test ./...` → all packages PASS incl. new `internal/sshtunnel` (7 tests: BuildSSHArgs, BuildSSHArgsPortsDiffer, PickFreePortRequestedFree, PickFreePortBusy, PickFreePortBothBusy, LocalURL, TestExpandHome); `format-nix` → 0 reformatted (default.nix not restyled); `nix flake check --no-build` → **all checks passed!**, exit 0 (x86_64-darwin omission warning is the standard/safe system note). Extra proof: `nix build .#nixos-scripts` builds the derivation (checkPhase re-runs the suite in-sandbox) and `result/bin/adguard-tunnel` exists. Note: the new untracked files had to be `git add`-ed (staged, NOT committed — per repo convention apply stages; flake git-tree source excludes untracked files, first build failed with `stat /build/nixos-scripts/cmd/adguard-tunnel: directory not found` until staged).
  **Acceptance:** all three gates pass + derivation builds.
  **Depends on:** 7.4.

## Cross-Cutting Concerns

- **Before-apply (orchestrator must ask the user):**
  - Router reservation/TV access availability: Phase 1 and Phase 4 are `[USER]` and cannot proceed without the operator having Xiaomi router web UI access (reservation) and physical/TV access (manual DNS). Confirm both are available before apply starts, or apply is limited to Phases 2–3.6 (agent-only repo artifacts + phone install + LAN DNS verification).
  - Optional TV enrollment may be deferred; the change is only fully Done (per success criteria "enrolled TV appears in logs") after the operator enrolls at least one TV.
- **Git mutation is NOT part of apply:** commits/pushes are approved interactively by the user (repo convention). The commit belongs to the orchestrator/archive phase. Apply only stages the working tree changes; do not commit.
- **Address collision safety:** do not make `JICS` manual/static until the reservation is validated (Decision 1). If reservation validation fails, halt Phase 1 and report.
- **Drift:** AGH may rewrite the live YAML after UI edits (e.g. adding clients or enabling a list). The repo YAML stays the canonical baseline; redeploy intentionally removes drift (Decision 8). Clients named via UI are user data, not repo state.
- **Network exposure:** UI is plaintext and LAN-reachable; **however the phone runs a curated nftables allowlist firewall** (`/etc/nftables.nft`) that does NOT accept `:3000` from the LAN by default (discovered during apply; UI LAN access = operator opt-in, runbook documents the drop-in path). Never port-forward `3000`. DNS binds only `.12:53`, not wildcard or Tailscale (Decision 3).
- **Single point of failure:** enrolled TVs depend on the phone; rollback starts by restoring TV automatic/router DNS (Decision/Req 8), then removing unit/config/package.
- **No phone changes during artifact development:** artifacts are written before install (Phase 2 precedes Phase 3).
- **Hardcoded `8.8.8.8` blind spot:** a TV that resolves but is silent in AGH logs likely uses a hardcoded resolver; redirecting/blocking it is out of scope (Decision 10). Document in runbook.

## Verification mapping (spec requirements → tasks)

| Spec requirement | Task(s) | Machine-checkable? |
|------------------|---------|--------------------|
| 1. Stable Addressing Gate | 1.1, 1.2, 1.3 | Partially (lease stability = agent; reservation = operator) |
| 2. Service Install/Operate | 3.2–3.7 | Yes (agent) |
| 3. Manual TV Enrollment | 4.1, 4.2, 4.3 | Partially (operator sets DNS; agent verifies log) |
| 4. Log-Only Baseline | 2.1, 3.3, 6.1 | Yes (agent) |
| 5. Query-Log Retention | 2.1, 6.1 | Yes (agent) |
| 6. Hagezi Opt-In | 5.1, 5.2, 6.1 | Partially (inactive state = agent; blocking = operator) |
| 7. Repository Source of Truth | 2.1–2.3, 6.1 | Yes (agent) |
| 8. Complete Rollback | 2.3 (runbook), 6.3 | Operator-executed (TV restore) |
| 9. Nix Repository Invariance | 2.1–2.3, 6.2 | Yes (agent) |