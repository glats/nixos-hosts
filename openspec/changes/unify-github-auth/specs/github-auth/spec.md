# github-auth Specification

## Purpose

Defines repo-managed GitHub authentication for personal and work MCP accounts via `gh auth token`, replacing PAT-backed wrapper and shell behavior. Covers wrapper behavior, shell environment, secret declarations, and cross-platform module import parity.

## Requirements

### Requirement: Token Resolution via gh CLI

The MCP wrapper MUST obtain GitHub tokens exclusively via `gh auth token --hostname github.com --user <account>`. The personal wrapper SHALL target user `glats`; the work wrapper SHALL target user `jcuzmar-Falabella_FTC`. No static token files or sops PAT secrets SHALL be used for token injection.

#### Scenario: Personal MCP startup with valid gh login — hosts: rog, t14, thinkcentre

- GIVEN the host has `gh` authenticated for `glats`
- WHEN the personal GitHub MCP server starts
- THEN `gh auth token --hostname github.com --user glats` resolves successfully
- AND the MCP server starts without error

#### Scenario: Work MCP startup with valid gh login — hosts: rog, t14, thinkcentre

- GIVEN the host has `gh` authenticated for `jcuzmar-Falabella_FTC`
- WHEN the work GitHub MCP server starts
- THEN `gh auth token --hostname github.com --user jcuzmar-Falabella_FTC` resolves successfully
- AND the MCP server starts without error

#### Scenario: Missing gh account fails fast with actionable message — hosts: rog, t14, thinkcentre, mact2

- GIVEN the host does NOT have `gh` authenticated for the target account
- WHEN the MCP wrapper attempts token resolution
- THEN the wrapper exits with a non-zero status
- AND stderr MUST include the exact `gh auth login` remediation command naming the missing account

---

### Requirement: Shared Home Manager Module

The GitHub MCP wrapper MUST be implemented as a single shared Home Manager module at `shared/github-mcp-wrapper.nix`. This module MUST be imported by both `linux/home/shared-modules.nix` and `darwin/home/shared-modules.nix`. Platform-specific copies of the wrapper MUST NOT exist.

#### Scenario: Linux shared-module list imports wrapper — hosts: rog, t14, thinkcentre

- GIVEN `linux/home/shared-modules.nix` has been updated
- WHEN NixOS evaluates a Linux host config
- THEN `shared/github-mcp-wrapper.nix` is included in the Home Manager module set
- AND no Linux-only wrapper module is present

#### Scenario: Darwin shared-module list imports wrapper — hosts: mact2

- GIVEN `darwin/home/shared-modules.nix` has been updated
- WHEN nix-darwin evaluates the Darwin host config
- THEN `shared/github-mcp-wrapper.nix` is included in the Home Manager module set

#### Scenario: Cross-platform import parity verified

- GIVEN both platform shared-module lists reference `shared/github-mcp-wrapper.nix`
- WHEN `nix flake check --no-build` runs
- THEN evaluation succeeds for all four hosts: rog, t14, thinkcentre, mact2

---

### Requirement: No PAT Plumbing in Active Config

Linux configurations MUST NOT declare `github/personal_pat` or `github/work_pat` as active sops secrets. Linux configs MUST NOT ship a token-check activation script. Interactive shells MUST NOT export `GH_TOKEN` pinned to a sops secret path.

#### Scenario: Shell no longer exports GH_TOKEN — hosts: rog, t14, thinkcentre

- GIVEN `linux/home/shell.nix` has been updated
- WHEN an interactive shell session starts on a Linux host
- THEN `GH_TOKEN` is not set in the shell environment via sops secret injection
- AND `gh` resolves authentication through its own multi-account state

#### Scenario: PAT sops declarations absent from active config — hosts: rog, t14, thinkcentre

- GIVEN `linux/system/base/sops.nix` has been updated
- WHEN the host config is evaluated
- THEN neither `github/personal_pat` nor `github/work_pat` appear as declared sops secrets

#### Scenario: Token-check activation script absent — hosts: rog, t14, thinkcentre

- GIVEN `linux/system/services/github-token-check.nix` has been removed and imports updated
- WHEN the host config is evaluated
- THEN no activation script referencing GitHub token pre-check is present

---

### Requirement: GPG Secrets Preserved

`github/personal_gpg_key`, `github/work_gpg_key`, and their associated fingerprint secrets MUST remain declared in sops and deployed to hosts that previously used them. These secrets MUST NOT be removed or modified by this change.

#### Scenario: GPG keys still deployed after migration — hosts: rog, t14, thinkcentre

- GIVEN the change has been applied
- WHEN the host config is evaluated
- THEN `github/personal_gpg_key` and `github/work_gpg_key` sops entries are present and unchanged
- AND fingerprint secrets associated with these keys remain intact
