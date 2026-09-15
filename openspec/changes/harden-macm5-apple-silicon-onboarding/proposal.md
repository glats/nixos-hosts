# Proposal: Harden macm5 Apple Silicon Onboarding

## Intent

Activate `aarch64-darwin` `macm5` with Determinate Nix, then declaratively retire handed-over `mact2`. Native Apple Silicon activation is release gate; mact2 is never a fallback, validation target, or rollback path.

## Scope

### In Scope
- Route daemon and Cachix settings through `determinateNix.customSettings`; retain `nix.enable = false`.
- Provision `uuid_macm5`, then revoke the mact2 identity and required rog/SOPS records.
- After native acceptance, remove mact2 configuration and stale remote-access declarations.
- Document activation, retirement, recovery, and Git/generation rollback.

### Out of Scope
- Using, retaining, or validating mact2 operationally.
- Package/channel migration or `flake.lock`/`nixpkgs`/`nix-darwin` upgrades, unless required for safe retirement.
- Unrelated Darwin, Linux, or private-link redesign.

## Capabilities

### New Capabilities
- `macm5-apple-silicon-onboarding`: Determinate-first native activation, recovery, and release evidence.
- `darwin-host-retirement`: Gate mact2's declarative removal on accepted macm5 activation.

### Modified Capabilities
- `tunnel-device-onboarding`: Replace mact2's VLESS identity with an independently revocable macm5 identity and revoke mact2 after the gate.

## Approach

Keep Determinate as Nix owner and consolidate daemon/cache settings in `determinateNix.customSettings`. Validate macm5 natively: fresh Determinate-only install, evaluation, `/nix`, services, PATH, Home Manager, arm64 Homebrew, remote access, wsdd, and direct-default routing. Only then remove mact2 entries, files, identity, rog user, SOPS records, and stale links. Stop for APFS or daemon-socket failure.

Host scope: macm5 and rog private-link/SOPS records; mact2 is removed after the gate.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `darwin/system/nix.nix`, `darwin/system/cachix.nix`, `shared/cachix.nix` | Modified | Determinate settings. |
| `darwin/system/sing-box-link.nix`, `linux/system/services/network/sing-box-link.nix`, `hosts/rog/secrets.nix`, `.sops.yaml`, `secrets/shared/link-uuids.yaml` | Modified | Identity cutover. |
| `flake.nix`, `hosts/mact2/default.nix`, `linux/home/remote-desktop.nix`, `linux/home/ssh.nix` | Modified/Removed | mact2 retirement. |
| `docs/macm5-migration.md`, `docs/sops-new-host.md`, `docs/home-link.md` | Modified | Gate and recovery. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Inactive daemon settings | Medium | Validate on native macm5. |
| APFS/daemon/PATH failure | Medium | Stop and recover before retirement. |
| Premature retirement | Medium | Enforce native evidence before deletion. |

## Rollback Plan

Retain a Git reference and known-good macm5 generation. On failure, restore repository state and that generation; restore its UUID/server record if needed. Never reactivate mact2.

## Dependencies

- Physical macm5, Xcode CLI tools, Determinate Nix, SOPS identity, and ciphertext-rotation authorization.
- Recorded native macm5 acceptance evidence before mact2 retirement.

## Success Criteria

- [ ] macm5 activates natively with Determinate Nix and no mixed installer state.
- [ ] Cache, arm64 Homebrew, Home Manager, remote access, wsdd, and direct-default link checks pass.
- [ ] macm5 has a runtime-only UUID; mact2 identity, configuration, and stale access entries are removed only after the gate.
- [ ] Recovery is proven from Git and a known-good macm5 generation; release evidence is recorded.
