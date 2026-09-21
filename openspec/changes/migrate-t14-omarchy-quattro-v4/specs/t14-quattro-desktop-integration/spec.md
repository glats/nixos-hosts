# T14 Quattro Specification

## Requirements

### Requirement: Isolated T14 Boundary

`nixos-hosts` SHALL provide t14 a newer coherent Nixpkgs/HM/Hyprland/Qt/Quickshell boundary. It MUST NOT change global 26.05 or other hosts. `omarchy-nix` MUST use it exclusively for v4.

#### Scenario: [t14] Evaluate isolated host boundary

- GIVEN v4 t14 configuration is selected
- WHEN t14 NixOS and standalone HM outputs evaluate
- THEN Quattro uses that boundary and mact2 global 26.05

#### Scenario: [t14] Reject mixed desktop packages

- GIVEN Quickshell or Home Manager would resolve from a different package boundary
- WHEN the t14 configuration is evaluated
- THEN evaluation MUST fail or exclude the incoherent configuration

### Requirement: Quattro Runtime and Lua Ownership

`omarchy-nix` MUST own Quickshell, QML/assets, IPC, Lua, and themes. Lua MUST launch one `omarchy-shell`. V4 MUST NOT launch Waybar, Walker, Mako, SwayOSD, Swaybg, Hypridle, Hyprlock, or Hyprpolkitagent.

#### Scenario: [t14] Start the v4 desktop

- GIVEN a fresh t14 session
- WHEN Hyprland starts its Lua autostart
- THEN one shell provides bar, launcher, notifications, OSD, lock, and polkit
- AND no replaced v3 daemon is running or autostarted

### Requirement: T14 Host Policy

`nixos-hosts` MUST own t14 HDM, WayVNC, Edge, SOPS, hardware, boot, and network policy. Quattro MUST NOT replace HDM, WayVNC, or Edge wrapper/policy/MIME/launch behavior. Lua MAY adapt only integration boundaries and MUST NOT become a monitor-profile writer.

#### Scenario: [t14] Retain local host behavior

- GIVEN Quattro v4 is active
- WHEN docked, remotely logged in, and Edge is launched
- THEN HDM, WayVNC handoff, Edge XWayland, and MIME work

### Requirement: Pre-Login Authentication Boundary

t14 MUST retain greetd with ReGreet for pre-login authentication. Quickshell MUST start only after a user login and MUST NOT replace or run within the greeter session.

#### Scenario: [t14] Authenticate before the user session

- GIVEN t14 is at its login screen
- WHEN a user supplies valid credentials through ReGreet
- THEN ReGreet MUST complete authentication before the user session starts
- AND Quickshell MUST start only in that user session

#### Scenario: [t14] Independently validate the greeter path

- GIVEN ReGreet is displayed before login
- WHEN keyboard entry, focus traversal, and VNC access are tested independently
- THEN each check MUST succeed without requiring Quickshell

### Requirement: Authoritative Monitor Profiles

HDM MUST remain the sole authoritative service for t14 dock and lid monitor profiles, using UPower and Hyprland IPC. Quattro Lua and monitor hooks MUST NOT write competing monitor state or profiles.

#### Scenario: [t14] Apply dock and lid profiles

- GIVEN t14 is docked or its lid state changes
- WHEN HDM receives the UPower event and queries Hyprland IPC
- THEN HDM MUST apply the corresponding monitor profile

#### Scenario: [t14] Reject monitor-writer races

- GIVEN Quattro Lua or a Quattro monitor hook is active with HDM
- WHEN dock and lid transitions are exercised
- THEN acceptance MUST demonstrate no competing monitor write or profile race

### Requirement: NetworkManager Cutover

`omarchy-nix` MUST provide Quattro NetworkManager; `nixos-hosts` MUST retain wired, mDNS, netwatch, firewall, and NIC policy. NetworkManager SHALL solely own Wi-Fi/DHCP/DNS. Standalone iwd and unmanaged `wlan0` MUST NOT remain.

#### Scenario: [t14] Recover network across sleep

- GIVEN configured Wi-Fi and Ethernet
- WHEN t14 connects, resumes, and reconnects
- THEN shell state, DHCP/DNS, mDNS, and Docker remain functional

#### Scenario: [t14] Detect competing Wi-Fi ownership

- GIVEN standalone iwd or unmanaged Wi-Fi is present
- WHEN the v4 configuration is evaluated or inspected before activation
- THEN the cutover MUST be rejected until the competing owner is removed

### Requirement: NixOS Authentication Safety

`omarchy-nix` MUST declaratively define NixOS PAM lock/polkit, not write PAM files or use Arch-only includes. Password, failed/cancelled recovery, polkit, and configured fingerprint fallback MUST work. `nixos-hosts` MUST preserve reviewed wheel/fingerprint policy.

#### Scenario: [t14] Validate graphical authentication

- GIVEN a locked session and privileged action
- WHEN password, failure/cancel, `pkexec`, and enabled fingerprint are exercised
- THEN recovery and Quattro polkit authentication work

### Requirement: Themes and Staged Rollback

`omarchy-nix` MUST own immutable Quattro themes. HM MUST expose writable overrides only in `~/.config/omarchy/`, including `shell.toml`; v3 theme watchers/files MUST NOT be active. Until acceptance, retain selectable v3 input/configuration and known-good generation. Rollback MUST restore complete v3, never individual daemons.

#### Scenario: [t14] Preserve user shell override

- GIVEN a user changes `shell.toml` and selects a supported theme
- WHEN the shell reloads or restarts
- THEN the override persists and themes update without a rebuild

#### Scenario: [t14] Roll back a failed cutover

- GIVEN shell, lock, or network acceptance fails
- WHEN the operator selects the retained v3 configuration or known-good generation
- THEN t14 returns to the complete v3 desktop and connectivity path
- AND global 26.05 and mact2 remain unchanged

### Requirement: Acceptance Evidence

Before activation, t14 NixOS/HM and mact2 MUST evaluate. Manual acceptance MUST record shell/IPC, no v3 daemons, auth recovery, independent ReGreet keyboard/focus/VNC checks, NetworkManager reconnect, HDM dock/lid behavior, absence of Quattro monitor-writer races, WayVNC, Edge/MIME, themes, and rollback readiness.

#### Scenario: [t14] Gate activation on evidence

- GIVEN the v4 configuration is ready to activate
- WHEN evaluation or any required manual acceptance check is incomplete or fails
- THEN activation MUST NOT be accepted as complete
