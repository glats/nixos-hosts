# Proposal: Unify GitHub Auth

## Intent

- Replace fragile Linux PAT-based GitHub auth with the already-proven `gh` multi-account flow used on `mact2`.
- Remove structural expiry/SSO breakage from MCP wrappers and shell auth, especially for the Falabella work account.
- Host scope: `rog` deploy now; `t14` deploy after pull; `thinkcentre` config update only for now; `mact2` is reference-only and out of scope.

## Scope

### In Scope
- Move the Darwin GitHub MCP wrapper into shared Home Manager as `shared/github-mcp-wrapper.nix` and import it on Linux and Darwin.
- Remove Linux PAT plumbing: MCP service wrapper, token-check activation script, shell `GH_TOKEN` export, and sops PAT declarations.
- Keep non-PAT GitHub secrets intact, preserving GPG-based material and existing account names.

### Out of Scope
- Reworking `mact2` auth behavior beyond validating that shared-module evaluation still passes.
- Editing encrypted secrets files; stale PAT ciphertext may remain until a later cleanup.

## Capabilities

### New Capabilities
- `github-auth`: Defines repo-managed GitHub auth through `gh auth token --hostname github.com --user <user>` for personal and work accounts, replacing implicit PAT-backed wrapper/shell behavior.

### Modified Capabilities
- None. Existing specs under `openspec/specs/boot` and `openspec/specs/hardware-nvidia` do not cover GitHub auth behavior.

## Approach

- Promote the current Darwin wrapper logic into `shared/github-mcp-wrapper.nix` unchanged in behavior.
- Import it from `darwin/home/shared-modules.nix` and `linux/home/shared-modules.nix`.
- Delete Linux-only PAT modules and remove host imports from `hosts/rog/default.nix`, `hosts/t14/default.nix`, and `hosts/thinkcentre/default.nix`.
- Remove PAT-derived `GH_TOKEN` exports so active-account switching stays controlled by `gh`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/github-mcp-wrapper.nix` | New | Shared multi-account wrapper/pre-check |
| `darwin/home/github-mcp-server-wrapper.nix` | Removed | Superseded by shared module |
| `linux/home/shared-modules.nix`, `darwin/home/shared-modules.nix` | Modified | Import shared wrapper |
| `linux/system/services/github-mcp-server.nix`, `linux/system/services/github-token-check.nix` | Removed | Delete PAT-based Linux services |
| `hosts/{rog,thinkcentre,t14}/default.nix` | Modified | Remove deleted module imports |
| `linux/home/shell.nix`, `linux/system/base/sops.nix` | Modified | Remove PAT env/secret declarations |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Host lacks `gh` login for one account | Med | Wrapper pre-check fails early; verify on target hosts before deploy |
| Shared-module regression affects Darwin eval | Low | Run flake check plus Linux/Darwin eval-only checks |

## Rollback Plan

- Revert this change to restore Linux PAT modules, host imports, shell exports, and sops declarations.
- If deployment fails on a host, stop before switch, re-enable prior imports, and keep existing encrypted PAT entries available for temporary rollback.

## Dependencies

- Existing `gh` multi-account logins: personal `glats`, work `jcuzmar-Falabella_FTC`.
- Verification: `format-nix`, `nix flake check --no-build`, and eval-only checks for `rog`, `t14`, `thinkcentre`, and `mact2`.

## Success Criteria

- [ ] Linux and Darwin evaluate with the shared wrapper and no references to GitHub PAT secrets or token-check modules remain in active config.
- [ ] `rog`, `t14`, and `thinkcentre` resolve GitHub MCP auth through `gh` accounts; host rollout status matches approved scope.
