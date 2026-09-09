# Tasks: Official Atlassian Rovo MCP for mact2

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~130-170 (Nix ~25 + wrapper delete -40 + runbook ~85) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

Decision needed before apply: No (user decided: replace-keep-secrets; OAuth 2.1)
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Nix swap + removals + runbook + eval proofs | PR 1 | `format-nix && nix flake check --no-build` | `nix eval .#homeConfigurations.mact2.config.home.ai-assets.mcps.atlassian` + `nix eval .#homeConfigurations.mact2.config.sops.secrets` | Revert the 4 Nix edits from git history; secret files untouched |

## Phase 1: Core Implementation

- [x] 1.1 Replace the `atlassian` entry in `darwin/home/opencode/mcps-extra.nix` with
      `atlassian = { type = "remote"; url = "https://mcp.atlassian.com/v2/mcp"; enabled = true; }`
      (drop the old `command`/`timeout`/local shape; keep alphabetical position).
- [x] 1.2 Delete `darwin/home/atlassian-mcp-wrapper.nix` and remove its import line from
      `darwin/home/shared-modules.nix`.
- [x] 1.3 Remove the five secret declarations (`opencode/atlassian_jira_url`,
      `opencode/atlassian_username`, `opencode/atlassian_api_token`, `opencode/confluence_url`,
      `opencode/confluence_pat`) from `darwin/home/sops.nix`, keeping the module (sops-nix
      import + `shared/sops.nix`) intact.
- [x] 1.4 Confirm `secrets/user/atlassian.yaml` and `.sops.yaml` are untouched (retention
      contract).

## Phase 2: Documentation

- [x] 2.1 Create `docs/atlassian-rovo-mcp.md` per the runbook design: Purpose; What changed
      mapping; Prerequisites; First-time OAuth login on mact2 (browser, Falabella account);
      Verify (`opencode mcp list`); Uninstall sooperset leftovers
      (`uv tool uninstall mcp-atlassian`, `rm ~/.local/bin/mcp-atlassian-wrapper.py`);
      Human-only legacy-secret confirmation (`sops -d secrets/user/atlassian.yaml` — agents
      never decrypt); JSM/API-token future note; Troubleshooting (Netskope CA, re-auth,
      IP allowlist error).

## Phase 3: Validation

- [x] 3.1 Run `format-nix`; confirm clean formatting of all touched Nix files.
- [x] 3.2 Run `nix flake check --no-build`; confirm passing (includes mact2 darwin eval).
- [x] 3.3 Eval proof of the new shape (darwin extras live in `extraMcps`, merged with base
      `mcps` by `runtime-config.nix:23`; base path does not apply):
      `nix eval --json .#homeConfigurations.mact2.config.home.ai-assets.extraMcps.atlassian` →
      `{"enabled":true,"type":"remote","url":"https://mcp.atlassian.com/v2/mcp"}`.
- [x] 3.4 Eval proof of removals:
      `nix eval --json .#homeConfigurations.mact2.config.sops.secrets` → the five removed keys
      absent; unrelated secrets intact.
- [x] 3.5 Repo grep: no remaining references to `mcp-atlassian`, `atlassian-mcp-server` (binary),
      `JIRA_URL`, or `CONFLUENCE_PERSONAL_TOKEN` outside docs/history/encrypted file.

## Phase 4: Manual Post-Deployment Gates (on mact2, human)

- [x] 4.1 Rebuild on mact2 (`nixos-build`) — NOT runnable from this Linux host (x86_64-darwin
      drv blocker, browser-mcp-opencode 3.4 precedent).
      - user-confirmed deployment on mact2, 2026-09-08 ("quedó bien").
- [x] 4.2 Complete the first OAuth 2.1 login (OpenCode prompts; browser → Falabella Atlassian
      account) and confirm with `opencode mcp list`.
      - user-confirmed deployment on mact2, 2026-09-08 ("quedó bien").
- [x] 4.3 Run the sooperset uninstall steps from the runbook.
      - user-confirmed deployment on mact2, 2026-09-08 ("quedó bien").
- [ ] 4.4 (Optional, human-only) Confirm legacy secret contents:
      `sops -d secrets/user/atlassian.yaml` → verify site + email.
      - optional, not confirmed.
