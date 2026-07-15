{ ... }:

{
  imports = [
    ./gentle-ai-common.nix
  ];

  home.gentle-ai.enable = true;

  home.claude-code = {
    enable = true;

    permissions = {
      # dontAsk: auto-deny unmatched tools, no prompts. With Bash(*), everything
      # allowed runs silently; the deny list is the real safety boundary.
      # https://rajiv.com/blog/2026/03/31/stop-asking-me-configuring-claude-code-permissions-for-uninterrupted-flow/
      defaultMode = "dontAsk";

      allow = [
        "Bash(*)"
        "Read(*)"
        "Write(*)"
        "Edit(*)"
        "WebFetch(*)"
        "WebSearch(*)"
        "mcp__github-personal__*"
        "mcp__github-work__*"
        "mcp__nixos__*"
        "mcp__context7__*"
        "mcp__engram__*"
        "mcp__exa__*"
        "mcp__drawio__*"
        "mcp__playwright__*"
        "mcp__gcloud__*"
        "mcp__atlassian__*"
        "mcp__chrome-devtools__*"
        "mcp__mcp-xlsx__*"
      ];

      # Hard safety boundaries. deny always wins over allow, regardless of scope.
      deny = [
        # Destructive filesystem
        "Bash(rm -rf /)"
        "Bash(rm -rf /*)"
        "Bash(rm -rf ~)"
        "Bash(sudo *)"
        "Bash(chown *)"
        # Curl-pipe-to-shell
        "Bash(curl * | sh)"
        "Bash(curl * | bash)"
        "Bash(wget * | sh)"
        # Secrets / sops
        "Bash(sops *)"
        # Sensitive files
        "Read(./.env)"
        "Read(./.env.*)"
        "Read(./**/.env*)"
        "Read(./secrets/**)"
        "Read(./**/secrets.*)"
        "Read(/**/*.pem)"
        "Read(/run/secrets/**)"
      ];
    };
  };
}
