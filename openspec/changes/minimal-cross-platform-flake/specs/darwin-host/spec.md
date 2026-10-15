# darwin-host Specification

## Purpose

Define requirements for the `minimal-mac` aarch64-darwin nix-darwin configuration: Determinate Nix integration (canonical), user `claudio`, and Home Manager wiring.

## Requirements

### Requirement: Determinate Nix Canonical Integration

The `minimal-mac` configuration MUST use Determinate Nix as its Nix implementation, following the canonical pattern: `nix.enable = false` plus `inputs.determinate.darwinModules.default`.

#### Scenario: Determinate Nix replaces default Nix

- GIVEN the `minimal-mac` darwin configuration
- WHEN `nix.enable` is `false`
- AND `inputs.determinate.darwinModules.default` is imported as a module
- THEN the configuration evaluates without `nix`-related conflicts
- AND Deterministic Nix daemon manages Nix operations

### Requirement: Claudio User

The system MUST define user `claudio` with a home directory at `/Users/claudio`, a user ID, and a shell.

#### Scenario: User claudio on macOS

- GIVEN the `minimal-mac` config
- WHEN `users.users.claudio` is defined with `home = "/Users/claudio"` and a shell
- THEN the user exists after `darwin-rebuild switch`

### Requirement: State Version

The `minimal-mac` SHALL set `system.stateVersion = 5`, corresponding to the nix-darwin-26.05 branch.

#### Scenario: State version matches branch

- GIVEN the `minimal-mac` config
- WHEN `system.stateVersion` is evaluated
- THEN its value is `5`

### Requirement: Home Manager Integration

The `minimal-mac` configuration MUST import `inputs.home-manager.darwinModules.default` and wire a per-user Home Manager configuration for `claudio` through the `home-manager` module users list.

#### Scenario: Home Manager wired for claudio

- GIVEN the `minimal-mac` darwin configuration
- WHEN `home-manager.users.claudio` receives the shared Home Manager module
- THEN `home-manager` is active for `claudio`
- AND `pkgs.codex` is available to `claudio` on the macOS system
