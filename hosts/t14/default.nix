{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./secrets.nix

    ../../linux/system/base/cachix.nix
    ../../linux/system/base/nix-cache-client.nix
    ../../linux/system/base/nix.nix
    ../../linux/system/base/polkit.nix
    ../../linux/system/base/sops.nix
    ../../linux/system/base/users.nix
    ../../linux/system/base/zsh.nix
    ../../linux/system/base/packages.nix
    ../../linux/system/base/home-manager.nix

    ../../linux/system/desktop/i18n.nix
    ../../linux/system/desktop/fonts.nix
    ../../linux/system/desktop/kmscon.nix

    ../../linux/system/hardware/amd-laptop.nix
    ../../linux/system/hardware/keyring.nix
    ../../linux/system/hardware/openlogi.nix

    ../../linux/system/networking/openssh.nix
    ../../linux/system/networking/netwatch.nix

    ./overlays.nix
    ./omarchy-config.nix
    ./quattro.nix

    ../../linux/system/hardware/gamepad.nix
    ../../linux/system/features/gaming.nix

    ../../linux/system/features/boot.nix

    ../../linux/system/virtualisation/docker.nix
  ];

  networking = {
    hostName = "t14";
    networkmanager.enable = true;
    firewall.enable = false;
  };

  services.netwatch.enable = true;

  services.avahi.nssmdns6 = lib.mkForce false;

  services.avahi.allowInterfaces = [ "enp2s0f0" ];

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePackages = [
      "joypixels"
      "fbneo"
      "genesis-plus-gx"
    ];
    joypixels.acceptLicense = true;
  };

  boot-settings.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_zen;

  boot.kernelParams = [ "pcie_aspm.policy=performance" ];

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.default.arp_announce" = 2;
  };

  boot.initrd.supportedFilesystems = [ "xfs" ];

  boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";

  security.wrappers.pkexec.enable = lib.mkForce true;

  services.xserver.xkb = {
    layout = lib.mkForce "latam";
    variant = "";
  };
  console.keyMap = lib.mkForce "la-latin1";

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

  my.desktop.suite = "gnome";

  my.gaming = {
    enable = true;
    pegasus.enable = true;
  };
  my.gamepad.enable = true;

  hardware.graphics.enable32Bit = true;

  assertions = [
    {
      assertion = config.services.upower.enable;
      message = "UPower must be enabled for HDM lid events — see modules/hardware/amd-laptop.nix";
    }
  ];

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

    (pkgs.symlinkJoin {
      name = "microsoft-edge";
      paths = [ pkgs.microsoft-edge ];
      buildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/microsoft-edge \
          --unset NIXOS_OZONE_WL \
          --add-flags "--ozone-platform=x11"
        # Desktop files are symlinks into the immutable store; replace
        # them with writable copies before substituting the Exec path.
        for f in $out/share/applications/*.desktop; do
          rm -f "$f"
          cp "${pkgs.microsoft-edge}/share/applications/$(basename "$f")" "$f"
          substituteInPlace "$f" \
            --replace-fail "${pkgs.microsoft-edge}/bin/microsoft-edge" \
            "$out/bin/microsoft-edge"
        done
      '';
    })

  ];

  environment.variables.NIXOS_OZONE_WL = "1";

  systemd.services.r8169-tune = {
    description = "Tune Realtek r8169 NICs (NAPI coalescing off, EEE off)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-pre.target" ];
    before = [ "network.target" ];
    path = [ pkgs.ethtool ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for iface in /sys/class/net/enp*; do
        [ -d "$iface" ] || continue
        name="$(basename "$iface")"
        [ -f "$iface/napi_defer_hard_irqs" ] && echo 0 > "$iface/napi_defer_hard_irqs"
        ethtool --set-eee "$name" eee off 2>/dev/null || true
      done
    '';
  };

  system.stateVersion = "26.05";
}
