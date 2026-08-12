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
, inputs
, ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    # === BASE (minimal viable) ===
    ../../linux/system/base/cachix.nix
    ../../linux/system/base/nix.nix
    ../../linux/system/base/polkit.nix
    ../../linux/system/base/sops.nix
    ../../linux/system/base/users.nix
    ../../linux/system/base/zsh.nix
    ../../linux/system/base/packages.nix
    ../../linux/system/base/home-manager.nix

    # === DESKTOP ===
    # Omarchy provides Hyprland + PipeWire + NetworkManager + Bluetooth
    # + printing + gvfs. The previous GNOME module
    # (linux/system/desktop/gnome.nix) and avahi module
    # (linux/system/networking/avahi.nix) are no longer imported because
    # omarchy's system.nix supersedes them.
    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/kmscon.nix

    # === HARDWARE ===
    ../../linux/system/hardware/amd-laptop.nix
    ../../linux/system/hardware/keyring.nix

    # === NETWORKING ===
    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/netwatch.nix

    # === HOST-SPECIFIC OVERRIDES ===
    ./overlays.nix
    ./omarchy-config.nix

    # === GAMING ===
    ../../linux/system/hardware/gamepad.nix
    ../../linux/system/features/gaming.nix

    # === BOOT ===
    # Required: the system will not boot without bootloader configured.
    ../../linux/system/features/boot.nix

    # === MCP REQUIREMENTS ===
    ../../linux/system/services/github-mcp-server.nix
    ../../linux/system/services/github-token-check.nix
    ../../linux/system/virtualisation/docker.nix
  ];

  networking = {
    hostName = "t14";
    networkmanager.enable = true;
    # Defense-in-depth: keep host firewall off. Omarchy's firewall is
    # explicitly disabled below via omarchy.firewall.enable = false, but
    # this line ensures the NixOS-level firewall also stays off.
    firewall.enable = false;
  };

  # Background network health monitor — checks r8169 interfaces every
  # 60s and logs degradation events to journald (identifier "netwatch").
  # Query: journalctl -t netwatch -p warning --since "24 hours ago"
  services.netwatch.enable = true;

  nixpkgs.config = {
    allowUnfree = true;
    # fonts.nix includes joypixels; requires explicit license acceptance.
    allowUnfreePackages = [
      "joypixels"
      "fbneo" # libretro core — non-commercial clause
      "genesis-plus-gx" # libretro core — non-commercial clause
    ];
    joypixels.acceptLicense = true;
  };

  # Enable the imported boot module (systemd-boot, plymouth, zen kernel)
  boot-settings.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Disable PCIe Active State Power Management to prevent the Realtek
  # r8169 NIC from entering low-power states that cause intermittent
  # throughput drops (link stays up but speed degrades to <10MB/s).
  # See: Arch bbs#293977, Debian bug#1110193, netdev@ regression thread.
  boot.kernelParams = [ "pcie_aspm=off" ];

  # Loose reverse-path filtering — required when multiple NICs share
  # the same subnet (both enp2s0f0 and enp5s0 on 172.16.0.0/24).
  # rp_filter=2 (strict) drops legitimate packets arriving on one
  # interface whose source IP belongs to the other, causing TCP
  # timeouts and slow page loads.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
  };

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

  # === EDGE ENTERPRISE POLICIES ===
  # Disable Copilot, sidebar hub, shopping, rewards, and built-in
  # password manager. Policies are read from /etc/opt/edge/policies/managed/
  # at Edge startup. Verify with edge://policy.
  environment.etc."opt/edge/policies/managed/disable-bloat.json" = {
    text = builtins.toJSON {
      HubsSidebarEnabled = false;
      Microsoft365CopilotChatIconEnabled = false;
      ShowMicrosoftRewards = false;
      EdgeShoppingAssistantEnabled = false;
      PasswordManagerEnabled = false;
      QuickSearchShowMiniMenu = false;
    };
    mode = "0444";
  };

  # Desktop suite — t14 uses GNOME apps alongside omarchy/Hyprland.
  # omarchy-nix provides nautilus, calculator, evince, etc.;
  # this adds gnome-system-monitor via modules/base/profiles/gnome.nix.
  my.desktop.suite = "gnome";

  # Gaming — RetroArch + standalone emulators + Xbox controller.
  # Omarchy's retroarch.enable is disabled (uses deprecated API incompatible
  # with nixos-26.05); our features/gaming.nix provides the full stack.
  my.gaming = {
    enable = true;
    pegasus.enable = true; # Optional catalog frontend
  };
  my.gamepad.enable = true;

  # 32-bit OpenGL — required by some standalone emulators (PCSX2, RPCS3).
  hardware.graphics.enable32Bit = true;

  # HDM lid events depend on UPower D-Bus.  The amd-laptop module
  # (modules/hardware/amd-laptop.nix) enables services.upower by default,
  # but this assertion catches any accidental disable that would silently
  # degrade lid-event handling.
  assertions = [
    {
      assertion = config.services.upower.enable;
      message = "UPower must be enabled for HDM lid events — see modules/hardware/amd-laptop.nix";
    }
  ];

  # Microsoft Teams (teams-for-linux) wrapped to XWayland.
  # NIXOS_OZONE_WL=1 (set below) is global for Brave, VS Code, etc.
  # but teams-for-linux has known Electron tray bugs under native Wayland
  # (electron#40936, electron#43709, teams-for-linux#1609).
  # The symlinkJoin wrapper unsets NIXOS_OZONE_WL and explicitly passes
  # --ozone-platform=x11 (belt-and-suspenders: Electron 38+ auto-detects
  # Wayland from XDG_SESSION_TYPE even without the env var).
  # Screen sharing still works via WebRTCPipeWireCapturer in config.json.
  # Remove this wrapper when upstream fixes native Wayland tray support.
  environment.systemPackages = [
    (pkgs.symlinkJoin {
      name = "teams-for-linux";
      paths = [ pkgs.teams-for-linux ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/teams-for-linux \
          --unset NIXOS_OZONE_WL \
          --add-flags "--ozone-platform=x11" \
          --add-flags "--password-store=gnome-libsecret"
      '';
    })

    # Network diagnostic tool for r8169 multi-NIC debugging.
    # Run `netdiag` when slowness is felt; use `netdiag --watch 5`
    # to monitor and capture snapshots automatically.
    (pkgs.writeShellApplication {
      name = "netdiag";
      runtimeInputs = with pkgs; [
        bc
        curl
        ethtool
        iproute2
        nettools
      ];
      text = builtins.readFile ../../bin/netdiag;
    })
  ];

  environment.variables.NIXOS_OZONE_WL = "1";

  # === NETWORK TUNING ===
  # Disable NAPI software interrupt coalescing on Realtek r8169 NICs
  # (enp2s0f0 & enp5s0 — both 10ec:8168).  Kernel 6.2+ defaults
  # napi_defer_hard_irqs=1 which causes throughput regression from
  # ~100MB/s → ~10MB/s on certain RTL8111/8168 revisions.
  # See: netdev@ commit 42f66a44d8 ("r8169: enable GRO software
  # interrupt coalescing per default") regression thread.
  systemd.services.r8169-napi-fix = {
    description = "Disable NAPI interrupt coalescing on Realtek r8169 NICs";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    before = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for iface in /sys/class/net/enp*/napi_defer_hard_irqs; do
        [ -f "$iface" ] && echo 0 > "$iface"
      done
    '';
  };

  system.stateVersion = "26.05";
}
