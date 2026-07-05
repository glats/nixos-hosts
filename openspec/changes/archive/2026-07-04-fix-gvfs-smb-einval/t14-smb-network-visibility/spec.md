# Spec: t14 SMB Network Visibility

**Change**: Make the SMB share at `smb://172.16.0.5:445/public` (hosted by `rog`) visible in GNOME Files Network browsing on `t14` via DNS-SD.

**Domain**: rog-samba

---

## ADDED Requirements

### REQ-SMB-VIS-001: SMB service advertisement via Avahi DNS-SD on rog

The system MUST publish an `_smb._tcp` DNS-SD service record on `rog` via Avahi, advertising the SMB share on port 445.

**Rationale**: GNOME Files discovers network shares via mDNS/DNS-SD (Avahi). Without the service record, the share is invisible in the Network browsing UI even though it is reachable via direct IP.

**Scenarios**:

- **Happy path — Share appears in GNOME Files after Avahi restart**
  Given the Avahi service file for `_smb._tcp` has been deployed on `rog`
  When the avahi-daemon is restarted (`sudo systemctl restart avahi-daemon`)
  Then `avahi-browse _smb._tcp -r` from any host on the LAN MUST return the service record with hostname and port 445.

- **Verification — DNS-SD record is published correctly**
  Given `rog` is running Avahi with the new service file
  When running `avahi-browse _smb._tcp -r` on `t14` (or `rog` itself)
  Then the output MUST include a service of type `_smb._tcp` with hostname matching `rog` and port 445
  And the TXT record SHOULD include key-value pairs describing the share (e.g., `path=/public`).

- **Rollback — Removing the block restores original state**
  Given the `avahi.publish.userServices` block has been removed from `hosts/rog/services/samba.nix`
  When `nixos-build` is run on `rog`
  Then `avahi-browse _smb._tcp -r` MUST NOT show the SMB service from `rog`
  And `systemctl status avahi-daemon` MUST report no errors.

- **Edge case — Direct SMB access remains functional**
  Given the Avahi service file is deployed on `rog`
  When a user connects to `smb://172.16.0.5:445/public` directly (bypassing Network discovery)
  Then the connection MUST succeed and list the `public` directory contents
  (The DNS-SD advertisement is additive and MUST NOT alter the underlying Samba service behavior.)

### REQ-SMB-VIS-002: GNOME Files Network discovery on t14

The `t14` host MUST be able to discover `rog`'s SMB share in GNOME Files "Other Locations" -> "Networks" without manual IP entry.

**Rationale**: This is the end-user visible outcome of the change. If the share does not appear in GNOME Files, the change is incomplete.

**Scenarios**:

- **Happy path — Share visible in GNOME Files**
  Given the `_smb._tcp` service record is published by `rog`
  And `t14` has avahi-daemon running and gvfs with SMB support
  When a user opens GNOME Files and navigates to "Other Locations"
  Then the "Networks" section MUST display an entry for `rog`'s SMB share
  And clicking the entry SHOULD mount and list the `public` directory contents.

- **Edge case — No change to t14 configuration**
  Given `t14` has no new packages installed and no NixOS module changes
  When the user opens GNOME Files "Other Locations"
  Then the share MUST still be discoverable and accessible
  (This verifies the change is purely on `rog` and requires zero setup on `t14`.)

### REQ-SMB-VIS-003: Additive, non-disruptive integration

The change MUST be strictly additive to `hosts/rog/services/samba.nix` and MUST NOT modify any existing Samba configuration, firewall rules, or Avahi settings.

**Rationale**: The existing Samba service on `rog` is stable and serves multiple shares. The DNS-SD advertisement is a metadata layer that should not alter Samba behavior, port bindings, or security posture.

**Scenarios**:

- **Verification — Existing SMB access still works**
  Given the Avahi service file has been deployed
  When a user accesses any SMB share on `rog` via direct IP (`smb://172.16.0.5/share_name`)
  Then the existing shares MUST be accessible with the same credentials and permissions as before.

- **Verification — Avahi configuration unchanged**
  Given the change has been deployed
  When inspecting `services.avahi` configuration on `rog` via `nixos-option services.avahi`
  Then `publish.enable` MUST still be `true` (unchanged)
  And `publish.addresses` MUST still be `true` (unchanged)
  And only the `userServices` list MUST have the new `_smb._tcp` entry added.

### REQ-SMB-VIS-004: Single-host deployment

The change SHALL be deployed solely on `rog`. No files on `t14` (or any other host) SHALL be modified.

**Rationale**: Keeping the change scoped to `rog` minimizes risk and deployment surface. `t14` already has Avahi and gvfs configured for DNS-SD discovery — it only needs a publisher on the network.

**Scenarios**:

- **Verification — No t14 changes**
  Given the change is deployed on `rog`
  When running `git diff --stat` on the repository
  Then the only changed file SHALL be `hosts/rog/services/samba.nix` (or equivalent rog-specific path).

---

## Out of Scope

The following are explicitly out of scope for this change:

| Item | Reasoning |
|------|-----------|
| Installing `samba` or `smbclient` package on `t14` | Not needed — DNS-SD + gvfs is sufficient |
| Changing firewall rules | Both hosts have `networking.firewall.enable = false` |
| Changing Samba internal config (`smb.conf` options) | Samba config is already correct |
| NetBIOS/wsdd changes | DNS-SD/Avahi is the modern approach and sufficient |
| Adding packages to any host | No new packages required |

---

## Verification Steps

1. **Deploy on rog**: Build and switch on `rog`: `nixos-build`
2. **Restart Avahi**: `sudo systemctl restart avahi-daemon` on `rog`
3. **Verify DNS-SD record**: From any LAN host, run `avahi-browse _smb._tcp -r` — MUST show `rog` on port 445
4. **Verify GNOME Files**: On `t14`, open GNOME Files > "Other Locations" — the share MUST appear under "Networks"
5. **Verify direct access**: `smb://172.16.0.5:445/public` MUST still work
6. **Rollback test**: Remove the Avahi block, rebuild on `rog`, confirm `avahi-browse _smb._tcp -r` no longer shows the service

---

## Review Workload Estimation

**Decision needed before apply**: No
**Chained PRs recommended**: No
**400-line budget risk**: Low — expected change is fewer than 20 lines in a single file.
