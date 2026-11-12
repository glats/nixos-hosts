{ config, pkgs, ... }:

let
  mkGithubMcpWrapper =
    {
      name,
      user ? null,
      userFile ? null,
    }:
    pkgs.writeShellScriptBin name ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      GH="${pkgs.gh}/bin/gh"

      ${
        if userFile == null then
          ''ACCOUNT="${user}"''
        else
          ''
            if ! ACCOUNT=$(cat "${userFile}" 2>/dev/null) || [ -z "$ACCOUNT" ]; then
              echo "Error (${name}): work account secret is unavailable; check sops-nix." >&2
              exit 1
            fi
          ''
      }

      # Pre-check + fetch: requires this exact account logged in on github.com
      if ! TOKEN=$($GH auth token --hostname github.com --user "$ACCOUNT" 2>/dev/null); then
        echo "Error (${name}): gh has no account '$ACCOUNT' on github.com" >&2
        echo "  Run: gh auth login --hostname github.com  (and choose account $ACCOUNT)" >&2
        exit 1
      fi

      GITHUB_PERSONAL_ACCESS_TOKEN="$TOKEN"
      export GITHUB_PERSONAL_ACCESS_TOKEN

      exec ${pkgs.github-mcp-server}/bin/github-mcp-server "''${@:-stdio}"
    '';

  githubMcpServerPersonal = mkGithubMcpWrapper {
    name = "github-mcp-server-personal";
    user = "glats";
  };

  githubMcpServerWork = mkGithubMcpWrapper {
    name = "github-mcp-server-work";
    userFile = config.sops.secrets."github/work_account".path;
  };

in
{
  home.packages = [
    githubMcpServerWork
    githubMcpServerPersonal
  ];
}
