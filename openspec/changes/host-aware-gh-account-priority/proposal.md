# Proposal: Host-aware GitHub CLI Account Priority

## Intent

Reassert the preferred active `gh` account after Home Manager activation without replacing either stored GitHub account or affecting explicit MCP account selection.

## Scope

### In Scope
- Add shared Home Manager activation behavior that selects the configured existing `github.com` account with `gh auth switch --user`.
- Set the default active account to `glats` on `rog`, `t14`, and `thinkcentre`, and to `jcuzmar-Falabella_FTC` on `mact2`.
- Make a missing login a safe no-op, preserving both authenticated accounts and their keyring-backed tokens.

### Out of Scope
- Fake GitHub hostnames, `programs.gh.hosts`, `hosts.yml` ownership, or token/PAT management.
- Changes to `shared/github-mcp-wrapper.nix` or `shared/opencode/mcps-base.nix`; `github-personal` and `github-work` remain explicit `--user` wrappers.
- Per-directory account switching or handling stale `GH_TOKEN`/`GITHUB_TOKEN` environments.

## Capabilities

### New Capabilities
- `github-cli-account-priority`: Host-specific default selection of an already-authenticated GitHub CLI account after Home Manager activation.

### Modified Capabilities
None.

## Approach

Create a shared Home Manager module with an overridable default-account option. Import it from Linux and Darwin shared module lists. An idempotent activation entry runs after Home Manager writes its files, checks that the target account exists in `~/.config/gh/hosts.yml`, then invokes the absolute `gh auth switch --hostname github.com --user <account>` command. Errors are non-fatal to support first-run hosts.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/gh-default-account.nix` | New | Option and guarded activation entry. |
| `linux/home/shared-modules.nix` | Modified | Import shared module for rog/t14/thinkcentre. |
| `darwin/home/shared-modules.nix` | Modified | Import shared module for mact2. |
| `darwin/home/default.nix` | Modified | Set or inherit the mact2 work-account default. |
| `shared/github-mcp-wrapper.nix` | Unchanged | Explicit personal/work wrapper contract. |
| `shared/opencode/mcps-base.nix` | Unchanged | MCP server registration contract. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Target account is not logged in | Low | Guard and no-op without failing activation. |
| Manual account selection is reverted | Medium | Document Home Manager activation as the host-policy boundary. |
| Darwin keychain behavior differs | Low | Verify on mact2; switching only changes the active marker. |

## Rollback Plan

Remove the shared module imports and activation entry, then run Home Manager activation. Existing `hosts.yml` account entries and keyring tokens remain intact; select an account manually with `gh auth switch` if needed.

## Dependencies

- Existing `gh` installation and user-managed authentication for both accounts on each host.

## Success Criteria

- [ ] Activation selects `glats` on rog, t14, and thinkcentre, and `jcuzmar-Falabella_FTC` on mact2.
- [ ] Both accounts remain listed and usable on every host; only the active marker changes.
- [ ] `gh auth status --active --hostname github.com` reports each host's expected account.
- [ ] Activation succeeds without a `gh` login and performs no interactive authentication.
- [ ] The two GitHub MCP wrappers and their explicit `--user` behavior are unchanged.
- [ ] No fake hosts, `programs.gh.hosts`, or token/PAT management is introduced.
- [ ] `nix flake check --no-build` passes for all four hosts.
