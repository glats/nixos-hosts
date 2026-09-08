## Exploration: browser-mcp-opencode

### Current State

OpenCode config on every host is generated declaratively by Home Manager. `shared/opencode.nix` defines `home.opencode.*` options and imports `./ai-assets.nix`, which imports `shared/opencode/mcps-base.nix` and `shared/opencode/mcps.nix`. MCP servers live in two merged option sets: `home.ai-assets.mcps` (base defaults in `mcps-base.nix`: `github-personal`, `github-work`, `nixos`, `context7`, `engram`, `exa`) and `home.ai-assets.extraMcps` (platform extras; darwin adds `playwright`, `gcloud`, `atlassian`, `chrome-devtools`, `mcp-xlsx`, `drawio` in `darwin/home/opencode/mcps-extra.nix`).

`shared/opencode/runtime-config.nix` merges both sets (`mcps // extraMcps`, line 23), filters by `enabled`, injects `proxyScrubEnv` into every `local` server's `environment` (lines 32–45), and serializes the whole `mcp` object into `~/.config/opencode/opencode.json` via `builtins.toJSON` (lines 94–127). The local-server entry format is `{ type = "local"; command = [ ... ]; enabled = true; environment = { ... }; timeout = ...; }` — the key field is `environment`, not `env`. The existing convention for npx-based local servers is already established (e.g. `playwright` → `["npx", "-y", "@playwright/mcp@latest"]`, `chrome-devtools` → `["npx", "-y", "chrome-devtools-mcp@latest", "--browser-url=..."]` in `darwin/home/opencode/mcps-extra.nix`).

Node.js (`npx`) is present on all four hosts: Linux via `linux/system/base/profiles/dev.nix` (`nodejs`, `nodejs_22`, ungated), mact2 via `darwin/home/packages.nix` (`nodejs`). No browser extension management exists anywhere in the repo today, and `programs.chromium` is not used.

Important cross-tool coupling: `shared/claude-code.nix` (line 21) also consumes `home.ai-assets.mcps // extraMcps` and translates every entry into Claude Code's `~/.claude.json`/`.mcp.json`. There is no per-tool MCP split — the same set feeds OpenCode AND Claude Code. Adding a server to the base therefore surfaces it in both tools.

### Browser Add-on Answer

**Yes — a per-browser extension is required, and it cannot be auto-installed by the MCP server or by npm.** Browser MCP is two cooperating halves: a Chrome/Chromium browser extension plus a local stdio MCP server (`@browsermcp/mcp`). Chrome's security boundary forbids extensions from self-installing from npm or any script, so the extension must be added to each browser one of two manual ways: (1) Chrome Web Store "Add to Chrome" (extension ID `bjfgambnhccakkhmkepdoekmckoijdlc`, v1.3.4), or (2) "Load unpacked" from a folder produced by `npx @browsermcp/mcp install`. There is no Firefox version; only Chromium-family browsers are supported (Chrome, and Chromium/Brave/Edge can also install the Chrome Web Store extension). After install there is a **manual pairing step**: open the extension popup and click **"Connect"** on the current tab (`docs.browsermcp.io/setup-extension`). There is no API key or connection token in the MCP config — the extension discovers the local server over a local WebSocket port scan.

Nix CAN declaratively manage the extension on Linux, partially: NixOS `programs.chromium.extensions` (a list of Chrome Web Store extension IDs) + `programs.chromium.enable` force-installs extensions into Chromium / Google Chrome / Brave via `ExtensionInstallForcelist` (verified option in nixpkgs). Caveats: it is a **NixOS system module, not Home Manager** (so it belongs in `hosts/*/default.nix` or a `linux/system/*` module, not in `shared/`); it **force-installs** (user cannot uninstall); it does **not** cover `microsoft-edge` (Edge reads its own policy JSON at `/etc/opt/edge/policies/managed/`, a pattern the repo already uses at `hosts/t14/default.nix:179-181`); and it does **not** cover mact2 (nix-darwin has no equivalent — Chrome on macOS would need a managed-preferences plist). Home Manager's `programs.firefox.extensions` is irrelevant (no Firefox anywhere, and no FF extension exists).

Sources: https://browsermcp.io · https://docs.browsermcp.io/setup-server.md · https://docs.browsermcp.io/setup-extension.md · https://github.com/BrowserMCP/mcp · https://www.npmjs.com/package/@browsermcp/mcp · https://chromewebstore.google.com/detail/browser-mcp-automate-your/bjfgambnhccakkhmkepdoekmckoijdlc · https://opencode.ai/docs/mcp-servers

### Affected Areas

- `shared/opencode/mcps-base.nix` — the single insertion point: add a `browsermcp` entry to `defaultMcps`, flowing to all hosts (Linux + Darwin) because both shared-modules lists import `../../shared/opencode.nix`.
- `shared/opencode/runtime-config.nix` — (read-only, no edit) merges/filters/serializes MCPs to `opencode.json`; confirms `command`-array + `environment` field shape.
- `shared/claude-code.nix` — (no edit expected, but affected) also consumes `home.ai-assets.mcps`, so a base MCP entry also lands in Claude Code.
- `linux/home/shared-modules.nix`, `darwin/home/shared-modules.nix` — no change required (opencode.nix already listed); these are the "all hosts" registration lists that confirm the base MCP path.
- `linux/system/base/profiles/dev.nix`, `darwin/home/packages.nix` — `nodejs`/`npx` already present; no change, just the dependency proof.
- `linux/system/base/profiles/browsers.nix`, `hosts/{rog,thinkcentre,t14}/default.nix`, `darwin/system/homebrew.nix` — browser inventory per host; relevant only to the manual/declarative extension decision, not the MCP entry itself.
- `docs/` — target for a one-time manual runbook (install extension + click Connect, per host) if Option A is chosen.

### Approaches

1. **Option A — shared MCP entry only; extension installed manually (recommended).** Add `browsermcp = { type = "local"; command = [ "npx" "-y" "@browsermcp/mcp@latest" ]; enabled = true; };` to `defaultMcps` in `shared/opencode/mcps-base.nix`. Document the per-host manual extension install (Chrome Web Store + click Connect) in a short `docs/` runbook.
   - Pros: one-file change, matches the existing `npx -y <pkg>@latest` pattern (`playwright`, `gcloud`, `chrome-devtools`); applies to all four hosts including mact2; no NixOS/HM/darwin split needed; extension stays user-managed and removable.
   - Cons: extension install + Connect remains manual per host per browser profile (a Nix rebuild cannot install it); runtime `npx` fetch is non-deterministic and needs npm-registry reachability; surfaces the server in Claude Code too (shared `mcps` option).
   - Effort: Low.

2. **Option B — A plus declarative extension install on Linux.** Keep the MCP entry from A, and additionally set `programs.chromium.extensions = [ "bjfgambnhccakkhmkepdoekmckoijdlc" ];` + `programs.chromium.enable = true;` in the Linux system config (not HM), plus an Edge policy JSON for Edge-using hosts.
   - Pros: removes the manual install step for Chrome/Chromium/Brave on Linux hosts; matches the "declarative everything" ethos.
   - Cons: NixOS system module (lives outside `shared/`, per-host or `linux/system/`); force-install (user cannot remove, which is undesirable for a security-sensitive automation extension); does not cover Edge (needs separate policy JSON) nor mact2 (manual only); more moving parts across Linux + Darwin asymmetry.
   - Effort: Medium.

3. **Option C — package `@browsermcp/mcp` as a Nix derivation.** A `buildNpmPackage` (source = npm tarball via `fetchFromNPM`) pinned to `0.1.3`, then reference the built binary path in the MCP `command` instead of `npx`.
   - Pros: deterministic, no runtime fetch, no npm-registry dependency at first-run.
   - Cons: upstream README states the package "cannot yet be built on its own due to dependencies on utils and types from the monorepo" (GitHub `BrowserMCP/mcp`); pinning a 0.1.3 package that the vendor intends to move to `@latest` self-updating; extra maintenance with no functional gain over npx.
   - Effort: Medium-High.

### Recommendation

Option A. It is the minimal, pattern-consistent change: one entry in `shared/opencode/mcps-base.nix` gives every host (rog, thinkcentre, t14, mact2) the Browser MCP server in OpenCode, exactly mirroring how `playwright`/`chrome-devtools` are already wired. The browser extension and its "Connect" pairing are inherently manual and per-browser (a Chrome security boundary, not a Nix gap), so the honest deliverable is: declarative MCP server + a one-time runbook for the extension. Option B's declarative extension install is available as a follow-up only if the Linux hosts want forced, non-removable extension management, but it cannot cover mact2 or Edge and adds a NixOS-system-module path that does not belong in `shared/`. The design/proposal phase should explicitly decide whether the shared `mcps` option surfacing `browsermcp` into Claude Code as well is acceptable (it likely is, but it is a side effect to name).

### Risks

- `runtime-config.nix` scrubs `HTTPS_PROXY`/`HTTP_PROXY`/`ALL_PROXY` for local MCP children (lines 32–45), so `npx` must reach the npm registry directly; hosts that rely on a proxy for npm fetches could fail the first `npx` run.
- The npm package is pinned at `0.1.3` (last publish 2025-12-18); `@latest` gives self-updating behavior but is non-reproducible; a pinned version (`@0.1.3`) is reproducible but never auto-updates.
- Adding to the base `mcps` also registers `browsermcp` in Claude Code (`shared/claude-code.nix:21`) — unintended unless accepted.
- Browser MCP grants an AI agent control of your real logged-in browser profile (cookies, sessions, 2FA) — a meaningful trust/security decision per host, especially the home-server `rog`.
- It requires a live GUI session with the browser running and the extension "Connect"-ed; on `thinkcentre` and `rog` (XRDP-only desktops) the server starts but has nothing to connect to until an XRDP session is active with a browser open — dormant, not an error.
- The extension is manual, so it silently breaks after a browser-profile wipe or a fresh host; the runbook must be re-run per host.

### Ready for Proposal

Yes. The orchestrator should tell the user: (1) Browser MCP needs both a local MCP server (declarable in Nix) and a per-browser Chrome extension that MUST be installed manually per host and paired with one "Connect" click — this is a Chrome security boundary, not something Nix can fully automate (Option B can force-install it on Chrome/Chromium/Brave Linux hosts only, not Edge/mact2, and makes it non-removable). (2) Recommend Option A now: declarative `browsermcp` MCP entry in `shared/opencode/mcps-base.nix` + a short manual-install runbook, with Option B as an explicit follow-up if forced Linux extension management is wanted. (3) Flag the Claude-Code side effect of the shared `mcps` option and the trust/security implications per host.
