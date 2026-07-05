# Proposal: t14 SMB Network Visibility

## Intent

Make the SMB share at `smb://172.16.0.5:445/public` (hosted by `rog`) visible in GNOME Files Network browsing on the `t14` laptop without requiring the user to manually enter the IP address.

## Scope

### In Scope

- Adding Avahi service file to publish `_smb._tcp` service records on `rog`
- Any NixOS module changes needed on `rog` to declare the service file declaratively
- Verification that the share appears in GNOME Files on `t14`

### Out of Scope

- Installing `samba` or `smbclient` packages on `t14`
- NetBIOS discovery via wsdd/nmbd on `t14`
- Changes to `t14`'s avahi or gvfs configuration (already correct)
- Firewall changes (both hosts have firewall disabled)
- Samba configuration changes on `rog` (already correct)

## Capabilities

After this change, the system SHALL:

1. Publish a `_smb._tcp` DNS-SD service record on `rog` advertising the SMB share
2. Allow GNOME Files on `t14` to discover `rog`'s SMB share under Network via mDNS/DNS-SD
3. Require no manual address entry by the user on `t14`
4. Require no additional packages on `t14`

## Approach

**Recommended: Approach A — Publish `_smb._tcp` via Avahi on rog**

Avahi is already running on `rog` with `publish.enable = true` and `publish.addresses = true`. The only missing piece is a service file that announces SMB services.

We will add a `services.avahi.publish.userServices` entry (or `services.avahi.extraServiceFiles`) in `hosts/rog/services/samba.nix` to publish `_smb._tcp` pointing to `rog`'s hostname on port 445. This is a single-file, single-add change with no new dependencies.

Rejected alternatives:
- **Approach B** (install samba client on t14): Adds ~200MB of packages for a marginal NetBIOS fallback that is not needed when DNS-SD works.
- **Approach C** (both): Unnecessary given Approach A is sufficient.

## Affected Areas

| Area | File | Change |
|------|------|--------|
| rog samba service config | `hosts/rog/services/samba.nix` | Add `avahi.publish.userServices` block for `_smb._tcp` |

No other files need modification. The Avahi module (`modules/networking/avahi.nix`) already provides `publish.enable = true`, so the service file will be picked up automatically.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Service type wrong preventing discovery | Low | Medium | Test with `avahi-browse -a` on t14 after applying |
| Port conflicts if another service starts on 445 | Very Low | Low | Samba already binds port 445 exclusively |
| Regression on Avahi publishing | Low | Low | Service file is additive; removing it restores original state |

## Rollback Plan

1. Remove the `avahi.publish.userServices` block from `hosts/rog/services/samba.nix`
2. Run `nixos-build` on `rog`
3. Verify via `systemctl status avahi-daemon` that no errors appear
4. Confirm with `avahi-browse -a` (or equivalent) that `_smb._tcp` is no longer advertised

Rollback is trivial and low-risk — a single line removal and rebuild.

## Dependencies

- `rog` must be on the same network segment as `t14` (172.16.0.0/24) — already true
- mDNS traffic must not be blocked by firewall — both hosts have `networking.firewall.enable = false`
- Avahi must be running on `rog` with publish enabled — already true

## Acceptance Criteria

1. **After deploying the change on rog** — `avahi-browse -a` on `t14` (or `rog` itself) shows a `_smb._tcp` service
2. **GNOME Files on t14** — opening "Network" (or "Other Locations") shows `rog` or the share name without any manual IP entry
3. **Connection works** — clicking the discovered share in GNOME Files mounts and lists the `public` directory contents
