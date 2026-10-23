let
  flake = builtins.getFlake (toString ../.);
  rog = flake.nixosConfigurations.rog.config;
  settings = rog.services.dnsmasq.settings;
  clientConfig = builtins.unsafeDiscardStringContext rog.system.activationScripts.wireguard-client-configs;
in
assert rog.services.dnsmasq.enable;
assert settings."listen-address" == [ "10.13.13.1" ];
assert settings."bind-interfaces" == [ true ];
assert builtins.elem "/lan/172.16.0.1" settings.server;
assert builtins.elem "1.1.1.1" settings.server;
assert builtins.elem "8.8.8.8" settings.server;
assert builtins.match ".*DNS = 10\\.13\\.13\\.1.*" clientConfig != null;
assert
  builtins.match ".*AllowedIPs = 10\\.13\\.13\\.0/24, 172\\.16\\.0\\.0/24.*" clientConfig != null;
assert
  (builtins.length (
    builtins.filter builtins.isList (builtins.split "DNS = 10\\.13\\.13\\.1" clientConfig)
  )) == 3;
true
