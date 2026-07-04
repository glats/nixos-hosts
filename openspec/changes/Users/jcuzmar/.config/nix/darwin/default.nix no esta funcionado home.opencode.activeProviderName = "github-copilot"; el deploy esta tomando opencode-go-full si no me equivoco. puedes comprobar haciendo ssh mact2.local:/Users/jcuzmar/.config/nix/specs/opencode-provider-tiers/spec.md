# Delta Spec: mact2 provider deployment-path consistency
# Domain: opencode-provider-tiers
# Change: Fix mact2 OpenCode provider drift (darwin vs. standalone HM)
# Date: 2026-07-03

## Problem Statement

`home.opencode.activeProviderName = "github-copilot"` is set in `darwin/default.nix` and is
correctly threaded through `darwinConfigurations.mact2`. However, the standalone
`homeConfigurations.mact2` entry in `flake.nix` does NOT inherit that override — it receives
only the default `opencode-go-medium`. When any `home-manager switch --flake .#mact2` is run
without a preceding `darwin-rebuild switch`, the deployed `opencode.json` silently regresses to
medium-tier models, contradicting the intent expressed in `darwin/default.nix`.

---

## MODIFIED Requirements

### Requirement: Host Provider Mapping

Each host MUST have a valid `activeProviderName` assignment. Hosts MAY override the default via
plain attribute assignment.

> MODIFICATION: Extends the mact2 row to add the dual-path consistency constraint. The full
> requirement block is reproduced here per delta-spec convention (MODIFIED must include all
> preserved scenarios).

| Host | activeProviderName | Override Location |
|------|--------------------|-------------------|
| rog | opencode-go-medium | default (no override) |
| thinkcentre | opencode-go-medium | default (no override) |
| t14 | opencode-go-full | `hosts/t14/home/omarchy.nix` |
| mact2 | github-copilot | `darwin/default.nix` AND `homeConfigurations.mact2` extras in `flake.nix` |

#### Scenario: t14 uses opencode-go-full

- GIVEN the t14 host configuration
- WHEN `home.opencode.activeProviderName` is evaluated
- THEN the value MUST be `"opencode-go-full"`

#### Scenario: rog and thinkcentre use opencode-go-medium

- GIVEN the rog or thinkcentre host configuration
- WHEN `home.opencode.activeProviderName` is evaluated without explicit override
- THEN the value MUST resolve to `"opencode-go-medium"` via the default

#### Scenario: mact2 darwinConfigurations resolves github-copilot

- GIVEN the `darwinConfigurations.mact2` flake target is evaluated
- WHEN `config.home-manager.users.jcuzmar.home.opencode.activeProviderName` is read
  (e.g., `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName`)
- THEN the value MUST be `"github-copilot"`

#### Scenario: mact2 homeConfigurations resolves github-copilot

- GIVEN the `homeConfigurations.mact2` flake target is evaluated
- WHEN `config.home.opencode.activeProviderName` is read
  (e.g., `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName`)
- THEN the value MUST be `"github-copilot"`
- AND the result MUST match the value from the `darwinConfigurations.mact2` path

#### Scenario: Both deployment paths produce identical opencode.json provider tier

- GIVEN mact2 is deployed first via `darwin-rebuild switch` (darwin path)
- AND then deployed via `home-manager switch --flake .#mact2` (standalone path)
- WHEN the remote `~/.config/opencode/opencode.json` is inspected after each deploy
- THEN the `activeProvider` key MUST be `github-copilot` in both cases
- AND the per-phase model assignments MUST reference github-copilot models, not opencode-go-medium models

---

## ADDED Requirements

### Requirement: Darwin Host Dual-Path Consistency

For any Darwin host whose `darwin/default.nix` sets a non-default `activeProviderName`, the
corresponding `homeConfigurations.<host>` entry in `flake.nix` MUST also receive that same
override, so that both supported deployment paths agree at evaluation time.

- The override MUST be applied either as an inline module
  `{ home.opencode.activeProviderName = "<value>"; }` in the `extraModules` list, or by
  importing a shared per-host override module (e.g., `hosts/mact2/home/provider.nix`).
- The override MUST NOT require `lib.mkForce` — it MUST win via the standard plain-assignment
  priority over `mkDefault`.
- If the `homeConfigurations.<host>` standalone target is intentionally removed, a code comment
  MUST document that darwin-rebuild is the only supported deployment path for that host.

#### Scenario: Override added as inline module in homeConfigurations extras

- GIVEN `flake.nix` extends `homeConfigurations.mact2` with an inline module
  `{ home.opencode.activeProviderName = "github-copilot"; }`
- WHEN the flake is evaluated
- THEN `homeConfigurations.mact2.config.home.opencode.activeProviderName` MUST equal `"github-copilot"`
- AND `nix flake check --no-build` MUST pass

#### Scenario: Override added via shared per-host module

- GIVEN `hosts/mact2/home/` contains a module that sets `home.opencode.activeProviderName = "github-copilot"`
- AND that module is imported by both `darwinConfigurations.mact2` and `homeConfigurations.mact2`
- WHEN either flake target is evaluated
- THEN both MUST resolve to `"github-copilot"` without duplication of the literal string

#### Scenario: Standalone HM target removed (alternative approach)

- GIVEN `homeConfigurations.mact2` is removed from `flake.nix`
- WHEN the flake is evaluated
- THEN `nix flake check --no-build` MUST pass
- AND a comment MUST document that `darwin-rebuild switch --flake .#mact2` is the required deployment path

### Requirement: Provider Drift Detection

The `nix eval` commands used to verify provider alignment MUST be executable without deploying
to the remote host, so that drift can be caught before a switch.

- Both eval commands MUST be runnable from the development machine.
- The `openspec` verification criterion MUST list both `nix eval` commands with expected output.

#### Scenario: Pre-deploy drift check for darwinConfigurations path

- GIVEN the development machine has access to the flake
- WHEN the engineer runs:
  `nix eval --raw .#darwinConfigurations.mact2.config.home-manager.users.jcuzmar.home.opencode.activeProviderName`
- THEN the output MUST be `github-copilot`
- AND no network access to mact2.local MUST be required

#### Scenario: Pre-deploy drift check for homeConfigurations path

- GIVEN the development machine has access to the flake
- WHEN the engineer runs:
  `nix eval --raw .#homeConfigurations.mact2.config.home.opencode.activeProviderName`
- THEN the output MUST be `github-copilot`
- AND no network access to mact2.local MUST be required

---

## Out of Scope

- Provider catalog changes or new provider tiers.
- Changes to Linux host deployment paths (rog, thinkcentre, t14).
- Changes to the provider plumbing (`providers-base.nix`, `providers.nix`, `agents.nix`) — those
  were addressed in the `opencode-go-per-host-config` change and MUST NOT be re-opened here.
- Adding CI enforcement of the drift check — desirable but deferred.
