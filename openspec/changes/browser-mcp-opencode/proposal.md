# Proposal: Browser MCP for OpenCode

## Intent

Provide Browser MCP declaratively on rog, thinkcentre, t14, and mact2 while keeping its Chromium extension user-managed. The shared entry will serve both OpenCode and Claude Code.

## Scope

### In Scope
- Add enabled local server `browsermcp` to `defaultMcps` in `shared/opencode/mcps-base.nix` with `command = [ "npx" "-y" "@browsermcp/mcp@latest" ];`.
- Add `docs/browser-mcp-setup.md` covering Chrome Web Store installation, **Connect**, OpenCode verification, profile trust, XRDP dormancy, and no Nix-side secret.
- Verify the entry reaches both tools on all four hosts.

### Out of Scope
- Forced Chromium extension installation (Option B), Edge policy JSON, or a mact2 managed-preferences plist.
- Firefox support, pinning the npm version, or packaging the npm package as a Nix derivation.

## Capabilities

### New Capabilities
- `browser-mcp-integration`: Shared registration, manual extension pairing, verification, and security guidance.

### Modified Capabilities
None.

## Approach

Use existing `home.ai-assets.mcps`; do not add host modules. `shared/opencode/runtime-config.nix` serializes local entries for OpenCode, while `shared/claude-code.nix` translates them for Claude Code. Shared-module and Node.js changes are unnecessary.

Estimated work: MCP entry and Nix verification, 15–25 minutes; runbook and operational checklist, 20–30 minutes.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/mcps-base.nix` | Modified | Add MCP entry. |
| `docs/browser-mcp-setup.md` | New | Document setup and trust. |
| `shared/opencode/runtime-config.nix` | Behavioral | Existing OpenCode consumer; no edit. |
| `shared/claude-code.nix` | Behavioral | Existing Claude consumer; no edit. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Proxy scrubbing blocks the first `npx` fetch | Medium | Document direct npm-registry access and test startup. |
| Agent accesses cookies, sessions, and 2FA | High | Require a per-host trust decision. |
| Browser is disconnected outside GUI/XRDP sessions | Medium | Document dormancy and Connect checks. |
| `@latest` changes without Nix changes | Medium | Verify runtime startup. |

## Rollback Plan

Remove the entry and runbook, rebuild, and manually uninstall the extension. Existing MCPs and imports remain unchanged.

## Dependencies

- Existing `npx` installation and direct npm-registry access on first run.
- Browser MCP Chromium extension `bjfgambnhccakkhmkepdoekmckoijdlc`; no API key or Nix secret.

## Success Criteria

- [ ] `browsermcp` is generated for OpenCode and Claude Code on rog, thinkcentre, t14, and mact2.
- [ ] The runbook enables a user to install, connect, and verify Browser MCP without adding a secret.
- [ ] `format-nix && nix flake check --no-build` passes; optionally build t14 first as the fastest evaluation sanity check.
