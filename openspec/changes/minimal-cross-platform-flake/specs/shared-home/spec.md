# shared-home Specification

## Purpose

Define the cross-platform Home Manager module shared by `minimal-linux` and `minimal-mac`, providing the OpenAI Codex CLI (`pkgs.codex`).

## Requirements

### Requirement: Shared Home Manager Module Exists

A Home Manager module file SHALL exist that is importable by both NixOS and nix-darwin configurations without platform-specific branching.

#### Scenario: Module is cross-platform

- GIVEN the shared module file
- WHEN it is imported by a NixOS `home-manager.users.claudio` configuration
- AND when it is imported by a nix-darwin `home-manager.users.claudio` configuration
- THEN both evaluation environments accept the module without `imports` or `disabledModules` platform guards

### Requirement: Codex CLI in Home Packages

The shared module MUST declare `home.packages = [ pkgs.codex ]`. The Codex CLI SHALL be the only package in the shared module (no other packages, no environment.systemPackages).

#### Scenario: Codex is available to the user

- GIVEN the shared Home Manager module
- WHEN `home.packages` is evaluated for `claudio` on either host
- THEN the list includes `pkgs.codex`
- AND `pkgs.codex` resolves to the OpenAI Codex CLI from nixpkgs `nixos-26.05`

#### Scenario: Only Codex is included

- GIVEN the shared Home Manager module
- WHEN `home.packages` length is checked
- THEN it contains exactly one package (`pkgs.codex`)

### Requirement: No Auth Baked In

The shared module MUST NOT include any Codex authentication configuration (`~/.codex/config.toml`, `OPENAI_API_KEY`, `codex login` in activation scripts). Authentication is interactive and documented separately.

#### Scenario: Module is auth-free

- GIVEN the shared Home Manager module
- WHEN inspected
- THEN no `home.file."~/.codex/config.toml"` or `home.sessionVariables` setting `OPENAI_API_KEY` is present
- AND no `home.activation` scripts call `codex login`
