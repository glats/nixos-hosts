# Tasks: VNC regreet + hyprland — output selection + verification

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10 permanent (8 in omarchy-nix, 2 in nixos-hosts) + 4 temporary (reverted after tests) |
| 400-line budget risk | None |
| Chained PRs recommended | No |
| Suggested split | Two commits: omarchy-nix first, then nixos-hosts |
| Delivery strategy | sequential (omarchy-nix commit/push, then flake lock update + t14 config + commit/push) |
| Chain strategy | n/a |

> **Guard lines**: `Decision needed before apply: No` | `Chained PRs recommended: No` | `400-line budget risk: None`
>
> Implementation is ~10 lines of permanent code across 2 repos. The verification phase adds temporary config mutations (port change, disable toggle, invalid output) that are reverted immediately after their respective tests. All Phase 2 config inspection tasks (2.1, 2.2) from the original verification are already complete per apply-progress.md. The only new verification is confirming the `-o DP-3` flag and the DP-3 capture behavior.

---

## Phase 1: Implement output selection

**Goal**: Add `output` option to `omarchy.greeter.wayvnc`, update wayvnc exec-once to pass `-o` flag, and configure t14 to target DP-3.

- [x] **1.1 Add `output` option to omarchy-nix/config.nix**

  **Covers**: Spec scenarios 24 (output set to DP-3), 25 (empty output preserves default), 26 (invalid output fails gracefully)

  **File**: `omarchy-nix/config.nix` — inside the `wayvnc` submodule (after `enable_pam` at line 390)

  **Action**:
  ```nix
  # Add this option inside the wayvnc submodule options block (after enable_pam):
  output = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Output name for wayvnc to capture (e.g. DP-3, eDP-1). Leave empty to capture the first available output.";
    example = "DP-3";
  };
  ```

  **Verification**:
  ```bash
  # In omarchy-nix repo
  nix flake check --no-build
  # Assert: exit 0
  ```

  **Pass criteria**:
  - `output` option added inside the `wayvnc` submodule
  - Default value is `""` (empty string)
  - `nix flake check --no-build` passes
  - Option tree: `omarchy.greeter.wayvnc.{enable, address, port, enable_pam, output}`

- [x] **1.2 Update wayvncExec in omarchy-nix/modules/nixos/system.nix**

  **Covers**: Spec scenarios 24 (output flag in exec-once), 25 (no flag when empty), scenario 2 (modified — wayvnc uses `-o DP-3` flag when set)

  **File**: `omarchy-nix/modules/nixos/system.nix` — line 277

  **Action**: Modify `wayvncExec` from:
  ```nix
  wayvncExec = lib.optionalString cfg.greeter.wayvnc.enable "exec-once = ${pkgs.wayvnc}/bin/wayvnc ${cfg.greeter.wayvnc.address} ${toString cfg.greeter.wayvnc.port} &\n";
  ```

  To:
  ```nix
  wayvncExec = lib.optionalString cfg.greeter.wayvnc.enable (
    "exec-once = ${pkgs.wayvnc}/bin/wayvnc"
    + lib.optionalString (cfg.greeter.wayvnc.output != "") " -o ${cfg.greeter.wayvnc.output}"
    + " ${cfg.greeter.wayvnc.address} ${toString cfg.greeter.wayvnc.port} &\n"
  );
  ```

  **Verification**:
  ```bash
  # In omarchy-nix repo
  nix flake check --no-build && format-nix
  # Assert: exit 0
  ```

  **Pass criteria**:
  - When `output = ""` (default): `exec-once = .../wayvnc <address> <port> &` (byte-identical to current)
  - When `output = "DP-3"`: `exec-once = .../wayvnc -o DP-3 <address> <port> &`
  - `-o` flag always placed between wayvnc binary path and address/port arguments
  - `nix flake check --no-build` passes, `format-nix` produces no changes

- [x] **1.3 Set `output = "DP-3"` in hosts/t14/default.nix**

  **Covers**: Spec scenario 24 (output set to DP-3 -> exec-once contains `-o DP-3`)

  **File**: `hosts/t14/default.nix` — inside the `omarchy.greeter.wayvnc` block (line 225)

  **Action**: Change:
  ```nix
  wayvnc.enable = true;
  ```

  To:
  ```nix
  wayvnc = {
    enable = true;
    output = "DP-3";
  };
  ```

  **Verification**:
  ```bash
  # In nixos-hosts repo
  nix eval --raw .#nixosConfigurations.t14.config.omarchy.greeter.wayvnc.output
  # Assert: "DP-3"
  ```

  **Pass criteria**:
  - `output` set to `"DP-3"` in the greeter wayvnc block
  - `enable = true` preserved
  - No other greeter options changed

- [x] **1.4 Update focusMonitor in hosts/t14/default.nix**

  **Covers**: Spec scenarios 27 (AOC 2470W connected — DP-3 focused, DP-5 disabled), 28 (AOC 2470W NOT connected — fallback to eDP-1), 29 (both AOC monitors — only DP-3 active)

  **File**: `hosts/t14/default.nix` — line 202

  **Action**: Change:
  ```nix
  focusMonitor = "LEN G24";
  ```

  To:
  ```nix
  focusMonitor = "AOC 2470W";
  ```

  **Reason**: "LEN G24" is no longer connected. "AOC 2470W" matches the currently-connected landscape monitor (DP-3). The greeter script uses this as a description substring match via `hyprctl monitors -j | jq contains`. When matched, it disables all other external monitors (DP-5 portrait) and focuses the greeter on DP-3.

  **Verification**:
  ```bash
  # In nixos-hosts repo
  nix eval --raw .#nixosConfigurations.t14.config.omarchy.greeter.focusMonitor
  # Assert: "AOC 2470W"
  ```

  **Pass criteria**:
  - `focusMonitor` value changed from `"LEN G24"` to `"AOC 2470W"`
  - No other greeter options changed
  - Note: "AOC 2470W" is a SUBSTRING match — the full monitor description is "AOC 2470W GGZM3HA438259"

---

## Phase 2: Build & deploy

**Goal**: Commit both repos, push, update flake lock, and deploy on t14.

- [x] **2.1 Commit omarchy-nix + push**

  **Covers**: Prerequisite for all remaining tasks

  **Steps**:
  ```bash
  cd ~/repos/omarchy-nix

  # Verify changes
  git diff
  git status

  # Stage and commit
  git add config.nix modules/nixos/system.nix
  git commit -m "feat(greeter): add output option to wayvnc submodule

  Add omarchy.greeter.wayvnc.output (string, default \"\") to let
  per-host configs target a specific monitor for wayvnc capture.
  When set, the -o flag is emitted in the exec-once line between
  the binary path and address/port arguments. When empty (default),
  no -o flag is emitted — backward compatible with all existing hosts."

  # Push
  git push origin main
  ```

  **Pass criteria**:
  - Commit created with both files (`config.nix`, `modules/nixos/system.nix`)
  - Push succeeds (no conflicts)
  - Commit message follows conventional commits format

- [x] **2.2 Update flake lock + commit nixos-hosts + push**

  **Covers**: Prerequisite for deploy on t14

  **Steps**:
  ```bash
  cd ~/.nixos

  # Update omarchy-nix flake input to pull the new commit
  nix flake lock --update-input omarchy-nix

  # Verify the lock update points to the new commit
  git diff flake.lock | head -20

  # Verify t14 evaluates (dry-run)
  nix eval --raw .#nixosConfigurations.t14.config.omarchy.greeter.wayvnc.output
  # Assert: "DP-3"

  nix eval --raw .#nixosConfigurations.t14.config.omarchy.greeter.focusMonitor
  # Assert: "AOC 2470W"

  # Full flake check
  nix flake check --no-build

  # Format
  format-nix

  # Stage and commit
  git add flake.lock hosts/t14/default.nix
  git commit -m "feat(t14): set wayvnc output to DP-3, update focusMonitor

  - Set omarchy.greeter.wayvnc.output = \"DP-3\" to capture the
    landscape external monitor (AOC 2470W) for VNC.
  - Update focusMonitor from \"LEN G24\" (no longer connected) to
    \"AOC 2470W\" to focus the greeter on DP-3 and disable the
    portrait monitor (DP-5, AOC 24P1W1) during login.
  - Bump omarchy-nix input for new wayvnc output option."

  # Push
  git push origin master
  ```

  **Pass criteria**:
  - `flake.lock` updated to point to the new omarchy-nix commit
  - `nix flake check --no-build` passes all hosts (t14, rog, thinkcentre, mact2)
  - Commit pushed successfully
  - Non-t14 hosts produce byte-equivalent configs (their `output` defaults to `""`)

- [ ] **2.3 Rebuild on t14**

  **Covers**: Deploy prerequisite for all Phase 3 verification tasks

  **Steps**:
  ```bash
  # On t14 (SSH or physical)
  cd ~/.nixos

  # Pull the new commits
  git pull origin master

  # Build and switch
  nixos-build switch

  # Verify generation incremented
  sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | tail -3

  # Verify hyprland.conf contains -o DP-3
  grep "wayvnc -o DP-3" /etc/greetd/hyprland.conf
  # Assert: one match, containing full path and "5900 &"

  # Verify config file still exists
  cat /var/lib/greeter/.config/wayvnc/config
  ```

  **Pass criteria**:
  - `nixos-build switch` exits 0
  - System switches to new generation
  - `/etc/greetd/hyprland.conf` contains `exec-once = .../wayvnc -o DP-3 0.0.0.0 5900 &`
  - `/var/lib/greeter/.config/wayvnc/config` still exists with correct content

---

## Phase 3: Verification

**Goal**: Verify the output selection fix works end-to-end, run parameterized tests, and confirm all 29 spec scenarios.

> **Note**: Tasks 2.1 (hyprland.conf inspection) and 2.2 (wayvnc config inspection) from the original tasks.md are already complete per apply-progress.md. Task 3.1 below is the NEW verification of the `-o DP-3` flag AND the focusMonitor behavior. Existing E2E tasks (3.2-3.4) are updated to reflect the new expected behavior (DP-3 landscape instead of DP-5 portrait).

- [ ] **3.1 Restart greetd, verify wayvnc captures DP-3 output**

  **Covers**: Spec scenarios 1 (wayvnc before regreet), 2 (modified — `-o DP-3` flag present), 24 (output set -> `-o DP-3` in exec-once), 27/29 (focusMonitor — only DP-3 active, DP-5 disabled), 4-8 (wayvnc config file)

  **Steps**:
  ```bash
  # 1. Restart greeter to simulate cold boot
  sudo systemctl restart greetd
  sleep 3

  # Scenario 1 + 2 (modified) + 24: verify exec-once line
  grep -n "wayvnc" /etc/greetd/hyprland.conf
  grep -n "greetd-regreet-start" /etc/greetd/hyprland.conf
  # Assert: wayvnc line number < regreet line number
  # Assert: contains "/nix/store" (full binary path)
  # Assert: contains "-o DP-3" BEFORE "0.0.0.0"
  # Assert: contains "5900" and ends with "&"

  # Explicit ordering check
  grep "wayvnc -o DP-3 0.0.0.0" /etc/greetd/hyprland.conf
  # Assert: exactly one match (the -o flag precedes address/port)

  # Scenario 27/29: verify only DP-3 is active (focusMonitor working)
  hyprctl monitors -j | jq '[.[] | .name] | sort'
  # Assert: ["DP-3"] only (DP-5 + eDP-1 disabled)

  # Verify wayvnc process is running
  ps aux | grep "[w]ayvnc.*5900"
  # Assert: >=1 process

  # Scenario 4-8: verify config file
  cat /var/lib/greeter/.config/wayvnc/config
  # Assert: address=0.0.0.0, port=5900, enable_pam=true
  # Assert: NO output= key (output is CLI-only)
  ```

  **Pass criteria**:
  - wayvnc exec-once line contains `-o DP-3` positioned before `0.0.0.0 5900`
  - wayvnc process running on port 5900
  - `hyprctl monitors -j` shows only DP-3 active (focusMonitor disabled DP-5 and eDP-1)
  - wayvnc config file exists with correct content

- [ ] **3.2 E2E VNC test — connect, authenticate, observe handoff**

  **Covers**: Spec scenarios 9 (modified — VNC shows DP-3 landscape, not DP-5 portrait), 10 (PAM auth succeeds), 11 (PAM auth fails), 12 (physical display unaffected), 13 (greeter wayvnc exits on auth), 14 (user wayvnc takes over), 15 (disconnect brief), 27/29 (focusMonitor confirmed), 26 (invalid output edge case — optional), 16 (no orphaned listener — optional), 28 (undocked fallback — optional)

  **Precondition**: Task 3.1 passed — wayvnc is running, DP-3 is the only active monitor in the greeter session.

  **CLI pre-checks**:
  ```bash
  # Verify wayvnc running
  ps aux | grep "[w]ayvnc.*5900"   # >=1 process
  ss -tlnp | grep 5900              # wayvnc listening on 0.0.0.0:5900

  # Verify monitor state (focusMonitor working)
  hyprctl monitors -j | jq '[.[] | {name, description}]'
  # Assert: only DP-3 active, description contains "AOC 2470W"
  ```

  **Manual VNC steps**:

  | Step | Scenario | Action | Assert |
  |------|----------|--------|--------|
  | 1 | S9 (modified) | Connect Remmina to `t14:5900` | regreet visible in LANDSCAPE (1920x1080), NOT portrait. Keyboard/mouse input work. |
  | 2 | S11 | Disconnect, reconnect, enter INVALID creds | Connection rejected at VeNCrypt layer. `ps aux \| grep "[w]ayvnc.*5900"` still >= 1. |
  | 3 | S10 | Connect with VALID `glats` creds | VNC session established, regreet UI interactive. |
  | 4 | S12 | During VNC session, observe physical DP-3 | Shows regreet normally, same greeter state as VNC. |
  | 5 | S13 | Authenticate (via VNC or physical -> regreet exits) | `ps aux \| grep "[w]ayvnc.*5900"` -> 0 greeter wayvnc processes. |
  | 6 | S14 | Remmina auto-reconnects (or manually) | User Hyprland desktop visible within 5s. `ss -tlnp \| grep 5900` shows user-session wayvnc. |
  | 7 | S15 | Time the disconnect from auth to reconnect | ~1s (acceptable: <5s). |

  **Note on VeNCrypt vs regreet auth**: wayvnc with `enable_pam=true` performs PAM authentication at the VNC protocol level (VeNCrypt TLS auth). You may need to configure the VNC client to use VeNCrypt authentication. In Remmina: Connection > Advanced > Security = "VeNCrypt" (or "TLS"). If the VNC client doesn't support VeNCrypt, try `enable_pam = false` temporarily to test basic connectivity, then re-enable.

  **Scenario 16 (optional edge case — no orphaned listener)**:
  ```bash
  # Temporarily disable user-session wayvnc (line 194 in hosts/t14/default.nix):
  # set omarchy.wayvnc.enable = false
  nixos-build switch
  sudo systemctl restart greetd
  # Authenticate via physical display
  ss -tlnp | grep 5900    # Assert: NOT bound
  # RESTORE: omarchy.wayvnc.enable = true, nixos-build switch
  ```

  **Scenario 26 (optional edge case — invalid output fails gracefully)**:
  ```bash
  # Temporarily set wayvnc.output = "DP-9"
  nixos-build switch
  sudo systemctl restart greetd
  # Assert: regreet still launches on physical DP-3
  # Assert: VNC connection to t14:5900 either refused OR shows blank/first-available
  # RESTORE: wayvnc.output = "DP-3", nixos-build switch
  ```

  **Scenario 28 (optional — undocked fallback)**:
  ```
  - Physically undock t14 (disconnect both external monitors)
  - Reboot or systemctl restart greetd
  - Assert: no monitor matches "AOC 2470W", greeter script no-op
  - Assert: regreet visible on eDP-1 (laptop screen)
  - RESTORE: dock t14 again
  ```

  **Pass criteria**:
  - regreet visible via VNC pre-login on DP-3 landscape (NOT portrait DP-5)
  - Keyboard and mouse input work
  - Wrong credentials rejected, wayvnc stays running
  - Correct credentials allow access
  - Physical DP-3 display unaffected by VNC session
  - Only DP-3 active during greeter session (focusMonitor disables DP-5)
  - Greeter wayvnc exits on auth
  - User wayvnc takes over port 5900 within 5s

  **Failure modes**:

  | Symptom | Likely cause | Debug command |
  |---------|-------------|---------------|
  | VNC shows portrait monitor | `-o DP-3` not applied or wrong output name | `grep "\-o DP-3" /etc/greetd/hyprland.conf`; `hyprctl monitors -j \| jq '.[].name'` |
  | VNC connection refused | wayvnc not running | `ps aux \| grep wayvnc`, `journalctl -u greetd` |
  | VNC black screen | WAYLAND_DISPLAY not set or wrong socket | `sudo cat /proc/$(pgrep -f "wayvnc.*5900")/environ \| tr '\0' '\n' \| grep WAYLAND` |
  | DP-5 still active during greeter | focusMonitor typo or not matching | `hyprctl monitors -j \| jq '.[].description'` — does any contain "AOC 2470W"? |
  | VNC auth fails with valid creds | PAM socket missing | `ls /run/greetd/pam_socket`, `journalctl -u greetd \| grep -i pam` |

- [ ] **3.3 Custom port test (temporary: `port = 5901`, then revert)**

  **Covers**: Spec scenarios 20 (custom port in config file), 21 (custom port in hyprland.conf, `-o DP-3` preserved), 22 (wayvnc binds to 5901), 23 (VNC connects to 5901, 5900 refused)

  **WARNING**: This task makes a TEMPORARY edit to `hosts/t14/default.nix`. The edit is reverted at the end. Do NOT commit.

  **Steps**:
  ```bash
  cd ~/.nixos

  # 1. TEMPORARY EDIT: add port = 5901 to greeter.wayvnc block
  # Edit hosts/t14/default.nix, change:
  #   wayvnc = {
  #     enable = true;
  #     output = "DP-3";
  #   };
  # To:
  #   wayvnc = {
  #     enable = true;
  #     output = "DP-3";
  #     port = 5901;
  #   };

  # 2. Build and deploy
  nixos-build switch

  # 3. Scenario 20: Custom port in wayvnc config file
  grep "5901" /var/lib/greeter/.config/wayvnc/config
  # Assert: port=5901

  # 4. Scenario 21: Custom port in hyprland.conf, -o DP-3 PRESERVED
  grep "5901" /etc/greetd/hyprland.conf
  # Assert: exec-once line contains "5901" AND "-o DP-3" (both present)

  # 5. Restart greeter
  sudo systemctl restart greetd
  sleep 3

  # 6. Scenario 22: wayvnc binds to 5901
  ss -tlnp | grep 5901   # Assert: wayvnc listening on 0.0.0.0:5901
  ss -tlnp | grep 5900   # Assert: port 5900 NOT bound by wayvnc

  # 7. Scenario 23: [MANUAL] VNC connect test
  # - Remmina -> t14:5901 -> Assert: regreet visible (landscape, DP-3)
  # - Remmina -> t14:5900 -> Assert: connection refused

  # 8. REVERT: remove "port = 5901;" line, restore to:
  #   wayvnc = {
  #     enable = true;
  #     output = "DP-3";
  #   };

  # 9. Rebuild and deploy reverted config
  nixos-build switch

  # 10. Verify revert
  grep "port=5900" /var/lib/greeter/.config/wayvnc/config && echo "PASS: port 5900"
  grep "5900" /etc/greetd/hyprland.conf | grep -v "5901" && echo "PASS: hyprland.conf back to 5900"
  git diff hosts/t14/default.nix
  # Assert: (empty — no uncommitted changes)
  ```

  **Pass criteria**:
  - `port=5901` in wayvnc config file
  - `5901` AND `-o DP-3` both present in hyprland.conf
  - wayvnc bound to 5901, 5900 free
  - VNC connects to 5901, fails on 5900
  - After revert: all configs back to 5900, no git diff

- [ ] **3.4 Negative test (temporary: `enable = false`, then restore)**

  **Covers**: Spec scenarios 17 (feature disabled removes ALL artifacts — including `-o DP-3` line), 18 (feature re-enabled restores ALL artifacts — including `-o DP-3`), 25 (empty output default produces no `-o` flag — verified at build time for non-t14 hosts), 19 (disabled by default on non-t14 hosts)

  **WARNING**: This task makes a TEMPORARY edit to `hosts/t14/default.nix`. The edit is reverted at the end. Do NOT commit.

  **Precondition**: Tasks 3.3 fully reverted. System back at default state (`enable = true`, `port = 5900`, `output = "DP-3"`).

  **Steps**:
  ```bash
  cd ~/.nixos

  # 1. TEMPORARY EDIT: disable wayvnc in greeter
  # Edit hosts/t14/default.nix, change:
  #   wayvnc = {
  #     enable = true;
  #     output = "DP-3";
  #   };
  # To:
  #   wayvnc = {
  #     enable = false;
  #     output = "DP-3";
  #   };

  # 2. Build and deploy
  nixos-build switch

  # 3. Scenario 17: Feature disabled removes ALL artifacts

  # 3a. No wayvnc in hyprland.conf (including the -o DP-3 line)
  grep -c "wayvnc" /etc/greetd/hyprland.conf
  # Assert: 0

  # 3b. No wayvnc config file
  ls /var/lib/greeter/.config/wayvnc/config 2>&1
  # Assert: "No such file or directory"

  # 3c. No wayvnc process in greeter session
  sudo systemctl restart greetd
  sleep 3
  ps aux | grep "[w]ayvnc"
  # Assert: 0 wayvnc processes in greeter context

  # 4. RESTORE: re-enable wayvnc
  # Edit back to:
  #   wayvnc = {
  #     enable = true;
  #     output = "DP-3";
  #   };

  # 5. Build and deploy restored config
  nixos-build switch

  # 6. Scenario 18: Feature re-enabled restores ALL artifacts

  # 6a. wayvnc back in hyprland.conf with -o DP-3
  grep -n "wayvnc" /etc/greetd/hyprland.conf
  # Assert: line present, before regreet, contains "-o DP-3 0.0.0.0 5900 &"

  # 6b. Config file restored
  test -f /var/lib/greeter/.config/wayvnc/config && echo "PASS: config restored" || echo "FAIL"

  # 6c. wayvnc process running
  sudo systemctl restart greetd
  sleep 3
  ps aux | grep "[w]ayvnc.*5900" && echo "PASS: process running" || echo "FAIL"

  # 7. Scenario 25: Build-time check — non-t14 hosts never emit -o flag
  nix flake check --no-build
  # Assert: exit 0 on ALL hosts (rog, thinkcentre, mact2)
  # Non-t14 hosts have output="" by default -> no -o flag in exec-once
  # Since wayvnc.enable = false on all non-t14 hosts, exec-once line is not emitted at all

  # 8. Verify git state
  git diff hosts/t14/default.nix
  # Assert: (empty — no uncommitted changes)
  ```

  **Pass criteria**:
  - When disabled: no wayvnc line (including `-o DP-3`) in hyprland.conf, no config file, no wayvnc process
  - When re-enabled: wayvnc line restored with `-o DP-3 0.0.0.0 5900 &`, config file exists, process runs
  - `nix flake check --no-build` passes all hosts
  - No uncommitted git changes

---

## Phase 4: Cleanup & Final Verification

**Goal**: Confirm t14 is back to its normal operating state and all build checks pass.

- [ ] **4.1 Verify restored state (`enable = true`, `port = 5900`, `output = "DP-3"`)**

  **Covers**: Sanity check — ensures t14 is back to normal after all temporary test changes

  **Steps**:
  ```bash
  cd ~/.nixos

  # 1. Verify enable = true, output = "DP-3" in source
  grep -A3 "wayvnc" hosts/t14/default.nix | head -5
  # Assert: enable = true, output = "DP-3" present

  # 2. Verify focusMonitor is "AOC 2470W"
  grep "focusMonitor" hosts/t14/default.nix
  # Assert: focusMonitor = "AOC 2470W"

  # 3. Verify no stray test config remains
  grep -E "port = 5901|enable = false|DP-9" hosts/t14/default.nix && echo "WARNING: test config still present!" || echo "OK: clean"

  # 4. Verify git state
  git status --short hosts/t14/default.nix
  # Assert: (empty — no uncommitted changes)

  # 5. Final deployed config inspection
  echo "=== hyprland.conf ==="
  grep "wayvnc" /etc/greetd/hyprland.conf
  # Assert: contains -o DP-3 0.0.0.0 5900 &

  echo "=== wayvnc config ==="
  cat /var/lib/greeter/.config/wayvnc/config
  # Assert: address=0.0.0.0, port=5900, enable_pam=true

  echo "=== wayvnc process ==="
  ps aux | grep "[w]ayvnc.*5900"
  # Assert: >=1 process

  echo "=== port binding ==="
  ss -tlnp | grep 5900
  # Assert: wayvnc listening on 0.0.0.0:5900

  echo "=== monitor state ==="
  hyprctl monitors -j | jq '[.[] | .name] | sort'
  # Assert: only DP-3 active if docked, or eDP-1 if undocked
  ```

  **Pass criteria**:
  - `hosts/t14/default.nix` has `wayvnc.enable = true`, `wayvnc.output = "DP-3"`, `focusMonitor = "AOC 2470W"`
  - No stray test config (`port = 5901`, `enable = false`, `DP-9`)
  - `git status` clean for `hosts/t14/default.nix`
  - All deployed configs match expected state
  - wayvnc running on port 5900 with `-o DP-3`

- [ ] **4.2 Build verification — all hosts**

  **Covers**: Spec scenario 19 (disabled by default on non-t14 hosts — build-time check), scenario 25 (no `-o` flag for empty default)

  **Steps**:
  ```bash
  cd ~/.nixos

  # 1. Full flake evaluation for ALL hosts
  nix flake check --no-build
  # Assert: exit 0

  # 2. Format check
  format-nix
  # Assert: no format changes produced

  # 3. Verify non-t14 hosts are unaffected
  # Non-t14 hosts: output="" (default) AND wayvnc.enable=false
  # Both produce no -o flag in any deployed config
  nix eval --raw .#nixosConfigurations.rog.config.omarchy.greeter.wayvnc.output 2>/dev/null || echo "rog: not configured (expected)"

  # 4. Verify t14 produces correct hyprland.conf (dry-run build)
  nix build .#nixosConfigurations.t14.config.system.build.toplevel --dry-run 2>&1 | head -5
  # Assert: evaluates without errors
  ```

  **Pass criteria**:
  - `nix flake check --no-build` exits 0 for all hosts
  - Non-t14 hosts produce byte-equivalent configs (no `-o` flag — output defaults to `""`)
  - t14 evaluates cleanly

---

## Scenario Coverage Summary

29 scenarios across 8 requirements mapped to tasks:

| # | Requirement | Scenario | Task | Method |
|---|-------------|----------|------|--------|
| 1 | Hyprland Config Injection | wayvnc before greeter script | 3.1 | CLI |
| 2 | Hyprland Config Injection [MODIFIED] | wayvnc uses addr, port, AND `-o DP-3` | 3.1 | CLI |
| 3 | Hyprland Config Injection | Config rebuild-resistant | 2.3 opt | Reboot |
| 4 | wayvnc Config File | Exists with correct content | 3.1 | CLI |
| 5 | wayvnc Config File | Correct ownership + permissions | 3.1 | CLI |
| 6 | wayvnc Config File | Survives reboot | 2.3 opt | Reboot |
| 7 | wayvnc Config File | Parent directories correct | 3.1 | CLI |
| 8 | wayvnc Config File | Readable by greeter user | 3.1 | CLI |
| 9 | VNC Access at Login [MODIFIED] | VNC shows DP-3 landscape regreet | 3.2 | Manual |
| 10 | VNC Access at Login | PAM auth succeeds | 3.2 | Manual |
| 11 | VNC Access at Login | PAM auth fails | 3.2 | Manual |
| 12 | VNC Access at Login | Physical display unaffected | 3.2 | Manual |
| 13 | Login Transition | Greeter wayvnc exits on auth | 3.2 | CLI+Manual |
| 14 | Login Transition | User wayvnc takes over port 5900 | 3.2 | Manual |
| 15 | Login Transition | Disconnect is brief | 3.2 | Manual |
| 16 | Login Transition | No orphaned listener | 3.2 opt | CLI |
| 17 | Opt-in Gating | Feature disabled removes ALL artifacts | 3.4 | CLI |
| 18 | Opt-in Gating | Feature re-enabled restores artifacts | 3.4 | CLI |
| 19 | Opt-in Gating | Disabled by default on non-t14 hosts | 4.2 | Build |
| 20 | Custom Port | Custom port in config file | 3.3 | CLI |
| 21 | Custom Port | Custom port in hyprland.conf (preserves `-o DP-3`) | 3.3 | CLI |
| 22 | Custom Port | wayvnc binds to custom port | 3.3 | CLI |
| 23 | Custom Port | VNC connects to custom port | 3.3 | Manual |
| 24 | Output Selection [NEW] | `output="DP-3"` -> exec-once contains `-o DP-3` | 1.1-1.3, 3.1 | CLI |
| 25 | Output Selection [NEW] | `output=""` default -> no `-o` flag | 1.1-1.2, 3.4 | Build |
| 26 | Output Selection [NEW] | Invalid output fails gracefully | 3.2 opt | Manual |
| 27 | Focus Monitor Update [NEW] | AOC 2470W -> matches DP-3, disables DP-5 | 1.4, 3.1, 3.2 | CLI+Manual |
| 28 | Focus Monitor Update [NEW] | AOC 2470W NOT connected -> fallback eDP-1 | 3.2 opt | Manual |
| 29 | Focus Monitor Update [NEW] | Both monitors -> only DP-3 active | 1.4, 3.1, 3.2 | CLI+Manual |

---

## Summary

| Phase | Tasks | Scenarios covered | Permanent changes | Temporary changes |
|-------|-------|-------------------|-------------------|-------------------|
| 1: Implement | 1.1, 1.2, 1.3, 1.4 | 24, 25, 27, 29 | ~10 lines (2 repos) | none |
| 2: Build & deploy | 2.1, 2.2, 2.3 | prereqs | 2 commits | none |
| 3: Verify | 3.1, 3.2, 3.3, 3.4 | 1-18, 20-29 | none | port change, disable toggle, invalid output |
| 4: Cleanup | 4.1, 4.2 | 19 | none | none |

**Total**: 12 task checkboxes, 29 spec scenarios, ~10 permanent code lines, 3 temporary mutations (fully reverted).
