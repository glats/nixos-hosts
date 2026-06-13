# T14 ghostty overlay.
#
# Imports the shared `home-linux/ghostty.nix` module (which sets the
# nix-colors theme palette) and applies t14-specific settings.  We use
# `lib.mkForce` on the theme key so the shared module's nix-colors
# palette wins over omarchy's runtime theme symlink.
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
{ lib, ... }:

{
  imports = [ ../../../home-linux/ghostty.nix ];

  programs.ghostty.settings = {
    # Force the shared module's nix-colors theme over omarchy's runtime
    # symlink (which points at the omarchy theme).
    theme = lib.mkForce "nix-colors";

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
