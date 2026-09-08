# Browser MCP Setup

## Purpose

Browser MCP gives the agent (OpenCode or Claude Code) control of a Chromium
browser tab via the [Browser MCP](https://browsermcp.com) project. The MCP
server side is handled automatically: both tools already receive the
`browsermcp` local server (`npx -y @browsermcp/mcp@latest`) from this repo's
shared configuration. What remains manual is the browser side:

- Install the Browser MCP extension in a Chromium-family browser.
- Click **Connect** in the extension popup while on the tab you want the
  agent to work with.

There is **no** API key, sops secret, or any other Nix-side credential to
configure. The pairing lives entirely in the browser profile.

## Prerequisites

- `npx` is available on the system — already true on all hosts (Nix hosts ship
  Node.js; mact2 has Node via Homebrew/mise).
- Network access to the npm registry (`registry.npmjs.org`) on the **first**
  server start — the repo scrubs proxy environment variables for MCP child
  processes, so the first `npx` run cannot go through a proxy. See
  [Troubleshooting](#troubleshooting).
- A Chromium-family browser profile you are willing to trust the agent with.
- The Browser MCP extension: opens in Chrome Web Store.

## Per-Host Setup

| Host | User | Browser environment | Session requirement |
|------|------|--------------------|---------------------|
| rog | glats | Chromium-family browser in an **active desktop (XRDP)** session | The server stays dormant until an active desktop session has a browser open and paired |
| thinkcentre | glats | Chromium-family browser in an **active desktop (XRDP)** session | Same dormant-until-paired behavior as rog |
| t14 | glats | Chromium-family browser under Hyprland (Omarchy) | Browser window must be open and paired during agent use |
| mact2 | jcuzmar | macOS Chrome | Chrome running with the profile paired during agent use |

Setup is **per browser profile**. Each profile where you want Browser MCP
needs the extension installed and its own **Connect** pairing. Pairing does
not transfer between profiles or between hosts.

Both the extension install and the **Connect** click are manual
post-deployment steps — they are deliberately **not automated** by this repo
(no extension force-install policy, no AppleScript/Edge policy, no Firefox
support). Nothing in a host build performs them for you.

## Install the Extension

1. Chrome Web Store ID:
   `bjfgambnhccakkhmkepdoekmckoijdlc`
   Direct link: https://chromewebstore.google.com/detail/bjfgambnhccakkhmkepdoekmckoijdlc
2. Click **Add to Chrome** (or the equivalent for your Chromium-family
   browser: Brave, Edge, Vivaldi, etc.) and confirm.
3. Pin the extension so the popup is easy to reach.

## Pair the Current Tab

1. Open the browser tab you want the agent to control.
2. Click the Browser MCP extension icon.
3. Click **Connect**.
4. A status indicator in the popup shows the tab is paired.

The MCP server process (`@browsermcp/mcp`) is started by OpenCode/Claude Code
on demand. It connects to the extension through the paired browser. If no
extension is paired, the server starts but has nothing to talk to.

## Verify in OpenCode

1. Open OpenCode (`opencode` in a terminal) on the host.
2. Browser MCP tools should appear in the available tools for the session.
3. Ask the agent to navigate or read the paired tab: a successful tool call
   means the extension-to-server pairing works.
4. If tools are absent, check the pairing status in the extension popup and
   re-run **Connect**, then restart OpenCode so the server process reconnects.

## Security

- **The agent gains control of the logged-in browser profile**: cookies,
  authenticated sessions, and 2FA flows reachable in that profile are all
  exposed to the paired tab's content and whatever the agent chooses to do
  with the tab.
- Grant access **consciously, per profile**. Pair only a profile dedicated to
  work you are comfortable delegating (ideally a separate work profile).
-   Do not pair your main personal profile where banking websites, primary
  email, or 2FA wallets live.
- There is no API key or Nix-side secret: trust is the pairing itself. This
  means no sops secret needs to be added anywhere in this repo.

## Troubleshooting

- **First `npx` startup fails with a network error.** The repo strips
  `HTTP_PROXY`/`HTTPS_PROXY`/`ALL_PROXY` env vars from MCP child processes,
  so the first run (which downloads `@browsermcp/mcp` from
  `registry.npmjs.org`) needs **direct** reachability to the npm registry.
  If your network requires a proxy for npm, configure the proxy inside npm's
  own config (`npm config set proxy ... https-proxy ...`) rather than relying
  on environment variables. Subsequent starts use the local cache.
- **Tools listed but every call fails / hangs.** The paired tab was closed,
  the browser restarted, or the profile changed. Re-open the tab, click
  **Connect** again, and restart the agent session.
- **Browser/profile mismatch.** Extension installed in profile A but
  **Connect** was clicked in profile B — pair the same profile you intend to
  use. On macOS Chrome Profile switching also un-pairs.
- **Server appears dormant with no error on rog/thinkcentre.** This is not a
  failure: with no active XRDP desktop session there is no live browser to
  connect to, so the MCP server idles until an active desktop session opens a
  paired   browser. It is dormant, not failed.
- **Reconnect after host reboot.** Extension pairing survives reboots, but
  the tab session does not. Re-open the browser and confirm the popup still
  shows the tab as connected; click **Connect** if not.
