# Spec: waybar-config

> Domain: waybar systemd user service for t14 host.
> Host: t14 only.
> Source files: `hosts/t14/home/default.nix` (waybar systemd block).
> Design note: omarchy-nix ships NO waybar systemd unit -- t14's unit is the sole definition and cannot be simplified to only overrides.

---

## REQ-WB-001: Maintain waybar systemd unit with sane restart limits

**What**: The waybar systemd user service definition in `hosts/t14/home/default.nix` SHALL use sensible restart limits with explanatory comments.

**Why**: omarchy-nix's waybar HM module installs only the package + static config files -- it does NOT ship a systemd unit. The t14 unit is the sole definition. `Restart=always` + a short `RestartSec` recover waybar quickly when it crashes on monitor hotplug (a known Hyprland multi-monitor race).

**Current configuration**:
- `StartLimitBurst = 5` (tighter than previous 20)
- `StartLimitIntervalSec = "10s"` (sane back-off window)
- `Restart = "always"`
- `RestartSec = "100ms"`
- `StandardOutput = "null"`
- `StandardError = "journal"`

#### Scenario: t14 waybar unit uses Restart = "always"

- **Given** the waybar systemd unit
- **When** the systemd user service is generated
- **Then** `Service.Restart` SHALL be `"always"`
- **And** `Service.RestartSec` SHALL be `"100ms"`
- **And** waybar SHALL restart automatically after any exit

#### Scenario: Waybar still starts after graphical session

- **Given** the unit configuration
- **When** the `graphical-session.target` is reached
- **Then** waybar SHALL start automatically

#### Scenario: Non-t14 hosts retain their waybar configuration

- **Given** rog and thinkcentre also use waybar
- **When** t14 waybar unit is changed
- **Then** rog's waybar configuration SHALL NOT be affected
- **And** thinkcentre's waybar configuration SHALL NOT be affected

#### Scenario: Unit rationale is clearly annotated

- **Given** the waybar unit definition
- **When** a developer reads `hosts/t14/home/default.nix`
- **Then** a comment SHALL explain why the custom unit exists (omarchy-nix ships no waybar unit)
