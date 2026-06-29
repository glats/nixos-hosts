# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Helper scripts (kb-toggle, kb-layout)
#   - Ghostty + kitty settings (imported directly from home-linux/ because
#     t14's curated import list omits home-linux/shared-modules.nix)
#   - mouse-wiggle launcher
{ lib, ... }:

{
  imports = [
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/looknfeel.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix
    ../../../home-linux/ghostty.nix
    ../../../home-linux/kitty.nix
    ./mouse-wiggle.nix
    ../../../home-linux/webcam-rog.nix
  ];

  # ------------------------------------------------------------------
  # Helper scripts (accessible from PATH via omarchy's bin directory)
  # ------------------------------------------------------------------

  # Seed settings.conf at activation time (NOT via home.file — that
  # would make it a read-only Nix store symlink).  The file must be
  # writable so the lid-switch bindl and exec-once validator can update
  # $ENABLE_LAPTOP at runtime.
  home.activation.seedHyprSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -f "$HOME/.config/hypr/settings.conf" ]; then
      mkdir -p "$HOME/.config/hypr"
      printf '$ENABLE_LAPTOP = 1\n' > "$HOME/.config/hypr/settings.conf"
    fi
  '';

  home.file = {

    # Keyboard layout toggle (es <-> latam)
    ".local/share/omarchy/bin/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };

    # Keyboard layout set (es or latam)
    ".local/share/omarchy/bin/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };

    # ------------------------------------------------------------------
    # kb-layout.sh / kb-toggle.sh — the symlink copies into
    # ~/.config/hypr/ are kept for any waybar module / hyprland plugin
    # that resolves helper scripts at that path.  The canonical
    # source lives in scripts/; the bin copies above expose them on
    # PATH.  Both paths point to the same source file (no duplicate
    # content).
    # ------------------------------------------------------------------
    ".config/hypr/kb-layout.sh" = {
      source = ./scripts/kb-layout.sh;
      executable = true;
    };
    ".config/hypr/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };
  };
}
