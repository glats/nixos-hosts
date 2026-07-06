# Design: VNC regreet + hyprland — output selection + verification execution plan

## Technical Approach

This change has **two coordinated parts**: (1) a small implementation that fixes wayvnc output selection so VNC clients see the correct monitor, and (2) a verification execution plan that exercises the previously-complete greetd/regreet Hyprland VNC configuration on t14, including the new output-selection behavior.

### Part 1 — Output selection fix (implementation)

The `omarchy.greeter.wayvnc` submodule (in `omarchy-nix/config.nix`) already exists with `enable`, `address`, `port`, and `enable_pam` options. The `exec-once = wayvnc` injection is wired in `omarchy-nix/modules/nixos/system.nix`. The tmpfiles `C+` rule deploys the wayvnc config file. `nix flake check --no-build` passes on all hosts.

What's broken: in the greeter Hyprland session on t14, two external monitors are active — DP-3 (AOC 2470W, landscape, where regreet appears) and DP-5 (AOC 24P1W1, portrait, at position 0x0, focused). wayvnc's default behavior captures the first available output, which resolves to DP-5. VNC clients therefore see an empty portrait screen instead of the regreet login form.

Root cause (per re-exploration): wayvnc selects its output at Wayland initialization via `output_first()` when the `-o` CLI flag is absent. This happens BEFORE the greeter script runs, so even if the greeter script disables DP-5, wayvnc has already committed to DP-5. The `-o` flag is the only way to control wayvnc output selection at startup — no config-file equivalent exists (verified by reading wayvnc's `cfg.c` parser).

Fix scope:

- Add an `output` string option (default `""`) to `omarchy.greeter.wayvnc` inside `omarchy-nix/config.nix`.
- Modify the `wayvncExec` let-binding in `omarchy-nix/modules/nixos/system.nix` to conditionally append `-o ${output}` between the wayvnc binary path and the address/port arguments, only when `output != ""`.
- Set `wayvnc.output = "DP-3"` and update `focusMonitor` from `"LEN G24"` to `"AOC 2470W"` in `hosts/t14/default.nix`.

The fix is backward compatible: every host with the default `"output = """` value still produces an exec-once line with no `-o` flag, preserving the current "first available" behavior. The two changes (wayvnc `-o` and focusMonitor) work independently — the `-o` flag guarantees VNC correctness regardless of focusMonitor; the focusMonitor update improves the physical greeter experience regardless of VNC by disabling the portrait monitor during the greeter session.

### Part 2 — Verification execution plan (Phase 4)

All greetd/regreet/wayvnc code from the prior `greetd-wayvnc-feasibility` change (phases 1-3) remains complete and merged. Phase 4 is the manual verification on t14 hardware. This design defines the step-by-step execution plan to verify the 5 Phase 4 tasks AND the 6 new scenarios added by the output-selection delta (3 output-selection scenarios + 3 focus-monitor scenarios), for 29 total scenarios across 8 requirements. The only mutations during verification are temporary config changes for the custom-port test (task 4.4) and the negative test (task 4.5), both reverted after execution.

**Verification philosophy**: Config-inspection first, then end-to-end. If config files are correct but E2E fails, the root cause is runtime (network, firewall, VNC client). If config files are wrong, E2E would fail anyway and debugging would be harder. Config-first isolates the failure domain.

**Affected hosts**: t14 (implementation + verification). rog, thinkcentre, mact2 are untouched — the new `output` option defaults to `""` on every host, so non-t14 builds are byte-equivalent to before.

## Architecture Decisions

### Decision (implementation): Output selection — add `output` option + `-o` CLI flag

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add `output` option + `-o` CLI flag (conditional on non-empty) | Explicit, per-host configurable, backward compatible, follows existing submodule pattern | **Chosen** |
| Hardcode `-o DP-3` in `system.nix` | Simpler, but output names are kernel-assigned and not portable across hosts | Rejected — not configurable per host |
| `-a` capture-all flag | One flag, but produces a ~3000x1920 combined virtual desktop with regreet in a corner — unusable for a greeter | Rejected |
| Headless virtual output | Clean separation, but Hyprland cannot mirror outputs; regreet would only appear on one of physical or virtual | Rejected — changes architecture, doesn't solve mirroring |

**Rationale**: The `-o` flag is the only startup-time control over wayvnc output selection (the config-file parser does not support an `output` key — verified against wayvnc's `cfg.c` source and all four distro man pages). An empty default means the existing exec-once line is byte-identical for hosts that don't opt in, so the blast radius of this option is exactly the hosts that set a value.

### Decision (implementation): Focus monitor update — `"LEN G24"` -> `"AOC 2470W"`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Change `focusMonitor` to `"AOC 2470W"` | Matches the currently-connected landscape external monitor; greeter script disables DP-5 (portrait), leaving only DP-3 active | **Chosen** |
| Keep `focusMonitor = "LEN G24"` | Matches the old hardware, but LEN G24 is not currently connected, so the focus/disable logic is a no-op | Rejected |
| Remove `focusMonitor` entirely | Greeter falls back to "first available external" — could pick either monitor depending on enumeration order | Rejected — non-deterministic |

**Rationale**: This is a bonus fix independent of wayvnc. The `focusMonitor` value is matched as a description substring against `hyprctl monitors -j` output using `jq contains`. `"AOC 2470W"` matches the DP-3 description `AOC 2470W GGZM3HA438259`. When matched, the greeter script disables every other external monitor (DP-5 here) and focuses the target. Result: only DP-3 is active during the greeter session, so regreet and the VNC capture both target the landscape monitor. The change is one-line and host-local.

### Decision (implementation): Output option placement — inside existing wayvnc submodule

`output` is added as a sibling option to `enable`, `address`, `port`, `enable_pam` inside `config.nix`. This follows the pattern established by the prior design and keeps greeter wayvnc configuration in a single place. No new submodule is introduced and the option tree shape is unchanged.

### Decision (verification): Verification order — config inspection first, then deploy, then E2E

**Chosen**: Config inspection (4.1, 4.2) -> deploy (if needed) -> E2E (4.3) -> custom port (4.4) -> negative test (4.5).

| Order | Tradeoff | Decision |
|-------|----------|----------|
| Config-first (4.1, 4.2 -> 4.3 -> 4.4 -> 4.5) | Isolates failure domain: config vs runtime | **Chosen** |
| E2E-first (4.3 -> 4.1 -> 4.2) | Tests user-visible behavior first, but mixes config and runtime failures | Rejected |
| Build-only (skip E2E) | Fast, but doesn't prove runtime behavior | Rejected |

**Rationale**: If config files are correct but E2E fails, the root cause is runtime (network, firewall, VNC client configuration). If config files are wrong, E2E would fail anyway and debugging would be harder. Config-first isolates the failure domain and produces faster root-cause isolation.

### Decision (verification): Custom port test uses a temporary Nix change, restored after

**Chosen**: Modify `omarchy.greeter.wayvnc.port = 5901` in `hosts/t14/default.nix`, rebuild, switch, test, then revert to the default.

| Approach | Tradeoff | Decision |
|----------|----------|----------|
| Temporary Nix config change + rebuild | Tests the full Nix pipeline (option -> `hyprland.conf` -> wayvnc config -> runtime) | **Chosen** |
| Command-line wayvnc override (`wayvnc 0.0.0.0 5901`) | Fast, but skips the Nix deployment path — doesn't test option propagation | Rejected |
| Separate test host | Isolated, but disproportionate for a single-option test | Rejected |

### Decision (verification): Negative test verifies cleanup, then restores `enable = true`

**Chosen**: Set `omarchy.greeter.wayvnc.enable = false`, rebuild, switch, verify no artifacts, then RESTORE `enable = true` and rebuild.

**Rationale**: The t14 host must return to its normal operating state after verification. The restore step also doubles as verification of scenario 18 ("Feature re-enabled restores all artifacts").

### Decision (verification): Cold-boot simulation via `systemctl restart greetd`

**Chosen**: Use `systemctl restart greetd` to simulate a cold boot of the greeter session, rather than physically rebooting t14 for every scenario.

**Rationale**: Physical reboots are slow (30-60s each) and disruptive if the VNC client is connected. `systemctl restart greetd` restarts the greeter Hyprland session, which re-reads `/etc/greetd/hyprland.conf` and re-executes all `exec-once` lines — functionally equivalent to a cold boot for wayvnc purposes. Physical reboot is reserved for scenarios that explicitly require it (rebuild-resistant scenario, config-survives-reboot scenario).

## Data Flow

### Implementation flow

```
  omarchy-nix (submodule change)
   ├── config.nix: add `output` option to wayvnc submodule (default "")
   ├── modules/nixos/system.nix: wayvncExec conditionally emits `-o ${output}`
   └── flake check --no-build (omarchy-nix self-check)
              │
              ▼
  omarchy-nix bump in nixos-hosts flake.lock
              │
              ▼
  nixos-hosts (t14 host config)
   ├── hosts/t14/default.nix: wayvnc.output = "DP-3" (inside the existing wayvnc block)
   ├── hosts/t14/default.nix: focusMonitor = "AOC 2470W" (replacing "LEN G24")
   └── nix flake check --no-build (all hosts)
              │
              ▼
  Deploy on t14: nixos-build switch
              │
              ▼
  /etc/greetd/hyprland.conf now contains:
    exec-once = /nix/store/...-wayvnc-.../bin/wayvnc -o DP-3 0.0.0.0 5900 &
  (before exec-once = .../greetd-regreet-start)
```

### Verification execution flow

```
 Pre-flight
  │
  ├── SSH to t14 (or physical access)
  ├── Check current generation: nix-env --list-generations --profile /nix/var/nix/profiles/system
  ├── Check if config deployed: grep -c wayvnc /etc/greetd/hyprland.conf
  │
  ▼
 Deploy (if needed)
  │
  ├── nixos-build switch    (if wayvnc not found in hyprland.conf)
  ├── Verify generation incremented
  │
  ▼
 Task 4.1: Hyprland config inspection (Req 1, scenarios 1-3)
  │
  ├── grep -n "wayvnc" /etc/greetd/hyprland.conf           -> line number N1
  ├── grep -n "greetd-regreet-start" /etc/greetd/hyprland.conf -> line number N2
  ├── Assert N1 < N2 (wayvnc BEFORE regreet)
  ├── Assert wayvnc line contains "/nix/store" (full path)
  ├── Assert wayvnc line ends with "&" (backgrounded)
  ├── Assert wayvnc line contains "-o DP-3" positioned before address/port
  ├── Assert wayvnc line contains "0.0.0.0" and "5900"
  │
  ▼
 Task 4.2: wayvnc config inspection (Req 2, scenarios 4-8)
  │
  ├── stat /var/lib/greeter/.config/wayvnc/config           -> owner=greeter, group=greeter, mode=0640
  ├── cat /var/lib/greeter/.config/wayvnc/config             -> address=0.0.0.0, port=5900, enable_pam=true
  ├── sudo -u greeter cat /var/lib/greeter/.config/wayvnc/config -> readable, no permission error
  ├── ls -ld /var/lib/greeter/.config /var/lib/greeter/.config/wayvnc -> parent dirs exist, greeter:greeter
  │
  ▼
 Task 4.3: E2E VNC test (Req 3, scenarios 9-12; Req 4, scenarios 13-16)
  │
  ├── systemctl restart greetd                              -> simulate cold boot
  ├── ps aux | grep "[w]ayvnc.*5900"                        -> >=1 process (scenario 9 precondition)
  ├── ss -tlnp | grep 5900                                  -> port listening
  ├── [MANUAL] VNC client (Remmina) -> t14:5900             -> regreet login screen visible on DP-3 (landscape) (scenario 9)
  ├── [MANUAL] Keyboard input                               -> login fields respond (scenario 9)
  ├── [MANUAL] Mouse input                                  -> pointer moves (scenario 9)
  ├── [MANUAL] Hyprctl monitors shows only DP-3 active      -> DP-5 disabled by focusMonitor (focus monitor scenario)
  ├── [MANUAL] Valid credentials                            -> PAM auth succeeds (scenario 10)
  ├── [MANUAL] Invalid credentials                          -> connection rejected, wayvnc still running (scenario 11)
  ├── [MANUAL] Physical display still shows regreet         -> VNC doesn't affect DP-3 (scenario 12)
  ├── [MANUAL] Authenticate -> greeter exits                 -> ps aux shows 0 greeter wayvnc (scenario 13)
  ├── [MANUAL] Remmina auto-reconnects                      -> user desktop visible within 5s (scenario 14)
  ├── [MANUAL] Disconnect duration                          -> ~1s (scenario 15)
  │
  ▼
 Task 4.4: Custom port test (Req 6, scenarios 20-23)
  │
  ├── Edit hosts/t14/default.nix: add port = 5901 to greeter.wayvnc
  ├── nixos-build switch
  ├── grep "5901" /var/lib/greeter/.config/wayvnc/config     -> port=5901 (scenario 20)
  ├── grep "5901" /etc/greetd/hyprland.conf                  -> exec-once line has 5901 (scenario 21)
  ├── systemctl restart greetd
  ├── ss -tlnp | grep 5901                                   -> wayvnc listening on 5901 (scenario 22)
  ├── [MANUAL] VNC client -> t14:5901                        -> regreet visible (scenario 23)
  ├── [MANUAL] VNC client -> t14:5900                        -> connection refused (scenario 23)
  ├── RESTORE: remove port = 5901 from hosts/t14/default.nix
  ├── nixos-build switch
  │
  ▼
 Task 4.5: Negative test (Req 5, scenarios 17-19)
  │
  ├── Edit hosts/t14/default.nix: set greeter wayvnc.enable = false
  ├── nixos-build switch
  ├── grep -c "wayvnc" /etc/greetd/hyprland.conf             -> 0 (scenario 17)
  ├── ls /var/lib/greeter/.config/wayvnc/config              -> No such file (scenario 17)
  ├── systemctl restart greetd
  ├── ps aux | grep "[w]ayvnc" (in greeter context)          -> 0 (scenario 17)
  ├── RESTORE: set wayvnc.enable = true
  ├── nixos-build switch
  ├── grep -n "wayvnc" /etc/greetd/hyprland.conf             -> line present, contains -o DP-3 (scenario 18)
  ├── ls /var/lib/greeter/.config/wayvnc/config              -> exists (scenario 18)
  ├── [BUILD-TIME] nix flake check --no-build (all hosts)    -> passes, non-t14 has no artifacts (scenario 19)
  │
  ▼
 Build verification
  │
  ├── nix flake check --no-build                            -> passes (omarchy-nix + nixos-hosts)
  ├── nixos-build build (t14)                               -> passes
  │
  ▼
 DONE — all 29 scenarios verified
```

## Scenario Coverage Matrix

29 scenarios across 8 requirements (6 new scenarios from the output-selection delta + 2 modified scenarios), mapped to verification tasks:

| # | Requirement | Scenario | Task | Method | Automated? |
|---|-------------|----------|------|--------|------------|
| 1 | Hyprland Config Injection | wayvnc exec-once appears before greeter script | 4.1 | `grep -n` line comparison | CLI |
| 2 | Hyprland Config Injection [MODIFIED] | wayvnc uses configured address, port, and output (`-o DP-3` when set; no `-o` when empty) | 4.1 | `grep` for `-o DP-3`, `0.0.0.0`, `5900` | CLI |
| 3 | Hyprland Config Injection | Config file is rebuild-resistant | 4.1 | Physical reboot + re-`grep` | Semi-automated |
| 4 | wayvnc Config File Deployment | Config file exists with correct content | 4.2 | `cat` + verify key-values | CLI |
| 5 | wayvnc Config File Deployment | Correct ownership and permissions | 4.2 | `stat` -> owner/group/mode | CLI |
| 6 | wayvnc Config File Deployment | Config file survives reboot | 4.2 | Physical reboot + re-`stat` | Semi-automated |
| 7 | wayvnc Config File Deployment | Parent directories are correct | 4.2 | `ls -ld` parent dirs | CLI |
| 8 | wayvnc Config File Deployment | Readable by greeter user | 4.2 | `sudo -u greeter cat` | CLI |
| 9 | VNC Access at Login Screen [MODIFIED] | VNC client connects, displays regreet on DP-3 (landscape); DP-5 disabled by focusMonitor | 4.3 | Remmina + `hyprctl monitors` | Manual |
| 10 | VNC Access at Login Screen | PAM authentication succeeds | 4.3 | Enter valid credentials | Manual |
| 11 | VNC Access at Login Screen | PAM auth fails with wrong credentials | 4.3 | Enter invalid credentials | Manual |
| 12 | VNC Access at Login Screen | VNC-only does not affect physical display | 4.3 | Observe DP-3 during VNC session | Manual |
| 13 | Login Transition Handoff | Greeter wayvnc exits on authentication | 4.3 | `ps aux` after auth | CLI + Manual |
| 14 | Login Transition Handoff | User-session wayvnc takes over port 5900 | 4.3 | Remmina auto-reconnect + observe | Manual |
| 15 | Login Transition Handoff | VNC disconnect during handoff is brief | 4.3 | Time the disconnect | Manual |
| 16 | Login Transition Handoff | No orphaned listener without user wayvnc | 4.3 | `ss -tlnp` (requires temp disable of user wayvnc) | CLI + Manual |
| 17 | Opt-in Gating | Feature disabled removes all artifacts | 4.5 | `grep -c`, `ls`, `ps aux` after disable | CLI |
| 18 | Opt-in Gating | Feature re-enabled restores all artifacts (and `-o DP-3` line returns) | 4.5 | `grep`, `ls` after re-enable | CLI |
| 19 | Opt-in Gating | Disabled by default on non-t14 hosts | 4.5 | `nix flake check --no-build` | Build-time |
| 20 | Custom Port Configuration | Custom port in config file | 4.4 | `grep "5901"` config file | CLI |
| 21 | Custom Port Configuration | Custom port in Hyprland config | 4.4 | `grep "5901"` `hyprland.conf` | CLI |
| 22 | Custom Port Configuration | wayvnc binds to custom port at runtime | 4.4 | `ss -tlnp \| grep 5901` | CLI |
| 23 | Custom Port Configuration | VNC connect to custom port | 4.4 | Remmina -> t14:5901 + t14:5900 refused | Manual |
| 24 | Output Selection [NEW] | `output = "DP-3"` -> exec-once contains `-o DP-3` BEFORE address/port | 4.1 | `grep -o DP-3` ordering check | CLI |
| 25 | Output Selection [NEW] | `output = ""` (default) -> no `-o` flag, byte-identical to pre-change | 4.5 (build) + 4.1 (deployed) | `grep -c "\-o"` == 0 when default; build passes for non-t14 | CLI |
| 26 | Output Selection [NEW] | Invalid/unavailable output fails gracefully; regreet still launches on physical | 4.3 (edge case) | Manually set bad output temporarily, observe greeter still works | Manual |
| 27 | Greeter Focus Monitor Update [NEW] | AOC 2470W connected -> matches DP-3, disables DP-5, regreet on DP-3 only | 4.3 | `hyprctl monitors -j` during greeter; observe only DP-3 active | Manual |
| 28 | Greeter Focus Monitor Update [NEW] | AOC 2470W NOT connected (undocked) -> no match, no disable, greeter on eDP-1 | 4.3 (undocked) | Re-run greeter undocked, verify regreet on eDP-1 | Manual |
| 29 | Greeter Focus Monitor Update [NEW] | Both AOC monitors connected -> only DP-3 remains (DP-5 and eDP-1 disabled) | 4.3 (default docked state) | `hyprctl monitors -j` during greeter; verify DP-5 + eDP-1 disabled | Manual |

## File Changes

**Permanent (implementation) changes**:

| File | Repo | Change | Lines |
|------|------|--------|-------|
| `config.nix` | omarchy-nix | Add `output` option inside the `omarchy.greeter.wayvnc` submodule (after `enable_pam`) | +5 |
| `modules/nixos/system.nix` | omarchy-nix | Modify the `wayvncExec` let-binding to conditionally emit `-o ${output}` | +3 / -1 |
| `hosts/t14/default.nix` | nixos-hosts | Set `wayvnc.output = "DP-3"` inside the existing `wayvnc.enable` block | +1 |
| `hosts/t14/default.nix` | nixos-hosts | Update `focusMonitor` from `"LEN G24"` to `"AOC 2470W"` | -1 / +1 |

**Total**: ~10 lines across 2 repos.

**Temporary verification-only mutations** (reverted immediately after their respective tests):

| File | Temporary change | Reverted after | Purpose |
|------|------------------|----------------|---------|
| `hosts/t14/default.nix` (wayvnc block) | Add `port = 5901;` | Task 4.4 complete | Test custom port propagation |
| `hosts/t14/default.nix` (wayvnc block) | Set `wayvnc.enable = false;` | Task 4.5 complete | Test opt-in gating cleanup |
| `hosts/t14/default.nix` (wayvnc block) | Temporarily set `wayvnc.output = "DP-9"` | Task 4.3 edge case | Verify invalid-output fails gracefully |

**Source files (read-only reference — NOT modified by this design beyond the lines listed above)**:

| File | Repo | Role |
|------|------|------|
| `config.nix:368-395` | omarchy-nix | `omarchy.greeter.wayvnc` submodule (enable, address, port, enable_pam, **output**) |
| `modules/nixos/system.nix:11-21` | omarchy-nix | `wayvncConfigFile` let-binding (`pkgs.writeText`) |
| `modules/nixos/system.nix:71-78` | omarchy-nix | `systemd.tmpfiles.rules` for config file + parent dirs |
| `modules/nixos/system.nix:256-260` | omarchy-nix | `wayvncExec` let-binding (now conditionally emits `-o`) |
| `modules/nixos/system.nix:263` | omarchy-nix | Injection point: `${wayvncExec}` before `exec-once = ${greeterScript}` |
| `modules/nixos/system.nix:196-225` | omarchy-nix | Greeter monitor-focus script (uses `FOCUS='${cfg.greeter.focusMonitor}'`) |
| `hosts/t14/default.nix:184` | nixos-hosts | `focusMonitor` value (changes to `"AOC 2470W"`) |
| `hosts/t14/default.nix:207` | nixos-hosts | `wayvnc.enable = true` line (now joined by `output = "DP-3"`) |

**Deployed artifacts on t14 (verified)**:

| Artifact | Path | Expected content (post-fix) |
|----------|------|------------------------------|
| Hyprland config | `/etc/greetd/hyprland.conf` | `exec-once = /nix/store/...-wayvnc-.../bin/wayvnc -o DP-3 0.0.0.0 5900 &` BEFORE `exec-once = /nix/store/...-greetd-regreet-start` |
| wayvnc config | `/var/lib/greeter/.config/wayvnc/config` | `address=0.0.0.0\nport=5900\nenable_pam=true` (owner: greeter:greeter, mode: 0640) |

## Interfaces / Contracts

### Option tree (after this change)

```
omarchy.greeter.wayvnc.enable      : bool   (default: false)   <- t14 sets true
omarchy.greeter.wayvnc.address     : str    (default: "0.0.0.0")
omarchy.greeter.wayvnc.port        : port   (default: 5900)
omarchy.greeter.wayvnc.enable_pam  : bool   (default: true)
omarchy.greeter.wayvnc.output      : str    (default: "")       <- NEW; t14 sets "DP-3"
omarchy.greeter.focusMonitor       : str    (default: "")       <- t14 changes "LEN G24" -> "AOC 2470W"
```

Note: the implementation uses `enable_pam` (snake_case) — this matches both the existing config.nix definition and the wayvnc config-file key. The prior design chart's `enablePam` (camelCase) was a typo in the chart only, not the implementation.

### Exec-once line contract

For any host with `wayvnc.enable = true`:

| `output` value | Generated `exec-once` line |
|---------------|-----------------------------|
| `""` (default) | `exec-once = /nix/store/.../bin/wayvnc <address> <port> &` (unchanged) |
| `"DP-3"` | `exec-once = /nix/store/.../bin/wayvnc -o DP-3 <address> <port> &` |
| `"eDP-1"` | `exec-once = /nix/store/.../bin/wayvnc -o eDP-1 <address> <port> &` |

The `-o` flag is always positioned immediately after the wayvnc binary path and before the address/port arguments. This matches wayvnc's argument parser (positional `address port` come last).

### Verification command contract

Each verification step has a defined command and expected output (updated to include the new `-o DP-3` assertion):

| Step | Command | Expected output |
|------|---------|-----------------|
| 4.1a | `grep -n "wayvnc" /etc/greetd/hyprland.conf` | Line number N1, contains `/nix/store` path + `-o DP-3` + `0.0.0.0` + `5900` + `&` |
| 4.1b | `grep -n "greetd-regreet-start" /etc/greetd/hyprland.conf` | Line number N2, where N2 > N1 |
| 4.1c (NEW) | `grep -o "\-o DP-3" /etc/greetd/hyprland.conf` | `-o DP-3` appears exactly once before `0.0.0.0` |
| 4.2a | `stat -c '%U %G %a' /var/lib/greeter/.config/wayvnc/config` | `greeter greeter 640` |
| 4.2b | `cat /var/lib/greeter/.config/wayvnc/config` | Three lines: `address=0.0.0.0`, `port=5900`, `enable_pam=true` (no `output` key — wayvnc config file does not support `output`) |
| 4.2c | `sudo -u greeter cat /var/lib/greeter/.config/wayvnc/config` | Same content, no permission error |
| 4.2d | `ls -ld /var/lib/greeter/.config /var/lib/greeter/.config/wayvnc` | Both exist, owner greeter:greeter |
| 4.3a | `ps aux \| grep "[w]ayvnc.*5900"` | At least 1 process (greeter wayvnc) |
| 4.3b | `ss -tlnp \| grep 5900` | wayvnc listening on 0.0.0.0:5900 |
| 4.3c (NEW) | `hyprctl monitors -j \| jq '.[].name'` (during greeter) | Only `DP-3` present (DP-5, eDP-1 disabled) |
| 4.4a | `grep "5901" /var/lib/greeter/.config/wayvnc/config` | `port=5901` |
| 4.4b | `grep "5901" /etc/greetd/hyprland.conf` | exec-once line with `5901` and `-o DP-3` still present |
| 4.4c | `ss -tlnp \| grep 5901` | wayvnc listening on 0.0.0.0:5901 |
| 4.5a | `grep -c "wayvnc" /etc/greetd/hyprland.conf` | `0` |
| 4.5b | `ls /var/lib/greeter/.config/wayvnc/config 2>&1` | `No such file or directory` |

## Testing Strategy

The design is both an implementation and a testing strategy. Implementation is verified by `nix flake check --no-build` (build-time) plus Phase 4 manual verification (runtime). Verification is organized in five tasks mapped to the 29 spec scenarios.

### Implementation verification (build-time)

```bash
# 1. omarchy-nix self-check after adding the `output` option
# (run inside omarchy-nix repo)
nix flake check --no-build

# 2. nixos-hosts full check after bumping omarchy-nix + setting output/focusMonitor
# (run inside nixos-hosts repo)
nix flake check --no-build        # MUST pass for all hosts (rog, thinkcentre, mact2, t14)
format-nix                         # format both modified files
```

Pass criteria: flake check exits 0 on both repos; non-t14 hosts produce byte-identical exec-once lines (no `-o` flag because their `output` defaults to `""`).

### Task 4.1 — Hyprland config inspection (Req 1, scenarios 1-3, 24)

**Goal**: Verify `/etc/greetd/hyprland.conf` contains the wayvnc exec-once line before the regreet start line, with full store path, `-o DP-3` flag, backgrounding, and correct address/port.

**Commands**:
```bash
# Scenario 1: wayvnc exec-once appears before greeter script
grep -n "wayvnc" /etc/greetd/hyprland.conf
grep -n "greetd-regreet-start" /etc/greetd/hyprland.conf
# Assert: wayvnc line number < regreet line number
# Assert: wayvnc line contains /nix/store (full binary path)
# Assert: wayvnc line ends with & (backgrounded)

# Scenario 2 (MODIFIED): wayvnc uses configured address, port, and output
# The wayvnc line should contain "-o DP-3" positioned before "0.0.0.0 5900"
grep -o "\-o DP-3" /etc/greetd/hyprland.conf    # exactly one match

# Scenario 24 (NEW): output flag placed before address/port arguments
# The string "-o DP-3" must appear before "0.0.0.0" on the same line
grep "wayvnc -o DP-3 0.0.0.0" /etc/greetd/hyprland.conf    # one match

# Scenario 3: Config file is rebuild-resistant
# Physical reboot t14, then re-run grep -n "wayvnc" /etc/greetd/hyprland.conf
# Assert: line still present, still before regreet, still containing -o DP-3
```

**Pass criteria**: wayvnc line exists, line number < regreet line number, full `/nix/store` path, `-o DP-3` flag positioned before address and port, `&` suffix, `0.0.0.0 5900` arguments.

### Task 4.2 — wayvnc config inspection (Req 2, scenarios 4-8)

**Goal**: Verify `/var/lib/greeter/.config/wayvnc/config` exists with correct content, ownership, permissions, parent directories, and is readable by the greeter user.

```bash
# Scenario 4: Config file exists with correct content
cat /var/lib/greeter/.config/wayvnc/config
# Assert: address=0.0.0.0
# Assert: port=5900
# Assert: enable_pam=true
# Assert: NO `output=` key (wayvnc config file does NOT support output selection — CLI only)

# Scenario 5: Correct ownership and permissions
stat -c '%U %G %a' /var/lib/greeter/.config/wayvnc/config
# Assert: greeter greeter 640

# Scenario 6: Config file survives reboot
# Physical reboot, then re-run stat + cat
# Assert: same content, ownership, mode

# Scenario 7: Parent directories are correct
ls -ld /var/lib/greeter/.config /var/lib/greeter/.config/wayvnc
# Assert: both exist, owner greeter:greeter

# Scenario 8: Readable by greeter user
sudo -u greeter cat /var/lib/greeter/.config/wayvnc/config
# Assert: content displayed, no permission error
```

**Pass criteria**: file exists, content matches configured options (no `output` key — output is CLI-only), `greeter:greeter 0640`, parent dirs exist and owned by greeter, greeter user can read.

### Task 4.3 — E2E VNC test (Req 3, scenarios 9-12, 26; Req 4, scenarios 13-16; Focus Monitor Req, scenarios 27-29)

**Goal**: Verify VNC client can connect to t14:5900 pre-login, see regreet on DP-3 (landscape), authenticate, and auto-reconnect to the user desktop during the handoff. Also verify the focusMonitor correctly disables DP-5 and the output flag fails gracefully when set to an invalid name.

**Prerequisite**: Another device with a VNC client (Remmina on rog, or any VNC viewer). Physical access to t14 for observing DP-3.

**Commands (CLI-verifiable preconditions)**:
```bash
# Restart greeter to simulate cold boot
systemctl restart greetd

# Scenario 9 precondition: wayvnc process running
ps aux | grep "[w]ayvnc.*5900"
# Assert: >=1 process

# Port listening
ss -tlnp | grep 5900
# Assert: wayvnc listening on 0.0.0.0:5900

# Scenario 27/29 (NEW): only DP-3 active during greeter (focusMonitor working)
hyprctl monitors -j | jq '[.[] | .name] | sort'
# Assert: ["DP-3"] only (DP-5 + eDP-1 disabled)
```

**Manual steps (VNC client)**:
```
# Scenario 9 (MODIFIED): VNC client connects, displays regreet on DP-3 (landscape)
# - Open Remmina, create VNC connection to t14:5900
# - Assert: regreet login screen visible (LANDSCAPE orientation, 1920x1080 — not portrait)
# - Assert: keyboard input works (login fields respond to typing)
# - Assert: mouse input works (pointer moves within VNC session)

# Scenario 10: PAM authentication succeeds
# - Enter valid glats credentials in regreet
# - Assert: VNC session established, regreet UI interactive

# Scenario 11: PAM auth fails with wrong credentials
# - Disconnect, reconnect, enter invalid credentials
# - Assert: connection rejected
# - Assert: wayvnc process still running (ps aux | grep "[w]ayvnc.*5900" >= 1)

# Scenario 12: VNC-only does not affect physical display
# - During VNC session, observe t14 physical display (DP-3)
# - Assert: physical display shows regreet normally
# - Assert: both displays reflect same greeter state

# Scenario 13: Greeter wayvnc exits on authentication
# - Authenticate successfully via VNC (or physical display)
# - After regreet exits: ps aux | grep "[w]ayvnc.*5900"
# - Assert: 0 greeter wayvnc processes
# - Assert: user Hyprland session starts

# Scenario 14: User-session wayvnc takes over port 5900
# - Remmina auto-reconnects (or manually reconnect)
# - Assert: user desktop visible within 5 seconds
# - Assert: ss -tlnp | grep 5900 shows wayvnc (user session)

# Scenario 15: VNC disconnect is brief
# - Time the disconnect from auth to reconnect
# - Assert: ~1 second (acceptable range: <5 seconds)

# Scenario 16: No orphaned listener without user wayvnc (EDGE CASE)
# - Edit hosts/t14/default.nix: set omarchy.wayvnc.enable = false (user-session wayvnc, line 176)
# - nixos-build switch, systemctl restart greetd
# - Authenticate via physical display
# - ss -tlnp | grep 5900 -> Assert: not bound
# - RESTORE: omarchy.wayvnc.enable = true, nixos-build switch

# Scenario 26 (NEW): Invalid output fails gracefully
# - Edit hosts/t14/default.nix: temporarily set wayvnc.output = "DP-9"
# - nixos-build switch, systemctl restart greetd
# - Assert: regreet still launches on physical display (DP-3 via focusMonitor fallback)
# - Assert: VNC connection to t14:5900 either refused OR shows blank/first-available
# - RESTORE: wayvnc.output = "DP-3", nixos-build switch

# Scenario 28 (NEW): Undocked fallback
# - Physically disconnect both external monitors (undock t14)
# - Reboot or systemctl restart greetd
# - Assert: no monitor matches "AOC 2470W" (focusMonitor)
# - Assert: greeter script executes no-op (all monitors stay)
# - Assert: regreet visible on eDP-1 (laptop screen)
# - RESTORE: dock t14 again
```

**Pass criteria**: regreet visible via VNC pre-login on DP-3 landscape (not portrait DP-5), keyboard/mouse work, PAM auth succeeds/fails correctly, physical display unaffected, DP-5 disabled during greeter session, greeter wayvnc exits on auth, user wayvnc takes over within 5s, no orphaned listener when user wayvnc disabled, invalid output fails gracefully, undocked fallback works on eDP-1.

### Task 4.4 — Custom port test (Req 6, scenarios 20-23)

**Goal**: Verify setting `omarchy.greeter.wayvnc.port = 5901` propagates through the entire Nix pipeline to runtime, and that the `-o DP-3` flag is preserved alongside the custom port.

```bash
# 1. Temporary config change
# Edit hosts/t14/default.nix, add port = 5901 to greeter.wayvnc block:
#   wayvnc = {
#     enable = true;
#     output = "DP-3";
#     port = 5901;
#   };

# 2. Deploy
nixos-build switch

# Scenario 20: Custom port in config file
grep "5901" /var/lib/greeter/.config/wayvnc/config
# Assert: port=5901

# Scenario 21: Custom port in Hyprland config (preserves -o DP-3)
grep "5901" /etc/greetd/hyprland.conf
# Assert: exec-once line contains "5901" AND "-o DP-3" (both present)

# 3. Restart greeter
systemctl restart greetd

# Scenario 22: wayvnc binds to custom port at runtime
ss -tlnp | grep 5901
# Assert: wayvnc listening on 0.0.0.0:5901

# Scenario 23: VNC connect to custom port
# [MANUAL] Remmina -> t14:5901 -> Assert: regreet visible
# [MANUAL] Remmina -> t14:5900 -> Assert: connection refused (port not bound)

# 4. RESTORE
# Remove port = 5901 from hosts/t14/default.nix (revert to default 5900)
nixos-build switch
```

**Pass criteria**: config file has `port=5901`, `hyprland.conf` has both `5901` and `-o DP-3`, wayvnc listens on 5901, VNC connects on 5901 and fails on 5900, config restored to 5900 after test.

### Task 4.5 — Negative test (Req 5, scenarios 17-19, 25)

**Goal**: Verify that `enable = false` removes all greeter wayvnc artifacts (including the `-o DP-3` line), that re-enabling restores them, and that non-t14 hosts never emit the `-o` flag.

```bash
# 1. Temporary config change
# Edit hosts/t14/default.nix, set greeter.wayvnc.enable = false:
#   wayvnc = {
#     enable = false;
#     output = "DP-3";
#   };

# 2. Deploy
nixos-build switch

# Scenario 17: Feature disabled removes all artifacts
grep -c "wayvnc" /etc/greetd/hyprland.conf
# Assert: 0

ls /var/lib/greeter/.config/wayvnc/config 2>&1
# Assert: "No such file or directory"

systemctl restart greetd
# Wait for greeter to start, then:
ps aux | grep "[w]ayvnc"
# Assert: 0 wayvnc processes in greeter session

# 3. RESTORE (also verifies scenario 18)
# Edit hosts/t14/default.nix, set greeter.wayvnc.enable = true
nixos-build switch

# Scenario 18: Feature re-enabled restores all artifacts (including -o DP-3)
grep -n "wayvnc" /etc/greetd/hyprland.conf
# Assert: line present, before regreet, containing "-o DP-3 0.0.0.0 5900 &"

ls /var/lib/greeter/.config/wayvnc/config
# Assert: file exists

systemctl restart greetd
ps aux | grep "[w]ayvnc.*5900"
# Assert: >=1 process

# Scenario 19: Disabled by default on non-t14 hosts
nix flake check --no-build
# Assert: passes (rog, thinkcentre, mact2 have output="" by default)

# Scenario 25 (NEW): Empty output default produces no -o flag
# Build a non-t14 host's hyprland.conf (if it ever enables wayvnc)
# and verify no "-o" appears in the exec-once line.
# For hosts with wayvnc.enable = false (all non-t14), this is trivially
# satisfied because the exec-once line is not emitted at all.
# The build-time flake check above covers this: no non-t14 host sets output.
```

**Pass criteria**: no wayvnc in `hyprland.conf` when disabled, no config file, no process; all restored (with `-o DP-3`) when re-enabled; non-t14 hosts unaffected (build passes, no `-o` flag emitted for hosts with `output = ""`).

## Edge Cases and Rollback

### Edge case: wayvnc fails to start

**Behavior**: The wayvnc exec-once is backgrounded with `&`. If wayvnc fails (e.g., port already bound, missing Wayland socket, output name not found), the process exits silently. Regreet launches normally on the physical display.

**Impact**: Greeter works without VNC. No regression to physical login.

**Debug**: Check `journalctl -u greetd` for wayvnc stderr output. Verify `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR` are set in the greeter Hyprland environment. For output-name failures specifically, run wayvnc with `-v` (verbose) temporarily to see the list of detected outputs at startup.

### Edge case: Output name not found (new, from this change)

**Behavior**: If `wayvnc.output` references a monitor that does not exist on the current hardware (e.g., a stale `DP-3` after a dock change reassigns outputs to DP-4), wayvnc fails to find the output during startup. Depending on wayvnc's version, it either exits immediately or falls back to capturing the first available output.

**Impact**: VNC is partially or fully unavailable; regreet on the physical display is unaffected because wayvnc is backgrounded.

**Debug**: `hyprctl monitors -j | jq '.[].name'` lists currently connected output short names. If `DP-3` is missing, update `omarchy.greeter.wayvnc.output` to the new name (or set it to `""` to fall back to first-available behavior).

**Verification**: Scenario 26 explicitly tests this by temporarily setting `output = "DP-9"`.

### Edge case: focusMonitor no match (laptop undocked)

**Behavior**: If `focusMonitor = "AOC 2470W"` but no monitor's description contains that substring (e.g., laptop undocked, only eDP-1 active), the greeter script's `TARGET_MON` variable is empty. The script skips the disable loop (guarded by `if [ -n "$TARGET_MON" ]`). Phase 2 then disables eDP-1 only when externals are connected — with no externals, eDP-1 stays active and regreet appears on it.

**Impact**: Undocked greeter session works correctly on the laptop screen. This is scenario 28 in the matrix.

### Edge case: tmpfiles rule fails

**Behavior**: If the greeter home directory (`/var/lib/greeter`) doesn't exist, the tmpfiles `C+` rule cannot create the file. NixOS activation reports a warning.

**Impact**: wayvnc starts without a config file and uses compiled-in defaults (address `0.0.0.0`, port `5900`, PAM enabled). Functionally equivalent to the configured values for the default case, but custom port/address would not take effect. **Note**: output selection is NOT affected by this — the `-o` flag comes from the `exec-once` line in `hyprland.conf`, which does not depend on the wayvnc config file.

**Debug**: `systemctl status systemd-tmpfiles-setup.service` and `journalctl -u systemd-tmpfiles-setup.service`.

**Note**: The implementation creates parent directories with `d` type rules before the `C+` rule, so this edge case is mitigated.

### Edge case: Port conflict (greeter vs user wayvnc)

**Behavior**: Greeter wayvnc and user-session wayvnc never run simultaneously. Greetd exits the greeter Hyprland session before the user session starts. The port is freed before the user wayvnc binds.

**Impact**: None — no conflict possible by design.

### Rollback

The implementation change is two independent commits (one per repo), each individually revertible:

1. **omarchy-nix**: Revert the commit adding the `output` option and the `wayvncExec` change. All hosts return to the default behavior (no `-o` flag).
2. **nixos-hosts**: Revert `output = "DP-3"` (or set it back to `""`), and revert `focusMonitor` to `"LEN G24"`.

Rollback time: one `git revert` + rebuild per repo (~5 minutes total). At any point during verification, the greeter can be rolled back further to disable wayvnc entirely:

```bash
# Edit hosts/t14/default.nix
# Set omarchy.greeter.wayvnc.enable = false
nixos-build switch
```

This removes all greeter VNC artifacts. The existing regreet login screen works regardless of wayvnc.

**NixOS generation rollback** (if a deploy causes issues):
```bash
# List generations
nix-env --list-generations --profile /nix/var/nix/profiles/system

# Rollback to previous generation
sudo nixos-rebuild --rollback switch
```

## Migration

N/A — no data migration, no state transition. The new `output` option defaults to `""`, so all existing hosts are byte-equivalent before and after the omarchy-nix bump. t14 opts into the non-default value (`"DP-3"`) and updates its `focusMonitor` from `"LEN G24"` to `"AOC 2470W"`. The `focusMonitor` change is host-local and affects only the greeter session — user-session monitor configuration is untouched.

**Upgrade note**: If t14's hardware changes (dock replaced, monitors plugged into different ports), the `DP-3` short name may move. The kernel/drm subsystem assigns `DP-N` names based on connector enumeration order, not on physical port labels. Mitigation: `hyprctl monitors -j | jq '.[].name'` lists currently-connected short names; update `omarchy.greeter.wayvnc.output` to match. The failure mode is graceful — VNC becomes unavailable but regreet on the physical display is unaffected.

## Open Questions

1. **SSH access to t14**: The exploration noted SSH failed with a host key verification error from a non-t14 machine. Verification requires either SSH access (fix `known_hosts`) or physical access to t14. This is an access prerequisite, not a technical blocker.

2. **VNC client availability**: Task 4.3 requires a VNC client on another device. Remmina is installed on rog. Fallback: `vncdotool` (CLI VNC client) or `gvncviewer` if Remmina is unavailable.

3. **Scenario 16 (no orphaned listener)**: This edge case requires temporarily disabling user-session wayvnc (`omarchy.wayvnc.enable = false` at line 176 of t14/default.nix), which is outside the greeter-wayvnc feature scope. Execute it last (after all other E2E tests) to avoid disrupting the user-session VNC that scenario 14 depends on. Optional — if the user-session wayvnc is always enabled on t14, scenario 16 documents the expected behavior but may not need live testing.

4. **Scenario 28 (undocked fallback)**: Requires physically undocking t14 to verify the focusMonitor no-match fallback. If undocking is impractical during the verification session, this scenario can be deferred and documented as "expected per code review" (the greeter script's `if [ -n "$TARGET_MON" ]` guard makes the no-op fallback explicit in the source).

5. **Output name stability**: DP-3 is stable for t14's fixed hardware (Lenovo dock + two AOC monitors). If the dock is replaced or monitors are moved, the short name may change. The option is explicit and documented — a future enhancement could resolve a description substring to a short name before passing to wayvnc, but that requires wayvnc to start after the greeter script, which breaks the current "wayvnc before regreet" ordering. Out of scope for this change.

## Build Verification

| Check | Repo | Command | Status |
|-------|------|---------|--------|
| Flake evaluation (all hosts) | nixos-hosts | `nix flake check --no-build` | To run after implementation |
| omarchy-nix self-check | omarchy-nix | `nix flake check --no-build` | To run after adding `output` option |
| t14 build | nixos-hosts | `nixos-build build` (t14) | To run during Phase 4 deploy |
| Format check | both | `format-nix` | To run if any temporary changes are made |
| Non-t14 hosts unaffected | nixos-hosts | `nix build .#nixosConfigurations.{rog,thinkcentre}.config.system.build.toplevel --dry-run` | Confirms byte-equivalence (no `-o` flag emitted) |