# Tasks: Browser MCP for OpenCode

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~35-55 (Nix entry ~8 + runbook ~40) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Nix entry + eval proof + runbook | PR 1 | `format-nix && nix flake check --no-build` | `nix build .#nixosConfigurations.t14.config.system.build.toplevel` + `nix build .#homeConfigurations.mact2.activationPackage` | Revert `browsermcp` attrset in `shared/opencode/mcps-base.nix` + delete `docs/browser-mcp-setup.md` |

## Phase 1: Core Implementation

- [x] 1.1 Add `browsermcp` local entry to `defaultMcps` in `shared/opencode/mcps-base.nix`, placed in the local-server block (after `engram`, before remote `exa`), matching existing style exactly: `browsermcp = { type = "local"; command = [ "npx" "-y" "@browsermcp/mcp@latest" ]; enabled = true; };` — `@latest`, no `environment`/`timeout`, no pinning, no derivation.
- [x] 1.2 Confirm the diff touches ONLY `shared/opencode/mcps-base.nix` (edit) plus the new runbook; verify `shared/opencode/runtime-config.nix` (read-only), `shared/claude-code.nix` (read-only), `shared/ai-assets.nix` (read-only), `linux/home/shared-modules.nix` (read-only), and `darwin/home/shared-modules.nix` (read-only) are untouched.

## Phase 2: Validation

- [x] 2.1 Run `format-nix` on the repo; confirm `shared/opencode/mcps-base.nix` is formatted cleanly.
- [x] 2.2 Run `nix flake check --no-build` (MUST include `--no-build` to avoid building all three NixOS toplevels); confirm all checks pass.

## Phase 3: Eval / Build Proof

- [x] 3.1 Evaluate shared registration as JSON: `nix eval --json .#homeConfigurations.<host>.config.home.ai-assets.mcps.browsermcp` for rog, thinkcentre, t14, and mact2 (bare host keys); assert `command`/`enabled` match and no Browser-specific `environment` key.
- [x] 3.2 Run `nix build .#nixosConfigurations.t14.config.system.build.toplevel`; `nix-store -qR ./result` to locate generated `opencode.json`, inspect `mcp.browsermcp` with `jq` (env contains repo-wide proxy scrub, command `["npx","-y","@browsermcp/mcp@latest"]`).
- [x] 3.3 From the t14 closure, locate and `jq`-inspect the generated Claude `claude-mcp.json` (read-only result file); assert `mcpServers.browsermcp` = `{ type="stdio"; command="npx"; args=["-y","@browsermcp/mcp@latest"]; }` — this proves Claude propagation on a Linux host.
- [ ] 3.4 Run `nix build .#homeConfigurations.mact2.activationPackage` (NOT `jcuzmar@mact2`); inspect `result/home-files/.config/opencode/opencode.json` `mcp.browsermcp` with `jq` for Darwin parity. — **BLOCKED on this apply batch**: the x86_64-darwin derivation `gentle-ai-assets` (`/nix/store/8bxlwsnk9m4wiy33dfpbb6g6q6ffh09c-...drv`) is required and not substitutable from any cache, so it cannot be built or IFD-evaluated on this x86_64-linux host. Run the build on mact2 (e.g. `nixos-build` there). Partial proof achieved: `nix eval --json .#homeConfigurations.mact2.config.home.ai-assets.mcps.browsermcp` = exact required shape.

## Phase 4: Documentation

- [x] 4.1 Create `docs/browser-mcp-setup.md` runbook matching `docs/sops-new-host.md` style: Purpose; Prerequisites; per-host table (`glats` Linux, `jcuzmar` on mact2, active XRDP desktop for rog/thinkcentre); Install extension (Web Store ID `bjfgambnhccakkhmkepdoekmckoijdlc`); **Connect** on current tab; Verify in OpenCode; Security (agent controls logged-in profile: cookies/sessions/2FA, trusted profile only, no API key or Nix secret); Troubleshooting (direct npm-registry reachability on first `npx`, profile/browser mismatch, reconnect, dormant-not-failed without live GUI/XRDP browser).

## Phase 5: Final Gate

- [x] 5.1 Run `format-nix && nix flake check --no-build`; confirm passing as final verification gate.
- [x] 5.2 Confirm manual human step (install extension + click **Connect** per host per Chromium profile) is explicitly documented as OUT of automation — not an automated gate.