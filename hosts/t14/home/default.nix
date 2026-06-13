# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Local waybar config additions (kb-layout module)
#   - Helper scripts (window-switcher, monitor-hotplug-handler, kb-*, mouse-wiggle)
#   - Ghostty non-theme settings (font, opacity, backend)
#   - mouse-wiggle launcher and its systemd user service
{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  inherit (lib) mkDefault;
in
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
  # Ghostty — omarchy handles the theme; we add only non-theme settings
  # ------------------------------------------------------------------
  programs.ghostty = {
    enable = true;
    settings = {
      # Font — slightly larger than omarchy default for the laptop screen
      font-family = mkDefault "JetBrainsMono Nerd Font";
      font-size = 10;

      # Opacity for the laptop display
      background-opacity = 0.92;

      # NOTE: `renderer = "OpenGL"` and `gtk-theme = "dark"` were removed.
      # Ghostty 1.3.1 rejects both as unknown INI fields:
      #   * `renderer` is no longer a top-level config option (the
      #     renderer is selected at build time, see `ghostty +show-config`).
      #   * `gtk-theme` was removed in favor of a single `theme = "name"`
      #     option that controls both libadwaita and the terminal palette;
      #     the theme itself is supplied by omarchy's runtime symlink
      #     (~/.config/omarchy/current/theme/ghostty.conf) and would
      #     conflict with `theme = TokyoNight` written there.
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
