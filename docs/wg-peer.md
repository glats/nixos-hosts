# wg-peer — WireGuard peer management on rog

One command to list, create, delete, and QR-print WireGuard peers. The peers stay
declarative in Nix; the script writes the Nix for you and rebuilds.

## Quick path

```bash
wg-peer add samsung2      # creates peer: keypair, next free IP, rebuild, conf + QR
wg-peer list              # see all peers with IPs and last handshake
wg-peer qr samsung2       # reprint the QR any time
wg-peer remove samsung2   # delete peer and clean up its files
```

After `add`, scan the printed QR with the WireGuard app (Android/iOS) or import
the `.conf` file (macOS/Windows/Linux) and activate the tunnel.

## Where things live

| Path | What |
|------|------|
| `linux/system/services/network/wireguard.nix` | Peers (declarative, source of truth) |
| `/etc/wireguard/clients/<name>.conf` | Ready-to-import config (real PrivateKey included) |
| `/etc/wireguard/clients/<name>.png` | QR code of the config |
| `/etc/wireguard/keys/<name>.key` | Client private key (root-only, chmod 600) |

## Details

| Topic | Decision |
|-------|----------|
| Model | Model B — server generates keys, confs are ready to import (like commercial VPNs / wg-easy) |
| IPs | Auto-assigned from `10.13.13.0/24`, next free (`.7`, `.8`, …) |
| PSK | New peers get no PSK (optional in WireGuard); the 5 original peers keep theirs |
| AllowedIPs | `10.13.13.0/24, 172.16.0.0/24` — VPN + home LAN routes through the tunnel |
| Endpoint | `guard.glats.org:51820` |
| Rebuild | `wg-peer add/remove` runs `nixos-build` automatically |

## Declarative or not?

The peers **are declarative**. `wireguard.nix` is the single source of truth —
`wg-peer` only inserts or removes peer blocks between the
`wg-peer:managed-start` / `wg-peer:managed-end` markers and then rebuilds.
Hand-editing the file works identically; the script is just a convenience.

The only non-declarative pieces are derived artifacts (client keys in
`/etc/wireguard/keys/` and confs/QRs in `/etc/wireguard/clients/`), which the
activation script regenerates from the declared peers on every rebuild.

## Checklist

- [ ] `wg-peer list` shows all 5 peers with correct IPs
- [ ] `wg-peer add <name>` ends with a printed QR
- [ ] `/etc/wireguard/clients/<name>.conf` contains a real `PrivateKey`
- [ ] `wg-peer remove <name>` leaves no trace in the module, `/etc/wireguard`, or `wg show`
