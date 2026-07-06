# Spec: hyprland-config

> Domain: Hyprland configuration for t14 Omarchy host.
> Host: t14 only.
> Source files: `hosts/t14/home/hypr/looknfeel.nix`, `hosts/t14/home/hypr/input.nix`, `hosts/t14/home/omarchy.nix`.

---

## REQ-HC-002: Gate full-opacity windowrule behind configurable boolean

**What**: The `mkAfter` blanket `windowrule = opacity 1.0 1.0, match:class .*` in `hosts/t14/home/hypr/input.nix` SHALL be replaceable with a conditional block gated by a configurable boolean.

**Rationale**: The current implementation uses `lib.mkAfter` on `extraConfig`, which appends after all of omarchy-nix's layered extraConfig blocks (including per-app opacity rules in `windows.nix` and `apps.conf`). This blanket rule defeats omarchy's theme opacity system entirely. The gate makes the override explicit and configurable.

**Implementation detail**: The windowrule stays in `extraConfig` rather than `settings.windowrule` because `mkAfter` ordering is required to defeat omarchy's `-default-opacity` tagged per-app rules (see design Section 2.2). A `lib.optionalString` + `lib.mkAfter` pattern is used since `extraConfig` is a plain string value, not a config attrset.

**Current state**: `let forceFullOpacity = true;` in `hosts/t14/home/hypr/input.nix`. Toggle to `false` to restore omarchy's per-app opacity theme rules.

#### Scenario: forceFullOpacity = true (default)

- **Given** `forceFullOpacity` is `true`
- **When** Home Manager activation evaluates the Hyprland configuration
- **Then** `extraConfig` SHALL include `windowrule = opacity 1.0 1.0, match:class .*`
- **And** all windows SHALL render at full opacity
- **And** omarchy's per-app opacity rules in `windows.nix` and `apps.conf` SHALL be overridden

#### Scenario: forceFullOpacity = false

- **Given** `forceFullOpacity` is `false`
- **When** Home Manager activation evaluates the Hyprland configuration
- **Then** `extraConfig` SHALL NOT contain any blanket opacity rule
- **And** omarchy's per-app opacity rules SHALL apply normally

---

## REQ-HC-003: Document Hyprland-as-greeter-compositor architecture decision

**What**: `hosts/t14/home/omarchy.nix` SHALL include a documentation block explaining WHY the Hyprland/ReGreet architecture was chosen over the default cage-based approach.

**Rationale**: The current configuration avoids the standard NixOS `programs.regreet.enable` default (which uses cage) and instead launches Hyprland directly as the greeter compositor. This is an intentional architectural decision driven by keyboard layout switching requirements on this bilingual (es/latam) host.

**Content**: The documentation block SHALL cover:
1. The keyboard layout toggle requirement (Alt+Shift between es and latam) at login
2. Why cage cannot provide this (cage is a minimal compositor with no input-method support)
3. How the greetd session command chains Hyprland + regreet
4. The escape hatch (`systemd.mask=greetd.service` on kernel cmdline)
5. That this architecture is owned by omarchy-nix and the t14 module only documents it

#### Scenario: Architecture documentation exists in omarchy.nix

- **Given** the t14 host uses Hyprland as the greetd compositor
- **When** a developer reads `hosts/t14/home/omarchy.nix`
- **Then** there SHALL be a comment block explaining the architecture decision
- **And** the block SHALL reference the keyboard layout toggle requirement as the primary driver
- **And** the block SHALL include the greetd -> Hyprland -> regreet chain description
- **And** the block SHALL document the VT escape hatch (`systemd.mask=greetd.service`)

#### Scenario: Documentation survives formatting

- **Given** the architecture documentation block is added
- **When** `format-nix` is run on the file
- **Then** the documentation SHALL remain intact (nixfmt preserves multi-line comments)
- **And** `nix flake check --no-build` SHALL pass

#### Scenario: Documentation explicitly states ownership boundary

- **Given** the architecture documentation is present
- **When** a developer reads it
- **Then** it SHALL clearly state that the greeter wiring is owned by `omarchy-nix/modules/nixos/system.nix`
- **And** that the t14 module only documents and configures it, not owns it

---

## REMOVED

### REQ-HC-001: Remove obsolete WLR_RENDERER_ALLOW_SOFTWARE env var

**Status**: Deleted. The `env = [ "WLR_RENDERER_ALLOW_SOFTWARE,0" ]` line was removed in commit `d12602d`.
**Reason**: Obsolete on Hyprland 0.54+ with AMD iGPU. No replacement needed.
