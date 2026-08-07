{ config, lib, ... }:

{
  # Deploy rom-downloader skill to all agent skill directories
  home.file = {
    # Primary: OpenCode
    ".config/opencode/skills/rom-downloader".source = ../../shared/skills/rom-downloader;

    # Claude Code compatible agents
    ".claude/skills/rom-downloader".source = ../../shared/skills/rom-downloader;

    # Generic agents (OpenFang, OpenClaw, etc.)
    ".agents/skills/rom-downloader".source = ../../shared/skills/rom-downloader;
  };
}
