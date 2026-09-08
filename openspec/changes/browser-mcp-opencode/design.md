# Design: Browser MCP for OpenCode

## Technical Approach

Add one enabled local MCP to the shared `home.ai-assets.mcps` default and rely on the existing OpenCode and Claude Code consumers. Keep browser installation and pairing operational, documented, and per profile. This implements every `browser-mcp-integration` scenario without adding host-specific modules, secrets, extension policy, or packaging.

## Architecture Decisions

| Decision | Choice and rationale | Rejected alternatives |
|---|---|---|
| Registration point | Add `browsermcp` to `defaultMcps` in `shared/opencode/mcps-base.nix:11-63`; this inventory already reaches both tools and all hosts. | Host-specific entries would duplicate configuration. |
| Local entry shape | Use only `type`, `command`, and `enabled`, matching every current base local entry (`mcps-base.nix:12-56`). Omit `environment` and `timeout`; `runtime-config.nix:38-45` supplies repository-wide local-child environment defaults. | Browser-specific environment or timeout values have no requirement and would diverge from base style. |
| Browser setup | Document manual Chrome Web Store installation and **Connect** per Chromium profile. | Force-install policy, Edge/macOS automation, Firefox support, pinning, and a Nix derivation are binding exclusions. |

## Data Flow

```text
shared/opencode/mcps-base.nix
  -> shared/ai-assets.nix (imports the MCP option, lines 13-16)
     -> shared/opencode.nix -> shared/opencode/runtime-config.nix
        -> filter enabled + add proxy scrub environment (lines 22-45)
        -> ~/.config/opencode/opencode.json on rog, thinkcentre, t14, mact2
     -> shared/claude-code.nix
        -> local-to-stdio translation (lines 20-57)
        -> ~/.claude.json mcpServers on all four hosts (lines 193-207)
```

No edits are made to `shared/opencode/runtime-config.nix`, `shared/claude-code.nix`, `linux/home/shared-modules.nix`, or `darwin/home/shared-modules.nix`; the latter two already import both shared tool modules (`linux/home/shared-modules.nix:35-38`, `darwin/home/shared-modules.nix:34-37`).

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/mcps-base.nix` | Modify | Add the shared MCP entry. |
| `docs/browser-mcp-setup.md` | Create | Add the manual setup and operations runbook. |

## Interfaces / Contracts

The exact attrset added inside `defaultMcps` is:

```nix
browsermcp = {
  type = "local";
  command = [
    "npx"
    "-y"
    "@browsermcp/mcp@latest"
  ];
  enabled = true;
};
```

Generated OpenCode configuration may contain the global proxy-scrub `environment`; the source entry must not contain a Browser-MCP-specific override. Claude Code must translate it to `type = "stdio"`, `command = "npx"`, and args `[ "-y" "@browsermcp/mcp@latest" ]`.

## Runbook Design

Match the direct heading, numbered procedure, fenced-command, notes, and troubleshooting style used by `docs/sops-new-host.md`. Sections: Purpose (what/why); Prerequisites; Per-host installation table (`glats` on Linux, `jcuzmar` on mact2, active XRDP desktop for rog/thinkcentre); Install the extension (Web Store ID `bjfgambnhccakkhmkepdoekmckoijdlc`); Pair the current tab (**Connect**); Verify in OpenCode; Security (control of cookies, sessions, and 2FA; trusted profile only; no API key or Nix secret); Troubleshooting (direct npm-registry access on first `npx`, browser/profile mismatch, reconnect, and dormant-not-failed state without a live GUI/XRDP browser).

## Testing Strategy

1. Inspect the source diff to prove the exact shape, `@latest`, absent Browser-specific environment, and prohibited-scope absence.
2. Run `format-nix && nix flake check --no-build`; this formats the Nix edit and evaluates all three NixOS checks without building every toplevel.
3. Evaluate `homeConfigurations.<host>.config.home.ai-assets.mcps.browsermcp` as JSON for `rog`, `thinkcentre`, `t14`, and `mact2` (bare host keys) to prove shared registration.
4. Run `nix build .#nixosConfigurations.t14.config.system.build.toplevel`; use `nix-store -qR ./result` to locate generated `opencode.json` and `claude-mcp.json`, then inspect their Browser MCP objects with `jq`. This is the representative Linux output proof.
5. Run `nix build .#homeConfigurations.mact2.activationPackage` (not `jcuzmar@mact2`); inspect `result/home-files/.config/opencode/opencode.json` and the closure's `claude-mcp.json` with `jq` for Darwin parity.
6. Review the runbook against every required setup, security, and troubleshooting statement. No Go code changes, so `go test` is unaffected.

Extension installation and the **Connect** click cannot be verified without a human and live browser profile; mark both as manual post-deployment checks, not automated gates.

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable classification | None | None |
| Git repository selection | N/A: no Git command behavior | None | None |
| Commit state | N/A: no commit automation | None | None |
| Push state | N/A: no push automation | None | None |
| PR commands | N/A: no PR automation | None | None |

The new local process is fixed, declarative argv rather than user-composed shell input. Safe behavior is direct `npx` startup with runtime proxy scrubbing; failure is a visible startup error when npm is unreachable, documented without fallback credentials or secrets. No applicable matrix row requires a RED test.

## Migration / Rollout and Rollback

No migration or feature flag is required. Roll out through normal host builds, then perform manual per-profile extension setup. Roll back by reverting only the `browsermcp` attrset in `shared/opencode/mcps-base.nix` and deleting `docs/browser-mcp-setup.md`; rebuild to remove both generated registrations. Manual extension removal is optional cleanup.

## Open Questions

None.
