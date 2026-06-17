# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Helper scripts (window-switcher, monitor-hotplug-handler, kb-*, mouse-wiggle)
#   - Ghostty settings (imported via ./ghostty.nix; non-theme)
#   - Kitty settings (imported via ./kitty.nix; colorScheme + font)
#   - Remmina remote-desktop launchers + connection files (./remmina.nix)
#   - mouse-wiggle launcher and its systemd user service
{
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/bindings.nix
    ./hypr/looknfeel.nix
    ./hypr/autostart.nix
    ./hypr/hypridle.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix
    ./hypr/xdph.nix
    ./ghostty.nix
    ./kitty.nix
    ./remmina.nix
    ./mouse-wiggle.nix
  ];

  # ------------------------------------------------------------------
  # Helper scripts (accessible from PATH via omarchy's bin directory)
  # ------------------------------------------------------------------
  home.file = {
    # Window switcher — uses omarchy's walker menu backend
    ".local/share/omarchy/bin/window-switcher.sh" = {
      source = ./scripts/window-switcher.sh;
      executable = true;
    };

    # Monitor hotplug handler — calls omarchy's monitor management
    ".local/share/omarchy/bin/monitor-hotplug-handler.sh" = {
      source = ./scripts/monitor-hotplug-handler.sh;
      executable = true;
    };

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

  # No waybar overrides — omarchy-nix owns the waybar config and theme
  # end-to-end (config/ + theme.css). Past local style.css.d/ fragments
  # were dead code: omarchy's style.css does not @import from style.css.d/.
}
