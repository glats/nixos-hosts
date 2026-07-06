# greeter-wayvnc-verification Specification (Delta)

## Purpose

Delta spec adding output selection and focus monitor update requirements to the base `greeter-wayvnc-verification` spec. This delta ADDS two new requirements (Output Selection, Greeter Focus Monitor Update) and MODIFIES two existing requirements (Hyprland Config Injection scenario 2, VNC Access at Login Screen scenario 9) to reflect the `-o` flag behavior and the DP-3 capture target.

The base spec defines verification requirements for the greetd/regreet Hyprland VNC configuration on t14. All code for the original `greetd-wayvnc-feasibility` change (phases 1-3) is already complete. This delta extends the spec to cover the output selection fix (`omarchy.greeter.wayvnc.output`) and the `focusMonitor` update from `"LEN G24"` to `"AOC 2470W"`.

## ADDED Requirements

### Requirement: Output Selection

The system SHALL allow explicit output selection for greeter wayvnc via `omarchy.greeter.wayvnc.output`. When set to a non-empty string, wayvnc SHALL capture only the specified output using the `-o` CLI flag. When empty (default), wayvnc SHALL use its default behavior (captures the first available output) and SHALL NOT include the `-o` flag in the exec-once line.

#### Scenario: output set to specific monitor name [NEW]

- GIVEN `omarchy.greeter.wayvnc.output` is set to `"DP-3"` in `hosts/t14/default.nix`
- AND the system has been deployed via `nixos-build switch`
- WHEN inspecting `/etc/greetd/hyprland.conf`
- THEN the wayvnc exec-once line contains `-o DP-3` BEFORE the address and port arguments
- AND the generated line has the form: `exec-once = .../wayvnc -o DP-3 <address> <port> &`

#### Scenario: output is empty (default) preserves backward compatibility [NEW]

- GIVEN `omarchy.greeter.wayvnc.output` is set to `""` (the default value)
- AND the system has been deployed
- WHEN inspecting `/etc/greetd/hyprland.conf`
- THEN the wayvnc exec-once line contains NO `-o` flag
- AND the generated line has the same form as before the `output` option was introduced (no behavioral change)
- AND the `nix flake check --no-build` SHALL pass on all hosts (rog, thinkcentre, mact2) that do not set a custom `output` value

#### Scenario: invalid or unavailable output name fails gracefully [NEW]

- GIVEN `omarchy.greeter.wayvnc.output` is set to a monitor name that does not exist on the current hardware (e.g., `"DP-9"`)
- AND the system is deployed and the greeter Hyprland session starts
- WHEN wayvnc attempts to start with `-o DP-9`
- THEN wayvnc SHALL either exit with an error (process terminates) OR capture the first available output (implementation-dependent fallback)
- AND regreet SHALL still launch and be visible on the physical display (wayvnc is backgrounded with `&`, so its failure does not block the greeter script)
- AND the greeter session SHALL be fully functional for local (physical) login

### Requirement: Greeter Focus Monitor Update

The greeter focus monitor on t14 SHALL target `"AOC 2470W"` (the landscape external monitor at DP-3) instead of the previous `"LEN G24"`. This SHALL ensure the greeter script correctly identifies and focuses the landscape external monitor when connected, and SHALL disable the portrait monitor (DP-5, AOC 24P1W1) during the greeter session.

#### Scenario: AOC 2470W connected — focus monitor matches DP-3 [NEW]

- GIVEN `omarchy.greeter.focusMonitor` is set to `"AOC 2470W"` in `hosts/t14/default.nix`
- AND the AOC 2470W monitor is connected (appears in `hyprctl monitors` output)
- AND the system is deployed and the greeter session starts
- WHEN the greeter script executes its monitor-focus logic
- THEN the script SHALL identify the monitor whose description contains `"AOC 2470W"` (expected to be DP-3)
- AND the script SHALL disable all other external monitors (including DP-5)
- AND the greeter session SHALL display regreet on the AOC 2470W (DP-3) monitor only

#### Scenario: AOC 2470W NOT connected — fallback graceful [NEW]

- GIVEN `omarchy.greeter.focusMonitor` is set to `"AOC 2470W"`
- AND the AOC 2470W monitor is NOT connected (e.g., laptop undocked)
- AND the system is deployed and the greeter session starts
- WHEN the greeter script executes its monitor-focus logic
- THEN the script SHALL find no monitor matching `"AOC 2470W"`
- AND the script SHALL fall back gracefully: no monitors are disabled, the greeter SHALL display on the available output (eDP-1 laptop screen)
- AND the greeter session SHALL be fully functional

#### Scenario: both AOC monitors connected — only DP-3 remains active [NEW]

- GIVEN `omarchy.greeter.focusMonitor` is set to `"AOC 2470W"`
- AND both AOC monitors are connected: DP-3 (AOC 2470W, landscape) and DP-5 (AOC 24P1W1, portrait)
- AND the system is deployed and the greeter session starts
- WHEN the greeter script executes its monitor-focus logic
- THEN the script SHALL identify DP-3 as the focus target (description contains `"AOC 2470W"`)
- AND the script SHALL disable DP-5 (AOC 24P1W1, portrait)
- AND the script SHALL also disable eDP-1 (laptop screen, per existing external-monitor logic in phase 2)
- AND ONLY DP-3 SHALL remain active during the greeter session
- AND regreet SHALL appear on DP-3 only

## MODIFIED Requirements

### Requirement: Hyprland Config Injection

The generated `/etc/greetd/hyprland.conf` SHALL contain an `exec-once` line launching wayvnc, positioned BEFORE the `exec-once` line that starts `greetd-regreet-start`, when `omarchy.greeter.wayvnc.enable` is `true`. When `omarchy.greeter.wayvnc.output` is set to a non-empty value, the wayvnc exec-once line SHALL include the `-o <output>` flag before the address and port arguments.

#### Scenario: wayvnc exec-once appears before greeter script

- GIVEN the t14 host has `omarchy.greeter.wayvnc.enable = true`
- AND the system has been deployed via `nixos-build switch`
- WHEN inspecting `/etc/greetd/hyprland.conf`
- THEN a line matching `exec-once = .../wayvnc ... 5900 &` appears BEFORE any line matching `exec-once = .../greetd-regreet-start`
- AND the wayvnc exec-once uses the full `/nix/store` path to the wayvnc binary
- AND the wayvnc process is backgrounded with `&`

#### Scenario: wayvnc exec-once uses configured address, port, and output [MODIFIED]

- GIVEN `omarchy.greeter.wayvnc.address` is set to `"0.0.0.0"` (default)
- AND `omarchy.greeter.wayvnc.port` is set to `5900` (default)
- WHEN inspecting `/etc/greetd/hyprland.conf`
- THEN the wayvnc exec-once line contains `0.0.0.0` as the bind address
- AND contains `5900` as the port argument
- AND when `omarchy.greeter.wayvnc.output` is set to a non-empty value (e.g., `"DP-3"`), the wayvnc exec-once line SHALL contain `-o DP-3` positioned BEFORE the address and port arguments
- AND when `omarchy.greeter.wayvnc.output` is `""` (default), the wayvnc exec-once line SHALL contain NO `-o` flag (backward compatible, preserves existing behavior for all other hosts)

#### Scenario: Config file is rebuild-resistant

- GIVEN the system has been deployed
- WHEN the t14 reboots
- THEN `/etc/greetd/hyprland.conf` still contains the wayvnc exec-once line in the correct position

### Requirement: VNC Access at Login Screen (E2E)

A VNC client connecting to the configured address and port SHALL display the regreet login screen and accept user interaction before any user has authenticated. When `omarchy.greeter.wayvnc.output` is configured to a specific output, the VNC session SHALL display that output's content.

#### Scenario: VNC client connects and displays regreet [MODIFIED]

- GIVEN the t14 has been cold-booted (or greetd restarted via `systemctl restart greetd`)
- AND no user is currently logged in
- AND `omarchy.greeter.wayvnc.enable` is `true`
- AND the wayvnc process is running in the greeter session (verify with `ps aux | grep -c "[w]ayvnc.*5900"` reporting at least 1)
- WHEN a VNC client (e.g., Remmina) connects to `t14:5900` (or the configured address/port)
- THEN the VNC client displays the regreet login screen
- AND keyboard input is accepted (the login fields respond to typing)
- AND mouse input is accepted (pointer moves within the VNC session)
- AND when `omarchy.greeter.wayvnc.output` is set to `"DP-3"`, the VNC display SHALL show the content of the DP-3 output (AOC 2470W, landscape, 1920x1080) rather than the first available output
- AND when `omarchy.greeter.focusMonitor` is set to `"AOC 2470W"`, DP-5 (portrait) SHALL be disabled, and the VNC view SHALL show only regreet on the landscape DP-3 output

#### Scenario: PAM authentication via VNC succeeds

- GIVEN a VNC client is connected to the greeter wayvnc
- AND `omarchy.greeter.wayvnc.enable_pam` is `true` (default)
- AND the VNC client is configured with VeNCrypt authentication
- WHEN valid Unix credentials for the `glats` user are provided
- THEN the VNC session is established
- AND the user can interact with the regreet greeter UI

#### Scenario: PAM authentication via VNC fails with wrong credentials

- GIVEN a VNC client is connected to the greeter wayvnc
- AND `omarchy.greeter.wayvnc.enable_pam` is `true`
- WHEN invalid credentials are provided
- THEN the VNC connection is rejected
- AND the greeter wayvnc process remains running (available for another connection attempt)

#### Scenario: VNC-only operation does not affect physical display

- GIVEN the t14 physical display (eDP-1) shows the regreet greeter
- AND a VNC client is connected to the greeter wayvnc
- WHEN the VNC client interacts with the greeter (typing, mouse movement)
- THEN the physical display continues to show regreet normally
- AND both the physical display and VNC session reflect the same greeter state
