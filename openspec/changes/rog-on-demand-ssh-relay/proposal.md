# Proposal: On-Demand SSH Through rog

## Intent

Enable operator/agent SSH from rog to macm5 through on-demand outbound HTTPS/WSS443 at exactly `relay.glats.org`. rog is the relay, not a VPS; nightly absence is normal.

## Scope

### In Scope
- Separate rog ingress/backend, runtime credentials, and loopback-only reverse SSH listener.
- macm5 `on/off/status` CLI and background lifecycle independent of linkctl.
- rog SSH alias using `juan`, key authentication, and verified Mac host keys.

### Out of Scope
- VPN/WireGuard, TUN/routing changes, other targets, remote visitors, dashboards, and existing remote power control.
- Client reboot persistence: unconfirmed, outside MVP. Manual startup/no boot autostart is recommended, not user-approved persistence policy.
- SSH availability while rog is off or session survival through relay loss/Mac sleep.

## Capabilities

### New Capabilities
- `on-demand-ssh-relay`: authenticated reverse publication, local operator SSH, enabled-intent recovery, cancellation, bounded truthful status, and isolation across rog/macm5.

### Modified Capabilities
None; existing onboarding and VLESS/linkctl requirements remain unchanged.

## Approach

User explicitly approved replacing Chisel with erebe Rust wstunnel11.0.0 after `exploration.md`/Engram #3688 real-binary tests. Native restriction YAML permits only authenticated `!ReverseTunnel` protocol `[Tcp]`, port `['22220']`, CIDR `[127.0.0.1/32]`; all other declared modes/listeners are denied. Supply independently revocable per-host Authorization through native `--http-headers-file`, never credential argv/environment/store/logs. The trusted managed Mac forwards only `127.0.0.1:22`; no malicious-endpoint attestation is claimed. Mandatory TLS/system-CA verification and final Mac SSH key/host-key checks replace obsolete Chisel transport fingerprints. Preserve nginx WSS443 topology, separate linkctl and manual launchagent. Native reconnect maintains enabled intent; off cancels the owned job without another supervisor. Policy/credential updates require dedicated-server STOP, changed-policy validation, then START; failures stay stopped and last removal uses `restrictions: []`. No automatic secret reload before stop or hot-reload-only revocation. Provisioning/deployment remain unauthorized.

## Affected Areas

| Path | Planned impact |
|---|---|
| `hosts/rog/default.nix`, `linux/system/services/network/ssh-relay.nix` | Import/new relay |
| `linux/system/services/web/nginx.nix` | Isolated vhost/path |
| `hosts/macm5/default.nix`, `darwin/system/ssh-relay.nix` | Import/new client |
| `linux/home/ssh.nix`, `shared/ssh/lan-mesh.nix` | Host-scoped additive alias/key reuse |
| `pkgs/nixos-scripts/{cmd,internal,default.nix}` | Thin Go control/status |
| `.sops.yaml`, `docs/rog-ssh-relay.md` | Credential rules/runbook |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| DNS/CDN/TLS ingress unproven | Medium | Validate exact hostname/WS coexistence |
| ACL bypass/public listener | Medium | Patched artifact, loopback binding, denial tests |
| Workplace restrictions/outage noise | Medium | Authorized native tests, verified TLS, quiet retries |

## Rollback Plan

Disable/unload only new units; revoke new credentials; remove new imports, vhost/path, and alias. Restore known-good host generations without altering linkctl, LAN SSH, or other vhosts.

## Dependencies

Linux wstunnel binary positive/negative tests support selection, not production acceptance. Require pinned Rust packaging, native Darwin-arm64 execution, exact DNS/TLS/nginx Authorization/WSS443, safe revocation transaction, retry/sleep longevity and final Mac SSH proof. Do not roll back to rejected Chisel/frp policy modes.

## Success Criteria

- [ ] Authorized rog-to-Mac SSH succeeds; unauthorized publication/SSH fails; reverse listener is loopback-only.
- [ ] `on` during outage returns promptly and automatically reconnects after endpoint recovery without another `on`.
- [ ] `off` before rog returns produces zero reconnects afterward.
- [ ] Read-only noninteractive status meets a documented finite deadline, distinguishes intent/process/relay/SSH evidence, and redacts secrets.
- [ ] Outages cause no boot/login blocking, repetitive errors, routing changes, or unrelated app failures; LAN SSH and `tun.glats.org`/linkctl remain functional.
