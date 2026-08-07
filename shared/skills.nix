{ config, lib, ... }:

{
  # Deploy rom-downloader skill to all agent skill directories
  home.file = {
    ".config/opencode/skills/rom-downloader".source = ./skills/rom-downloader;
    ".claude/skills/rom-downloader".source = ./skills/rom-downloader;
    ".agents/skills/rom-downloader".source = ./skills/rom-downloader;
  };
}
