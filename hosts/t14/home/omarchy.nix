# T14 Home Manager — Omarchy HM entry point.
#
# Replaces the previous home/gnome.nix. This module wires the
# omarchy-nix homeManagerModules.default alongside the t14-specific
# overlays already present in home/default.nix.
#
# The glats theme is handled natively by omarchy-nix via
# `omarchy.theme = "glats"` (see hosts/t14/default.nix).  Previously
# the local t14/home/theme.nix + theme-files.nix pair was required
# to (a) override omarchy's colorScheme with the custom glats palette
# and (b) deploy theme files to ~/.config/omarchy/themes/glats/.
# After the upstream omarchy-nix PR that added native glats support,
# both files were deleted and no local override is needed.
#
# Selective shared-module imports (matches what the old gnome.nix
# preserved):
#   * Imported: base, shell, git, gh, ssh, neovim, tmux, opencode, sops.
#   * Excluded:  rofi (omarchy uses walker instead),
#                mate (GNOME/MATE only — incompatible with Hyprland),
#                chrome-apps (webapps are managed by omarchy webapp
#                tooling; the home-linux list is for rog/thinkcentre),
#                linux/home/theme.nix (it configures GTK/Qt/dconf and
#                `colorScheme = shared/palette.nix`; the former is
#                owned by omarchy and the latter is now driven by
#                omarchy.theme = "glats" too).
#
# The omarchy HM module is imported FIRST so that any conflicting
# definitions from t14/home/default.nix can be overridden via
# lib.mkForce when needed.
{ config
, pkgs
, lib
, inputs
, ...
}:

{
  imports = [
    # Omarchy HM module — supplies Hyprland overlays, waybar, walker,
    # elephant, ghostty, alacritty, kitty, btop, neovim, fcitx5,
    # and all the user-level defaults. Imported first so subsequent
    # t14-specific fragments can override.
    inputs.omarchy-nix.homeManagerModules.default

    # t14-specific Hyprland config fragments (monitor, input, looknfeel)
    ./hypr/monitors.nix
    ./hypr/input.nix
    ./hypr/looknfeel.nix
    ./hypr/hyprlock.nix
    ./hypr/hyprsunset.nix

    # t14-specific peripherals
    ./mouse-wiggle.nix
    ../../../linux/home/webcam.nix

    # T14-specific app/tool configs
    ./fcitx5.nix
    ./mpv.nix
    ./thinkfan-ui.nix

    # Gaming — RetroArch config + ROM directories + SDL2 mappings
    ../../../linux/home/gaming.nix
  ];

  # Use SSH host key for sops decryption (matches host_t14 in .sops.yaml).
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # ------------------------------------------------------------------
  # HyprDynamicMonitors — event-driven monitor profile daemon.
  # Detects lid state via UPower D-Bus and monitor hotplug via
  # native Hyprland IPC. Profiles + hyprconfigs deployed from ./hdm/.
  # ------------------------------------------------------------------
  home.hyprdynamicmonitors = {
    enable = lib.mkDefault true;
    configFile = ../hdm/config.toml;
    extraFiles = {
      "hyprdynamicmonitors/hyprconfigs/docked-lid-open.conf" = ../hdm/hyprconfigs/docked-lid-open.conf;
      "hyprdynamicmonitors/hyprconfigs/docked-lid-closed.conf" =
        ../hdm/hyprconfigs/docked-lid-closed.conf;
      "hyprdynamicmonitors/hyprconfigs/undocked-lid-open.conf" =
        ../hdm/hyprconfigs/undocked-lid-open.conf;
      "hyprdynamicmonitors/hyprconfigs/undocked-lid-closed.conf" =
        ../hdm/hyprconfigs/undocked-lid-closed.conf;
      "hyprdynamicmonitors/hyprconfigs/fallback.conf" = ../hdm/hyprconfigs/fallback.conf;
    };
    extraFlags = [ "--enable-lid-events" ];
    installExamples = false;
  };

  # Waybar systemd user service.
  # omarchy-nix's waybar HM module installs only the package + static config
  # files -- it does NOT ship a systemd unit -- so this is the sole service
  # definition and cannot be removed.
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
      StartLimitBurst = 5;
      StartLimitIntervalSec = "10s";
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "always";
      RestartSec = "100ms";
      StandardOutput = "null";
      StandardError = "journal";
      SyslogIdentifier = "waybar";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # ------------------------------------------------------------------
  # Helper scripts (deployed to ~/.local/bin via home.file, accessible
  # from PATH via home.sessionPath in base.nix)
  # ------------------------------------------------------------------
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

  # Disable omarchy's zsh extras that conflict with shell.nix prezto setup.
  # rog/thinkcentre use pure prezto (no starship, no zplug). Match them.
  programs.zsh.zplug.enable = lib.mkForce false;
  programs.starship.enable = lib.mkForce false;

  # Disable HM-level fontconfig — rely on system-level fonts.nix (same as rog).
  # omarchy-nix's HM fonts module overrides defaults with different fonts;
  # rog/thinkcentre only use the system-level config from modules/desktop/fonts.nix.
  fonts.fontconfig.enable = lib.mkForce false;

  # Per-component font family overrides for t14.
  # Default omarchy-nix uses "monospace" everywhere; we switch GUI surfaces to sans.
  omarchy.fonts.waybar = lib.mkForce "Source Sans 3 Semibold";
  omarchy.fonts.swayosd = lib.mkForce "sans";
  omarchy.fonts.mako = lib.mkForce "sans";
  omarchy.fonts.rofi = lib.mkForce "sans";
  # Terminals get an explicit Nerd Font (CaskaydiaCove) so glyphs render
  # correctly. alacritty + ghostty are owned by the shared home-linux
  # modules; kitty is also resolved by `linux/home/kitty.nix` (which
  # uses `lib.mkForce` on `programs.kitty.settings` but does not set
  # `programs.kitty.font.name` — omarchy.fonts.kitty supplies it).
  omarchy.fonts.kitty = lib.mkForce "CaskaydiaCove Nerd Font";
  # walker, hyprlock keep default "monospace"

  # Keep wallpaper static across Hyprland sessions — user-chosen
  # backgrounds (via SUPER+CTRL+SPACE walker or omarchy-theme-bg-set)
  # persist across logins instead of advancing on every session start.
  omarchy.rotate_on_start = lib.mkForce false;

  # Omarchy-nix's tmux module is "neutralized" by linux/home/tmux.nix
  # (imported above): it uses `lib.mkForce` on `programs.tmux.extraConfig`
  # and `programs.tmux.plugins` to drop the omarchy prefix/status/theme
  # at eval time.  We don't need to set `enable = false` here — the
  # merged `enable` from omarchy-nix + shared + home-linux is `true`,
  # and HM's tmux module runs its config block with the home-linux
  # values.  Default C-b prefix + base16 theme from shared/tmux.nix
  # + xclip bindings + vim-tmux-navigator plugin from nixpkgs.

  # Set icon theme explicitly — omarchy-nix manages gtk.theme and gtk.cursorTheme
  # but does NOT set gtk.iconTheme. Papirus-Dark is already installed system-wide
  # (via modules/base/profiles/base.nix) but never activated on t14 because
  # linux/home/theme.nix is excluded (omarchy owns the visual layer).
  gtk.iconTheme = {
    name = "Papirus-Dark";
    package = pkgs.papirus-icon-theme;
  };

  # Enable dark mode entries for both GTK3 and GTK4 settings.ini.
  # Without this, GTK4 settings.ini has no gtk-theme-name (HM 26.05
  # silences gtk4.theme by default) and no gtk-application-prefer-dark-theme.
  # Nautilus (libadwaita) reads these to determine dark mode.
  gtk.colorScheme = "dark";

  # Fix: home-manager escribe gtk-interface-color-scheme=2 (integer) pero
  # GTK4 espera el string "dark" — sin esto libadwaita ignora el dark mode.
  gtk.gtk4.extraConfig."gtk-interface-color-scheme" = "dark";

  # Override omarchy-nix's default GTK theme (Adwaita-dark) to Materia-dark-compact
  # to match rog and thinkcentre. lib.mkForce defeats omarchy's priority-100
  # definition. materia-theme is auto-installed by HM via gtk.theme.package.
  gtk.theme = lib.mkForce {
    name = "Materia-dark-compact";
    package = pkgs.materia-theme;
  };

  # Remove GTK3 CSD decoration margin on t14 (Hyprland).
  #
  # Materia theme (gtk-3.0) applies `margin: 8px` to the `decoration`
  # CSS node for the resize cursor area. On GNOME/Mutter this creates a
  # clickable resize zone; on Hyprland/Wayland the compositor handles
  # resize on its own, so the margin becomes a transparent gap between
  # the compositor border (2px, omarchy default) and the visible window
  # content.
  #
  # The gap is most visible on floating file-picker dialogs opened by
  # xdg-desktop-portal-gtk, where the forced `size 875 600` and true
  # black glats background make the 8px margin stand out.
  #
  # GTK4 is deliberately NOT patched — Materia GTK4 has no
  # `decoration { margin }` rule (confirmed by reading the compiled
  # theme CSS).  The GTK4 gap is a separate Hyprland opaque-region
  # artifact (wp_fractional_scale rounding, Hyprland#11005).  Writing a
  # bare gtk-4.0/gtk.css would also overwrite Home Manager's theme
  # @import, breaking theming for non-libadwaita GTK4 apps.
  #
  # After deploy, restart the portal to flush its in-memory CSS cache:
  #   systemctl --user restart xdg-desktop-portal-gtk
  xdg.configFile."gtk-3.0/gtk.css".text = ''
    /* Remove CSD decoration margin to eliminate transparent gap between
       Hyprland border and window content on floating GTK dialogs. */
    window decoration {
      margin: 0;
      border: 0;
    }
  '';

  # Qt configuration: Adwaita Dark style with GTK3 platform theme bridge.
  # Matches linux/home/theme.nix used on rog and thinkcentre.
  # adwaita-qt is auto-installed by HM when qt.style.name = "adwaita-dark".
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  # Cycle VNC outputs during a wayvnc remote session so the viewer can
  # switch between built-in and external monitors without touching t14.
  # wayvncctl is provided by pkgs.wayvnc (installed via omarchy.wayvnc
  # upstream module).
  wayland.windowManager.hyprland.settings.bind = [
    "SUPER CTRL, D, exec, wayvncctl output-cycle"
    # Compositor recovery: when Hyprland enters a frozen state (cursor
    # visible but no frame/content rendered — usually after a dock
    # hotplug storm or GPU driver hiccup), this forces a compositor
    # reset via SIGUSR2 without losing any windows or session state.
    "SUPER CTRL, R, exec, pkill -USR2 Hyprland"
  ];

  # === EDGE AS DEFAULT BROWSER ===
  # Override omarchy-nix's $browser and $webapp Hyprland variables.
  # omarchy-nix sets these with lib.mkDefault (brave/chromium only);
  # lib.mkForce redirects to microsoft-edge. Brave stays installed
  # via omarchy.browser = "brave" for fallback.
  wayland.windowManager.hyprland.settings."$browser" =
    lib.mkForce "~/.local/share/omarchy/bin/omarchy-launch-or-focus microsoft-edge 'microsoft-edge-stable --new-window'";
  wayland.windowManager.hyprland.settings."$webapp" =
    lib.mkForce "~/.local/share/omarchy/bin/omarchy-launch-or-focus microsoft-edge 'microsoft-edge-stable --app'";

  # Edge flags: force X11/XWayland for stability on Hyprland.
  # Native Wayland causes SIGSEGV on hover over images (omarchy#5097).
  # Also disable Microsoft diagnostic data collection telemetry.
  xdg.configFile."microsoft-edge-stable-flags.conf".text = ''
    --ozone-platform=x11
    --enable-features=msDiagnosticDataForceOff
  '';

  # Default browser: Edge for all web MIME types.
  # Overrides omarchy-nix's lib.mkDefault (brave/chromium desktop entries).
  xdg.mimeApps.defaultApplications = lib.mkForce {
    "text/html" = "microsoft-edge.desktop";
    "text/xml" = "microsoft-edge.desktop";
    "x-scheme-handler/http" = "microsoft-edge.desktop";
    "x-scheme-handler/https" = "microsoft-edge.desktop";
    "x-scheme-handler/ftp" = "microsoft-edge.desktop";
    "application/xhtml+xml" = "microsoft-edge.desktop";
  };

  # Override copyScreensaverTxt: upstream runs it after writeBoundary but
  # before linkGeneration, so the home.file symlinks (logo.txt) don't exist
  # yet on first activation. Run after linkGeneration instead.
  home.activation.copyScreensaverTxt = lib.mkForce (
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ ! -f "$HOME/.config/omarchy/branding/screensaver.txt" ]; then
        mkdir -p "$HOME/.config/omarchy/branding"
        cp "$HOME/.local/share/omarchy/logo.txt" "$HOME/.config/omarchy/branding/screensaver.txt"
      fi
    ''
  );

  # Microsoft Teams (teams-for-linux) configuration.
  # GPU stays enabled for camera video processing. PipeWire capturer + camera
  # are enabled via electron CLI flags. Hardware media keys are disabled because
  # Hyprland doesn't implement them. Electron-native notifications are more
  # reliable than system D-Bus notifications on Hyprland. Screen sharing
  # thumbnail preview is disabled (the mirror window is a distraction on a
  # single-screen laptop).
  xdg.configFile."teams-for-linux/config.json".text = builtins.toJSON {
    disableGpu = false;
    electronCLIFlags = [
      [
        "enable-features"
        "WebRTCPipeWireCapturer,WebRtcPipeWireCamera"
      ]
      [
        "disable-features"
        "HardwareMediaKeyHandling"
      ]
    ];
    notificationMethod = "electron";
    followSystemTheme = true;
    screenSharing.thumbnail.enabled = false;
  };
}
