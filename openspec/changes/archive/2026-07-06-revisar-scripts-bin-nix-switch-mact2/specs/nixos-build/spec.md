# Delta Spec: nixos-build — Darwin Home Manager Single Activation

## ADDED Requirements

### REQ-HM-SINGLE-1: Darwin switch MUST NOT double-activate Home Manager

`nixos-build switch` on Darwin (mact2) MUST invoke `darwin-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"` exactly once and MUST NOT invoke `home-manager switch` afterward. Home Manager activation MUST occur solely through nix-darwin's integrated module (`darwin/default.nix` line 11: `inputs.home-manager.darwinModules.home-manager`).

**Scenario: mact2 switch activates HM exactly once**

- **Given** the system is running on Darwin (mact2)
- **And** `darwin/default.nix` imports `inputs.home-manager.darwinModules.home-manager`
- **And** `darwin/default.nix` configures `home-manager.users` at lines 43-66 importing `../home-darwin`
- **When** the user runs `nixos-build switch`
- **Then** the script outputs `> Building Darwin configuration (switch)...`
- **And** executes `sudo darwin-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"`
- **And** does NOT output `> Switching home-manager...`
- **And** does NOT execute `home-manager switch --flake "$FLAKE_PATH#$HOSTNAME"`
- **And** Home Manager is activated exactly once (by nix-darwin during the switch)

### REQ-HM-SINGLE-2: Darwin upgrade MUST NOT double-activate Home Manager

`nixos-build upgrade` on Darwin MUST update flake inputs, invoke `darwin-rebuild switch`, and MUST NOT invoke `home-manager switch` afterward.

**Scenario: mact2 upgrade does not re-activate HM**

- **Given** the system is running on Darwin (mact2)
- **When** the user runs `nixos-build upgrade`
- **Then** the script updates npm packages (if configured)
- **And** updates flake inputs via `nix flake update --flake "$FLAKE_PATH"`
- **And** executes `sudo darwin-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"`
- **And** does NOT output `> Switching home-manager...`
- **And** does NOT execute `home-manager switch`

### REQ-HM-SINGLE-3: Darwin safe MUST NOT double-activate Home Manager

`nixos-build safe` on Darwin MUST run the sequential workflow (check -> build -> dry -> switch) using only `darwin-rebuild` commands, and MUST NOT invoke `home-manager switch` after the final switch step.

**Scenario: mact2 safe workflow completes without HM re-activation**

- **Given** the system is running on Darwin (mact2)
- **When** the user runs `nixos-build safe`
- **Then** step [1/4] runs `nix flake check`
- **And** step [2/4] runs `nix build "$FLAKE_PATH#darwinConfigurations.$HOSTNAME.config.system.build.toplevel"`
- **And** step [3/4] runs `darwin-rebuild check`
- **And** step [4/4] runs `darwin-rebuild switch`
- **And** does NOT output `> Switching home-manager...`
- **And** the script exits with success message `> Safe build completed successfully!`

### REQ-HM-SINGLE-4: Linux (NixOS) commands MUST remain unchanged

All `nixos-build` commands on Linux (NixOS hosts: rog, thinkcentre, t14) MUST preserve their current behavior without any modification to the switch, boot, test, upgrade, dry, build, safe, or check flows.

**Scenario: rog switch is unchanged**

- **Given** the system is running on Linux (rog, thinkcentre, or t14)
- **And** `nh` is available on PATH
- **When** the user runs `nixos-build switch`
- **Then** the script executes `nh os switch`
- **And** does NOT execute any darwin-related commands

**Scenario: rog switch with --raw is unchanged**

- **Given** the system is running on Linux
- **When** the user runs `nixos-build switch --raw`
- **Then** the script executes `sudo nixos-rebuild switch --flake "$FLAKE_PATH#$HOSTNAME"`
- **And** behavior matches pre-change behavior

**Scenario: Linux dry-activate is unchanged**

- **Given** the system is running on Linux with `nh` available
- **When** the user runs `nixos-build dry`
- **Then** the script executes `nh os switch --dry`
- **And** no Darwin-specific code path is entered

### REQ-HM-SINGLE-5: Flake addressing MUST remain consistent on Darwin

`darwin-rebuild` invocations on Darwin MUST continue using `--flake "$FLAKE_PATH#$HOSTNAME"` (same as pre-change behavior). The flake path and hostname resolution (`get_flake_path`, `HOSTNAME=$(hostname)`) MUST remain unchanged.

**Scenario: mact2 flake path is worktree-aware**

- **Given** the system is running on Darwin
- **And** the current working directory is inside `$REPO_ROOT/.worktrees/some-feature`
- **When** the user runs `nixos-build switch`
- **Then** `FLAKE_PATH` resolves to `.` (current directory for worktree-relative flake)
- **And** `darwin-rebuild switch` is invoked with `--flake "./#$HOSTNAME"`

**Scenario: mact2 flake path is repo-root**

- **Given** the system is running on Darwin
- **And** the current working directory is inside `$REPO_ROOT` but not in `.worktrees/`
- **When** the user runs `nixos-build switch`
- **Then** `FLAKE_PATH` resolves to `$REPO_ROOT`
- **And** `darwin-rebuild switch` is invoked with `--flake "$REPO_ROOT#$HOSTNAME"`
