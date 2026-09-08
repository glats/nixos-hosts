# Browser MCP Integration Specification

## Purpose

Define shared Browser MCP registration, cross-tool host propagation, and the manual browser-extension setup contract.

## Requirements

### Requirement: Declarative base MCP registration

The shared base MCP inventory MUST contain an enabled `browsermcp` local server whose command is exactly `[ "npx" "-y" "@browsermcp/mcp@latest" ]`. Its source entry MUST use `type`, `command`, and `enabled`, MUST set `enabled = true`, and MUST NOT add Browser-MCP-specific environment overrides; repository-wide local-child defaults MAY still appear in generated configuration.

#### Scenario: Base entry has the required shape [rog, thinkcentre, t14, mact2]

- GIVEN the evaluated shared base MCP inventory
- WHEN the `browsermcp` entry is inspected
- THEN its type, command, and enabled value match the required values exactly
- AND it contains no Browser-MCP-specific environment override

#### Scenario: Latest package selection remains explicit [rog, thinkcentre, t14, mact2]

- GIVEN the Browser MCP command in the shared inventory
- WHEN its npm package argument is inspected
- THEN it MUST be `@browsermcp/mcp@latest`, not a pinned version or packaged executable

### Requirement: All-host and cross-tool propagation

The generated user configuration MUST expose `browsermcp` to both OpenCode and Claude Code on `rog`, `thinkcentre`, `t14`, and `mact2` without host-specific registration.

#### Scenario: Linux build outputs contain both registrations [rog, thinkcentre, t14]

- GIVEN a built or evaluated Home Manager output for each Linux host
- WHEN its generated `opencode.json` and Claude MCP activation data are inspected
- THEN OpenCode contains enabled local `browsermcp` with the required command
- AND Claude contains stdio `browsermcp` with command `npx` and args `[ "-y" "@browsermcp/mcp@latest" ]`

#### Scenario: Darwin build output contains both registrations [mact2]

- GIVEN a built or evaluated Home Manager output for user `jcuzmar` on `mact2`
- WHEN its generated `opencode.json` and Claude MCP activation data are inspected
- THEN both tools contain the same Browser MCP registration described above

### Requirement: Manual extension runbook

`docs/browser-mcp-setup.md` MUST document installation of Chrome Web Store extension `bjfgambnhccakkhmkepdoekmckoijdlc`, the extension-popup **Connect** step, and verification from OpenCode. It MUST state that setup is per Chromium browser profile, `rog` and `thinkcentre` require an active desktop/XRDP session, and the `mact2` user is `jcuzmar`. It MUST warn that the agent can control the logged-in browser profile, note direct npm-registry reachability for first `npx` startup, and state that no API key or Nix-side secret is required.

#### Scenario: A user can complete pairing [rog, thinkcentre, t14, mact2]

- GIVEN a supported Chromium-family browser profile
- WHEN the user follows the runbook to install the extension and click Connect
- THEN the runbook provides an OpenCode verification step
- AND identifies the host/session prerequisites that can leave the server dormant

#### Scenario: Trust and dependency constraints are visible [rog, thinkcentre, t14, mact2]

- GIVEN a user reviews the runbook before pairing
- WHEN they read its prerequisites and security guidance
- THEN browser-profile control and npm reachability are explicit
- AND no secret creation or Nix secret configuration is requested

### Requirement: Automation and packaging boundaries

The change MUST NOT force-install a Chromium extension, automate Edge or macOS extension policy, claim Firefox support, pin the npm package version, or package Browser MCP as a Nix derivation.

#### Scenario: Scope remains manual and minimal [rog, thinkcentre, t14, mact2]

- GIVEN the change diff and evaluated configuration
- WHEN extension policy, package, and browser-support changes are inspected
- THEN none of the prohibited automation, Firefox, pinning, or derivation changes are present

## Source Context

- `openspec/changes/browser-mcp-opencode/proposal.md` — approved scope and capability.
- `openspec/changes/browser-mcp-opencode/exploration.md` — verified integration and extension constraints.
- `shared/opencode/mcps-base.nix` — shared base inventory contract.
- `shared/opencode/runtime-config.nix` — OpenCode filtering, environment defaults, and serialization.
- `shared/claude-code.nix` — Claude Code translation and activation contract.
