# T14 — ThinkPad T14 AMD Gen 4 running Omarchy (Hyprland-based).
#
# Migrated from temporary GNOME to permanent Omarchy desktop. The omarchy
# NixOS module is wired in via flake.nix extraModules (omarchy-nix +
# nixos-hardware T14 profile). This host file provides the per-host overrides:
#   - omarchy config block (username, identity, theme, monitors, browser,
#     terminal, firewall disabled)
#   - XKB layout forced to "latam" (Chile) since i18n.nix defaults to "es"
#   - btrfs swap, fonts, kmscon, and amd-laptop settings inherited from base
#   - home-manager wired to ./home/omarchy.nix (replaces ./home/gnome.nix)
{ config
, lib
, pkgs
, ...
}:

{
  imports = [
    ./hardware-configuration.nix

    # === BASE (minimal viable) ===
    ../../modules/base/cachix.nix
    ../../modules/base/nix.nix
    ../../modules/base/polkit.nix
    ../../modules/base/sops.nix
    ../../modules/base/users.nix
    ../../modules/base/zsh.nix
    ../../modules/base/packages.nix
    # NOTE: modules/base/home-manager.nix is NOT imported — we use our
    # own home-manager config below with a targeted set.

    # === DESKTOP ===
    # Omarchy provides Hyprland + PipeWire + NetworkManager + Bluetooth
    # + printing + gvfs. The previous GNOME module
    # (modules/desktop/gnome.nix) and avahi module
    # (modules/networking/avahi.nix) are no longer imported because
    # omarchy's system.nix supersedes them.
    ../../modules/desktop/i18n.nix
    ../../modules/desktop/fonts.nix
    ../../modules/desktop/kmscon.nix

    # === HARDWARE ===
    ../../modules/hardware/amd-laptop.nix
    ../../modules/hardware/keyring.nix

    # === NETWORKING ===
    ../../modules/networking/openssh.nix

    # === HOST SECRETS ===
    ./secrets.nix

    # === BOOT ===
    # Required: the system will not boot without bootloader configured.
    ../../modules/features/boot.nix

    # === MCP REQUIREMENTS ===
    ../../modules/features/services/github-mcp-server.nix
    ../../modules/virtualisation/docker.nix
  ];

  networking = {
    hostName = "t14";
    networkmanager.enable = true;
    # Defense-in-depth: keep host firewall off. Omarchy's firewall is
    # explicitly disabled below via omarchy.firewall.enable = false, but
    # this line ensures the NixOS-level firewall also stays off.
    firewall.enable = false;
  };

  nixpkgs.config = {
    allowUnfree = true;
    # fonts.nix includes joypixels; requires explicit license acceptance.
    allowUnfreePackages = [ "joypixels" ];
    joypixels.acceptLicense = true;
  };

  # Patch xdg-desktop-portal to allow non-flatpak callers for the
  # Settings portal. xdp 1.20.x added an authorization callback that
  # resolves the caller's app ID via /proc/PID/root/.flatpak-info.
  # For non-flatpak apps (native Nautilus on Hyprland), this fails
  # and the portal denies Settings.Read with AccessDenied.
  nixpkgs.overlays = [
    (final: prev: {
      xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ../../patches/xdg-desktop-portal/settings-allow-unsandboxed.patch
        ];
      });
    })
  ];

  # VNC server — captures Wayland screen via wlroots screencopy.
  # Runs inside Hyprland session (autostart.nix) on 0.0.0.0:5900.
  # The actual `programs.wayvnc.enable = true` lives in
  # omarchy-nix:modules/nixos/wayvnc.nix, gated by `omarchy.wayvnc.enable`
  # (set below in the omarchy = { … } block).

  # Enable the imported boot module (systemd-boot, plymouth, zen kernel)
  boot-settings.enable = true;

  # Ensure XFS kernel module is available in the initrd (stage 1).
  # Without this, boot fails with "an error occurred at stage 1"
  # because the kernel can't mount the XFS root filesystem.
  boot.initrd.supportedFilesystems = [ "xfs" ];

  # Enable manual fan control for thinkfan-ui (PyQt6 GUI). The kernel
  # `thinkpad_acpi` module exposes the fan interface under
  # /proc/acpi/ibm/fan, but only when `fan_control=1` is set. thinkfan-ui
  # (installed via home.packages in omarchy.nix) is the sole writer — the
  # `services.thinkfan` NixOS module must NOT be enabled alongside it
  # (they share the same write target and would race).
  boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";

  # Enable the pkexec setuid wrapper so thinkfan-ui can chown
  # /proc/acpi/ibm/fan via its built-in updatePermissions() function.
  # The polkit rule in modules/base/polkit.nix allows wheel users to
  # run any action without password, but without the setuid bit the
  # pkexec binary fails with "pkexec must be setuid root".
  security.wrappers.pkexec.enable = lib.mkForce true;

  # t14-specific keymap: latam (Chile) layout. modules/desktop/i18n.nix
  # uses "es" for compatibility with rog/thinkcentre; we force latam here.
  services.xserver.xkb = {
    layout = lib.mkForce "latam";
    variant = "";
  };
  console.keyMap = lib.mkForce "la-latin1";

  # === OMARCHY CONFIG BLOCK ===
  # Omarchy reads these options from the imported NixOS module to decide
  # which themes/monitors/identities to deploy. The full_name and
  # email_address are placeholders until sops-backed user identity is
  # wired in (tracked in proposal "Open Questions").
  omarchy = {
    username = "glats";
    full_name = "Glats";
    email_address = "glats@local";

    # "glats" is a first-class theme in upstream omarchy-nix after
    # the native-glats PR was merged.  The colorScheme is now driven
    # by omarchy-nix from the active theme; the local
    # hosts/t14/home/theme.nix + theme-files.nix pair was removed
    # because omarchy-nix generates the theme files dynamically.
    theme = "glats";

    # WiFi: iwd standalone for impala compatibility. NM ignores wlan0
    # and handles ethernet/Docker. iwd manages connections, DHCP, and
    # DNS via systemd-resolved on its own.
    wifi.backend = "standalone-iwd";

    # Built-in 14" 1920x1080 panel; external monitors are managed by
    # monitor-hotplug-handler.sh (see hosts/t14/home/hypr/autostart.nix).
    monitors = [ "eDP-1,preferred,auto,1" ];

    # T14 provides its own lid-switch bindl in monitors.nix that writes
    # settings.conf + calls hyprctl keyword directly. Disable omarchy's
    # default lid-switch bindl to eliminate the dual-writer race.
    hyprland.lidSwitch.enable = false;

    # Laptop panel is 1x scale (1920x1080 native).
    scale = 1;

    browser = "brave";
    terminal = "ghostty";

    # No firewall — development machine on controlled networks.
    # REQ-003: omarchy.firewall.enable = false is the canonical way to
    # opt out of omarchy's mkIf-guarded firewall module.
    firewall.enable = false;

    # VNC server — opt-in to omarchy.wayvnc (NixOS module enables
    # programs.wayvnc + systemPackages; HM module deploys the
    # systemd user service + config file). Port 5900 + enable_pam = true
    # match upstream defaults; set explicitly here for documentation.
    wayvnc.enable = true;

    # Greeter: regreet (greeter for Hyprland). Selects the regreet-based
    # login flow instead of the default tuigreet.
    greeter = {
      type = "regreet";
      # Matches "Lenovo Group Limited LEN G24-10 U5B4GWF1" from monitors below.
      # When empty (default) the selection phase is a no-op — current behaviour.
      focusMonitor = "LEN G24";
      keyboard = {
        layouts = [
          "es"
          "latam"
        ];
        # compose:caps removed: it would remap CAPS LOCK to Compose at
        # the login screen, breaking dead-key accented input there too.
        # Hyprland session's kb_options matches (no compose:caps) so the
        # greeter and the session behave identically.
        options = "grp:alt_shift_toggle";
      };
      monitors = [
        "desc:Lenovo Group Limited LEN G24-10 U5B4GWF1,1920x1080@60,1080x420,1"
        "desc:AOC 24P1W1 OTNQ4HA000101,1920x1080@60,0x0,1,transform,1"
        "desc:AOC 2470W GGZM3HA438259,1920x1080@60,3000x420,1"
      ];
      cursor.theme = "Bibata-Modern-Ice";

      # Pre-login VNC: wayvnc runs inside the greeter Hyprland session
      # (on the same port 5900 as the user-session wayvnc). Remmina
      # auto-reconnects across the ~1s handoff when the user logs in.
      # Defaults for address/port/enable_pam come from omarchy-nix.
      wayvnc.enable = true;
    };
  };

  # Desktop suite — t14 uses GNOME apps alongside omarchy/Hyprland.
  # omarchy-nix provides nautilus, calculator, evince, etc.;
  # this adds gnome-system-monitor via modules/base/profiles/gnome.nix.
  my.desktop.suite = "gnome";

  # === HOME-MANAGER ===
  # Omarchy + t14 Hyprland overlays imported via ./home/omarchy.nix.
  # The NixOS home-manager module is loaded by lib/mkHost.nix.
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # REQ (t14-omarchy-nix-best-way): pre-existing unmanaged files
    # (e.g. /home/glats/.config/user-dirs.dirs left over from the previous
    # GNOME session) block home-manager's symlink activation with
    # "would be clobbered" errors. Enabling backupFileExtension makes HM
    # rename the colliding file to <path>.backup instead of aborting.
    # We do not set overwriteBackup = true: the first run creates the
    # backup cleanly, and a future stale backup will surface a real
    # signal that something else is managing the same path.
    backupFileExtension = "backup";
    extraSpecialArgs = {
      hostName = config.networking.hostName;
    };
    users.glats = {
      imports = [ ./home/omarchy.nix ];
    };
  };

  system.stateVersion = "26.05";
}
