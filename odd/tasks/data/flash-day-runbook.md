# Flash-day runbook — Xiaomi AX3200 (RB01) → OpenWrt 25.12.5

Constraint (A3): the user loses external help while home internet is down. This runbook is self-contained: every step and every failure path is executable offline, without the assistant.

## Staged kit (already on disk: /tmp/opencode/modem-xiaomi-ax3200/)

- `recovery-kit/MIWIFIRepairTool.x86.zip` — official Xiaomi unbrick tool (TFTP, Windows/wine x86)
- `recovery-kit/stock-1.0.83-INT.bin` — the router's exact stock firmware (20,841,404 bytes)
- `secrets.env` — WAN PPPoE + WiFi keys (verified against the router; chmod 600)
- `*.json` — live-config exports (WAN/LAN/WiFi/port-forwards/state)
- Repo: `odd/tasks/data/openwrt-config-map.md` — UCI translation map

## Phase 0 — pre-flight (zero router risk)

1. PC wired to router (Ethernet, LAN side).
2. Phone hotspot ready as fallback network (escape hatch to reach help if needed).
3. Download OpenWrt 25.12.5 factory image once while internet is up and keep it:
   https://downloads.openwrt.org/releases/25.12.5/targets/mediatek/mt7622/xiaomi_redmi-router-ax6s-factory.bin
4. Copy the whole `/tmp/opencode/modem-xiaomi-ax3200/` folder to a second location (USB disk recommended).
5. Have the router admin password at hand for xmir-patcher.

## Phase 1 — unlock SSH on stock (expected downtime: zero, no reboot)

1. `git clone https://github.com/openwrt-xiaomi/xmir-patcher.git && cd xmir-patcher && ./run.sh`
2. Option 2 — connect/install exploit (asks the router's admin web password). WAN stays up.
3. Option 4 — create full backup; keep every produced file.
4. Option 6 — install permanent SSH.
5. Verify from the PC: `ssh root@172.16.0.1` then `cat /proc/mtd`.
6. Full-fidelity extras (only possible in this phase): `cat /etc/config/dhcp > dhcp-snapshot; cat /etc/config/wireless > wireless-stock; cat /etc/config/firewall > firewall-stock` (scp them to the PC); also download the web-UI backup file if present.

STOP HERE. Use SSH freely; Phase 2 happens only with explicit user go.

## Phase 2 — flash OpenWrt (expected downtime ~5–15 min; offline-capable)

1. Place the factory image in `xmir-patcher/firmware/`, run patcher, option 7. Device reboots with OpenWrt.
2. First check (by cable): LuCI reachable at http://172.16.0.1 — default OpenWrt LAN is 192.168.1.1; only after login set it to 172.16.0.1 per the config map.
3. Apply `openwrt-config-map.md`: WAN PPPoE (secrets from `secrets.env`), LAN 172.16.0.1/24, WiFi JICS/JICS-5G psk2, firewall redirects (wg/51820udp, http, https → 172.16.0.5), DHCP leases from the Phase-1 snapshots.
4. Boot-flag fix (MANDATORY on RB01, prevents the known reboot-loop):
   ```
   fw_setenv boot_fw1 "run boot_rd_img;bootm"
   fw_setenv flag_try_sys1_failed 8
   fw_setenv flag_try_sys2_failed 8
   fw_setenv flag_boot_rootfs 0
   fw_setenv flag_boot_success 1
   fw_setenv flag_last_success 1
   ```
   Verify: `fw_printenv | grep flag_try_sys1_failed` shows 8.
5. Final verification checklist: WAN link up (PPPoE, same ISP IP), every device reassociates to JICS/JICS-5G, port forwards reachable from outside, rog's wireguard handshake works.

## Failure paths (no assistant needed)

- OpenWrt misconfigured/regret: reflash factory image again via xmir-patcher, or failsafe (hold reset while powering on; OpenWrt recovery at 192.168.1.1).
- Boot loop after flash: three consecutive power cycles normally stop in recovery; with the Phase-2 boot-flag fix this is prevented anyway.
- Device looks dead (orange blink, nothing responds): MIWIFIRepairTool + `stock-1.0.83-INT.bin` → cable to WAN port, tool in Ethernet mode, hold reset while plugging power, release at fast orange blink → stock restored. Alternative LAN port 1 if WAN refuses.
- Worst case beyond that: UART (CH341A clip) — documented in OpenWrt wiki/mikeeq; hardware-level, do not attempt without reason.

## Rule of thumb

Never run a step that can reboot the router unless the PC can also reach it by cable and this runbook is saved locally (print or copy the file). If any doubt: stop, keep Phase 1 only — SSH root on stock is already the main prize and is fully reversible.
