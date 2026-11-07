# AdGuard Home on samsung (declarative NixOS), replacing the dead oneplus5 instance

Objective: run AdGuard Home on samsung at 172.16.0.12 with the exact configuration the OnePlus 5 served (90 rules, 4 clients, 2 HaGeZi lists, same upstreams), declared in Nix, keeping the DHCP DNS fallback so the LAN never loses resolution.
Branch: feat/samsung-adguard. Test runner: `nix eval` / `nix flake check --no-build`, AdGuard `--check-config` on the generated yaml, live `dig` battery after cutover.
Delivery strategy: ask-on-risk. Router changes and the samsung rebuild are manual/gated; no push or merge without the user's request.

## Specs

- S1 (user verbatim: "vamos a configurar esto apra samsung pero usando nix delcaritvo."): AdGuard Home on samsung is configured through the NixOS module `services.adguardhome`, not by hand.
- S2 (user verbatim: "Para llevarlo a samsung sin tocar el DHCP, se podría reservar .12. me gusta esta idea."): samsung is reserved at 172.16.0.12 and AdGuard binds `172.16.0.12:53`; DHCP option 6 (`6,172.16.0.12,172.16.0.1,9.9.9.9`) is not modified.
- S3 (user verbatim: "va haber que configurar la reserva para LG."): the LG webOS TV (MAC 48:8d:36:65:51:7c, currently dynamic 172.16.0.237) gets a DHCP reservation at 172.16.0.22; client `lg-tv` keeps both ids (.22 and .237) during the lease transition.
- S4 (user verbatim: "las listas HaGeZi LIGHT y TIF MINI, y los upstreams, como te conté. todas esas"): parity with the live OnePlus config: 13 rules for android-tv/android-tv-2 (.8 Philips, .7 Sony), 51 for roku (.14), 26 for lg-tv, filters HaGeZi Multi LIGHT and HaGeZi Threat Intelligence Feeds MINI, and the same upstreams, bootstrap, fallback, cache and DNSSEC settings.
- S5 (user verbatim: "tenemos dns fallback por si el servidor que tinen el adguard se apagaba. y no nos quedemos sin resolver."): the secondary DNS entries stay in DHCP option 6; the design never depends on samsung being the only resolver.
- S6 (assumption, user accepted the plan): the web panel binds `127.0.0.1:3000` only, reachable through an SSH tunnel, with no login, because declarative mode would place a password hash in /nix/store.
- S7 (assumption, marked optional): samsung is a Wi-Fi tablet acting as DNS host, so suspend targets and Wi-Fi power save are disabled to keep it resolving.
- S8 (router, gated, never run without explicit user OK): back up `/etc/config/dhcp`, repoint the `.12` reservation (currently `oneplus5`) to samsung MAC c8:f7:33:73:9a:24, add the LG reservation, restart only dnsmasq; ssh via `root@router.lan`.

## Tasks

- [x] T1 (S1,S2,S4,S5,S6) module `linux/system/services/network/adguardhome.nix` + `adguardhome-rules.txt`, imported by `hosts/samsung`. Route: inline. Commit: 9342e8d7. Evidence: parity vs OnePlus backup (schema 34=34, 90 rules identical in order, 2 filters, 4 clients, dns scalars identical); AdGuard 0.107.79 `--check-config` on the generated config: "configuration file is ok".
- [x] T2 (S7) samsung reliability settings in `hosts/samsung/default.nix` (suspend/sleep/hibernate targets off, `wifi.powersave = false`). Route: inline. Commit: 9342e8d7.
- [x] T3 docs: `docs/samsung-adguard-dns.md` runbook, superseded banner on `docs/oneplus5-adguard-dns.md`. Route: inline. Commit: this docs commit.
- [x] T4 verification: `nix eval` of samsung, rog, thinkcentre, t14 and home samsung OK; `nix flake check --no-build` all checks passed; parity and `--check-config` as in T1. Route: inline. Not covered: macm5 (cannot evaluate from Linux), live DNS behavior (needs T5 and the samsung rebuild).
- [ ] T5 (S2,S3,S8) router reservations. Route: manual, gated on explicit user OK. Status: not started.
- [ ] T6 (follow-up) remove dead oneplus5 from `shared/ssh/lan-mesh.nix` and docs. Route: inline, needs user OK.

Risk: T1-T2 none beyond item 3 check (new module only imported by samsung; shared files untouched). T5 touches live network config (item 5, delivery/environment): manual with backup and rollback.

## Log

- L1 (2026-11-07, user): "quiero ver el tema de adguard. que contexto tienes?"
- L2 (2026-11-07, user): "bie npara acceder al router vamos a usar ssh root@routern.lan. ahora creo que estuvo configurada la ip 172.16.0.12 que era el oneplus. adguard estuvo en el router pero parece que el dispositvo se quedaba sin ram. ademas tenia unas reglas para los televidores. me imagino que se perideron?"
- L3 (2026-11-07, user): "Para llevarlo a samsung sin tocar el DHCP, se podría reservar .12. me gusta esta idea. vale entonces vamos a configurar esto apra samsung pero usando nix delcaritvo. para eso necesitas hacer un explore o con la info que tienes ya puedes. aun no implemnetes yo te dire cuando."
- L4 (2026-11-07, user): "tenemos dns fallback por si el servidor que tinen el adguard se apagaba. y no nos quedemos sin resolver. esa era la cuestion. entonces en definitica dame el panorama completo que vamos a abordar antes de implementar para ver si estamos en la misma pagina"
- L5 (2026-11-07, user): "ya"
- Analysis: AdGuard was OOM-killed on the 242 MB router 4 s and ~81 s after the two HaGeZi list updates; pprof was disabled so the cause is probable, not proven (engram #4415, #5175). The only complete copy of the live config is the OnePlus backup (rog:~/Backups/oneplus5-rescue-20261105.fqBK85, etc/adguardhome/AdGuardHome.yaml, schema 34, AdGuard 0.107.79). Plan saved at engram #5174.
- Progress (2026-11-07): T1-T4 done and verified on branch feat/samsung-adguard. Next: user decision on T5 (router reservations) and the samsung rebuild; T6 pending user OK.
