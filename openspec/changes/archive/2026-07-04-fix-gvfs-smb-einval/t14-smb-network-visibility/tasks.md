# Tasks: t14 SMB Network Visibility

**Change**: Add Avahi DNS-SD `_smb._tcp` service advertisement to `rog` so the SMB share is visible in GNOME Files on `t14`.

**Delivery strategy**: single-pr | **400-line budget risk**: Low (~10 lines)

---

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Estimated lines changed | ~10 (additions only) |
| Files modified | 1 (`hosts/rog/services/samba.nix`) |
| PR budget (400 lines) | Well within budget |
| Decision needed before apply | No |
| Chained PRs recommended | No |
| 400-line budget risk | Low |

---

## Task Breakdown

### T-1: Add Avahi service file for `_smb._tcp` to samba.nix

**Description**: Append `services.avahi.extraServiceFiles` block to `hosts/rog/services/samba.nix` after the `services.samba-wsdd` block (line 37) and before `systemd.tmpfiles.rules` (line 39). The block defines an XML service advertisement for `_smb._tcp` on port 445 with TXT record `path=/public`.

**Files to modify**:
- `hosts/rog/services/samba.nix` — add `services.avahi.extraServiceFiles` attrset

**Exact code to add** (insert after line 37, before line 39):

```nix
  # DNS-SD service advertisement for SMB (mDNS/Linux discovery)
  services.avahi.extraServiceFiles = {
    smb = ''
      <?xml version="1.0" standalone='no'?'><!--*-nxml-*-->
      <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
      <service-group>
        <name replace-wildcards="yes">%h</name>
        <service>
          <type>_smb._tcp</type>
          <port>445</port>
          <txt-record>path=/public</txt-record>
        </service>
      </service-group>
    '';
  };
```

**Verification**: `nix flake check --no-build` passes (validates Nix syntax for all hosts). The only file changed is `hosts/rog/services/samba.nix` — no t14 changes.

**Dependencies**: None.

---

### T-2: Build rog configuration to verify compilation

**Description**: Build the rog NixOS configuration to confirm the new Avahi service file integrates correctly and the full system derivation compiles.

**Files to modify**: None (read-only verification).

**Verification**:
1. `nix build .#nixosConfigurations.rog.config.system.build.toplevel` succeeds
2. Optionally: `nixos-build` on rog, then `avahi-browse _smb._tcp -r` shows the service

**Dependencies**: T-1 must be complete.

---

## Dependency Graph

```
T-1 (add Avahi service file)  -->  T-2 (build rog to verify)
```

Sequential: T-2 depends on T-1.

---

## Acceptance Criteria (mapped to spec requirements)

| Requirement | Task | How verified |
|-------------|------|-------------|
| REQ-SMB-VIS-001 (DNS-SD advertisement) | T-1 | `nix flake check --no-build` passes; `avahi-browse _smb._tcp -r` shows service after deploy |
| REQ-SMB-VIS-002 (GNOME Files discovery) | T-2 (post-deploy) | Open GNOME Files on t14, check "Other Locations" > "Networks" |
| REQ-SMB-VIS-003 (additive, non-disruptive) | T-1 | Only `extraServiceFiles` added; no existing blocks modified |
| REQ-SMB-VIS-004 (single-host) | T-1 | `git diff --stat` shows only `hosts/rog/services/samba.nix` |
