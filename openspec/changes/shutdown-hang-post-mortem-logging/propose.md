# Proposal: Shutdown Hang — ASUS WMI Isolation + Late Shutdown Hook (Iteration 2)

## Intent

Host `rog` still hangs at poweroff after userspace shutdown completes. Iteration 1
proved that service teardown, filesystems, swap, Docker, network, and NVIDIA GPU
activity are all clean at hang time. The blocking point is now identified as the
firmware/ACPI S5 boundary, with ASUS WMI/ATKD errors (`\_SB.ATKD.WMNB` divide-by-
zero, `asus_wmi` fan-curve failures) as the primary software-level suspects. This
iteration shifts from diagnostic instrumentation to active remediation: isolate
ASUS WMI influence and replace the timing-incorrect `rog-shutdown.nix` service with
a true very-late shutdown hook that fires after `systemd-shutdown` hands off to the
kernel.

## What Changed from Iteration 1

| Item | Iteration 1 | Iteration 2 |
|------|-------------|-------------|
| Primary goal | Add diagnostics + fix service ordering | Remediate hang at ACPI/firmware boundary |
| `rog-shutdown.nix` role | Primary fix vehicle (too early) | Replaced by a hook that runs after `systemd-shutdown` |
| ASUS fan-control | Untouched | Add off switch; gate or disable before poweroff |
| Diagnostic baseline | Not present | Fully working; treat as read-only unless a minor addition adds real evidence |
| DSDT/SSDT override | Out of scope | Still out of scope — documented as explicit fallback only |
| Success criterion | Logs exist on disk | Machine actually powers off |

## Scope

### In Scope

- Add `services.asus-fan-control-custom.enable = false` on `rog` OR add a
  controlled shutdown-time disable path inside `asus-fan-control.nix` that
  unloads/resets ASUS EC state before poweroff. The goal is to test whether
  removing `asus-fan-control` influence at poweroff changes S5 behavior.
- Replace the current `rog-shutdown.nix` `shutdown.target`-era service with a
  `/usr/lib/systemd/system-shutdown/` hook script. This hook runs inside the
  `systemd-shutdown` initramfs-like pivot, after all mounts are gone and before
  the kernel issues the final poweroff syscall — the actual hang location.
- The new hook: optionally unload ASUS WMI modules (`asus_nb_wmi`, `asus_wmi`,
  `asus_armoury`, `acpi_call`) as a late cleanup step, then attempt the
  `_SI._SST` ACPI call fallback as before.
- Keep the existing `modules/base/shutdown-debug.nix` baseline intact. Add minor
  hook-breadcrumb evidence to `/run/shutdown-hook-ran` only if needed to prove
  the new hook executes.
- Update `hosts/rog/default.nix` to wire the new module and flip the fan-control
  experiment toggle.

### Out of Scope

- DSDT/SSDT custom override — documented as next fallback if this iteration fails.
- Touching `thinkcentre`, `t14`, or `mact2`.
- Rewriting the diagnostic capture service.
- Off-host log upload or remote collection.
- Watchdog disable (`shutdown-fix.nix`) — already in place and correct.

## Capabilities

### New Capabilities

- `rog-poweroff-hook`: a `/usr/lib/systemd/system-shutdown/` script that runs at
  the real end of shutdown (after `systemd-shutdown`, before kernel poweroff).
  Optionally unloads ASUS WMI modules, then fires the `_SI._SST` ACPI call.

### Modified Capabilities

- `asus-fan-control-custom.enable`: add an explicit host-level disable path so the
  service can be turned off on `rog` without removing the module from the codebase.
- `rog-shutdown.nix`: retire the `shutdown.target`-wired service once the new hook
  is confirmed to run, or reduce it to a no-op shim. The new hook supersedes it.

## Approach

1. **New file: `modules/hardware/rog-poweroff-workaround.nix`**
   - Installs a shell script to `${config.boot.kernelPackages}` store path via
     `systemd.shutdownRamfs.contents` (NixOS native path for late shutdown scripts)
     OR uses `environment.etc."systemd/system-shutdown/rog-poweroff"` depending on
     which NixOS option correctly places it under `/usr/lib/systemd/system-shutdown/`.
   - Script sequence: `rmmod asus_nb_wmi asus_armoury asus_wmi acpi_call 2>/dev/null || true`, then `modprobe acpi_call 2>/dev/null || true`, then `echo '\_SI._SST' > /proc/acpi/call 2>/dev/null || true`.
   - Gate behind a new option `hardware.rog.poweroffWorkaround.enable` (default `false`).
   - Research the correct NixOS option (`systemd.shutdownRamfs`) before writing.

2. **Modify `modules/hardware/asus-fan-control.nix`**
   - No behavior change for the default case.
   - When the service is disabled (`enable = false`), add an explicit
     `systemd.services.asus-fan-control.enable = false` guard so the unit is
     not just inactive but absent from the shutdown graph.

3. **Modify `hosts/rog/default.nix`**
   - Import `../../modules/hardware/rog-poweroff-workaround.nix`.
   - Set `hardware.rog.poweroffWorkaround.enable = true`.
   - Set `services.asus-fan-control-custom.enable = false` for the isolation test.

4. **Retire or reduce `modules/hardware/rog-shutdown.nix`**
   - Once the new hook is in place, either remove the `shutdown.target`-wired
     service (it fires too early to matter) or reduce it to a comment explaining
     the architecture shift.

5. **Verify**
   - `nix flake check --no-build` and `format-nix` clean.
   - Confirm the hook script lands in the correct path in the Nix store / etc overlay.
   - Test shutdown on `rog` and confirm the machine powers off.

## Affected Areas

| File | Action | Reason |
|------|--------|--------|
| `modules/hardware/rog-poweroff-workaround.nix` | Create | True late hook replacing the too-early service |
| `modules/hardware/rog-shutdown.nix` | Remove or reduce | Superseded by late hook |
| `modules/hardware/asus-fan-control.nix` | Modify | Add clean disable path |
| `hosts/rog/default.nix` | Modify | Wire new module, flip experiment toggles |
| `modules/base/shutdown-debug.nix` | Read-only | Baseline diagnostics stay as-is |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `systemd.shutdownRamfs` NixOS option path is wrong or not yet stable | Med | Research via `nixos_nix` MCP before writing; fall back to `environment.etc` path |
| ASUS WMI module unload causes kernel panic or hung task | Low-Med | `rmmod` wrapped with `|| true`; if unload fails, script continues to ACPI call |
| Disabling fan-control worsens thermals until confirmed | Low | Shutdown-only change; thermal risk is only during the few seconds before poweroff |
| Late hook script does not execute at the right phase | Low | `/usr/lib/systemd/system-shutdown/` is the documented systemd hook path; test with breadcrumb |
| DSDT firmware bug is deeper than module unload can fix | Med | This is acknowledged; if iteration 2 fails, DSDT override is the explicit next step |
| Removing `rog-shutdown.nix` breaks something unexpected | Low | Grep for all imports before removal; module is self-contained |

## Rollback Plan

- Revert `hosts/rog/default.nix` changes (one or two lines).
- Delete `rog-poweroff-workaround.nix`.
- Restore `rog-shutdown.nix` if removed (or it was never deleted — low-risk).
- Re-enable `asus-fan-control-custom` if disabled.
- `git revert` the commit if pushed.

All changes are additive or host-scoped. No shared module behavior changes.

## Dependencies

- `systemd.shutdownRamfs` NixOS option (needs verification before use).
- `pkgs.acpi_call` or `acpi_call` kernel module already loaded on `rog`.
- `pkgs.kmod` for `rmmod`/`modprobe` in the hook (or use full Nix store paths).
- No new flake inputs.

## DSDT Override — Explicit Fallback Statement

If disabling ASUS fan-control and the late hook both fail to stop the hang, the
next and final iteration will be a firmware-level workaround: `acpidump` on `rog`,
inspect `_PTS` / `\_SB.ATKD` / `\_SB.PCI0.LPCB.EC0` AML for the divide-by-zero
path, and ship a minimal SSDT override via `hardware.acpiTables`. This is
deliberately deferred until the cheaper software path is exhausted.

## Success Criteria

- [ ] `nix flake check --no-build` and `format-nix` pass for all hosts
- [ ] Hook script is present at `/usr/lib/systemd/system-shutdown/rog-poweroff`
      (or equivalent Nix store symlink path) after rebuild
- [ ] `rog` powers off completely after `shutdown -h now` (the primary bug)
- [ ] If hang still occurs: breadcrumb file `/run/shutdown-hook-ran` proves the
      hook at least executed, providing better fault isolation for iteration 3
- [ ] Fan-control service is absent from systemd unit graph on `rog` during the
      experiment
