# Proposal: Migrate T14 Omarchy to Quattro v4

## Intent

Evolve `/home/glats/Project/omarchy-nix` as a breaking Quattro v4 line for `t14`. Replace the v3 multi-daemon desktop with Quickshell without moving global nixpkgs 26.05, required by Intel `mact2`.

## Scope

### In Scope
- Establish a coherent newer t14-only nixpkgs/Home Manager boundary; Quickshell MUST use it.
- Adapt portable runtime in the v4 fork: Quickshell, Lua Hyprland, NetworkManager, theme, and PAM.
- Retain t14-only hardware, VNC, Edge, HDM, SOPS, and network policy here with staged, reversible validation.

### Out of Scope
- A new Omarchy repository, a global nixpkgs/Home Manager upgrade, or any mact2 change.
- Arch-only Quattro tooling and unselected application/plugin parity.
- Implementing the migration in this proposal phase.

## Capabilities

### New Capabilities
- `t14-quattro-desktop-integration`: Isolated t14 integration of the omarchy-nix Quattro v4 desktop and its compatible package boundary.

### Modified Capabilities
None.

## Approach

Keep portable runtime in `omarchy-nix`; this flake supplies the isolated t14 package/HM boundary and host policy. Stage boundary evaluation, v4 integration, and policy validation. Retain v3 input/configuration and a known-good generation until Quickshell, PAM, networking, themes, VNC, HDM, and Edge are accepted.

Host scope: `t14` only; the global flake contract remains unchanged for `rog`, `thinkcentre`, and `mact2`.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `flake.nix`, `lib/mkHost.nix` | Modified | Isolate t14 package/HM and v4 wiring. |
| `hosts/t14/default.nix`, `hosts/t14/omarchy-config.nix` | Modified | Preserve host policy while adapting v4 options. |
| `hosts/t14/home/default.nix` | Modified | Consume the matching t14 package set. |
| `/home/glats/Project/omarchy-nix` | Modified | Breaking v4 portable Quattro runtime and modules. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Mixed package sets cause ABI/module mismatch | Medium | Treat nixpkgs, Home Manager, and Quickshell as one boundary. |
| Quickshell migration loses desktop services | High | Stage and smoke-test each replacement before removing v3 services. |
| PAM, NetworkManager, theme, or Lua regressions block login | Medium | Retain v3 configuration and a known-good generation. |

## Rollback Plan

Revert t14 wiring and omarchy-nix v4 commits, select v3 input/configuration, and boot or switch to the retained generation. Do not alter global 26.05 or mact2.

## Dependencies

- Quattro v4 portable NixOS/Home Manager adaptations in `/home/glats/Project/omarchy-nix`.
- A compatible newer t14 nixpkgs/Home Manager/Quickshell set.

## Success Criteria

- [ ] `mact2` remains evaluated from global nixpkgs 26.05 while t14 uses a coherent newer boundary when required.
- [ ] t14 runs Quattro through Quickshell with migrated Lua, NetworkManager, theme, and PAM behavior.
- [ ] t14-only VNC, Edge, HDM, SOPS, hardware, and network policy remain local and pass acceptance checks.
- [ ] A tested v3/generation rollback exists; unrelated working-tree changes remain untouched.
