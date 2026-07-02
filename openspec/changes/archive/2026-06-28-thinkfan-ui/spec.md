# thinkfan-ui Packaging Specification

## Purpose

Package the [thinkfan-ui](https://github.com/zocker-160/thinkfan-ui) PyQt6 GUI as a local Nix derivation and wire it on the t14 host (ThinkPad T14 AMD Gen 4) for manual fan speed control via `/proc/acpi/ibm/fan`.

## Requirements

### Requirement: Derivation Build

The system SHALL provide a `thinkfan-ui` package derivable via `stdenv.mkDerivation` that installs the upstream Python source and produces a runnable executable at `$out/bin/thinkfan-ui`.

#### Scenario: Successful flake build

- GIVEN the flake input `thinkfan-ui-src` resolves to `github:zocker-160/thinkfan-ui`
- WHEN `nix build .#packages.x86_64-linux.thinkfan-ui` is executed
- THEN the build completes without errors
- AND the output store path contains `$out/bin/thinkfan-ui` as an executable file

#### Scenario: Executable is wrapped with runtime dependencies

- GIVEN the derivation has been built successfully
- WHEN the `$out/bin/thinkfan-ui` binary is inspected
- THEN it SHALL be a `makeWrapper`-generated wrapper script
- AND the wrapper SHALL include `python3` with `PyQt6` in its `PYTHONPATH`
- AND the wrapper SHALL include `lm-sensors` (`sensors` binary) in its `PATH`
- AND the wrapper SHALL include `polkit` (`pkexec` binary) in its `PATH`

#### Scenario: Qt plugins are discoverable

- GIVEN the derivation uses `wrapQtAppsHook` in `nativeBuildInputs`
- WHEN the executable is launched
- THEN Qt plugin paths (platform themes, icon engines) SHALL resolve correctly
- AND the application SHALL NOT fail with "could not find or load the Qt platform plugin"

### Requirement: Flake Input and Overlay Wiring

The system SHALL expose `thinkfan-ui` through the standard package discovery chain: flake input → overlay → `linuxPackages`.

#### Scenario: Flake input resolves to upstream

- GIVEN the `flake.nix` declares `thinkfan-ui-src`
- WHEN the flake is evaluated
- THEN `thinkfan-ui-src` SHALL have `url = "github:zocker-160/thinkfan-ui"` and `flake = false`

#### Scenario: Overlay provides pkgs.thinkfan-ui

- GIVEN `overlays/linux.nix` registers `thinkfan-ui`
- WHEN any NixOS host evaluates `pkgs.thinkfan-ui`
- THEN it SHALL resolve to the local derivation from `pkgs/thinkfan-ui/default.nix`
- AND the derivation SHALL receive `thinkfan-ui-src = inputs.thinkfan-ui-src`

#### Scenario: Package accessible via linuxPackages

- GIVEN `lib/packages.nix` includes `thinkfan-ui` in `linuxPackages`
- WHEN `nix build .#thinkfan-ui` is executed on x86_64-linux
- THEN the build SHALL succeed and produce the same output as `.#packages.x86_64-linux.thinkfan-ui`

### Requirement: Host Wiring on t14

The t14 host SHALL enable the `thinkpad_acpi` kernel module fan control parameter and install `thinkfan-ui` in the user environment.

#### Scenario: Kernel module parameter is set

- GIVEN the t14 host configuration is evaluated
- WHEN `boot.extraModprobeConfig` is inspected
- THEN it SHALL contain `options thinkpad_acpi fan_control=1`

#### Scenario: thinkfan-ui is in user packages

- GIVEN the t14 home-manager configuration is evaluated
- WHEN `home.packages` is inspected
- THEN it SHALL include `pkgs.thinkfan-ui`

### Requirement: Flake Check

The overall flake SHALL pass validation without build errors.

#### Scenario: Flake check succeeds

- GIVEN all files are syntactically valid Nix
- WHEN `nix flake check --no-build` is executed
- THEN the command SHALL exit with code 0
- AND no evaluation errors SHALL be reported

### Requirement: Non-Interference

thinkfan-ui and the thinkfan daemon SHALL NOT be enabled simultaneously on any host.

#### Scenario: thinkfan service is not enabled on t14

- GIVEN the t14 host configuration is evaluated
- WHEN `services.thinkfan.enable` is inspected
- THEN it SHALL be `false` (default) or explicitly unset

#### Scenario: No conflicting fan control mechanisms

- GIVEN thinkfan-ui is installed on t14
- WHEN the system is running
- THEN no other service SHALL write to `/proc/acpi/ibm/fan` concurrently
