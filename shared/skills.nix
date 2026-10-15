{ config, lib, ... }:

{
  home.file = {
    # `.claude/skills/rom-downloader` is NOT deployed here: the claude
    # asset reconcile (ai-assets-reconcile) owns real files under
    # ~/.claude/skills and refuses symlinked paths. Keep only the
    # ~/.agents symlink, which no reconcile manages.
    ".agents/skills/rom-downloader".source = ./skills/rom-downloader;
  };
}
