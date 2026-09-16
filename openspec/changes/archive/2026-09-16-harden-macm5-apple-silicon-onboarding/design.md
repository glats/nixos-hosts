# Design: Harden macm5 Apple Silicon Onboarding

## Technical Approach

Keep Determinate Nix as the sole Nix owner on `macm5`: `nix.enable = false`; all daemon, cache substituter, and trusted-key settings flow through `determinateNix.customSettings`. Stage an independently revocable `uuid_macm5` on both endpoints, activate and prove the Apple Silicon host natively, then make one declarative retirement change for `mact2`. The existing `tunnel-device-onboarding` and TLS-tunnel requirements remain the routing authority.

The Darwin builder receives a logical `configName`, separate from physical
macOS naming. The macm5 host declares the primary account as `juan` while the
GitHub identity remains the explicit `jcuzmar` value. No macm5 module declares
`networking.hostName`, so the managed LocalHostName stays
`CLFTCLGV2FHWW0W`. On Darwin, `nixos-build` resolves `macm5` by default and
accepts `NIXOS_DARWIN_HOST` only as an explicit override.

## Architecture Decisions

| Decision | Choice | Alternative | Rationale |
|---|---|---|---|
| Nix ownership | Determinate plus `customSettings` | Enable nix-darwin Nix | The installed Determinate module owns the daemon and generated `nix.conf`; `nix.settings` is inactive with `nix.enable = false`. |
| Credential lifecycle | Add `uuid_macm5`, then remove `uuid_mact2` only after evidence | Reuse or immediately replace mact2 UUID | Distinct scalar runtime secrets permit independent revocation and prevent ambiguous server identity. |
| Retirement gate | Native macm5 acceptance record precedes every mact2 deletion | Linux evaluation or mact2 fallback | Only the Apple Silicon machine proves APFS, daemon, launchd, Home Manager, Homebrew, and routing. |
| Recovery | Git reference plus known-good macm5 generation | Reactivate mact2 | Recovery stays on the new host and cannot undo retirement safety. |

## Data Flow

```text
sops ciphertext -> root 0400 runtime UUID -> macm5 sing-box LaunchDaemon
rog sops declaration -> sing-box VLESS user -> TLS/WS private link -> route rules
Determinate customSettings -> nix.custom.conf -> Nix daemon/cache
```

The macm5 client retains `full` as default: private IPs, configured CIDRs, configured domains, and best-effort named security processes are direct; the final outbound is the existing direct-safe `urltest` group. `launchd.daemons.sing-box` remains root-owned, manual-start, non-restarting, and reads only the rendered root-`0400` configuration.

## File Changes

| File | Action | Description |
|---|---|---|
| `darwin/system/nix.nix`, `darwin/system/cachix.nix`, `shared/cachix.nix` | Modify | Merge Darwin cache settings into Determinate custom settings without changing Linux `nix.settings`. |
| `darwin/system/sing-box-link.nix` | Modify | Consume only `uuid_macm5`; retain routing and LaunchDaemon contract. |
| `hosts/rog/secrets.nix`, `linux/system/services/network/sing-box-link.nix`, `.sops.yaml`, `secrets/shared/link-uuids.yaml` | Modify | Stage macm5 recipient/key/user, then remove mact2 recipient/key/user after acceptance; never commit plaintext. |
| `flake.nix`, `hosts/mact2/default.nix`, `linux/home/{remote-desktop,ssh}.nix`, `darwin/home/remote-desktop.nix` | Modify/Delete | Remove mact2 configurations, host directory, and stale access targets after the gate. |
| `docs/{macm5-migration,sops-new-host,home-link}.md` | Modify | Replace obsolete instructions with activation evidence, retirement order, and recovery. |
| `pkgs/nixos-scripts/{cmd/nixos-build,internal/nixbuild}` | Modify | Resolve the stable Darwin logical selector with a tested explicit override. |
| `darwin/home/{shell,git}.nix`, `hosts/macm5/default.nix` | Modify | Use `primaryUser` for profiles, configure `juan`, preserve independent `jcuzmar` identity, and avoid hostname override. |

## Interfaces / Contracts

```nix
nix.enable = false;
determinateNix.customSettings = { substituters = [ ... ]; trusted-public-keys = [ ... ]; };
link.mode = "full"; # enum: "full" | "scoped", default "full"
link.directDomains = [ ]; # list of domain suffixes, direct
link.directCidrs = [ ];   # list of CIDRs, direct
```

No public `link.*` option changes: macm5 inherits this interface. The breaking migration is secret identity only: add the macm5 SOPS recipient and `uuid_macm5`, deploy rog and macm5, prove it, then remove `uuid_mact2`, mact2 recipient records, declarations, and server user in the same retirement slice. Roll back pre-retirement with Git and the known-good macm5 generation; if retirement has begun, restore the last accepted macm5 Git state/generation and its macm5 UUID record, never mact2.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Evaluation | Determinate ownership, cache settings, macm5 configuration | RED: assertions fail while caches remain only in `nix.settings` or client selects mact2; then `format-nix` and `nix flake check --no-build`. |
| Service | Rendered config, permissions, launchd, routing | RED: pre-change inspection expects absent macm5 user/secret; native proof runs `sing-box check`, `launchctl print`, verifies root/`0400`, direct LAN/EDR and default egress. |
| Lifecycle | Isolated connection and revocation | RED: macm5 handshake cannot authenticate before staged UUID; after gate, mact2 handshake fails while macm5 remains healthy. |

## Threat Matrix

| Boundary | Applicability | Design response and RED-test intent |
|---|---|---|
| Documentation-like paths | N/A — no executable-file classification changes. | — |
| Git repository selection | N/A — rollback instructions name the checked-out repository but add no selector or automation. | — |
| Commit state | N/A — no commit automation. | — |
| Push state | N/A — no push automation. | — |
| PR commands | N/A — no PR automation. | — |

Process integration is applicable outside these VCS rows: RED inspection must show no root LaunchDaemon/config before activation; success requires the declared root `sing-box` job and safe direct-default behavior, while APFS mount or daemon-socket failure stops activation and blocks retirement.

## Migration / Rollout

1. Add macm5 SOPS access and credential, server user, Determinate cache wiring, and runbook; evaluate before touching mact2.
2. On a fresh Determinate-only macm5, prove `/nix`, daemon socket/PATH, Home Manager, arm64 Homebrew, SSH/Screen Sharing, wsdd, launchd, and private-link routing; record evidence and known-good generation.
3. Only on accepted evidence, remove mact2 identity, host/configuration, and remote entries. Retain 26.05 pins and defer channel/platform-output cleanup to a separate change.

## Open Questions

- [ ] What durable location and approval format records native acceptance evidence before the retirement commit?
