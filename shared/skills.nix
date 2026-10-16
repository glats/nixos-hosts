{ config, lib, ... }:

{
  home.file = {
    ".agents/skills/rom-downloader".source = ./skills/rom-downloader;
  };
}
