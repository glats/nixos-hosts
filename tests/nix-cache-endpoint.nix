let
  flake = builtins.getFlake (toString ../.);
  cache = import ../shared/nix-cache.nix;
  rog = flake.nixosConfigurations.rog.config;
  t14 = flake.nixosConfigurations.t14.config;
  mac = flake.darwinConfigurations.macm5.config;
  vhosts = rog.services.nginx.virtualHosts;
  vhost = vhosts."nix-cache.glats.org";
  netrc = "/run/secrets/nix-cache/netrc";
  checkSettings =
    settings:
    assert builtins.elem "http://172.16.0.11:8501?priority=30" settings.substituters;
    assert builtins.elem "https://nix-cache.glats.org?priority=45" settings.substituters;
    assert !(builtins.elem "https://cache.glats.org?priority=45" settings.substituters);
    assert builtins.elem cache.ncps.publicKey settings.trusted-public-keys;
    assert builtins.elem cache.harmonia.publicKey settings.trusted-public-keys;
    true;
in
assert cache.remoteUrl == "https://nix-cache.glats.org";
assert builtins.elem "glats" rog.nix.settings.trusted-users;
assert builtins.elem "glats" t14.nix.settings.trusted-users;
assert builtins.elem "root" mac.determinateNix.customSettings.trusted-users;
assert builtins.elem "juan" mac.determinateNix.customSettings.trusted-users;
assert !(vhosts ? "cache.glats.org");
assert vhost.useACMEHost == "glats.org";
assert vhost.forceSSL;
assert vhost.basicAuthFile == "/run/secrets/nix-cache/htpasswd";
assert vhost.locations."/".proxyPass == "http://172.16.0.11:5000";
assert checkSettings rog.nix.settings;
assert checkSettings t14.nix.settings;
assert checkSettings mac.determinateNix.customSettings;
assert rog.nix.settings.netrc-file == netrc;
assert t14.nix.settings.netrc-file == netrc;
assert mac.determinateNix.determinateNixd.authentication.additionalNetrcSources == [ netrc ];
assert builtins.all (config: config.sops.secrets."nix-cache/netrc".mode == "0400") [
  rog
  t14
  mac
];
true
