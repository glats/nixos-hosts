# HDM Hyprconfigs Specification

## Purpose

Static per-profile Hyprland config files applied by HDM. Each contains `monitor=` directives with explicit coordinates AND `workspace=` rules. ALL monitor matching uses `desc:` prefix (EDID-based, connector-agnostic).

## Requirements

### Requirement: Monitor Directives

The system SHALL provide 5 static Hyprland config files with exact monitor positions. eDP-1 MUST be parked at `-30000x0` when lid is closed (NOT disabled — Hyprland #1274). Externals MUST be at y=420 when lid is open, y=0 when lid is closed. AOC 24P1W1 MUST include `transform,1` (portrait rotation) in all docked profiles.

| Req | Requirement |
|-----|-------------|
| REQ-MON-1 | `docked-lid-open.conf`: eDP-1 at `4920x420`, 3 externals at y=420, AOC 24P1W1 `transform,1` |
| REQ-MON-2 | `docked-lid-closed.conf`: eDP-1 at `-30000x0`, 3 externals at y=0, AOC 24P1W1 `transform,1` |
| REQ-MON-3 | `undocked-lid-open.conf`: only eDP-1 at `0x0` |
| REQ-MON-4 | `undocked-lid-closed.conf`: only eDP-1 at `0x0` (clamshell pre-suspend) |
| REQ-MON-5 | `fallback.conf`: `monitor=,preferred,auto,1` — generic fallback |

#### Scenario: Dead-zone y=420 in docked-lid-open

- GIVEN `docked-lid-open.conf` is applied
- WHEN Hyprland parses monitor directives
- THEN AOC 24P1W1 at y=420 with `transform,1`, Lenovo at y=420, AOC 2470W at y=420
- AND eDP-1 at `4920x420`

#### Scenario: eDP-1 parked off-screen in docked-lid-closed

- GIVEN `docked-lid-closed.conf` is applied
- WHEN Hyprland parses monitor directives
- THEN eDP-1 is at `-30000x0` (off-screen, NOT disabled)
- AND 3 externals are at y=0

#### Scenario: Portrait rotation in all docked profiles

- GIVEN either `docked-lid-open.conf` or `docked-lid-closed.conf` is applied
- WHEN Hyprland parses monitor directives
- THEN AOC 24P1W1 has `transform,1` (90° portrait rotation)

#### Scenario: Fallback handles unknown monitor sets

- GIVEN `fallback.conf` is applied (unknown monitor set triggers fallback)
- WHEN Hyprland parses monitor directives
- THEN generic `monitor=,preferred,auto,1` is used
- AND system remains usable (no crash, no blank screen)

### Requirement: Workspace Distribution

Workspaces MUST be bound via `monitor:desc:...` syntax. Workspaces 1-3 MUST always bind to eDP-1. Workspaces 4-20 MUST distribute across 3 externals with mod-3 cycling: AOC 24P1W1 → 4,7,10,13,16,19; Lenovo → 5,8,11,14,17,20; AOC 2470W → 6,9,12,15,18.

| Req | Requirement |
|-----|-------------|
| REQ-WS-1 | Workspaces 1-3 MUST bind to eDP-1 in ALL profiles |
| REQ-WS-2 | Docked profiles MUST distribute workspaces 4-20 across 3 externals (mod-3) |
| REQ-WS-3 | `docked-lid-closed.conf` MUST NOT define workspaces 1-3 (eDP-1 is off-screen) |
| REQ-WS-4 | Undocked profiles MUST only define workspaces 1-3 (no phantom 4-20) |
| REQ-WS-5 | Fallback profile MUST NOT define workspace rules |

#### Scenario: Undocked shows only workspaces 1-3

- GIVEN `undocked-lid-open.conf` or `undocked-lid-closed.conf` is applied
- WHEN workspace rules are parsed
- THEN only workspaces 1-3 are defined on eDP-1
- AND no workspace 4-20 rules exist (no phantom workspaces on missing externals)

#### Scenario: Docked distributes workspaces 4-20 with mod-3 pattern

- GIVEN `docked-lid-open.conf` or `docked-lid-closed.conf` is applied
- WHEN workspace rules are parsed
- THEN AOC 24P1W1 gets 4,7,10,13,16,19
- AND Lenovo gets 5,8,11,14,17,20
- AND AOC 2470W gets 6,9,12,15,18

#### Scenario: Workspaces 1-3 persist across all active profiles

- GIVEN any profile with eDP-1 active (`docked-lid-open`, `undocked-lid-open`, `undocked-lid-closed`)
- WHEN workspace rules are parsed
- THEN workspaces 1, 2, 3 bind to `monitor:desc:<eDP-1 EDID>`

### Requirement: EDID-Based Monitor Matching

ALL `monitor=desc:` and `workspace=monitor:desc:` directives MUST use EDID description strings. Connector names (`DP-3`, `DP-4`, `DP-5`) MUST NOT appear in any hyprconfig. This ensures correctness across kernel updates and hardware re-enumeration.

#### Scenario: Connector name changes do not break matching

- GIVEN a kernel update renumbers connectors (e.g., DP-3 → DP-5)
- AND hyprconfigs use `desc:` prefix exclusively
- WHEN Hyprland parses monitor and workspace directives
- THEN correct monitors are positioned (EDID descriptions unchanged)
