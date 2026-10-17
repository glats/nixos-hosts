# Run: nix eval --impure --json --expr 'import ./tests/t14-networkmanager.nix { flake = builtins.getFlake (toString ./.); }'
{ flake }:
let
  lib = flake.inputs.nixpkgs.lib;
  host = flake.nixosConfigurations.t14.config;
  home = host.home-manager.users.glats;
  checks = {
    networkManagerOwnsWifi =
      host.omarchy.wifi.backend == "nm-iwd"
      && host.networking.networkmanager.enable
      && host.networking.networkmanager.wifi.backend == "iwd"
      && host.networking.networkmanager.dhcp == "internal"
      && host.networking.networkmanager.dns == "systemd-resolved"
      && host.networking.networkmanager.unmanaged == [ ];
    noCompetingWifiConfiguration =
      host.networking.wireless.iwd.enable
      && !host.networking.wireless.enable
      && !(host.systemd.services ? wpa_supplicant)
      && !(host.systemd.services ? dhcpcd)
      && !host.systemd.network.enable
      && host.networking.wireless.iwd.settings == { }
      && !(host.networking.wireless.iwd.settings.General.EnableNetworkConfiguration or false)
      && !((host.networking.wireless.iwd.settings.Network or { }) ? NameResolvingService);
    resolverPreserved = host.services.resolved.enable;
    desktopPolicyPreserved =
      !host.omarchy.hyprland.lidSwitch.enable
      && host.omarchy.greeter.type == "regreet"
      && host.services.greetd.enable
      && host.omarchy.greeter.wayvnc.enable
      && host.omarchy.wayvnc.enable
      && host.omarchy.terminal == "ghostty";
    mouseWigglePreserved =
      builtins.elem "graphical-session.target" home.systemd.user.services.mouse-wiggle.Install.WantedBy
      && home.systemd.user.services.mouse-wiggle.Service.Restart == "on-failure";
  };
in
assert lib.assertMsg (lib.all (ok: ok) (builtins.attrValues checks)) (
  "T14 NetworkManager regression checks failed: "
  + lib.concatStringsSep ", " (builtins.attrNames (lib.filterAttrs (_: ok: !ok) checks))
);
checks
