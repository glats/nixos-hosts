{ ... }:

{
  imports = [
    ./gentle-ai-common.nix
  ];

  home.gentle-ai.enable = true;

  home.claude-code = {
    enable = true;

    # opusplan: Opus during plan mode, Sonnet during execution.
    # Matches Falabella corporate guide recommendation.
    model = "opusplan";

    permissions = {
      # dontAsk: auto-deny unmatched tools. Zero prompts for allowed tools.
      # AcceptEdits would be safer for teams, but this is personal machine.
      defaultMode = "dontAsk";
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

      # Hard safety boundaries. deny wins over allow, regardless of scope.
      # Tool names with specifiers must use the correct format: Tool(pattern).
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
