# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Local waybar config additions (kb-layout module)
#   - Helper scripts (window-switcher, monitor-hotplug-handler, kb-*, mouse-wiggle)
#   - Ghostty settings (imported via ./ghostty.nix; theme + non-theme)
#   - Kitty settings (imported via ./kitty.nix; colorScheme + font)
#   - Wiremix audio mixer config (./wiremix.nix)
#   - Remmina remote-desktop launchers + connection files (./remmina.nix)
#   - mouse-wiggle launcher and its systemd user service
{ lib
, pkgs
, inputs
, ...
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
    ./waybar.nix
    ./btop.nix
    ./ghostty.nix
    ./kitty.nix
    ./wiremix.nix
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
    # The user's personal waybar config.jsonc references the kb-layout
    # and kb-toggle helpers at ~/.config/hypr/ (not the omarchy bin
    # directory). Symlink the bin copies into ~/.config/hypr/ so the
    # waybar custom/kb-layout module finds them at the expected paths.
    # Both paths point to the same source file (no duplicate content).
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

  # ------------------------------------------------------------------
  # Local waybar style tweaks on top of omarchy's theme CSS.
  # The actual waybar config.jsonc is managed by omarchy; we add a
  # minimal local config that extends (not replaces) it via HM's waybar
  # module options where available, and a local style override file.
  # ------------------------------------------------------------------
  xdg.configFile."waybar/config.d/50-t14-local.jsonc" = lib.mkIf false {
    text = ''
      // T14 local waybar config — KB layout module
      // Omarchy manages the primary config; this file is loaded via
      // waybar's conf include dirs when omarchy's config uses them.
      // Currently inactive — omarchy's waybar config does not use
      // config.d includes.  Override path reserved for future use.
    '';
  };

  # T14 waybar style overrides (extends omarchy theme CSS)
  xdg.configFile."waybar/style.css.d/50-t14-local.css" = {
    text = ''
      /* T14-specific waybar layout tweaks */
      #waybar {
        font-size: 12px;
      }

      /* Slightly tighter modules for the laptop */
      #workspaces button {
        padding: 2px 6px;
      }
    '';
  };
}
