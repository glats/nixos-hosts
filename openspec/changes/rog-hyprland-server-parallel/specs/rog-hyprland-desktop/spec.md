# Spec: rog-hyprland-desktop

## Overview

Hyprland/Omarchy desktop on rog using Intel iGPU for Wayland rendering while NVIDIA GTX 1050 continues driving xrdp headless Xorg + CUDA. Both greetd and xrdp run simultaneously with no lid-switch toggle.

## Requirements

| ID | Requirement | Priority | Modules | Coexists With |
|----|------------|----------|---------|---------------|
| REQ-RHD-001 | Omarchy stack active on rog | MUST | `inputs.omarchy-nix.nixosModules.default` via extraModules, `omarchy.greeter.type = "regreet"` | xrdp, all server services |
| REQ-RHD-002 | Intel iGPU drives Hyprland display | MUST | modesetting driver auto-loads; NVIDIA stays on xrdp headless X only (`videoDrivers = ["nvidia"]`) | -- |
| REQ-RHD-003 | greetd + xrdp coexist via separate PAM stacks and graphics devices | MUST | greetd on VT7 (Hyprland compositor), xrdp via xrdp-sesman (separate PAM) | -- |
| REQ-RHD-004 | Lid switch does NOT toggle services | SHALL | `HandleLidSwitch = "ignore"` (no change from current) | -- |
| REQ-RHD-005 | Build validation passes | MUST | `nix flake check --no-build` exit 0; all 20+ services evaluable | -- |

### Requirement: REQ-RHD-001 -- Omarchy Desktop Stack

The rog host MUST run the Omarchy/Hyprland desktop stack on the Intel iGPU, with greetd+regreet as the graphical greeter. The `omarchy-nix.nixosModules.default` MUST be added to rog's `extraModules` in `flake.nix`. The rog `default.nix` MUST include an `omarchy = { ... }` config block. The `services.greetd` settings are managed by omarchy-nix (no direct greetd config in rog's default.nix).

#### Scenario: Omarchy module resolves in flake evaluation

- GIVEN `inputs.omarchy-nix.nixosModules.default` is in rog's extraModules
- WHEN `nix flake check --no-build` is run
- THEN evaluation succeeds for rog with exit code 0

#### Scenario: greetd greeter starts on boot

- GIVEN `omarchy.greeter.type = "regreet"` is set
- WHEN the system boots
- THEN `greetd.service` starts, manages VT7 with a Hyprland compositor
- AND regreet renders the login screen on the Intel iGPU-connected display

#### Scenario: User logs into Hyprland session

- GIVEN greetd+regreet is running on VT7
- WHEN user glats authenticates via regreet
- THEN a Hyprland desktop session starts
- AND omarchy-nix HM configuration is applied

### Requirement: REQ-RHD-002 -- Intel iGPU Display Rendering

The Intel iGPU MUST drive Hyprland/Wayland rendering via GBM/DRM. The NVIDIA GTX 1050 SHALL NOT participate in Wayland framebuffer or display output. NVIDIA continues serving xrdp's headless Xorg via `services.xserver.videoDrivers = ["nvidia"]` (no change to `modules/hardware/nvidia.nix`).

#### Scenario: Intel iGPU is primary Wayland renderer

- GIVEN the `modesetting` driver auto-loads for the Intel iGPU
- WHEN Hyprland starts
- THEN GBM/DRM rendering uses `/dev/dri/card0` (Intel)
- AND the NVIDIA GPU is not used for framebuffer allocation

#### Scenario: NVIDIA serves xrdp only

- GIVEN `services.xserver.videoDrivers = ["nvidia"]` and `services.xrdp.enable = true`
- WHEN xrdp-sesman starts a headless X session
- THEN the Xorg server uses the NVIDIA GPU for virtual framebuffer
- AND no physical display output is driven by NVIDIA

### Requirement: REQ-RHD-003 -- greetd + xrdp Coexistence

greetd and xrdp MUST run simultaneously without session conflicts. They use separate PAM stacks (greetd vs xrdp-sesman) and separate graphics devices (Intel iGPU vs NVIDIA). The profile chain break (server.nix -> desktop.nix -> base.nix replaced with direct module imports) MUST NOT regress xrdp behavior.

#### Scenario: Both services active simultaneously

- GIVEN `greetd.service` and `xrdp.service` are enabled
- WHEN the system boots
- THEN both services are `active/running`
- AND no mutual exclusion or login loop occurs

#### Scenario: xrdp MATE sessions work after profile chain break

- GIVEN rog's imports no longer use `modules/profiles/server.nix`
- WHEN a user connects via xrdp
- THEN a MATE desktop session starts correctly
- AND all xrdp behaviors (session loop, cleanup, preamble) function as before

### Requirement: REQ-RHD-004 -- No Lid-Switch Toggle

The lid switch SHALL NOT toggle greetd or xrdp. `HandleLidSwitch` remains `"ignore"` (set in `modules/base/logind.nix`, shared across hosts, unmodified by this change).

#### Scenario: Lid close does not affect services

- GIVEN `HandleLidSwitch = "ignore"` and both greetd.service + xrdp.service are active
- WHEN the laptop lid is closed
- THEN neither service restarts, stops, or changes state

### Requirement: REQ-RHD-005 -- Build Validation

Rog's NixOS configuration MUST pass `nix flake check --no-build` after the profile chain break and omarchy module addition. All 20+ server services (arr-stack, jellyfin, nginx, docker, wireguard, etc.) MUST remain evaluable.

#### Scenario: Flake check passes

- GIVEN omarchy-nix is in rog's extraModules and the profile chain is broken
- WHEN `nix flake check --no-build` is run
- THEN exit code is 0 with no evaluation errors for rog

#### Scenario: Server services survive import restructuring

- GIVEN all services from `hosts/rog/services/` are individually imported in rog's default.nix
- WHEN rog's configuration is evaluated
- THEN all services resolve without missing import errors
