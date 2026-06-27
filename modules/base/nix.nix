{ lib, ... }:

{
  nix.gc = {
    automatic = false;
    dates = "weekly";
    randomizedDelaySec = "1h";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;

    # Cache alternativo: mirror Fastly que usa el mismo bucket S3 de cache.nixos.org
    # con binarios pre-firmados (sin necesidad de trusted-public-keys extra).
    # La URL freetls soporta IPv6 + HTTP/2.
    substituters = lib.mkBefore [
      "https://aseipp-nix-cache.freetls.fastly.net"
      "https://aseipp-nix-cache.global.ssl.fastly.net"
    ];

    # HTTP/2 puede ser 10x más lento en algunas conexiones (curl bug).
    # Desactivarlo fuerza HTTP/1.1 que suele ser más estable con fastly.
    http2 = false;

    # Resiliencia ante red lenta
    stalled-download-timeout = 30; # default 300s — falla rápido en descargas colgadas
    http-connections = 50; # default 25 — más descargas paralelas
    download-attempts = 10; # default 5 — más reintentos
    connect-timeout = 15; # timeout de conexión
  };
}
