# OpenLogi Platform Integration Specification

## Purpose

Provide independent OpenLogi installations on t14 and macm5, without cross-host switching or synchronization.

## Requirements

### Requirement: Selective platform ownership

Linux enablement MUST require only one explicit reusable module import, initially present only on t14. Linux GUI and agent MUST use the same pinned release. macm5 MUST use its native signed Homebrew cask and existing rolling-update policy, without exact Linux/macOS version parity. Existing macm5 onboarding MUST remain unchanged.

#### Scenario: Enabled targets [t14, macm5]
- GIVEN the target configurations
- WHEN their OpenLogi integration is evaluated
- THEN t14 exposes compatible GUI/agent packages and macm5 declares the native cask under existing update policy.

#### Scenario: Excluded hosts [rog, thinkcentre]
- GIVEN hosts without the reusable import
- WHEN their configurations are evaluated
- THEN this change adds no OpenLogi packages, services, permissions or shared Home Manager enablement.

### Requirement: GUI-owned host-local configuration

Settings MUST remain mutable, host-local and GUI-owned. The integration MUST NOT impose immutable Home Manager configuration, custom mappings, Flow, synchronization or automatic switching.

#### Scenario: Persistence without propagation [t14, macm5]
- GIVEN a GUI-written setting and its backup
- WHEN the application restarts or the declarative configuration is reapplied after authorized deployment
- THEN that local setting remains writable and preserved without propagating to another host.

### Requirement: Bounded lifecycle and permissions

Each platform MUST have one agent owner: Linux graphical-session lifecycle or macOS embedded Login Item. The integration MUST NOT add a competing Darwin LaunchAgent, broad input-group access or firewall openings. Linux device access MUST be seat-scoped and its control socket user-isolated; macOS grants MUST target the actual agent.

#### Scenario: Native lifecycle and access [t14, macm5]
- GIVEN a separately authorized native session
- WHEN lifecycle and permissions are inspected
- THEN one owner controls the agent; t14 seat ACLs/socket isolation and macm5 Agent Accessibility/Input Monitoring grants are evidenced.

#### Scenario: Restricted access [t14, macm5]
- GIVEN missing device or privacy authorization
- WHEN discovery or control fails
- THEN verification records the limitation without widening permissions or starting a second manager.

### Requirement: Explicit proof levels

Verification MUST distinguish configuration evaluation, exact Linux derivation compilation, native Darwin build/install evidence, and postdeployment runtime/hardware acceptance. Unavailable native evidence MUST be deferred, not reported as passed. Planning, implementation and verification authorization MUST NOT authorize deployment, commit or push.

#### Scenario: Non-native verification [t14, macm5]
- GIVEN successful format/check/evaluation results and an exact Linux package build
- WHEN verification is reported without deployed native sessions
- THEN configuration/build evidence is recorded separately and Darwin native and runtime acceptance remain deferred, including t14 Hyprland foreground-backend proof.

### Requirement: Evidence-bounded device acceptance

Native acceptance MUST evidence K780 discovery/battery and supported controls, plus G305 battery/DPI read-write-restore, or explicitly record limitations. Probable G502 LIGHTSPEED identity MUST remain uncertain until native identification; remapping/profile support MUST NOT be guaranteed.

#### Scenario: Deferred hardware [t14, macm5]
- GIVEN no authorized native device session
- WHEN acceptance is assessed
- THEN K780/G305 controls remain unproven and the probable G502 variant remains unidentified.

### Requirement: Recoverable adoption

Rollback MUST remove only this change, preserving unrelated dirty work. Before deployment, recovery MUST retain known-good generations, a signed macOS artifact and matching configuration backups. Agent shutdown MUST precede prior-manager restoration. Recovery MUST separately address mutable configuration/device state and unwanted Login Item/TCC grants; Nix rollback MUST NOT imply Homebrew version restoration.

#### Scenario: Recovery readiness [t14, macm5]
- GIVEN a rollback plan before deployment
- WHEN its coverage is reviewed
- THEN declarative reversal, retained artifacts, owner shutdown and separate mutable-state/privacy recovery are documented without executing deployment.
