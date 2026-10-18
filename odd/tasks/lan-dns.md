# LAN DNS names (.lan) on OpenWrt via AGH domain routing

Objective: every house device resolvable by DHCP name via real DNS (ping oneplus5.lan) without touching mDNS/zeroconf behavior. Domain chosen by user: `.lan`.
Branch: feature/lan-dns (stacks on feature/adguard). Verification: dig/dns probe battery + ping from rog.
Delivery: ask-on-risk (single user decision = the baptism table; rest inline).

## Specs

- S1 (user verbatim: "quiero que nombres toda la tabla dhcp ahora para yo poder bautizar los dominios" + ".lan suena bien"): `.lan` names resolve through DNS for every DHCP-announced hostname and for the USER-baptized static hosts; mDNS/.local behavior untouched and nothing removed.
- S2 (no-loop routing): AdGuard Home routes `[/lan/]` and `[/172.16.in-addr.arpa/]` queries to `127.0.0.1:5353` (dnsmasq), everything else to Quad9 doT exactly as today (upstream_mode parallel, DNSSEC on — untouched).
- S3 (dnsmasq auto-registration): dnsmasq already serves lease hostnames under `.lan` (uci defaults verified: domain='lan', expandhosts=1, local='/lan/', domainneeded=1) — no extra config needed for dynamic devices; static dhcp.@host entries get USER-baptized names (migration of the rogue 'dev6'/'dev9'/'dev10'/'dev11'/'dns12' placeholders).
- S4 (evidence-confirmed statics from the Xiaomi app export misystem_status.json): .9=5a:d7:9c:c6:98:4b=macm5, .11=6c:4b:90:2d:97:42=thinkcentre, .5=rog (confirmed), .12=ee:03:cd:b0:51:74=oneplus5 (confirmed). .6=f8:e4:3b:53:64:cc and .10=54:05:db:a1:3f:01 placeholders the USER identifies in the baptism table.
- S5 (lease-announced names use the live lease; anonymized-MAC devices like t14-over-wifi or the SONY (.183) resolve by their live lease with rotating IPs — accepted behavior — stable-IP bindings are a user decision per device, not forced).

## Tasks

- T1 [S2] inline DONE — AGH upstream list gained domain-routing: `"[/lan/]127.0.0.1:5353"` + `"[/172.16.in-addr.arpa/]127.0.0.1:5353"` (quoted — yaml flow-sequence hazard), check-config ok, restarted, public names still via Quad9 parallel.
- T2 [S3] inline DONE — statics renamed (macm5/t14/thinkcentre/oneplus5) + 8 leases promoted to static hosts with user-baptized names (roku/cam/redmu/tabs7/sony/iphone-nicole/motorola-edge/asus/oneplus9 = 14 hosts total). PENDING user word: `dlink-repeater` duplicate (baptized for BOTH .3 D-Link and .149 RE305 — different devices) and the `redmu` probable typo (¿redmi?). Unbaptized (.6 offline unnamed, .108 Intel PC, .249 blind) resolve by lease self-names when present.
- T3 [S1] inline DONE — 15/15 names resolve via dig @172.16.0.1; the 4 offline statics fixed via /etc/hosts entries (OpenWrt regen treats dhcp.@host as DHCP-maps, NOT A-records — names resolve only with live leases otherwise; /etc/hosts is the canonical persistent place: dnsmasq now reads 54 names). PTR reverse verified (macm5.lan/oneplus5.lan). Public names unaffected (Quad9 path unchanged).
- T4 [S5] inline DONE-PENDING-REBUILD — ssh mesh: the correct fix is the nix module shared/ssh/lan-mesh.nix (all 5 members' hostName .local→.lan — edited on this branch); sed-on-generated-file was wiped by the home-manager regen (lesson: the mesh config is HM-generated; never edit ~/.ssh/config directly). The user's fleet rebuild (their nixos-build run) applies it; macm5-relay (127.0.0.1:22220) untouched by design.
- T5 close — docs (config map note), engram mirror, work-unit commit on feature/lan-dns.

## Log

L1 (2026-10-17) user: "ya ahora me gustaria tener dns. casi todos los equipos usan avahi o algo asi zero conf par ala red. pero me encantaria un dns y que cada hosts tenga su nbombre y hacer solo ping nombre.local., no se si .local es lo mejor. cohara con algo? lo quiero en openwertt" → presented .local (mDNS-reserved, conflicts with zeroconf) vs .lan (default dnsmasq convention) vs home.arpa (RFC 8375) vs .glats.org (public/private mixing — rejected). User: ".lan suena bien. quiero que nombres toda la tabla dhcp ahora para yo poder bautizar los dominios" — the baptism table presented next; names applied on user reply.

L2 (2026-10-18 00:56) IMPLEMENTATION COMPLETE + THREE LESSONS. (1) OpenWrt's dhcp.@host entries are DHCP-maps, NOT DNS A-records: the regenerated /tmp/hosts/dhcp.cfg* only holds the router's own entry; static names resolve ONLY when the device has a live lease — the canonical fix for always-resolvable fixed hosts = /etc/hosts entries on the router (persistent via overlay, dnsmasq re-reads: 12→54 names). (2) The user's ~/.ssh/config is HOME-MANAGER-GENERATED from shared/ssh/lan-mesh.nix (matchBlocks); sed edits on the generated file get wiped by the next regeneration — the correct fix = edit the module (done: all 5 hostName values .local→.lan) + fleet rebuild by the user (their activation decision). (3) The mDNS .local resolution on rog is broken independent of DNS ("Device or resource busy" — a separate rog-side bug, not this feature's scope; the .lan names make the mesh work regardless via router DNS). Verification: 15/15 dig names + PTRs + external edge 200. Pending user word: dlink-repeater duplicate (.3 vs .149), redmu→redmi typo check, and their fleet rebuild for the mesh.
