# HDM Profiles Specification

## Purpose

HDM (HyprDynamicMonitors) TOML configuration for T14 dynamic monitor profile selection via EDID-based description matching, UPower lid events, and scored profile disambiguation.

## Requirements

### Requirement: Profile Definitions

The system SHALL define 4 named profiles: `docked_lid_open`, `docked_lid_closed`, `undocked_lid_open`, `undocked_lid_closed`. Each profile MUST declare `required_monitors` (list of `description` strings, EDID-based) and `required_lid_states` (`["Opened"]` or `["Closed"]`). Each MUST specify `config_file` (absolute path to its hyprconfig) and `config_file_type = "static"`.

| Req | Requirement |
|-----|-------------|
| REQ-PROF-1 | Profile conditions MUST use `description` (EDID), NOT `name` (connector) |
| REQ-PROF-2 | `match_description_using_regex = true` MUST be set (substring match, connector-agnostic) |
| REQ-PROF-3 | `docked_lid_open` MUST require 4 monitors (eDP-1 + 3 externals) and lid `["Opened"]` |
| REQ-PROF-4 | `docked_lid_closed` MUST require 4 monitors (eDP-1 + 3 externals) and lid `["Closed"]` |
| REQ-PROF-5 | `undocked_lid_open` MUST require 1 monitor (eDP-1) and lid `["Opened"]` |
| REQ-PROF-6 | `undocked_lid_closed` MUST require 1 monitor (eDP-1) and lid `["Closed"]` |

#### Scenario: Docked + lid open selects docked_lid_open

- GIVEN 4 monitors connected (eDP-1 + 3 externals matching EDID descriptions)
- AND UPower reports lid state "Opened"
- WHEN HDM evaluates profiles
- THEN `docked_lid_open` is selected (lid_state_match + monitor_match + description_match scored highest)

#### Scenario: Docked + lid closed selects docked_lid_closed

- GIVEN 4 monitors connected
- AND UPower reports lid state "Closed"
- WHEN HDM evaluates profiles
- THEN `docked_lid_closed` is selected

#### Scenario: Undocked + lid open selects undocked_lid_open

- GIVEN only eDP-1 connected
- AND UPower reports lid state "Opened"
- WHEN HDM evaluates profiles
- THEN `undocked_lid_open` is selected

#### Scenario: Undocked + lid closed selects undocked_lid_closed

- GIVEN only eDP-1 connected
- AND UPower reports lid state "Closed"
- WHEN HDM evaluates profiles
- THEN `undocked_lid_closed` is selected

#### Scenario: EDID description matching survives connector renames

- GIVEN kernel update changes connector names (e.g., DP-3 → DP-5)
- AND EDID descriptions remain identical
- WHEN HDM evaluates profiles
- THEN correct profile is selected (description match is connector-agnostic)

### Requirement: Fallback Profile

The system SHALL provide `[fallback_profile]` (top-level section, NOT `[profiles.fallback]`). It MUST apply when no named profile's `required_monitors` match.

#### Scenario: Unknown monitor set triggers fallback

- GIVEN a monitor set not matching any named profile
- WHEN HDM evaluates profiles
- THEN `[fallback_profile]` is selected

### Requirement: Scoring Configuration

The system SHALL configure `[scoring]` with `lid_state_match = 10`, `monitor_match = 5`, `description_match = 5`. Scoring MUST disambiguate when multiple profiles overlap on lid state. Higher aggregate score wins.

#### Scenario: Scoring disambiguates docked vs undocked at same lid state

- GIVEN both `docked_lid_open` and `undocked_lid_open` match lid state "Opened"
- AND 4 monitors connected (docked scores higher via monitor_match + description_match)
- WHEN HDM evaluates profiles
- THEN `docked_lid_open` wins (higher aggregate score)

### Requirement: Lid Event Handling

The system SHALL provide `[lid_events]` with `enabled = true`, using UPower D-Bus. HDM MUST be launched with `extraFlags = ["--enable-lid-events"]`.

#### Scenario: Lid close triggers profile re-evaluation

- GIVEN HDM is running with lid_events enabled
- WHEN UPower D-Bus emits lid "Closed" signal
- THEN HDM re-evaluates and applies matching profile

#### Scenario: Lid open triggers profile re-evaluation

- GIVEN HDM is running with lid_events enabled and lid is currently closed
- WHEN UPower D-Bus emits lid "Opened" signal
- THEN HDM re-evaluates and applies matching profile

### Requirement: Debounce Configuration

The system SHALL provide `[general]` with `debounce_time_ms = 1500`. Debounce MUST absorb rapid dock/undock transients to prevent profile thrashing (#152 mitigation).

#### Scenario: Debounce absorbs rapid dock/undock

- GIVEN `debounce_time_ms = 1500`
- WHEN two monitor change events occur within 1500ms
- THEN only one profile re-evaluation occurs
