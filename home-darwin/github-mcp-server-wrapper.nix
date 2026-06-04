{ pkgs, config, ... }:

let
  githubMcpServerWrapped = pkgs.writeShellScriptBin "github-mcp-server-wrapped" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    GITHUB_TOKEN_FILE="${config.sops.secrets."github/token".path}"

    if [ ! -f "$GITHUB_TOKEN_FILE" ]; then
      echo "Error: GitHub token secret not found at $GITHUB_TOKEN_FILE" >&2
      exit 1
    fi

    GITHUB_PERSONAL_ACCESS_TOKEN=$(cat "$GITHUB_TOKEN_FILE")
    export GITHUB_PERSONAL_ACCESS_TOKEN

    exec ${pkgs.github-mcp-server}/bin/github-mcp-server "stdio" "''${@:-}"
  '';
in
{
  home.packages = [
    githubMcpServerWrapped
  ];
}
