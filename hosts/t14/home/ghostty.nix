# T14 ghostty overlay.
#
# Imports the shared `home-linux/ghostty.nix` module — the single source
# of truth for ghostty config across every Linux host.  The shared
# module sets the nix-colors theme palette, font family / size /
# features, scrollback limit, and window padding defaults.  This
# overlay only adds t14-specific hardware tweaks on top.
#
# omarchy-nix also pulls in a `programs.ghostty` block (via its
# `homeManagerModules.default`).  The shared file uses
# `lib.mkForce` on `programs.ghostty.themes` to drop omarchy's
# `themes.omarchy` so it never reaches the static config, and the
# import order makes per-key `settings` resolve in favor of this
# module.  The t14-specific values that need to override shared
# defaults use `lib.mkForce` here for the same reason.
{
  lib,
  ...
}:

{
  imports = [ ../../../home-linux/ghostty.nix ];

  programs.ghostty.settings = {
    # T14 laptop panel translucency — overrides the shared 0.8.
    background-opacity = lib.mkForce 0.9;

    # Slightly slower scroll for the laptop touchpad.
    mouse-scroll-multiplier = lib.mkForce 0.95;
  };
}
