# Design: t14 SMB Network Visibility

**Change**: Make the SMB share at `smb://172.16.0.5:445/public` (hosted by `rog`) visible in GNOME Files Network browsing on `t14` via DNS-SD (Avahi).

**Delivery strategy**: single-pr | 400-line budget risk: Low (~10 lines)

---

## 1. Architecture Overview

### How the pieces fit together

```
rog (server)                              t14 (client)
┌─────────────────────────┐               ┌──────────────────────────┐
│ Samba (port 445)        │               │ GNOME Files (nautilus)   │
│   /run/media/stuff/samba│               │   Network browser        │
│                         │               │     ↓ gvfs ↓             │
│ Avahi Daemon            │  mDNS/DNS-SD  │   Avahi Daemon           │
│   _smb._tcp service ────┼───────────────┼──→ DNS-SD resolver       │
│   publish.enable=true   │  multicast    │   nssmdns4=true          │
│   extraServiceFiles:    │  224.0.0.251  │   browseDomains=["local"]│
│     smb.service (XML)   │  UDP 5353     │                          │
└─────────────────────────┘               └──────────────────────────┘
```

**Flow**:

1. `rog`'s Avahi reads the `.service` file from `/etc/avahi/services/smb.service` (installed via `services.avahi.extraServiceFiles`)
2. Avahi broadcasts a DNS-SD record `_smb._tcp` on the LAN via mDNS multicast (UDP 5353, 224.0.0.251)
3. `t14`'s Avahi (nssmdns4 enabled) receives the multicast and resolves the service
4. `t14`'s gvfs queries Avahi for `_smb._tcp` services via D-Bus
5. GNOME Files ("Other Locations" > "Networks") displays the discovered share
6. User clicks the share → gvfs mounts it via SMB protocol

**Key insight**: Both hosts already run Avahi with publishing and discovery enabled. The missing piece is the service *declaration* on `rog` — a single XML file telling Avahi to announce `_smb._tcp`. No changes are needed on `t14`; it already listens for DNS-SD services.

---

## 2. Implementation Plan

### 2.1 Exact Nix code to add

Append the following block to `hosts/rog/services/samba.nix`, after the `services.samba-wsdd` block and before the `systemd.tmpfiles.rules` block (grouped with network discovery services):

```nix
  # DNS-SD service advertisement for SMB (mDNS/Linux discovery)
  services.avahi.extraServiceFiles = {
    smb = ''
      <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
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

### 2.2 Where in the file it goes

Insert between line 37 (end of `services.samba-wsdd` block) and line 39 (start of `systemd.tmpfiles.rules` block). The resulting file structure:

```
Line  1:  { config, pkgs, ... }:
Line  2:
Line  3:  {
Line  4:    # Samba server                    ← existing
Line  5:    services.samba = { ... };
Line  6:
Line  7:    # Network discovery for Windows    ← existing
Line  8:    services.samba-wsdd = { ... };
Line  9:
Line 10:    # DNS-SD service advertisement     ← NEW
Line 11:    services.avahi.extraServiceFiles = { ... };
Line 12:
Line 13:    # Ensure directory exists          ← existing
Line 14:    systemd.tmpfiles.rules = [ ... ];
Line 15:  }
```

### 2.3 How to validate

1. `nix flake check --no-build` — validates the Nix expression compiles (must exit 0)
2. `nix build .#nixosConfigurations.rog.config.system.build.toplevel` — builds the rog config without switching (optional, for early verification)
3. `format-nix` — ensures formatting is correct before committing

### 2.4 Service file that gets generated

After `nixos-build` applies the change, the file `/etc/avahi/services/smb.service` will contain:

```xml
<?xml version="1.0" standalone='no'?><!--*-nxml-*-->
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
    <txt-record>path=/public</txt-record>
  </service>
</service-group>
```

The `%h` wildcard expands to `rog` (the hostname). The TXT record `path=/public` provides the share name to clients that read TXT data (gvfs uses this to auto-populate the share path).

---

## 3. Configuration Details

### 3.1 Option decision: `extraServiceFiles` vs `userServices`

| Option | Type | Behavior |
|--------|------|----------|
| `services.avahi.publish.userServices` | **boolean** | Enables/disables publishing of user-level services (`~/.config/avahi/services/`). Does NOT accept service definitions. |
| `services.avahi.extraServiceFiles` | **attrset of (string or path)** | Installs raw XML `.service` files to `/etc/avahi/services/`. Accepts inline XML strings or paths to `.service` files. |

**Decision**: Use `services.avahi.extraServiceFiles`.

**Rationale**: `extraServiceFiles` is the only option that accepts actual service definitions. `userServices` is a boolean toggle for user-level services, not a structured way to define services. The NixOS option documentation even includes `_smb._tcp` as its example.

### 3.2 Service attributes

| Attribute | Value | Notes |
|-----------|-------|-------|
| Service name | `%h` (hostname wildcard, resolves to `rog`) | Replaces wildcard with hostname automatically |
| Service type | `_smb._tcp` | Standard DNS-SD service type for SMB/CIFS |
| Port | `445` | Samba's Direct-hosted SMB port |
| Hostname | Implicit (Avahi uses the machine hostname) | No explicit `<host-name>` needed — leaving it out tells clients to use the responding host's address |
| TXT record | `path=/public` | Advertises the share name; gvfs may use this to pre-fill the mount path |

### 3.3 Requirements met

| Requirement | How it is satisfied |
|-------------|-------------------|
| REQ-SMB-VIS-001 | `extraServiceFiles` publishes `_smb._tcp` on port 445 |
| REQ-SMB-VIS-002 | DNS-SD record visible to `t14`'s gvfs via Avahi |
| REQ-SMB-VIS-003 | Change is additive only — no existing config is modified |
| REQ-SMB-VIS-004 | Only `hosts/rog/services/samba.nix` is changed |

---

## 4. Verification Procedure

### 4.1 After deployment on rog

**Step 1 — Check the service file exists**:
```bash
ls -la /etc/avahi/services/smb.service
cat /etc/avahi/services/smb.service
```

**Step 2 — Restart Avahi (optional, Avahi watches for changes)**:
```bash
sudo systemctl restart avahi-daemon
```

**Step 3 — Verify DNS-SD record from rog itself**:
```bash
avahi-browse _smb._tcp -r
```
Expected output includes: service type `_smb._tcp`, hostname `rog`, port `445`.

**Step 4 — Verify from t14 (or any LAN host)**:
```bash
avahi-browse _smb._tcp -r
```
Same as above — the record must appear across the network.

**Step 5 — Verify in GNOME Files on t14**:
- Open GNOME Files
- Click "Other Locations"
- Under "Networks", the `rog` SMB share should appear
- Click it — should mount and show contents of `public`

**Step 6 — Verify direct IP access still works**:
```bash
smbclient -N //172.16.0.5/public -c ls
```

### 4.2 How to rollback

1. Remove the `services.avahi.extraServiceFiles` block from `hosts/rog/services/samba.nix`
2. Run `nixos-build` on `rog`
3. Verify:
   - `systemctl status avahi-daemon` — no errors
   - `/etc/avahi/services/smb.service` no longer exists
   - `avahi-browse _smb._tcp -r` no longer shows the SMB service
   - SMB via direct IP still works (unchanged)

---

## 5. Impact Analysis

### 5.1 Hosts affected

| Host | Impact |
|------|--------|
| **rog** | Single file changed; Avahi config augmented with one additional service file. No service restarts or downtime. |
| **t14** | Zero changes. Receives the new DNS-SD multicast and displays the share in GNOME Files automatically. |
| **thinkcentre** | Zero changes. Will also see the `_smb._tcp` advertisement but has no GNOME Files/gvfs running (headless). No impact. |
| **mact2** | Zero changes. macOS has its own mDNS (Bonjour) and may also discover the share in Finder, but no config changes needed. |

### 5.2 Coordination needed

**None**. This is a single-host change on `rog`. There is no cross-host dependency during deployment — the DNS-SD advertisement is purely additive and other hosts will discover it organically after Avahi picks up the new service file.

### 5.3 Risk assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| XML syntax error in service file | Low | Service file not loaded, no service published | `nix flake check` catches Nix syntax; Avahi logs errors to journal |
| Port 445 conflicts | Very low | Samba already holds port 445 exclusively | Samba starts before Avahi on boot |
| Avahi crash due to malformed XML | Very low | Avahi skips malformed files gracefully | Avahi validates XML on read; logs error, continues serving other services |
| Regression on existing Avahi publishing | None | Extra file is additive; existing config unchanged | Verified by Step 3 in rollback plan |
| GNOME Files still doesn't show share | Low | gvfs may need restart | `systemctl --user restart gvfs-daemon` on t14 |

### 5.4 No changes to other services

This design does not touch:
- `services.samba` (Samba server config)
- `services.samba-wsdd` (WS-Discovery)
- `services.avahi.publish.enable` or `publish.addresses` (already set in `modules/networking/avahi.nix`)
- Firewall rules (both hosts have firewall disabled)
- Any t14 or thinkcentre configuration

---

## 6. Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Service definition format | Raw XML via `extraServiceFiles` | NixOS does not provide a structured Nix API for Avahi service definitions. The `extraServiceFiles` option is the canonical approach. |
| Service name | `%h` (hostname wildcard) | Shows the hostname (`rog`) in the network browser, which is clear and accurate. |
| TXT record | `path=/public` | Provides the share name as service metadata. gvfs may use this for auto-configuration on mount. Not strictly required, but helpful. |
| Placement in file | After `samba-wsdd` | Groups network-discovery-related services together (wsdd for Windows, Avahi DNS-SD for Linux). Logical reading order. |
| Single file change | `hosts/rog/services/samba.nix` | The avahi module is already imported. NixOS merges options across all modules, so setting `services.avahi.extraServiceFiles` from any module file works. |

---

## 7. Open Questions

None. All design decisions are resolved by the existing codebase patterns and NixOS option availability.
