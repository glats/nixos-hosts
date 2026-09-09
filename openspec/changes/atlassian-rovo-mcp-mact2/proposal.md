# Proposal: Official Atlassian Rovo MCP for mact2

## Intent

Replace the mislabeled community `mcp-atlassian` (sooperset) stdio stack on mact2 with the official
`atlassian/atlassian-mcp-server` (Atlassian Rovo MCP Server) as a remote MCP at
`https://mcp.atlassian.com/v2/mcp`, authenticated via OAuth 2.1 with the user's Falabella
Atlassian account.

## Scope

### In Scope
- Replace the `atlassian` entry in `darwin/home/opencode/mcps-extra.nix` with
  `{ type = "remote"; url = "https://mcp.atlassian.com/v2/mcp"; enabled = true; }`.
- Delete `darwin/home/atlassian-mcp-wrapper.nix` and its import in `darwin/home/shared-modules.nix`.
- Remove the 5 Atlassian/Confluence secret declarations from `darwin/home/sops.nix`.
- Create `docs/atlassian-rovo-mcp.md`: OAuth login on mact2, verification
  (`opencode mcp list`), sooperset uninstall (`uv tool uninstall mcp-atlassian`,
  remove `~/.local/bin/mcp-atlassian-wrapper.py`), human secret-confirmation step
  (`sops -d secrets/user/atlassian.yaml`), JSM/API-token future note.
- Verify via `format-nix && nix flake check --no-build` plus `nix eval` proofs of the mact2 MCP
  shape and secret-prune.

### Out of Scope
- Deleting `secrets/user/atlassian.yaml` or its `.sops.yaml` creation rule (retained as inert
  ciphertext, reusable for API-token/JSM mode).
- Propagating the official server to Linux hosts (scope is mact2, per user request; the darwin
  `extraMcps` layer keeps it darwin-only).
- API-token authentication mode (requires Falabella org-admin enablement; revisit only if JSM
  tools are needed).
- Pinning `cloudId`/Jira project/Confluence space in AGENTS.md (possible follow-up after first
  OAuth login).
- Changes to `shared/opencode/runtime-config.nix` or `shared/claude-code.nix` (existing remote
  consumers; drawio proves the path).

## Capabilities

### New Capabilities
- `atlassian-rovo-mcp`: official remote Atlassian registration on mact2, sooperset stack removal,
  secret retention contract, and operational runbook.

### Modified Capabilities
None.

## Approach

Edit only the darwin MCP layer plus its wrapper/sops wiring; rely on the existing remote-MCP
consumers in `runtime-config.nix` (pass-through) and `claude-code.nix` (remote →
`{ type = "http"; url }`). OAuth is automatic in OpenCode for remote servers (first-use prompt),
matching the working `drawio` precedent on mact2.

Estimated work: Nix edits ~20 lines, runbook ~80 lines, verification 10–15 minutes.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `darwin/home/opencode/mcps-extra.nix` | Modified | `atlassian` becomes the official remote entry. |
| `darwin/home/atlassian-mcp-wrapper.nix` | Deleted | Sooperset wrapper removed. |
| `darwin/home/shared-modules.nix` | Modified | Wrapper import removed. |
| `darwin/home/sops.nix` | Modified | 5 secret declarations removed; module stays. |
| `docs/atlassian-rovo-mcp.md` | New | OAuth + uninstall + verification runbook. |
| `secrets/user/atlassian.yaml`, `.sops.yaml` | Unchanged | Inert ciphertext retained by user decision. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| OAuth login requires interactive browser on mact2 | Certain | Runbook manual gate; not automatable from this host. |
| Netskope TLS interception breaks OAuth/tool calls | Low | drawio precedent proves remote-OAuth works under Netskope on mact2; troubleshooting entry. |
| JSM tools unavailable under OAuth | Certain | Documented; requires future API-token mode with admin enablement. |
| Stale uv-installed sooperset binary shadows expectations | Medium | Runbook uninstall step; wrapper removal makes the old path impossible. |
| Claude Code also gains the remote server | Low | Same class as drawio today; named in spec, acceptable. |

## Rollback Plan

Revert the `atlassian` attrset in `darwin/home/opencode/mcps-extra.nix` to the local entry,
restore `darwin/home/atlassian-mcp-wrapper.nix` + import + sops entries (all in git history),
rebuild. `secrets/user/atlassian.yaml` was never touched, so the old stack revives fully.

## Dependencies

- OpenCode remote-MCP + automatic OAuth support (verified in docs; drawio precedent in repo).
- Interactive browser access on mact2 for the first OAuth login with the Falabella account.
- Atlassian Cloud site access for the authorizing account (falabella.atlassian.net).

## Success Criteria

- [ ] mact2 eval exposes `home.ai-assets.mcps.atlassian` as the official remote entry
      (`type = "remote"`, v2 URL, enabled).
- [ ] No `atlassian-mcp-server` wrapper package, import, or Atlassian/Confluence sops declaration
      remains in darwin config; `secrets/user/atlassian.yaml` and `.sops.yaml` unchanged.
- [ ] `format-nix && nix flake check --no-build` passes.
- [ ] Runbook enables the user to complete OAuth login on mact2, verify with `opencode mcp list`,
      and uninstall the sooperset uv tool.
