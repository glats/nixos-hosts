# Design: Shutdown Hang Post-Mortem Logging

## Technical Approach

Add a systemd oneshot service that snapshots diagnostic state to `/var/log/shutdown-debug/{boot-id}/` at end of shutdown. Fix the ACPI S5 service ordering so it fires AFTER other services stop. Add journald persistence so kernel/dmesg survive reboot, and an opt-in `includeDiagLogging` kernel param flag. All changes are additive and reversible.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Import `shutdown-debug.nix` in `hosts/rog/default.nix` vs `profiles/base.nix` | Base import affects thinkcentre | Host-level import (rog only) |
| `services.journald.extraConfig` vs `systemd.settings` | extraConfig is simpler, enough for 3 lines | `extraConfig` (jed config is NOT a [Manager] section setting) |
| `requiredBy` replacing `before` for rog-shutdown | `before` fires ACPI S5 too early (before services stop); `requiredBy` pulls service in as a hard dep when target activates | `requiredBy = [ poweroff reboot halt ]` — no `before` needed |
| Append diag kernel params vs conditional `loglevel=3` removal | Append is simpler; kernel uses last value | Append `loglevel=7` after static `loglevel=3` (last wins) |
| Cleanup via `find -mtime +7` inline vs logrotate | No external config needed; directories are self-cleaning | Inline find in diagnostic script |

## Data Flow

```
shutdown.target activated
  │
  ├─ shutdown-debug-capture.service (wantedBy shutdown.target)
  │   ├─ after: local-fs.target, systemd-journald.service
  │   ├─ Type=oneshot, RemainAfterExit=yes
  │   └─ ExecStart: create /var/log/shutdown-debug/{boot_id}/
  │        ├─ journalctl -b         → journalctl-b.txt
  │        ├─ dmesg                 → dmesg.txt
  │        ├─ pstree -ap            → pstree.txt
  │        ├─ ps auxf               → ps.txt
  │        ├─ lsmod                 → lsmod.txt
  │        ├─ mount, df -h          → mount.txt, df.txt
  │        ├─ lsof +L1              → lsof.txt
  │        ├─ /proc/cmdline         → cmdline.txt
  │        ├─ /proc/acpi/wakeup     → acpi-wakeup.txt
  │        ├─ sensors               → sensors.txt
  │        ├─ nvidia-smi (if exist) → nvidia-smi.txt
  │        ├─ find -mtime +7        → cleanup old dirs
  │        └─ sync                  → flush to disk
  │
  ├─ rog-shutdown.service (requiredBy poweroff/reboot/halt)
  │   ├─ TimeoutStopSec=10
  │   └─ ExecStart: sync && echo _SI._SST > /proc/acpi/call
  │
  └─ systemd-shutdown → poweroff
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `modules/base/shutdown-debug.nix` | **Create** | Oneshot diagnostic capture service: `shutdown-debug-capture` with `defaultDependencies=false`, `Type=oneshot`, `RemainAfterExit=yes`, `wantedBy=[shutdown.target]`, `after=[local-fs.target systemd-journald.service]`. Adds `pkgs.lsof`. |
| `modules/base/shutdown-fix.nix` | **Modify** | Add `services.journald.extraConfig` block: `Storage=persistent`, `SystemMaxUse=500M`, `MaxRetentionSec=2week`. Existing watchdog-disable config untouched. |
| `modules/features/boot.nix` | **Modify** | New `boot-settings.includeDiagLogging` option (bool, default `false`). When true, appends `loglevel=7`, `systemd.log_level=debug`, `systemd.log_target=console` to `kernelParams`. |
| `modules/hardware/rog-shutdown.nix` | **Modify** | Remove `before=[poweroff.target]`. Add `requiredBy=[poweroff.target reboot.target halt.target]`. Add `TimeoutStartSec=0`, `TimeoutStopSec=10` to `serviceConfig`. `sync && echo` script retained. |
| `hosts/rog/default.nix` | **Modify** | Import `../../modules/base/shutdown-debug.nix`. Set `boot-settings.includeDiagLogging = true`. |

## NixOS Option Paths

| Option | Value | Module |
|--------|-------|--------|
| `services.journald.extraConfig` | `"Storage=persistent\nSystemMaxUse=500M\nMaxRetentionSec=2week"` | `shutdown-fix.nix` |
| `systemd.services.shutdown-debug-capture` | (service def, see File Changes) | `shutdown-debug.nix` |
| `systemd.services.rog-shutdown.requiredBy` | `[poweroff.target reboot.target halt.target]` | `rog-shutdown.nix` |
| `boot-settings.includeDiagLogging` | `true` (rog), `false` (default) | `boot.nix` |
| `boot.kernelParams` | +`loglevel=7 systemd.log_level=debug systemd.log_target=console` (when diag on) | `boot.nix` |
| `environment.systemPackages` | `[pkgs.lsof]` | `shutdown-debug.nix` |

## Module Dependency Chain

```
hosts/rog/default.nix
 ├── modules/base/shutdown-debug.nix      ← NEW import
 ├── modules/hardware/rog-shutdown.nix    ← MODIFIED (ordering fix)
 └── modules/profiles/server.nix
      └── modules/profiles/base.nix
           ├── modules/base/shutdown-fix.nix   ← MODIFIED (+journald)
           └── modules/features/boot.nix       ← MODIFIED (+option)
```

`shutdown-debug.nix` and `rog-shutdown.nix` are independent — no cross-reference needed. `shutdown-fix.nix` is always imported but journald persistence is benign for all hosts.

## Filesystem Layout

```
/var/log/shutdown-debug/
├── {boot-id-1}/          # Created by ExecStart, owned root:root, mode 0755
│   ├── journalctl-b.txt
│   ├── dmesg.txt
│   └── ... (11-12 files)
└── {boot-id-2}/
```

- Boot ID obtained via `/proc/sys/kernel/random/boot_id`
- Cleanup: `find ... -mtime +7 -exec rm -rf {} \;` runs each capture (self-cleaning)
- No logrotate config needed

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Build | All hosts evaluate | `nix flake check --no-build` |
| Format | All `.nix` files | `format-nix` |
| Integration | rog rebuild succeeds | `nixos-rebuild dry-activate` on rog |
| Behavioral | Directory populated after shutdown | Reboot rog, check `/var/log/shutdown-debug/` has ≥8 files |
| Behavioral | Journal persists | `journalctl --list-boots` shows ≥2 boots |
| Regression | thinkcentre unaffected | `nix flake check` includes thinkcentre; no journald errors |

## Open Questions

None.
