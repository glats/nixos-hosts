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

    atlassian = {
      type = "local";
      command = [
        "/Users/jcuzmar/.local/share/uv/tools/mcp-atlassian/bin/python3"
        "/Users/jcuzmar/.local/bin/mcp-atlassian-wrapper.py"
      ];
      timeout = 60000;
      environment = {
        JIRA_URL = "{env:JIRA_URL}";
        JIRA_USERNAME = "{env:JIRA_USERNAME}";
        JIRA_API_TOKEN = "{env:JIRA_API_TOKEN}";
        CONFLUENCE_URL = "{env:CONFLUENCE_URL}";
        CONFLUENCE_PERSONAL_TOKEN = "{env:CONFLUENCE_PERSONAL_TOKEN}";
      };
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
