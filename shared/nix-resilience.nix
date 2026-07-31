{ ... }:

{
  nix.settings = {
    # HTTP/2 puede ser 10x más lento en algunas conexiones (curl bug).
    # Desactivarlo fuerza HTTP/1.1 que suele ser más estable con fastly.
    http2 = false;

    # Resiliencia ante red lenta
    stalled-download-timeout = 30; # default 300s — falla rápido en descargas colgadas
    http-connections = 50; # default 25 — más descargas paralelas
    download-attempts = 3; # default 5 — menos reintentos para no colgarse
    connect-timeout = 5; # timeout de conexión — fallar rápido
    fallback = true; # si un caché falla, compilar local
  };
}
