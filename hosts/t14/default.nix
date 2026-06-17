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
    # Omarchy provides Hyprland + PipeWire + NetworkManager (iwd
    # backend) + Bluetooth + printing + gvfs. The previous GNOME module
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

  # Enable the imported boot module (systemd-boot, plymouth, zen kernel)
  boot-settings.enable = true;

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

    # Built-in 14" 1920x1080 panel; external monitors are managed by
    # monitor-hotplug-handler.sh (see hosts/t14/home/hypr/autostart.nix).
    monitors = [ "eDP-1,preferred,auto,1" ];

    # Laptop panel is 1x scale (1920x1080 native).
    scale = 1;

    browser = "brave";
    terminal = "ghostty";

    # No firewall — development machine on controlled networks.
    # REQ-003: omarchy.firewall.enable = false is the canonical way to
    # opt out of omarchy's mkIf-guarded firewall module.
    firewall.enable = false;
  };

  # === UWSM ===
  # The omarchy-nix NixOS module (modules/nixos/system.nix) only enables
  # `programs.uwsm` when `omarchy.seamless_boot.enable = true`. On this
  # host we deliberately keep seamless_boot off (no Plymouth / auto-login),
  # but the omarchy userland scripts (omarchy-launch-walker, omarchy-toggle-*,
  # omarchy-restart-app, etc.) all invoke `uwsm-app` to start GUI daemons
  # as detached children of the session. Without `uwsm-app` on PATH the
  # walker gapplication-service daemon never starts, so SUPER+SPACE opens
  # a walker client that cannot find the service and silently exits without
  # a window — the launcher appears "broken". Add `pkgs.uwsm` to the system
  # PATH so the scripts work without enabling seamless_boot. This does NOT
  # change the login manager or the boot flow; it only makes the binary
  # available on PATH for the user session.
  environment.systemPackages = [ pkgs.uwsm ];

  # === OMARCHY PATH ===
  # Hyprland's `exec` dispatcher runs commands in a non-interactive shell
  # that does NOT source ~/.zshrc or ~/.profile, so it does NOT see the
  # PATH injected by Home Manager's `home.sessionPath`. The result is that
  # all `bindd = SUPER, ..., exec, omarchy-launch-*` bindings fail because
  # the bare script names cannot be resolved. We add the directory to the
  # global session PATH so every shell (interactive or not) spawned by
  # Hyprland can find the omarchy helpers.
  environment.sessionVariables.PATH = "/home/glats/.local/share/omarchy/bin:/home/glats/.nix-profile/bin:/nix/profile/bin:/home/glats/.local/state/nix/profile/bin:/etc/profiles/per-user/glats/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";

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

  # === DISPLAY MANAGER ===
  # Omarchy provides greetd + tuigreet. The T14 keyboard layout (latam)
  # is configured via console.keyMap and services.xserver.xkb.
  services.greetd.enable = true;

  system.stateVersion = "26.05";
}
