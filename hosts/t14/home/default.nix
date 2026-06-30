# T14-specific Home Manager overlays on top of omarchy-nix.
# Omarchy's theme runtime owns the visual layer (waybar theme, mako theme,
# ghostty theme).  This module adds only the non-visual delta:
#   - Hyprland t14-specific config fragments (monitor, input, bindings, looknfeel)
#   - Helper scripts (kb-toggle, kb-layout)
#   - Ghostty + kitty settings (imported directly from home-linux/ because
#     t14's curated import list omits home-linux/shared-modules.nix)
#   - mouse-wiggle launcher
{ config, lib, ... }:

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
  # Helper scripts (deployed to ~/.local/bin via home.file, accessible
  # from PATH via home.sessionPath in base.nix)
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

  # Ensure DRM devices are probed before Hyprland starts.  The - prefix
  # makes it non-fatal — Hyprland still starts if udevadm is unavailable.
  xdg.configFile."systemd/user/wayland-wm@hyprland.desktop.service.d/udev-settle.conf".text = ''
    [Service]
    ExecStartPre=-/run/current-system/sw/bin/udevadm settle --timeout=10
  '';

  # Daemon that aligns monitors with lid state at startup and on every
  # dock/undock cycle.  Listens on Hyprland socket2 for monitor add/remove
  # events (complements omarchy-hyprland-monitor-watch which only reloads).
  systemd.user.services.monitor-lid-validator = {
    Unit = {
      Description = "Align monitors with lid state";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${config.home.homeDirectory}/.local/bin/monitor-lid-validator.sh --daemon";
      Environment = [
        "PATH=${config.home.homeDirectory}/.local/bin:/run/current-system/sw/bin"
        "XDG_RUNTIME_DIR=%t"
      ];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.file = {

    # Keyboard layout toggle (es <-> latam)
    ".local/share/omarchy/bin/kb-toggle.sh" = {
      source = ./scripts/kb-toggle.sh;
      executable = true;
    };

    # Monitor layout validator — aligns monitors with lid state at startup.
    ".local/bin/monitor-lid-validator.sh" = {
      source = ./scripts/monitor-lid-validator.sh;
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
