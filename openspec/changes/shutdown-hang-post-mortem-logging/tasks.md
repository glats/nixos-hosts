# Tasks: Shutdown Hang Post-Mortem Logging

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~90-120 net (4 files, 1 new) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Late shutdown hook, host isolation, and cleanup of old path | PR 1 | Single PR; keep diagnostics baseline untouched |

## Phase 1: Foundation

  - [x] 1.1 Create `modules/hardware/rog-poweroff-workaround.nix` with option `hardware.rog.poweroffWorkaround.enable` defaulting to `false`. Deliver the hook through `systemd.shutdownRamfs.contents."/etc/systemd/system-shutdown/rog-poweroff".source`, include `pkgs.kmod` in `systemd.shutdownRamfs.storePaths`, and keep every command `|| true` with no `set -e`. Verify hint: `nix eval .#nixosConfigurations.rog.config.hardware.rog.poweroffWorkaround.enable` should still be `false` until host wiring is added.
  - [x] 1.2 Put the hook script in the new module with absolute store paths for `rmmod` and `modprobe`, ordered ASUS WMI unloads, ACPI `_SI._SST`, and the `/run/shutdown-hook-ran` breadcrumb. Verify hint: read the module and confirm the hook is late-phase only, executable, and does not depend on PATH.

## Phase 2: Host isolation and cleanup

  - [x] 2.1 In `hosts/rog/default.nix`, import `../../modules/hardware/rog-poweroff-workaround.nix` and enable `hardware.rog.poweroffWorkaround.enable = true;`. Verify hint: `nix eval .#nixosConfigurations.rog.config.hardware.rog.poweroffWorkaround.enable` returns `true` after the change.
  - [x] 2.2 In `hosts/rog/default.nix`, set `services.asus-fan-control-custom.enable = false;` for rog only. Verify hint: `nix eval .#nixosConfigurations.rog.config.services.asus-fan-control-custom.enable` returns `false`, while other hosts keep the default.
  - [x] 2.3 In `modules/hardware/rog-shutdown.nix`, neutralize `systemd.services.rog-shutdown` so it is no longer part of the shutdown path. Prefer `enable = false;` inside the existing service definition and keep the file as an audit trail. Verify hint: `nix eval .#nixosConfigurations.rog.config.systemd.services.rog-shutdown.enable` returns `false`, and the service no longer wires into `poweroff.target` / `reboot.target` / `halt.target`.

## Phase 3: Baseline preservation and late-hook placement checks

  - [x] 3.1 Verify the diagnostics baseline stays intact: `shutdown-debug-capture`, `boot-settings.includeDiagLogging = true`, and persistent journal settings must remain unchanged. Verify hint: inspect the diff for only the iteration-2 hardware files and confirm no edits land in the baseline modules.
  - [x] 3.2 Verify the new hook is the late-phase path: `systemd.shutdownRamfs.contents` must deliver the script at `/etc/systemd/system-shutdown/rog-poweroff` inside the shutdown ramfs. Verify hint: confirm the module uses `systemd.shutdownRamfs.contents` rather than the older live-system shutdown symlink path.

## Phase 4: Verification

  - [x] 4.1 Run `nix flake check --no-build` and `format-nix`. Verify hint: both must be clean before any live testing.
 - [ ] 4.2 On rog, verify the host wiring and system graph after rebuild: the new hook file exists, `asus-fan-control` is absent, and `rog-shutdown` is absent. Verify hint: check `systemctl list-units --all` and the generated shutdown ramfs output.
 - [ ] 4.3 On rog, run the live shutdown test only after the above checks pass. Verify hint: `shutdown -h now` should power the machine off completely; if the hang persists, use the diagnostic capture to confirm whether `asus_nb_wmi` was unloaded.
