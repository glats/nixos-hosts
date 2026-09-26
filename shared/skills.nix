{ config, lib, ... }:

{
  home.file = {
    ".claude/skills/rom-downloader".source = ./skills/rom-downloader;
    ".agents/skills/rom-downloader".source = ./skills/rom-downloader;
  };
}
