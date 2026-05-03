{ config, pkgs, ... }:

{
  # ============================================================
  # FlareSolverr - Proxy to bypass Cloudflare protection
  # Used by Prowlarr for some trackers
  # No web UI - just API at http://127.0.0.1:8191
  # ============================================================
  services.flaresolverr = {
    enable = true;
    port = 8191;
    openFirewall = false; # Only accessed locally by Prowlarr
  };
}
