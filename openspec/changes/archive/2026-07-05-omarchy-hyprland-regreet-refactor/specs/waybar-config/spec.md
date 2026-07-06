# Delta Spec: waybar-config

> Domain: waybar systemd unit simplification for t14 host.
> Host: t14 only.
> Source files: `hosts/t14/home/default.nix` (waybar systemd block, lines 50-70).

---

## MODIFIED Requirements

### REQ-WB-001: Simplify waybar systemd unit using only required overrides

**What**: The waybar systemd user service definition in `hosts/t14/home/default.nix` (lines 50-70) SHALL be simplified. The current definition is a full `systemd.user.services.waybar` block that duplicates many defaults from the Home Manager waybar module. The revised definition SHALL only override what differs from Home Manager defaults.

**Why**: Home Manager's `programs.waybar` module already generates a `systemd.user.services.waybar` unit with sensible defaults. The current t14 definition contains:
- `Unit.Description`, `Unit.PartOf`, `Unit.After` — same as HM defaults
- `Unit.ConditionEnvironment` — same as HM defaults
- `Unit.StartLimitBurst` + `StartLimitIntervalSec` — aggressive restart throttling, MAY differ from HM defaults
- `Service.ExecStart` — same as HM defaults
- `Service.Restart = "always"` — different from HM default (HM uses `on-failure` or no restart)
- `Service.RestartSec = "100ms"` — t14-specific fast restart
- `Service.StandardOutput = "null"` — t14-specific (silence stdout)
- `Service.StandardError = "journal"` — same as HM defaults
- `Service.SyslogIdentifier` — same as HM defaults
- `Install.WantedBy` — same as HM defaults

The refactored definition SHALL keep only the t14-specific overrides (`Restart`, `RestartSec`, `StandardOutput`) and let Home Manager supply the rest. This reduces duplication, clarifies intent, and ensures the t14 config doesn't drift from Home Manager waybar module updates.

**Migration**: The existing full Service+Unit+Install block SHALL be simplified. The `Restart`, `RestartSec`, and `StandardOutput` settings SHALL be preserved. All other settings SHALL be inherited from Home Manager's defaults for `programs.waybar`.

#### Scenario: t14 waybar unit uses Restart = "always"

- **Given** the waybar systemd unit is simplified
- **When** the systemd user service is generated
- **Then** `Service.Restart` SHALL be `"always"`
- **And** `Service.RestartSec` SHALL be `"100ms"`
- **And** `Service.StandardOutput` SHALL be `"null"`
- **And** waybar SHALL restart automatically after any exit (not just failures)

#### Scenario: HM defaults are inherited for non-overridden fields

- **Given** the waybar unit is simplified and no longer explicitly sets `Unit.Description`, `Unit.PartOf`, `Unit.After`, `Unit.ConditionEnvironment`, `Service.ExecStart`, `Service.StandardError`, `Service.SyslogIdentifier`, and `Install.WantedBy`
- **When** the systemd user service is generated
- **Then** all these fields SHALL be present with Home Manager default values
- **And** the generated unit SHALL be functionally identical to the current unit except for the explicit Restart behavior

#### Scenario: Waybar still starts after graphical session

- **Given** the simplified unit
- **When** the graphical-session.target is reached
- **Then** waybar SHALL start automatically
- **And** waybar SHALL stop when the graphical session ends

#### Scenario: Non-t14 hosts retain their waybar configuration

- **Given** rog and thinkcentre also use waybar (via different HM module paths)
- **When** the t14 waybar unit is simplified
- **Then** rog's waybar configuration SHALL NOT be affected
- **And** thinkcentre's waybar configuration SHALL NOT be affected

#### Scenario: Simplification is clearly annotated

- **Given** the simplified waybar unit definition
- **When** a developer reads `hosts/t14/home/default.nix`
- **Then** a comment SHALL explain which settings are t14-specific overrides
- **And** the comment SHALL note that all other settings come from Home Manager's `programs.waybar` defaults
