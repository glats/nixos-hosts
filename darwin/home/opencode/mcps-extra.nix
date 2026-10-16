{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
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
  home.ai-assets.extraMcps = extraMcps;
}
