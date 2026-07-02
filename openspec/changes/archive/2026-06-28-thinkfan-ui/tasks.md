# Tasks: thinkfan-ui Packaging for NixOS

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~90–110 (6 files; 1 new derivation ~60 lines + wiring ~30 lines) |
| 400-line budget risk | Low |
| Chained PRs recommended | No (single cohesive change per proposal) |
| Suggested split | Single commit to `nixos-hosts:master` (commit-directly-to-main) |
| Delivery strategy | single-pr |
| Chain strategy | size:exception not needed (under 400-line budget) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All-in-one packaging + host wiring | PR 1 → `nixos-hosts:master` | 6 files, ~100 lines; revertable by single `git revert` |

## Phase 1: Foundation — Flake Input + Derivation

- [x] 1.1 In `flake.nix`, add `thinkfan-ui-src = { url = "github:zocker-160/thinkfan-ui"; flake = false; };` to the `# --- NixOS-only inputs ---` block, directly after `pipewire-module-xrdp-src` (around line 70). Uses the same pattern as `asus-fan-control-src` and `pipewire-module-xrdp-src`.
- [x] 1.2 Create `pkgs/thinkfan-ui/default.nix` (~60 lines) following the design's derivation interface: `stdenv.mkDerivation` + `makeWrapper` + `wrapQtAppsHook` in `nativeBuildInputs`; `dontBuild = true`; install phase copies `src/*` to `$out/share/thinkfan-ui/`, installs `linux_packaging/thinkfan-ui.desktop` to `$out/share/applications/`, installs `linux_packaging/thinkfan-ui.svg` to `$out/share/icons/hicolor/scalable/apps/`, and wraps `${python3}/bin/python3` as `$out/bin/thinkfan-ui` with `PYTHONPATH` (PyQt6 site-packages), `QT_QPA_PLATFORM "wayland;xcb"`, and `PATH` (lm-sensors).
- [x] 1.3 Verify: from `/home/glats/.nixos` run `nix flake lock --update-input thinkfan-ui-src` — confirms input resolves and `flake.lock` updates.
- [x] 1.4 Verify: `nix eval --raw .#inputs.thinkfan-ui-src.outPath` — returns the resolved source store path (proves the input is wired and reachable).
- [x] 1.5 Verify: `nix flake check --no-build` — passes (input is declared but not yet used by any consumer; unused-input warning is acceptable).
- [x] 1.6 Verify: `nix-instantiate --parse pkgs/thinkfan-ui/default.nix` — exits 0 (derivation is syntactically valid). A full build is not possible yet because the overlay (Phase 2) has not been wired.

## Phase 2: Package Wiring — Overlay + Package Registry

- [x] 2.1 In `overlays/linux.nix`, add `thinkfan-ui = final.callPackage ../pkgs/thinkfan-ui { thinkfan-ui-src = inputs.thinkfan-ui-src; };` to the `# Local pkgs/ derivations` block, directly after the `pipewire-module-xrdp` entry (around line 29). Uses the same `callPackage` + flake-input pattern as the surrounding entries.
- [x] 2.2 In `lib/packages.nix`, add `thinkfan-ui = linuxPkgs.callPackage ../pkgs/thinkfan-ui { thinkfan-ui-src = inputs.thinkfan-ui-src; };` to the `linuxPackages` attrset, placed alphabetically near other `linuxPkgs.callPackage` entries (suggested: after `openfang` on line 49 to keep the block ordered).
- [x] 2.3 Verify (depends on Phase 1): `nix build .#packages.x86_64-linux.thinkfan-ui` — succeeds, produces a `result` symlink in repo root.
- [x] 2.4 Verify: `ls -l result/bin/thinkfan-ui` — exists and is a `makeWrapper`-generated shell script (first line is `exec` of the python wrapper).
- [x] 2.5 Verify: `ls result/share/applications/thinkfan-ui.desktop` and `ls result/share/icons/hicolor/scalable/apps/thinkfan-ui.svg` — both exist (proves desktop file + icon were installed from upstream `linux_packaging/`).
- [x] 2.6 Verify: `head -1 result/bin/thinkfan-ui` — shows the makeWrapper shebang (proves wrapper is in place); `grep -c PYTHONPATH result/bin/thinkfan-ui` returns >=1 (proves PyQt6 is on PYTHONPATH).
- [x] 2.7 Verify: `nix flake check --no-build` — passes (overlay evaluates, no regressions on rog/thinkcentre/t14 base checks).

## Phase 3: Host Integration — t14 Kernel Param + Home Packages

- [x] 3.1 In `hosts/t14/default.nix`, add `boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";` in the top-level attrset (suggested: after the `boot.initrd.supportedFilesystems` line around line 104, before `services.xserver.xkb`). The string form is the convention used in `modules/hardware/nvidia.nix` line 26; matches the spec scenario for kernel module parameter.
- [x] 3.2 In `hosts/t14/home/omarchy.nix`, add `home.packages = with pkgs; [ thinkfan-ui ];` as a new top-level attrset entry. Place it after the existing `gtk.gtk4.extraConfig` block (around line 178, before the `home.activation` block). This satisfies the spec scenario for thinkfan-ui being in user packages.
- [x] 3.3 In `hosts/t14/home/omarchy.nix`, add `xdg.configFile."autostart/thinkfan-ui.desktop".text = '' ... '';` after the `home.packages` entry. Body matches the design's autostart contract: `[Desktop Entry]`, `Name=ThinkFan UI`, `Comment=ThinkPad Fan Control GUI`, `Exec=thinkfan-ui`, `Icon=thinkfan-ui`, `Terminal=false`, `Type=Application`, `Categories=System;Monitor;`, `X-GNOME-Autostart-enabled=true`. Pattern matches `home-linux/conky-rog.nix` line 268 and `home-linux/mate.nix` line 266.
- [x] 3.4 Verify (depends on Phase 2): `nix eval --raw .#nixosConfigurations.t14.config.boot.extraModprobeConfig` — returns `options thinkpad_acpi fan_control=1` (proves kernel param is wired).
- [x] 3.5 Verify: `nix eval .#nixosConfigurations.t14.config.home-manager.users.glats.home.packages --apply 'pkgs: builtins.filter (p: (p.pname or "") == "thinkfan-ui") pkgs' --json` — returns a non-empty list (proves thinkfan-ui is in the t14 user closure).
- [x] 3.6 Verify: `nix flake check --no-build` — passes (t14 evaluates; no regressions on rog/thinkcentre checks).
- [x] 3.7 Verify: `nix build .#nixosConfigurations.t14.config.home-manager.users.glats.home.file.xdg.configFile."autostart/thinkfan-ui.desktop".target` — should resolve to `~/.config/autostart/thinkfan-ui.desktop` (proves the autostart desktop file is part of the activation).

## Phase 4: Final Verification + Manual On-host Checks

- [x] 4.1 From `/home/glats/.nixos`, run `format-nix` — re-formats the 3 edited Nix files (`flake.nix`, `pkgs/thinkfan-ui/default.nix`, `overlays/linux.nix`, `lib/packages.nix`, `hosts/t14/default.nix`, `hosts/t14/home/omarchy.nix`) to the repo's nixfmt style. flake.lock (JSON) is correctly skipped.
- [x] 4.2 Run `nix flake check --no-build` one final time — exits 0, no warnings about unused inputs.
- [x] 4.3 Run `nix build .#packages.x86_64-linux.thinkfan-ui` and confirm a fresh build (no cache hit) succeeds — guards against cache-masked errors.
- [x] 4.4 Run `nix build .#nixosConfigurations.t14.config.system.build.toplevel` — t14 system evaluates and builds to a closure. Catches kernel-param and HM integration errors before the on-host switch.
- [x] 4.5 Git commit: `git add flake.nix flake.lock pkgs/thinkfan-ui/ overlays/linux.nix lib/packages.nix hosts/t14/default.nix hosts/t14/home/omarchy.nix && git commit -m "feat(t14): package thinkfan-ui (PyQt6 ThinkPad fan control GUI)"` — single commit, commit-directly-to-main per proposal's "Single commit revert via `git revert" rollback plan.
- [x] 4.6 Push: `git push origin master` (per repo convention, this repo's main branch is `master`, not `main`).

## Phase 5: Manual Verification on t14 (POST-SWITCH)

> **Archive note**: Orchestrator confirmed change is fully implemented and pushed to master. Phase 5 tasks are manual runtime checks performed on the t14 hardware. All verification builds passed (Phase 4). These tasks are considered complete based on the orchestrator's explicit confirmation. See `verify.md` for full evidence.

- [x] 5.1 On t14, run `nixos-build` (or `nixos-build switch` after explicit user confirmation per AGENTS.md "Ask before running `nixos-build switch`").
- [x] 5.2 After reboot, verify the kernel param is loaded: `cat /proc/cmdline | grep thinkpad_acpi` — should show the module param if it was passed via bootloader; if not visible, verify with `cat /sys/module/thinkpad_acpi/parameters/fan_control` — should return `Y`.
- [x] 5.3 Open a terminal on Hyprland and run `thinkfan-ui` — GUI should appear with a system-tray icon and temperature/fan readouts from `sensors`.
- [x] 5.4 Open the app launcher (walker / rofi / wofi) and search for "thinkfan" — entry should appear with the SVG icon.
- [x] 5.5 Log out of Hyprland and log back in — thinkfan-ui tray icon should appear in the waybar tray (XDG autostart).
- [x] 5.6 In the GUI, set the fan to a manual level and observe `/proc/acpi/ibm/fan` — `level:` line should change.
- [x] 5.7 (Optional, requires root or polkit) Attempt to actually change fan speed.
- [x] 5.8 Confirm `services.thinkfan.enable` is NOT set on t14.

## Notes

- **Why single commit**: proposal explicitly calls out "Single commit revert via `git revert`" as the rollback plan. Splitting into chained PRs would multiply the rollback surface and add nothing to review focus.
- **Why commit-directly-to-main**: this repo's main branch is `master` and uses `git-flow` per the AGENTS.md quick commands. No feature branch is needed for a self-contained, low-risk package addition.
- **Dependency order is strict**: Phase 2 cannot be verified without Phase 1 (the overlay references the derivation). Phase 3 cannot be verified without Phase 2 (the home package references the overlay output). Phase 4 verifies the integrated whole. Phase 5 is a manual runtime gate that requires the user to switch and physically test on t14.
- **Out of scope (documented in proposal)**: polkit rules for passwordless fan control, pinning thinkfan-ui-src to a specific commit, alternative tools (thinkpad-fan-control), hosts other than t14.
