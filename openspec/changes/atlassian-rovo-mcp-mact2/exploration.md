# Change: atlassian-rovo-mcp-mact2

## Exploration

### Current State (verified in repo)

mact2 (the only darwin host) runs an MCP named `atlassian` that is **NOT** the official
`atlassian/atlassian-mcp-server`. The stack:

- `darwin/home/opencode/mcps-extra.nix:39-46` — entry `atlassian = { type = "local";
  command = [ "atlassian-mcp-server" ]; timeout = 60000; enabled = true; }`.
- `darwin/home/atlassian-mcp-wrapper.nix` — a `writeShellScriptBin "atlassian-mcp-server"`
  wrapper that reads 5 sops secrets (`opencode/atlassian_jira_url`, `opencode/atlassian_username`,
  `opencode/atlassian_api_token`, `opencode/confluence_url`, `opencode/confluence_pat` from
  `secrets/user/atlassian.yaml` via `darwin/home/sops.nix:15-34`), exports
  `JIRA_URL`/`JIRA_USERNAME`/`JIRA_API_TOKEN`/`CONFLUENCE_URL`/`CONFLUENCE_PERSONAL_TOKEN`, and
  execs `~/.local/share/uv/tools/mcp-atlassian/bin/python3 ~/.local/bin/mcp-atlassian-wrapper.py`.
- The actual server is therefore **sooperset/mcp-atlassian** (community Python server), installed
  **out-of-band via `uv`** in `~/.local` — not a Nix derivation. The binary name
  `atlassian-mcp-server` collides with the official repo's name but is a different product.
- Import chain: `darwin/home/shared-modules.nix:43` imports the wrapper module;
  `darwin/home/default.nix` imports `./opencode/mcps-extra.nix`.
- Runtime consumers: `shared/opencode/runtime-config.nix:22-45` (merges `mcps // extraMcps`,
  filters `enabled`, proxy-scrubs only `local` children, serializes into
  `~/.config/opencode/opencode.json`) and `shared/claude-code.nix:20-57` (translates remote to
  `{ type = "http"; url }` for Claude `.mcp.json`).
- Historical evidence the sooperset stack ran: `openspec/changes/repair-mact2-native-openai-egress/preflight-evidence.md`
  (atlassian `✓ connected` per `opencode mcp list`) and
  `openspec/changes/archive/2026-09-02-mact2-openai-tls-tunnel-via-rog/home-evidence.md`
  (live `mcp-atlassian-wrapper` child process).

### Official server research (github.com/atlassian/atlassian-mcp-server)

- Product name: **Atlassian Rovo MCP Server** — cloud-hosted, Generally Available, Apache 2.0.
- Recommended endpoint (v2, exposes more tools/products): `https://mcp.atlassian.com/v2/mcp`.
  v1 endpoints remain supported; the `/v1/sse` transport dies after 2026-06-30.
- Products: Jira, Confluence, JSM, Bitbucket, Compass, Loom, Rovo platform (Projects/Goals/Teams/
  Focus/Talent/Teamwork Graph). Tools use lazy discovery (small primary set + on-demand), saving
  context vs. flat tool lists; gateways can force `?tools=all`.
- Auth: **OAuth 2.1** (browser flow) or **API token** (`Authorization: Basic base64(email:token)`
  or service-account Bearer). API-token mode requires **org-admin enablement**
  (Atlassian Administration → Rovo → Rovo MCP server → Authentication). JSM tools work ONLY with
  API-token auth.
- **The Atlassian site URL (e.g. falabella.atlassian.net) is never configured client-side.** The
  OAuth login binds the user's Atlassian Cloud account; site access flows from that account and
  its permissions. Optional post-login optimization: pin `cloudId`/project/space in AGENTS.md.
- Security: IP allowlisting honored; admin domain controls; audit log per tool use.

### Are the existing secrets the same?

- For **OAuth mode: no secrets are consumed at all** — auth lives in the OAuth token OpenCode
  obtains via browser. The 5 sops secrets become inert for the MCP.
- For future **API-token mode: same credential type.** sooperset/mcp-atlassian consumes an
  Atlassian Cloud API token (id.atlassian.com) + email — exactly what the official server accepts
  in Basic-auth mode. `preflight-evidence.md` shows the sooperset server connected on mact2,
  indicating the stored pair was valid.
- Agent policy: secrets are ciphertext-only here. Human confirmation step (runbook): run
  `sops -d secrets/user/atlassian.yaml` on mact2 and verify `atlassian_jira_url` =
  `https://falabella.atlassian.net` and `atlassian_username` = the corporate email.

### Auth decision confirmed: OAuth 2.1

1. Official README lists OAuth 2.1 as primary; API-token mode needs admin enablement the user
   does not control.
2. OpenCode supports automatic OAuth for `type = "remote"` servers (prompts on first use;
   verified in OpenCode docs). OpenCode also supports `headers` + `{env:...}` interpolation for
   token mode, but headers are static strings — sops secret *values* cannot flow into
   `opencode.json` without extra shell plumbing, another reason OAuth wins for interactive use.
3. In-environment precedent: `drawio` (`https://mcp.draw.io/mcp`, remote + OAuth) is configured in
   the same `mcps-extra.nix` and is `✓ connected` on mact2 under the same Netskope TLS-inspection
   regime — proves the browser OAuth + callback flow works on that host.

### Affected Areas

- `darwin/home/opencode/mcps-extra.nix` — replace the `atlassian` local entry with the official
  remote entry.
- `darwin/home/atlassian-mcp-wrapper.nix` — delete (sooperset wiring).
- `darwin/home/shared-modules.nix` — remove the wrapper import (line 43).
- `darwin/home/sops.nix` — remove the 5 `opencode/atlassian_*` / `opencode/confluence_*` secret
  declarations; keep the module (sops-nix import + shared/sops.nix) intact.
- `secrets/user/atlassian.yaml` + `.sops.yaml` rule — UNCHANGED (retained inert ciphertext;
  reusable for a future API-token/JSM setup).
- `docs/atlassian-rovo-mcp.md` — new runbook (OAuth login, verification, uv uninstall, secret
  confirmation, JSM future note).
- Read-only consumers: `shared/opencode/runtime-config.nix`, `shared/claude-code.nix` (remote
  translation already supported by drawio precedent).

### Approaches

1. **Option A — Replace, retain secrets (chosen by user).** Swap the entry to the official remote;
   delete wrapper + import + sops entries; keep `secrets/user/atlassian.yaml` and its `.sops.yaml`
   rule as inert ciphertext; runbook documents `uv tool uninstall mcp-atlassian` and cleanup of
   `~/.local/bin/mcp-atlassian-wrapper.py`. Pros: clean one-source-of-truth, zero-install official
   server, secrets preserved for JSM/API-token future. Cons: none material.
2. **Option B — Coexist.** Official as `atlassian` + sooperset renamed `atlassian-community`
   (disabled). Rejected by user: duplicate token cost when both enabled, more clutter.
3. **Option C — Full cleanup.** Also delete `secrets/user/atlassian.yaml` + `.sops.yaml` rule.
   Rejected: loses reusable API-token credential for the JSM-only scenario; sops file deletion is
   irreversible-ish and touches shared secret infrastructure.

### Recommendation

Option A. It matches the user's decision, keeps the encrypted secrets as cheap inert insurance,
and removes the only out-of-Nix MCP implementation in the repo.

### Risks

- OAuth login is an interactive human step on mact2 (browser + Falabella account); cannot be
  automated from this Linux host. Documented as a manual gate, like the browser-mcp Connect step.
- Netskope TLS interception on mact2 signs `mcp.atlassian.com` with the corporate CA; the CA is
  trust-pinned on the Mac and the drawio precedent proves remote-OAuth MCPs work under it. Listed
  in troubleshooting only.
- v1→v2: v2 is the recommended endpoint; no migration concern for a new setup.
- JSM tools unavailable under OAuth (API-token only) — documented, not blocking.
- Claude Code propagation side effect: the remote entry also lands in `~/.claude.json` as
  `http` type — same behavior class as drawio today; acceptable and named in the spec.
- mact2's x86_64-darwin `homeConfigurations` derivation cannot be built on this x86_64-linux host
  (same blocker as browser-mcp-opencode task 3.4: `gentle-ai-assets` darwin drv not
  substitutable). Eval-level `nix eval` proof here; full build+switch runs on mact2 via user.
