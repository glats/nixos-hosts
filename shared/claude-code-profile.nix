{ ... }:

{
  imports = [
    ./ai-assets.nix
  ];

  home.ai-assets.enable = true;

  home.claude-code = {
    enable = true;

    permissions = {
      defaultMode = "auto";
      additionalDirectories = [
        "~"
        "/tmp"
      ];

      allow = [
        "Bash(*)"
        "Read(*)"
        "Write(*)"
        "Edit(*)"
        "Glob(*)"
        "Grep(*)"
        "WebFetch(*)"
        "WebSearch"
        "Agent(*)"
        "Skill"
        "TaskCreate"
        "TaskGet"
        "TaskList"
        "TaskUpdate"
        "ExitPlanMode"
        "EnterPlanMode"
        "KillShell"
        "LSP"
        "NotebookEdit"
      ];

      deny = [
        "Bash(rm -rf *)"
        "Bash(sudo *)"
        "Bash(chown *)"
        "Bash(curl * | *sh*)"
        "Bash(curl * | *bash*)"
        "Read(./.env)"
        "Read(./.env.*)"
        "Read(./secrets/**)"
        "Read(./**/*.pem)"
        "Read(./**/*.key)"
      ];
    };
  };
}
