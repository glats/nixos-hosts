# supermercados-mcp

Objective: adopt `NLACE-COM/mcp-supermercados-cl` as a pinned, Nix-built stdio MCP server for the Linux hosts only (rog, thinkcentre, t14), never macm5.
Branch: `feature/supermercados`. Delivery strategy: `single-pr` (small change, push/PR left to the user). Test runner: `nix build .#mcp-supermercados-cl`, host `nix eval` of Linux home/toplevel, `nix flake check --no-build`.

## Specs

S1. "tool adoption solo para linuxes (no macm5) https://github.com/NLACE-COM/mcp-supermercados-cl" — the MCP server is available to agents on rog, thinkcentre, and t14, and is absent from macm5.
S2. Pinned build: `pkgs/mcp-supermercados-cl` builds upstream tag `v1.4.9` (commit `82e6bf8d94e58ec9655c0a0ab031614517bda0c1`, MIT) from source with `buildNpmPackage` and the upstream `package-lock.json`; no `npx`, no `@latest`, no runtime download.
S3. Linux-only wiring: the package is exported only through `linuxPackages` and the Linux overlay; the MCP entry lives in a Linux Home Manager module registered in `linux/home/shared-modules.nix`, merged through `home.ai-assets.extraMcps` (OpenCode and Claude Code both consume it).
S4. Assumption: the optional Playwright anti-bot bridge (`SUPERMERCADOS_PLAYWRIGHT_*`) is not configured; Tottus/Lider use the upstream manual `browserHtml` flow. Re-entry: a dedicated browser profile plus a pinned Playwright.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1-S4 | parent inline (one understood change; no writer trigger); independent verifier (Risk item 5) | done | commit 35363d73; checks in L4, verifier L5 |

## Log

L1 (2026-10-17, user, verbatim): "tool adoption solo para linuxes (no macm5) https://github.com/NLACE-COM/mcp-supermercados-cl"
L2 (2026-10-17, user, verbatim): "full odd"
L3 (2026-10-17, research): upstream MIT, TypeScript, npm `mcp-supermercados-cl@1.4.9` (2026-10-16, SLSA provenance), runtime deps only `@modelcontextprotocol/sdk` and `zod`; stdio transport, no listener; outbound HTTPS to Jumbo/Santa Isabel/Unimarc/Tottus/Lider at a human-paced rate with a 15 min in-memory cache; no telemetry found; session data stays in the user's browser (snippets), the server never receives credentials. Public frontend API keys embedded in source are not secrets. Playwright bridge is opt-in by env and reuses a Chrome profile (profile lock risk), so it is deferred. Harness fit: `home.ai-assets.extraMcps` (darwin already uses it via `darwin/home/opencode/mcps-extra.nix`); pinned npm build pattern exists in `pkgs/archify-skill`.
L4 (2026-10-17, checks): RED — `nix build .#mcp-supermercados-cl` failed on fake source/npm-deps hashes. GREEN — pinned hashes build `/nix/store/yxgg43a7…-mcp-supermercados-cl-1.4.9` (28M); stdio smoke returns serverInfo 1.4.9 and 14 tools. `extraMcps` names: rog/thinkcentre/t14 `["supermercados"]` (NixOS and standalone HM); macm5 unchanged (`atlassian, chrome-devtools, drawio, gcloud, mcp-xlsx, playwright`). Rendered rog `opencode.json` has `mcp.servers.supermercados` (local, store-path command). Linux toplevel drvPaths evaluate; `nix flake check --no-build` all checks passed; `nix fmt` 0 changed. macm5 toplevel eval fails on this Linux host at baseline bf758984 too (gentle-ai darwin IFD) — environmental. RDD globally off; native assess `medium`, raised to Risk item 5 (new third-party npm dependency). Work-unit commit 35363d73.
L5 (2026-10-17, verify): independent verifier PASS S1-S4, no blockers; confirmed tag v1.4.9 peels to 82e6bf8d, package only in linuxPackages/Linux overlay, existing MCPs unchanged vs baseline, Claude Code also receives the entry. Pending: activation with `nixos-build` on each Linux host (user); push/PR (user).
