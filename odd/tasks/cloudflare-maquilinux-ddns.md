# cloudflare-maquilinux-ddns

Objective: Cloudflare CLI on rog plus ddclient keeping maquilinux.org (apex + wildcard) pointed at rog, with glats.org unchanged.
Branch: `feat/cloudflare-maquilinux-ddns` · Delivery: ask-on-risk (forecast ~100 authored lines, single PR) · Checks: `nix fmt`, `nix eval` rog toplevel, `nix flake check --no-build`.

## Specs

- S1 — Cloudflare CLI: install `flarectl` on rog with a wrapper that reads the Cloudflare token from a sops secret readable by `glats` ("flarectl + wrapper"), so `flarectl dns list --zone maquilinux.org` works without exporting variables.
- S2 — ddclient migrates from the opaque sops `configFile` to native `services.ddclient` options with only the token in sops ("Native Nix + token in sops").
- S3 — glats.org "Leave it as is": ddclient keeps updating exactly `glats.org`, `*.glats.org`, `guard.glats.org`, IPv4 only, via `ifconfig.io`; no new AAAA records and no proxy change.
- S4 — maquilinux.org: "apex y wildcard", "Proxied" — `maquilinux.org` and `*.maquilinux.org` A records point at rog through the Cloudflare proxy and are kept updated by ddclient.
- S5 — Token: "Extend the existing one" — reuse `cloudflare_dns_api_token` (`secrets/host/rog/cloudflare.yaml`) for ACME, ddclient and the CLI. External step (user): add the maquilinux.org zone (Zone:Read + DNS:Edit) to that token in the Cloudflare dashboard.
- Assumption: ddclient's cloudflare protocol only updates existing records, so the initial maquilinux.org A records are created once with flarectl (`--proxy`) after deploy.

## Tasks

- [x] T1 — S1, S2, S3, S5 — Nix: native ddclient config + CLI module + sops declarations — route: inline — commit: 44be3965 (RDD off; independent verify PASS)
- [ ] T2 — S4, S5 — deploy, create proxied A records via flarectl, verify ddclient run — route: inline (needs user: token zone + `nixos-build switch`) — commit: n/a

## Log

- L1 (2026-10-15) user request: "configurafull odd para configurar cloudflare cli y configurar mis dns para que glats.orr y maquilinux.org y quiero configurar mi ddclient para maquilinux.org apunte a esta maquina rog."
- L2 (2026-10-15) answers: glats.org "Leave it as is"; maquilinux.org records "same as glast.rg pero claro vamos a necesitar ambos yo creo apex y wildcard"; proxy "Proxied (Recommended)"; ddclient "Native Nix + token in sops (Recommended)"; token "Extend the existing one (Recommended)"; CLI "flarectl + wrapper (Recommended)".
- L3 evidence: maquilinux.org registered 2026-10-15, NS garrett/kim.ns.cloudflare.com, no A record yet. ddclient cache/journal show hosts glats.org, *.glats.org, guard.glats.org with `use=web web=ifconfig.io`; public IPv4 201.188.176.217. flarectl 0.116.0 in rog pkgs.
- L4 T1 evidence: RED `services.ddclient.domains` = [""] (opaque file). GREEN rendered ddclient.conf has global zone=glats.org + `zone=maquilinux.org maquilinux.org,*.maquilinux.org` + `glats.org,*.glats.org,guard.glats.org`; rog toplevel eval OK; `nix flake check --no-build` passed; flarectl wrapper builds (shellcheck). Independent verifier: S1-S3,S5 pass, S4 pass on config; ddclient cloudflare only PATCHes content of existing records (proxied preserved), so T2 must create records first. Old secrets/host/rog/ddclient.yaml removed.
- L5 next: user adds maquilinux.org zone to the token, runs `nixos-build switch`; then `flarectl dns create --zone maquilinux.org --name maquilinux.org --type A --content <ip> --proxy` and same for `*`; then `sudo systemctl start ddclient` and check the journal.
- L6 (2026-10-15) user: "flarectl dns create ... ListZonesContext command failed: Invalid request headers (6003) ... despues del build nix". Root cause: `cloudflare_dns_api_token` is the lego env file `CLOUDFLARE_DNS_API_TOKEN=<token>`; ddclient also logged HTTP 400 for maquilinux.org. Fix cf835975: root ExecStartPre extracts bare token to /run/ddclient/cloudflare-token; wrapper strips prefix. Evidence: rebuilt wrapper `flarectl zone list` lists glats.org and maquilinux.org (token already covers both zones); rog eval + flake check pass.
