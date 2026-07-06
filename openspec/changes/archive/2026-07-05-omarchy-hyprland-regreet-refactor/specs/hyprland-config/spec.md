# Delta Spec: hyprland-config

> Domain: Hyprland configuration cleanup for t14 Omarchy host.
> Host: t14 only.
> Source files: `hosts/t14/home/hypr/looknfeel.nix`, `hosts/t14/home/hypr/input.nix`, `hosts/t14/home/omarchy.nix`.

---

## REMOVED Requirements

### REQ-HC-001: Remove obsolete WLR_RENDERER_ALLOW_SOFTWARE env var

**What**: The `env = [ "WLR_RENDERER_ALLOW_SOFTWARE,0" ]` line in `hosts/t14/home/hypr/looknfeel.nix` SHALL be removed entirely.

**Why**: Hyprland 0.54+ with AMD Phoenix 3 iGPU (t14's hardware) does not need this workaround. The env var was necessary for older Hyprland versions that required explicit opt-out of software rendering fallback on some GPU configurations. On current hardware and Hyprland version it has no effect and adds misleading noise to the configuration.

**Migration**: No replacement required. Removal is a deletion-only change.

**(Reason: obsolete on Hyprland 0.54+ with AMD iGPU)**

#### Scenario: WLR_RENDERER_ALLOW_SOFTWARE removed from config

- **Given** the t14 host with Hyprland 0.54+ and AMD Phoenix 3 APU
- **When** `home-manager` activation evaluates `hosts/t14/home/hypr/looknfeel.nix`
- **Then** the `wayland.windowManager.hyprland.settings.env` list SHALL NOT contain `WLR_RENDERER_ALLOW_SOFTWARE,0`
- **And** Hyprland SHALL continue to use hardware rendering without any regression

#### Scenario: Other env vars in looknfeel.nix are unaffected

- **Given** `looknfeel.nix` currently contains only the `WLR_RENDERER_ALLOW_SOFTWARE` env entry
- **When** the env var is removed
- **Then** the `env` attribute SHALL be removed from the module (leaving an empty list would be noise)
- **And** `general.gaps_*`, `decoration.*`, and `misc.initial_workspace_tracking` settings SHALL remain unchanged

---

## MODIFIED Requirements

### REQ-HC-002: Gate full-opacity windowrule behind configurable boolean

**What**: The `mkAfter` blanket `windowrule = opacity 1.0 1.0, match:class .*` in `hosts/t14/home/hypr/input.nix` SHALL be replaced with a conditional block gated by a new configuration option.

**Rationale**: The current implementation uses `lib.mkAfter` on `extraConfig`, which appends after all of omarchy-nix's layered extraConfig blocks (including per-app opacity rules in `windows.nix` and `apps.conf`). This blanket rule defeats omarchy's theme opacity system entirely. The user's intent is to disable transparency globally, but the implementation should be explicit and configurable rather than relying on priority-tricking semantics.

**New option**:

```nix
# In hosts/t14/home/hypr/input.nix, replace the `extraConfig` block with:
wayland.windowManager.hyprland.settings.windowrule = lib.mkIf config.t14.hyprland.forceFullOpacity [
  "opacity 1.0 1.0, match:class .*"
];
```

The module SHALL declare a new option `t14.hyprland.forceFullOpacity`:
- Type: `lib.types.bool`
- Default: `true` (preserving current behavior)
- Description: "Apply opacity 1.0 to all windows, overriding omarchy's per-app opacity rules"

If the option cannot be declared (e.g., the t14 module namespace does not exist yet), the module SHALL use a plain `lib.mkIf` with a local `let`-bound boolean for clarity.

**Migration**: The `extraConfig` + `lib.mkAfter` pattern SHALL be removed. The windowrule SHALL move from `extraConfig` to `settings.windowrule`, which is the declarative Hyprland settings path.

#### Scenario: forceFullOpacity = true (default)

- **Given** `t14.hyprland.forceFullOpacity` is `true` (or its local boolean equivalent is `true`)
- **When** Home Manager activation evaluates the Hyprland configuration
- **Then** `wayland.windowManager.hyprland.settings.windowrule` SHALL include `"opacity 1.0 1.0, match:class .*"`
- **And** all windows SHALL render at full opacity
- **And** the `extraConfig` attribute SHALL NOT contain any opacity windowrule
- **And** omarchy's per-app opacity rules in `windows.nix` and `apps.conf` SHALL be overridden because `settings.windowrule` is processed at the Hyprland-native windowrule priority level

#### Scenario: forceFullOpacity = false

- **Given** `t14.hyprland.forceFullOpacity` is `false`
- **When** Home Manager activation evaluates the Hyprland configuration
- **Then** `wayland.windowManager.hyprland.settings.windowrule` SHALL NOT contain any blanket opacity rule
- **And** omarchy's per-app opacity rules SHALL apply normally (e.g., browsers at 0.97, terminals at 0.9)
- **And** the user MAY change this value at runtime by editing `input.nix` and rebuilding

#### Scenario: Windowrule uses declarative settings path (not extraConfig)

- **Given** the windowrule is moved from `extraConfig` to `settings.windowrule`
- **When** `nix flake check --no-build` is run for the t14 host
- **Then** the Home Manager Hyprland module SHALL accept `settings.windowrule` as a valid attribute
- **And** no extraConfig-related warnings SHALL appear

---

## ADDED Requirements

### REQ-HC-003: Document Hyprland-as-greeter-compositor architecture decision

**What**: `hosts/t14/home/omarchy.nix` SHALL include a documentation block explaining WHY the Hyprland/ReGreet architecture was chosen over the default cage-based approach.

**Rationale**: The current configuration avoids the standard NixOS `programs.regreet.enable` default (which uses cage) and instead launches Hyprland directly as the greeter compositor. This is an intentional architectural decision driven by keyboard layout switching requirements on this bilingual (es/latam) host. Without documentation, future maintainers may attempt to "fix" the architecture by reverting to cage, which would break layout switching at the login screen.

**Content**: The documentation block SHALL cover:
1. The keyboard layout toggle requirement (Alt+Shift between es and latam) at login
2. Why cage cannot provide this (cage is a minimal compositor with no input-method support)
3. How the greetd session command chains Hyprland + regreet (the full chain: `greetd` → `start-hyprland -- --config /etc/greetd/hyprland.conf` → `exec-once = greetd-regreet-start` → `regreet` → `hyprctl dispatch exit`)
4. The escape hatch (`systemd.mask=greetd.service` on kernel cmdline)
5. That this architecture is owned by omarchy-nix and the t14 module only documents it; changes to the greetd wiring require omarchy-nix PRs

#### Scenario: Architecture documentation exists in omarchy.nix

- **Given** the t14 host uses Hyprland as the greetd compositor
- **When** a developer reads `hosts/t14/home/omarchy.nix`
- **Then** there SHALL be a comment block (50+ lines) clearly explaining the architecture decision
- **And** the block SHALL reference the keyboard layout toggle requirement as the primary driver
- **And** the block SHALL include the greetd → Hyprland → regreet chain description
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
