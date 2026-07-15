{ ... }:

{
  imports = [
    ./gentle-ai-common.nix
  ];

  home.gentle-ai.enable = true;

  home.claude-code = {
    enable = true;

    permissions = {
      # Auto-approve file edits, ask only for bash/network
      # https://code.claude.com/docs/en/permission-modes
      defaultMode = "acceptEdits";
      allow = [
        "Bash(cd *)"
        "Bash(ls *)"
        "Bash(find *)"
        "Bash(cat *)"
        "Bash(echo *)"
        "Bash(pwd)"
        "Bash(which *)"
        "Bash(git *)"
        "Bash(nix *)"
        "Bash(nixos-*)"
        "Bash(mkdir *)"
        "Bash(cp *)"
        "Bash(mv *)"
        "Bash(rm *)"
        "Bash(chmod *)"
        "Bash(head *)"
        "Bash(tail *)"
        "Bash(grep *)"
        "Bash(wc *)"
        "Bash(sort *)"
        "Bash(date *)"
        "Bash(env *)"
        "Bash(printenv *)"
        "Bash(python3 *)"
        "WebFetch"
        "WebSearch"
        "Read(~/.nixos/**)"
        "Read(~/.config/**)"
        "Read(~/.claude/**)"
      ];
      ask = [
        "Bash(curl *)"
        "Bash(wget *)"
        "Bash(sudo *)"
        "Bash(gh *)"
        "Bash(docker *)"
        "Bash(systemctl *)"
      ];
      deny = [
        "Read(./.env)"
        "Read(./.env.*)"
        "Read(**/secrets/**)"
        "Read(/run/secrets/**)"
        "Bash(sops *)"
      ];
    };
  };
}
