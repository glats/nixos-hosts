# macOS-specific MCPs that can be merged with mcps-base.nix
{ config
, lib
, pkgs
, ...
}:

with lib;

let
  # Extra MCPs for macOS
  extraMcps = {
    drawio = {
      type = "remote";
      url = "https://mcp.draw.io/mcp";
      enabled = true;
    };

    playwright = {
      type = "local";
      command = [
        "npx"
        "-y"
        "@playwright/mcp@latest"
      ];
      enabled = true;
    };

    gcloud = {
      type = "local";
      command = [
        "npx"
        "-y"
        "@google-cloud/gcloud-mcp"
      ];
      enabled = true;
    };

    # Official Atlassian Rovo MCP Server (remote, OAuth 2.1). OpenCode
    # triggers the browser OAuth flow on first use; the authorized Atlassian
    # Cloud account (e.g. falabella.atlassian.net) determines site access.
    # See docs/atlassian-rovo-mcp.md.
    atlassian = {
      type = "remote";
      url = "https://mcp.atlassian.com/v2/mcp";
      enabled = true;
    };

    chrome-devtools = {
      type = "local";
      command = [
        "npx"
        "-y"
        "chrome-devtools-mcp@latest"
        "--browser-url=http://127.0.0.1:9222"
      ];
      enabled = true;
    };

    mcp-xlsx = {
      type = "local";
      command = [
        "npx"
        "-y"
        "mcp-xlsx"
      ];
      enabled = true;
    };

  };
in
{
  # Export the extra MCPs for merging
  home.ai-assets.extraMcps = extraMcps;
}
