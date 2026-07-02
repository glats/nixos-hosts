# Proposal: Shutdown Hang Post-Mortem Logging

## Intent

The user's ASUS ROG laptop (host `rog`) hangs after Linux appears to shut down — OS claims poweroff but the laptop stays powered on. Two existing workarounds (`modules/base/shutdown-fix.nix` watchdog disable, `modules/hardware/rog-shutdown.nix` ACPI `\_SI._SST` S5 hack) have a service-ordering bug and **zero diagnostic capture**: kernel `loglevel=3`, volatile journald, S5 call fires too early. This change adds post-mortem logging and fixes the ordering bug.

## Scope

### In Scope
- New `modules/base/shutdown-debug.nix`: oneshot at end of shutdown capturing journalctl + dmesg + ps/pstree + mounts + lsof +L1 + nvidia-smi + ACPI wakeup + sensors to `/var/log/shutdown-debug/{boot-id}/`.
- Journald persistence in `shutdown-fix.nix`; new `boot-settings.includeDiagLogging` option (off by default).
- Fix `rog-shutdown.nix` ordering: drop `before=[poweroff.target]`, use `requiredBy` of all three targets, add timeouts.
- Wire new module into `hosts/rog/default.nix`.

### Out of Scope
- Replacing the ACPI S5 hack (need working path first, then evidence).
- Off-host log upload; `thinkcentre` changes (no hang observed).
- Touching the existing watchdog disable (still correct).

## Capabilities

### New Capabilities
- `shutdown-debug-capture`: systemd oneshot that snapshots diagnostic state to disk before poweroff/reboot/halt, persists across reboots.

### Modified Capabilities
None — `boot-settings` only adds a new opt-in option.

## Approach

1. **`modules/base/shutdown-debug.nix`** (new) — `systemd.services.shutdown-debug-capture` with `defaultDependencies=false`, `Type=oneshot`, `RemainAfterExit=yes`, `WantedBy=[shutdown.target]`, `after=[local-fs.target systemd-journald.service]`. `ExecStart` creates `/var/log/shutdown-debug/$(< /proc/sys/kernel/random/boot_id)/` and runs each diagnostic (`|| true`, `sync` between writes): `journalctl -b`, `dmesg`, `pstree -ap`, `ps auxf`, `lsmod`, `mount`, `df -h`, `lsof +L1`, `nvidia-smi` (if present), `/proc/cmdline`, `/proc/acpi/wakeup`, `sensors`. Adds `pkgs.lsof`.

2. **`shutdown-fix.nix`** — add `services.journald.config` block.

3. **`boot.nix`** — add `includeDiagLogging` option + conditional kernel params.

4. **`rog-shutdown.nix`** — `requiredBy` of all three targets; add `TimeoutStartSec=0`, `TimeoutStopSec=10`.

5. **`hosts/rog/default.nix`** — import new module; enable `boot-settings.includeDiagLogging`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `modules/base/shutdown-debug.nix` | New | Diagnostic capture service |
| `modules/base/shutdown-fix.nix` | Modified | +journald persistence |
| `modules/features/boot.nix` | Modified | +`includeDiagLogging` option |
| `modules/hardware/rog-shutdown.nix` | Modified | Fix service ordering |
| `hosts/rog/default.nix` | Modified | Import new module |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Capture service itself hangs | Med | `TimeoutStartSec=0` + `TimeoutStopSec=10`; every cmd `\|\| true` |
| High loglevel breaks Plymouth | Med | `includeDiagLogging` opt-in, off for thinkcentre |
| Journald fills disk | Low | `SystemMaxUse=500M` + `MaxRetentionSec=2week` |
| S5 fix regresses shutdown | Med | Single-file revert; `sync` retained; call runs LAST |
| `lsof` not in minimal profile | Low | Add `pkgs.lsof` in new module |

## Rollback Plan

`git revert` the merge commit. All changes additive except the S5 ordering fix (1 file, easy revert). Removing the new module import is one line. No migrations.

## Dependencies

None. `pkgs.lsof`, `nvidia-smi` in nixpkgs. No flake changes.

## Success Criteria

- [ ] `nix flake check --no-build` + `format-nix` clean; rebuild succeeds on rog
- [ ] `/var/log/shutdown-debug/<boot-id>/` has ≥8 files on next shutdown (≥5 on forced hang)
- [ ] `rog-shutdown.service` ordered after `systemd-shutdown.service`
- [ ] Journal survives reboot (`journalctl --list-boots` shows multiple)
