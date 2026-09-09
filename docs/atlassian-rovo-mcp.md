# Atlassian Rovo MCP (mact2) — OAuth Migration Runbook

## Purpose

mact2 now uses the **official Atlassian Rovo MCP Server**
([atlassian/atlassian-mcp-server](https://github.com/atlassian/atlassian-mcp-server)) as a
remote MCP at `https://mcp.atlassian.com/v2/mcp`, authenticated via OAuth 2.1. This replaces
the previous community `mcp-atlassian` (sooperset) stdio server that was installed out-of-band
with `uv` and driven by API-token sops secrets. Change record:
`openspec/changes/atlassian-rovo-mcp-mact2/`.

## What Changed

| Before | After |
|---|---|
| MCP `atlassian`, `type = "local"`, command `atlassian-mcp-server` | MCP `atlassian`, `type = "remote"`, url `https://mcp.atlassian.com/v2/mcp` |
| Shell wrapper `darwin/home/atlassian-mcp-wrapper.nix` (deleted) | No wrapper; no binary needed |
| sops secrets `opencode/atlassian_*` + `opencode/confluence_*` declared in `darwin/home/sops.nix` (removed) | No Atlassian secrets declared; OAuth holds the credential |
| Server installed via `uv` in `~/.local` (out of Nix) | Cloud-hosted by Atlassian; zero install |

`secrets/user/atlassian.yaml` and its `.sops.yaml` creation rule are **retained untouched** as
inert ciphertext — reusable if a future API-token setup is needed (see below).

## Prerequisites

- mact2 rebuilt after the Nix change: `nixos-build` (on mact2).
- A browser on mact2 for the OAuth consent screen.
- Your Falabella Atlassian Cloud account with access to `falabella.atlassian.net`.
  The official server does not take a site URL anywhere — the account you authorize decides
  which sites (Jira/Confluence spaces) the MCP can reach.

## First-Time OAuth Login (mact2)

1. Open OpenCode (new session).
2. On first use of an Atlassian tool (or via `/mcp` → `atlassian` → authenticate), OpenCode
   opens the browser for the OAuth 2.1 consent flow.
3. Sign in with the **Falabella Atlassian account** and approve the requested scopes.
4. The session connects to `mcp.atlassian.com/v2/mcp` from then on; tokens refresh
   automatically.

## Verify

```sh
opencode mcp list   # atlassian: ✓ connected
```

Then ask the agent something Atlassian-bound (e.g. "list my Jira projects") to confirm real
data access, not just the handshake.

## Remove Sooperset Leftovers (out-of-Nix artifacts)

The old server was never a Nix derivation — clean it by hand once:

```sh
uv tool uninstall mcp-atlassian
rm -f ~/.local/bin/mcp-atlassian-wrapper.py
```

After the wrapper's removal from Nix, the old `atlassian-mcp-server` binary path no longer
exists in `home.packages`; these two commands remove the residual `uv` copies.

## Confirm Legacy Secrets (human-only)

Agents must never decrypt secrets. If you want to confirm what the old stack stored (site URL,
email, token type), run yourself:

```sh
sops -d secrets/user/atlassian.yaml
```

Expected: `atlassian_jira_url` = `https://falabella.atlassian.net`, `atlassian_username` =
corporate email, `atlassian_api_token` = Atlassian Cloud API token (id.atlassian.com).
That pair is the **same credential type** the official server accepts in API-token mode —
keep the file if JSM is ever needed.

## JSM / API-Token Future

Jira Service Management tools work **only** with API-token auth, and that mode requires a
Falabella org admin to enable it (Atlassian Administration → Rovo → Rovo MCP server →
Authentication) plus a scoped token. With OAuth you get Jira/Confluence/Bitbucket/Loom/platform
tools but no JSM. If JSM becomes necessary, revisit
`openspec/changes/atlassian-rovo-mcp-mact2/exploration.md` (Approach notes) — OpenCode remote
MCPs accept static `headers` with `{env:...}` interpolation, but sops values would need a shell
hook; the retained `secrets/user/atlassian.yaml` holds a valid token pair.

## Troubleshooting

- **TLS/certificate errors or blocked OAuth**: mact2 sits behind Netskope corporate TLS
  interception (issuer `ca.grupofalabella.goskope.com`). The CA is trust-pinned on the Mac and
  the same remote+OAuth pattern already works for `drawio`; if `mcp.atlassian.com` is blocked by
  policy, contact IT to allowlist it.
- **"You don't have permission to connect from this IP address"**: your org uses IP
  allowlisting for Atlassian Cloud; the egress IP (home vs office/VPN) must be allowlisted.
- **Auth loop / 401 after password change**: re-run the OAuth flow (`/mcp` → atlassian →
  authenticate); if stale, clear OpenCode's cached MCP OAuth credentials for `atlassian`.
- **Tools missing (e.g. no JSM)**: expected under OAuth — see the JSM section above.

## Rollback

Revert the four Nix edits from git history (`mcps-extra.nix` entry, wrapper file + import,
`sops.nix` declarations), rebuild. `secrets/user/atlassian.yaml` was never modified, so the
sooperset stack revives after re-running its `uv` install.

## Notes

- Claude Code on mact2 receives the same server automatically
  (`~/.claude.json` → `atlassian: { type: "http", url: "https://mcp.atlassian.com/v2/mcp" }`);
  Claude Code runs its own OAuth prompt on first use.
- Optional post-login optimization: pin `cloudId` / default Jira project / Confluence space in
  AGENTS.md to skip discovery calls (see official README "Tips and tricks").
