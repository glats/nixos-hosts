# T14 ghostty overlay.
#
# Imports the shared `home-linux/ghostty.nix` module (which sets the
# nix-colors theme palette) and applies t14-specific settings.  The
# shared module's `theme = "nix-colors"` is the canonical reference
# to the nix-colors palette block; omarchy-nix's ghostty config
# (when present) takes effect via the normal merge order without
# needing a local lib.mkForce.
#
# T14-specific overrides (kept from the previous t14 ghostty module):
#   * font-family    = CaskaydiaCove Nerd Font
#   * font-size      = 11
#   * font-feature   = "liga"  (programming ligatures)
#   * background-opacity = 0.9  (laptop panel translucency)
#   * async-backend  = "epoll"  (best Linux input + render throughput)
#   * scrollback-limit = 4294967295  (u32 max, effectively unlimited)
#   * mouse-scroll-multiplier = 0.95  (slightly slower scroll for the
#     laptop touchpad)
{ ... }:

{
  imports = [ ../../../home-linux/ghostty.nix ];

  programs.ghostty.settings = {
    # T14-specific settings — override the shared defaults where the
    # laptop differs from the desktop.
    font-family = "CaskaydiaCove Nerd Font";
    font-size = 11;
    font-feature = "liga";
    background-opacity = 0.9;
    async-backend = "epoll";
    scrollback-limit = 4294967295;
    mouse-scroll-multiplier = 0.95;
  };
}
