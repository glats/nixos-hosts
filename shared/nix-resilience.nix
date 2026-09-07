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
  # HTTP/2 can be 10x slower on some connections (curl bug).
  # Disabling it forces HTTP/1.1, which is usually more stable with fastly.
  http2 = false;

  # Resilience for slow networks
  stalled-download-timeout = 30; # default 300s — fail fast on stalled downloads
  http-connections = 50; # default 25 — more parallel downloads
  download-attempts = 3; # default 5 — fewer retries so fetches don't hang
  connect-timeout = 5; # connection timeout — fail fast
  fallback = true; # if a cache fails, build locally
}
