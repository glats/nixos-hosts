# Shared nix.conf resilience settings — plain attrset, NOT a module.
#
# Imported by both platforms:
#   - NixOS:      nix.settings = (import .../nix-resilience.nix) // { ... }
#   - nix-darwin: determinateNix.customSettings = (import .../nix-resilience.nix) // { ... }
#
# On nix-darwin hosts managed by Determinate Nix, nix-darwin's `nix.settings`
# is SILENTLY IGNORED — Determinate generates /etc/nix/nix.custom.conf only
# from `determinateNix.customSettings`. Keep these values here so both
# platforms share one source of truth.
{
  # HTTP/2 puede ser 10x más lento en algunas conexiones (curl bug).
  # Desactivarlo fuerza HTTP/1.1 que suele ser más estable con fastly.
  http2 = false;

  # Resiliencia ante red lenta
  stalled-download-timeout = 30; # default 300s — falla rápido en descargas colgadas
  http-connections = 50; # default 25 — más descargas paralelas
  download-attempts = 3; # default 5 — menos reintentos para no colgarse
  connect-timeout = 5; # timeout de conexión — fallar rápido
  fallback = true; # si un caché falla, compilar local
}
