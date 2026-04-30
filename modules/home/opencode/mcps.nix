{ config, lib, pkgs, ... }:

with lib;

let
  # Static default MCPs - no config references in defaults
  defaultMcps = {
    github = {
      type = "local";
      command = [ "github-mcp-server" "stdio" ];
      enabled = true;
    };

    nixos = {
      type = "local";
      command = [ "docker" "run" "--rm" "-i" "ghcr.io/utensils/mcp-nixos" ];
      enabled = true;
    };

    context7 = {
      type = "remote";
      url = "https://mcp.context7.com/mcp";
      enabled = true;
    };

    engram = {
      type = "local";
      command = [ "engram" "mcp" "--tools=agent" ];
      enabled = true;
    };

    exa = {
      type = "remote";
      url = "https://mcp.exa.ai/mcp";
      enabled = true;
    };
  };
in
{
  options.home.opencode.mcps = mkOption {
    type = types.attrsOf (types.submodule {
      freeformType = types.attrs;
    });
    default = defaultMcps;
    description = ''
      MCP (Model Context Protocol) server configurations.
      Each MCP entry defines a server that provides tools to agents.
      
      Supported types:
      - local: Runs locally with a command array
      - remote: Connects to a remote URL
      
      Example:
      {
        my-mcp = {
          type = "local";
          command = [ "my-server" "arg1" "arg2" ];
          enabled = true;
        };
      }
    '';
  };
}
