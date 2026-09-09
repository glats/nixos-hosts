# Design: Official Atlassian Rovo MCP for mact2

## Technical Approach

Swap the darwin-only `atlassian` MCP entry from a local stdio command to the official remote
endpoint, and remove the sooperset wiring (wrapper module, import, sops declarations). Both
runtime consumers already handle `type = "remote"` with zero changes: `runtime-config.nix`
passes remote entries through untouched (proxy scrub is local-only), and `claude-code.nix`
translates remote → `{ type = "http"; url }`. OAuth 2.1 is OpenCode's default for remote servers
(no `oauth = false`, no headers), so no credentials enter any generated config.

## Architecture Decisions

| Decision | Choice and rationale | Rejected alternatives |
|---|---|---|
| Registration point | Keep name `atlassian` in `darwin/home/opencode/mcps-extra.nix` (`extraMcps`); darwin-only scope matches the user request and the current inventory location. | Base `mcps-base.nix` would leak the corporate Atlassian server to Linux hosts. |
| Endpoint | `https://mcp.atlassian.com/v2/mcp` — the officially recommended v2 endpoint (more tools/products; `/v1/sse` deprecated after 2026-06-30). | v1 `/mcp` (legacy), `?tools=all` (only for gateways needing flat lists). |
| Auth | OAuth 2.1 via OpenCode's automatic remote-OAuth flow; no `headers`, no `oauth` block, no secrets in config. | API-token header mode needs Falabella org-admin enablement and static headers that cannot read sops values; JSM-only concern, deferred. |
| Entry shape | `type`/`url`/`enabled` only, mirroring the `drawio` remote entry (no `timeout`). | Carrying the old `timeout = 60000` (local-stdio concern, meaningless for remote). |
| Sooperset removal | Delete wrapper module + import + 5 sops declarations; document out-of-Nix cleanup (`uv tool uninstall`). | Keeping both servers (token cost, confusion) or renaming (clutter). |
| Secret retention | `secrets/user/atlassian.yaml` + `.sops.yaml` rule untouched — inert ciphertext, reusable for a future API-token/JSM setup. | Full deletion is irreversible-ish and removes a valid, evidence-backed credential pair. |

## Data Flow

```text
darwin/home/opencode/mcps-extra.nix (atlassian = remote v2 URL)
  -> home.ai-assets.extraMcps
     -> shared/opencode/runtime-config.nix (merge, filter enabled; remote passes through,
        lines 38-45) -> ~/.config/opencode/opencode.json (mact2)
        -> OpenCode first use: OAuth 2.1 browser flow -> mcp.atlassian.com
           -> Falabella Atlassian account scopes (Jira/Confluence/...)
     -> shared/claude-code.nix (remote translation, lines 41-50)
        -> ~/.claude.json mcpServers.atlassian = { type = "http"; url = v2 URL }
```

## File Changes

| File | Action | Description |
|---|---|---|
| `darwin/home/opencode/mcps-extra.nix` | Modify | Replace local `atlassian` entry with official remote entry. |
| `darwin/home/atlassian-mcp-wrapper.nix` | Delete | Remove sooperset wrapper. |
| `darwin/home/shared-modules.nix` | Modify | Drop wrapper import. |
| `darwin/home/sops.nix` | Modify | Drop 5 `opencode/atlassian_*` / `opencode/confluence_*` declarations. |
| `docs/atlassian-rovo-mcp.md` | Create | Operational runbook. |

## Interfaces / Contracts

Exact attrset replacing the current entry inside `extraMcps`:

```nix
atlassian = {
  type = "remote";
  url = "https://mcp.atlassian.com/v2/mcp";
  enabled = true;
};
```

Generated outputs after this change:
- OpenCode (`mact2`): `mcp.atlassian = { type = "remote"; url = "https://mcp.atlassian.com/v2/mcp"; enabled = true; }` (no environment key — remote skips proxy scrub).
- Claude Code (`mact2`): `mcpServers.atlassian = { type = "http"; url = "https://mcp.atlassian.com/v2/mcp" }`.
- `home.packages` no longer contains `atlassian-mcp-server`; `config.sops.secrets` no longer
  contains the five `opencode/atlassian_*` / `opencode/confluence_*` keys.

## Runbook Design

`docs/atlassian-rovo-mcp.md`, matching `docs/sops-new-host.md` / `docs/browser-mcp-setup.md`
style: Purpose; What changed (mapping table old→new); Prerequisites; First-time OAuth login on
mact2 (OpenCode prompt → browser → Falabella account → scopes); Verify (`opencode mcp list`);
Uninstall sooperset leftovers (`uv tool uninstall mcp-atlassian`,
`rm ~/.local/bin/mcp-atlassian-wrapper.py`); Confirm legacy secrets (human-only
`sops -d secrets/user/atlassian.yaml` — agents never decrypt); JSM/API-token future note;
Troubleshooting (Netskope CA note, OAuth re-auth, IP allowlist error message from official docs).

## Testing Strategy

1. Diff inspection: exact remote shape, wrapper/import/sops removals, secret files untouched.
2. `format-nix && nix flake check --no-build` (mandatory repo gate; `--no-build` avoids building
   all three NixOS toplevels).
3. Eval proof: `nix eval --json .#homeConfigurations.mact2.config.home.ai-assets.mcps.atlassian`
   → exact required shape.
4. Eval proof of removal: `nix eval --json .#homeConfigurations.mact2.config.sops.secrets` → the
   five removed keys absent; remaining secrets intact.
5. Darwin toplevel build on this host is BLOCKED (x86_64-darwin `gentle-ai-assets` drv not
   substitutable here — same precedent as browser-mcp-opencode task 3.4); the build+switch and
   `opencode mcp list` run on mact2 as documented manual gates.
6. Claude propagation: same `nix eval` path cannot expose claude-mcp.json content (activation
   script), but the translation is deterministic from the shared attrset — covered by the shape
   proof in 3 plus unchanged `shared/claude-code.nix`.

OAuth login, the `opencode mcp list` check, and the uv uninstall are human steps on mact2 —
manual post-deployment checks, not automated gates.

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable classification | None | None |
| Git repository selection | N/A: no Git command behavior | None | None |
| Commit state | N/A: no commit automation | None | None |
| Push state | N/A: no push automation | None | None |
| PR commands | N/A: no PR automation | None | None |

No local process is spawned (remote server), no credentials enter config (OAuth), and the deleted
wrapper never handled user-composed input. No matrix row requires a RED test.

## Migration / Rollout and Rollback

Rollout: repo change lands via normal git flow; user rebuilds on mact2 (`nixos-build`), completes
OAuth in the next OpenCode session, then runs the uninstall + verification steps from the runbook.
Rollback: revert the four Nix edits from git history; `secrets/user/atlassian.yaml` was never
modified, so the sooperset stack revives after re-running its uv install (documented in runbook).

## Open Questions

None. Both user decisions recorded: replace-keep-secrets; OAuth 2.1 (with human confirmation of
secret contents and login respectively, as runbook steps).
