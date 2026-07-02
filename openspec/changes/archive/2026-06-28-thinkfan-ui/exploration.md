# SDD Explore: thinkfan-gui configuration for NixOS

**Change**: thinkfan-gui
**Project**: nixos-hosts
**Date**: 2026-06-28
**Mode**: engram (artifact mirrored to filesystem for hybrid persistence)

## 1. Current State

### Target host
**t14** — ThinkPad T14 AMD Gen 4, running Omarchy (Hyprland) on NixOS unstable. This is the only ThinkPad in the fleet (rog is desktop+nvidia, thinkcentre is headless, mact2 is macOS). The t14 is the only host that would use a ThinkPad fan GUI.

### Existing t14 hardware wiring (`/home/glats/.nixos/`)
- `hosts/t14/default.nix` — host entry. Imports `modules/hardware/amd-laptop.nix`, `modules/hardware/keyring.nix`, and the omarchy-nix + nixos-hardware T14 modules via `flake.nix` `extraModules`.
- `modules/hardware/amd-laptop.nix` — minimal AMD baseline (microcode, graphics, fwupd, power-profiles-daemon, zramSwap). **No `thinkpad_acpi` config, no `thinkfan` enable, no modprobe options for fan control.**
- `modules/base/polkit.nix` — grants `wheel` group full polkit access (no extra work needed for the GUI to call polkit).
- `hosts/t14/home/omarchy.nix` — HM entry; packages added at HM level (e.g. user-level apps).
- `lib/packages.nix` + `overlays/linux.nix` — single source of truth for what appears in `nix build .#<name>` and `pkgs` for Linux hosts. Custom packages follow the same `pkgs/<name>/default.nix` + flake input + overlay pattern (see `asus-fan-control` as the closest precedent — Rust-style `stdenv.mkDerivation` with `makeWrapper`).

### Existing custom-package pattern (asus-fan-control — closest precedent)
1. `flake.nix` — flake input `asus-fan-control-src = { url = "github:dominiksalvet/asus-fan-control"; flake = false; };`
2. `pkgs/asus-fan-control/default.nix` — `stdenv.mkDerivation` with `src = asus-fan-control-src;`, `makeWrapper` to fix PATH, installs binary + systemd unit + bash completion.
3. `overlays/linux.nix` — `asus-fan-control = final.callPackage ../pkgs/asus-fan-control { asus-fan-control-src = inputs.asus-fan-control-src; };`
4. `lib/packages.nix` — exposes it on `linuxPackages` (so `nix build .#asus-fan-control` works).
5. `modules/hardware/asus-fan-control.nix` — tiny NixOS module `services.asus-fan-control-custom.enable` that wires a systemd oneshot.
6. `hosts/rog/default.nix` — imports the module.

**thinkfan-ui is different in one key way**: it's a *user-level GUI*, not a daemon. So instead of (or in addition to) a NixOS module, it would primarily be wired in via `home.packages` in `hosts/t14/home/omarchy.nix`.

## 2. What thinkfan-gui actually is

The user's "thinkfan-gui" maps to the AUR package **`thinkfan-ui`** (`https://aur.archlinux.org/packages/thinkfan-ui`, source `https://github.com/zocker-160/thinkfan-ui`). It is **not** a frontend for the `thinkfan` daemon — it is a standalone GUI.

| Field | Value |
|---|---|
| Upstream | https://github.com/zocker-160/thinkfan-ui (156 stars, master, last release `1.0.2` 2026-01-12) |
| License | GPL-3.0-only |
| Language | Python (3.x) — only dep is `PyQt6` (`requirements.txt` is literally one line) |
| Runtime helpers | A 2-line bash shim `linux_packaging/thinkfan-ui` that calls `python3 /opt/thinkfan-ui/main.py "$@"` |
| What it controls | `thinkpad_acpi` kernel module fan interface, via direct writes to `/proc/acpi/ibm/fan` (the same interface `thinkfan` itself uses) |
| What it reads | CPU temperature via `sensors` command (lm-sensors), fan RPM and level from `/proc/acpi/ibm/fan` |
| Privileges | It calls `pkexec`/polkit when it needs to write to `/proc/acpi/ibm/fan` (graphical prompt); no systemd integration |
| CLI flags | `--no-tray`, `--hide` |
| Desktop file | Ships `linux_packaging/thinkfan-ui.desktop` (Categories=Utility) + `thinkfan-ui.svg` icon |
| modprobe config | `linux_packaging/thinkpad_acpi.conf`: `options thinkpad_acpi fan_control=1` (one line) |
| Source layout | `src/main.py` + `src/ui/*.py` + `src/QSingleApplication.py` (no `setup.py`/`pyproject.toml` — it's a loose script tree, NOT a Python package) |

**Two related but different repos exist**:
- `darchap/thinkfan-gui` (0 stars, 2024) — different person, never took off. **Not** what the user wants.
- `Swmarakis/thinkpad-fan-control` (newer, 2026-05) — has its own daemon + GUI. Wayland-friendly. The user did not mention this; it's a 2026 newcomer. **Mention as alternative but not the focus** — `thinkfan-ui` is what the user named.

## 3. What already exists in nixpkgs for thinkfan / fan control

| Thing | Status in nixpkgs unstable |
|---|---|
| `pkgs.thinkfan` (v2.0.0, the C++ daemon) | **Present** — `Simple, lightweight fan control program` |
| `services.thinkfan` NixOS module | **Present** with 14 options: `enable`, `settings`, `extraArgs`, `smartSupport`, `fans`, `sensors`, `levels`, etc. The module writes `boot.extraModprobeConfig = "options thinkpad_acpi experimental=1 fan_control=1";` automatically when enabled. |
| `hardware.fancontrol.enable` + `hardware.fancontrol.config` (lm-sensors pwmconfig) | **Present** (alternative for non-ThinkPad hwmon fans) |
| `pkgs.fancontrol-gui` (Qt5 KDE GUI for `fancontrol`, not for ThinkPad) | **Present** (v0.8) |
| `pkgs.nbfc-linux` (NoteBook FanControl) | **Present** (v0.3.19) |
| `pkgs.lm-sensors` (v3.6.2, `sensors` command) | **Present** |
| `python313Packages.pyqt6` (v6.9.0) | **Present** |
| `pkgs.thinkfan-ui` (the AUR GUI) | **Not in nixpkgs** — confirmed via nixos_nix package search and home-manager option search. No flake on FlakeHub either. |
| Any other ThinkPad-specific GUI in nixpkgs | None. |

### Important: thinkfan service vs thinkfan-ui GUI are mutually exclusive
Both `thinkfan` (the daemon) and `thinkfan-ui` (the GUI) write to the same `/proc/acpi/ibm/fan` file. **You cannot run both at once** — they will fight over fan level, and the daemon will override the GUI within its sampling interval (default 5s). The user must pick **one** approach. The NixOS `services.thinkfan` module sets `fan_control=1` automatically, but it also assumes the daemon is the sole writer. The user explicitly asked for a "GUI", so the natural fit is `thinkfan-ui` standalone.

## 4. Real-world NixOS thinkfan examples (from GitHub code search)

The pattern `services.thinkfan.enable = true; boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";` is universal across ~25+ public NixOS configs (daluca/nix-config, satler-git/dotfiles, caspervk/nixos, categorialcat/nixos, lucashuguet/nixconf, breuerfelix/nixos, danhab99/dotfiles, etc.). The `experimental=1` flag is sometimes included (enables some less-common sysfs attributes) but is **not required** for fan_control.

No public NixOS config in the search results currently uses thinkfan-ui packaged as a derivation — it would be a first.

## 5. The gap

| Need | Status | Notes |
|---|---|---|
| Kernel `thinkpad_acpi` module with `fan_control=1` | **Missing** | Needs `boot.extraModprobeConfig` on t14. (T14 AMD kernel should include thinkpad_acpi as a module; the nixos-hardware T14 profile doesn't touch it.) |
| `lm_sensors` for CPU temperature read | **Missing on t14** | Needed at runtime by thinkfan-ui. nixpkgs provides `pkgs.lm_sensors` (provides the `sensors` command). |
| `pkgs.thinkfan-ui` derivation | **Missing** | Need to write a `pkgs/thinkfan-ui/default.nix` that wraps the script with a `python3.withPackages (ps: [ ps.pyqt6 ])` interpreter, installs `linux_packaging/thinkfan-ui` (bash shim) + `main.py` + `ui/` + `QSingleApplication.py` + `.desktop` file + SVG icon. |
| `thinkfan-ui` flake input + overlay registration | **Missing** | Follow the asus-fan-control pattern in `flake.nix`, `overlays/linux.nix`, `lib/packages.nix`. |
| HM-level install on t14 (so the user can launch the GUI) | **Missing** | Add to `home.packages` in `hosts/t14/home/omarchy.nix` (or a new HM file under `hosts/t14/home/`). |
| Polkit permission for non-root writes to `/proc/acpi/ibm/fan` | **Already covered** | `modules/base/polkit.nix` grants `wheel` group polkit.Result.YES for all actions, so the GUI's `pkexec` call will succeed for any user in `wheel`. No extra rule needed. |
| `services.thinkfan` module | **Should NOT be enabled** | Adding it would conflict with thinkfan-ui. Leave `services.thinkfan.enable = false` (the nixpkgs default). |

## 6. Current repo patterns for adding custom packages

The repo has a well-established, repeatable pattern (used by `asus-fan-control`, `pipewire-module-xrdp`, `opencode`, `gentle-ai`, `engram`, `openfang`):

1. **Flake input** for the source in `flake.nix`:
   ```nix
   thinkfan-ui-src = {
     url = "github:zocker-160/thinkfan-ui";
     flake = false;
   };
   ```
2. **Derivation** at `pkgs/thinkfan-ui/default.nix` using `stdenv.mkDerivation` (or `python3Packages.buildPythonApplication` — but thinkfan-ui has no `setup.py`, so `mkDerivation` + `makeWrapper` is simpler, matching the asus-fan-control style).
3. **Overlay registration** in `overlays/linux.nix`:
   ```nix
   thinkfan-ui = final.callPackage ../pkgs/thinkfan-ui {
     thinkfan-ui-src = inputs.thinkfan-ui-src;
   };
   ```
4. **Package list** in `lib/packages.nix` (`linuxPackages` attrset) so `nix build .#thinkfan-ui` works.
5. **Optional NixOS module** at `modules/hardware/thinkfan-ui.nix` (probably NOT needed — see below).
6. **Host wiring**: thinkfan-ui is a user app, not a system service. So it should be wired in `home-manager` (`home.packages` in `hosts/t14/home/omarchy.nix`), and the modprobe option in `hosts/t14/default.nix` (or in `modules/hardware/amd-laptop.nix` since it's a ThinkPad hardware prerequisite — but t14 is the only ThinkPad, so host-local is fine).

## 7. Recommended approach

**Approach: package the standalone thinkfan-ui GUI and wire it as a user-level HM app on t14. Do NOT enable `services.thinkfan`.**

### Why this approach
- The user said "GUI" → that's thinkfan-ui, not thinkfan.
- thinkfan-ui and thinkfan cannot coexist (both write `/proc/acpi/ibm/fan`).
- thinkfan-ui is a single-file Python script with one runtime dep (PyQt6) and one runtime helper (`sensors`). Trivial to package.
- The repo already has a precedent (`asus-fan-control`) for a non-nixpkgs package via `pkgs/<name>/default.nix` + overlay.
- The polkit module is already configured to allow wheel users to run privileged operations — no extra rule needed.

### Why NOT the other approaches
- **`services.thinkfan` only** (no GUI) — the user explicitly wants a GUI.
- **Run thinkfan service + thinkfan-ui simultaneously** — race condition / conflict.
- **Upstream to nixpkgs** — out of scope; user wants local solution, not a PR. (Could be a future contribution.)
- **Just `nix run` from the upstream repo** — works, but bypasses the repo's reproducibility story and `nix build .#<name>` interface that this repo commits to.
- **Use `Swmarakis/thinkpad-fan-control` instead** — newer (2026-05), Wayland-friendly with a separate daemon + GUI design. Tempting, but the user named "thinkfan-gui" and the AUR reference is to `thinkfan-ui`. Worth mentioning as a future option if the user is unhappy with zocker-160's project.

### Implementation sketch (proposal phase will refine)
**New / changed files** (estimated 8 files, ~250–350 lines total — well under the 400-line PR review budget, single PR recommended):

| Path | Purpose | Est. lines |
|---|---|---|
| `flake.nix` | Add `thinkfan-ui-src` flake input | ~4 |
| `pkgs/thinkfan-ui/default.nix` | New derivation: `stdenv.mkDerivation` with `makeWrapper` to bind `python3.withPackages [ps.pyqt6]`, install `src/`, `linux_packaging/thinkfan-ui` (patched for `$out` path), `.desktop`, icon | ~80 |
| `overlays/linux.nix` | Register `thinkfan-ui` in the linux overlay | ~4 |
| `lib/packages.nix` | Expose `thinkfan-ui` on `linuxPackages` | ~2 |
| `hosts/t14/default.nix` | Add `boot.extraModprobeConfig = "options thinkpad_acpi fan_control=1";` (one line) + ensure `thinkpad_acpi` is in `boot.initrd.availableKernelModules` or `boot.kernelModules` | ~3 |
| `hosts/t14/home/omarchy.nix` | Add `home.packages = [ pkgs.thinkfan-ui ];` (or extract to `hosts/t14/home/thinkfan-ui.nix` for tidiness) | ~5 |
| `modules/hardware/thinkfan-ui.nix` (optional) | New module: `services.thinkfan-ui.enable` that just adds the HM package + the modprobe option. Convenient if we ever want to enable thinkfan-ui on another ThinkPad host (none currently). Optional for v1. | ~25 |

**NO new NixOS service module is strictly required** — the GUI is launched manually by the user (no systemd integration; thinkfan-ui doesn't ship a systemd unit). So `modules/hardware/thinkfan-ui.nix` is optional. The host-level wiring in `hosts/t14/default.nix` + `hosts/t14/home/omarchy.nix` is enough.

### Verification plan
- `nix flake check --no-build` — validates flake parses.
- `nix build .#thinkfan-ui` — package builds.
- `nixos-rebuild build` on t14 — evaluates without error.
- After `nixos-rebuild switch` + reboot: `cat /proc/acpi/ibm/fan` should show `commands: level <N>` writability for the user; `thinkfan-ui` should appear in app launcher; `sensors` should output CPU temps.

## 8. Risks

1. **Kernel module availability** — `thinkpad_acpi` is a Linux kernel module; need to verify it is included in the `zen` kernel that t14 uses (`modules/features/boot.nix`). It is upstream-standard, so almost certainly yes, but `hardware-configuration.nix` should be checked before relying on it. Risk: **Low**.
2. **AMD-specific quirks** — the T14 AMD Gen 4 is the target. The thinkpad_acpi module supports AMD ThinkPads, but the sensor names (hwmon paths) differ from Intel. thinkfan-ui's UI uses generic `sensors` parsing, so it should be fine, but the `/proc/acpi/ibm/fan` path is the same on AMD. Risk: **Low**.
3. **PyQt6 / Qt6 platform plugin on Wayland** — PyQt6 apps need `QT_QPA_PLATFORM=wayland` or `xcb` (via xwayland) to render on Hyprland. Most PyQt6 apps work on Wayland out of the box; if not, the user can override with an env var in the .desktop file. The upstream thinkfan-ui does not test on Wayland specifically. Risk: **Low–Medium** (mitigation: add `QT_QPA_PLATFORM=wayland;xcb` to the .desktop file's `Exec=` line if needed).
4. **Permission model** — thinkfan-ui uses polkit at runtime. The current `modules/base/polkit.nix` grants `wheel` blanket access, so this works. If we ever tighten polkit rules, this would break. Risk: **Low** (mitigation: a targeted polkit rule `org.freedesktop.policykit.exec` for the binary could replace the blanket one — not needed now).
5. **thinkfan-ui is mostly unmaintained** — last release Jan 2026, but 5 open issues, single maintainer (`zocker_160`). If the user wants long-term support, the `Swmarakis/thinkpad-fan-control` fork is a more actively developed alternative. Risk: **Low** (mitigation: package is small; a fork or local patch is feasible if upstream dies).
6. **No upstream nixpkgs package** — we own the maintenance. As with `asus-fan-control` (and `pipewire-module-xrdp`), this is acceptable and matches existing repo precedent. Risk: **Low**.

## 9. Affected areas

- `flake.nix` — add flake input
- `pkgs/thinkfan-ui/default.nix` — **NEW**
- `overlays/linux.nix` — register package
- `lib/packages.nix` — expose on `linuxPackages`
- `hosts/t14/default.nix` — `boot.extraModprobeConfig` for `thinkpad_acpi.fan_control=1`
- `hosts/t14/home/omarchy.nix` (or new `hosts/t14/home/thinkfan-ui.nix`) — `home.packages = [ pkgs.thinkfan-ui ]`
- (Optional) `modules/hardware/thinkfan-ui.nix` — shared NixOS module, no consumers in v1

## 10. Ready for proposal?

**Yes.** The exploration is complete:
- The AUR package is unambiguously `thinkfan-ui` (zocker-160/thinkfan-ui, PyQt6 Python).
- nixpkgs has thinkfan and the service module, but NOT the GUI. The gap is real and small.
- thinkfan-ui and thinkfan cannot coexist — the GUI is the right choice.
- The repo's packaging pattern is well established (asus-fan-control is a near-perfect precedent).
- The implementation is small (~250–350 lines, single PR, no chained-PR overhead).
- No external blockers. Optional follow-up: consider upstreaming the package to nixpkgs later.

### Orchestrator handoff
Next phase: `sdd-propose` for change `thinkfan-gui`. Scope: package thinkfan-ui, wire it on t14 (modprobe + HM), no `services.thinkfan` enable.
Delivery: single PR, direct commit to main (matches user's prior session preference of "commit directo a main, yo ejecuto nix-switch").
