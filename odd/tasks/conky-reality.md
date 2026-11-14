# Conky reflects reality

Objective: make conky show the real hardware state and the desktop environment actually running, for every host that enables it.
Branch: `feat/conky-reality`. Delivery: `ask-on-risk`. Test runner: `nix eval` per host plus `nix flake check --no-build`; no Go tests touched.

## Specs

S1. On thinkcentre, conky shows the real machine: CPU temperature from the available hardware sensor, one storage row per real filesystem, and a numeric install-days value. It must not show a filesystem that does not exist, and must not show the same filesystem twice under two names.

S2. Conky shows the desktop environment currently running, resolved at runtime, not at build time. MATE, KDE, GNOME and Hyprland are recognized; switching the session changes the displayed value without rebuilding the host.

S3. Every host that enables conky shares one implementation. Host differences come from the `conky-config` options (`enable`, `networkInterface`, `additionalInterfaces`, `mountPoints`). No interface name or mount point is hardcoded in the module.

S4. Existing behavior is preserved: network interface name, IP, SSID, up/down speed, top processes, IO line, NixOS logo, colors and three-column layout.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S3 | inline | done | 163d70fa |
| T2 | S1 | inline | done | 163d70fa |
| T3 | S2 | inline | done | 163d70fa |
| T4 | S3, S4 | inline | done | 163d70fa |
| T5 | S1-S4 | inline | done | 163d70fa |

## Log

L1: "conky para thinkcentre no refleja la realidad."

L2: "si. ahora para rog y todos los demas que usen conky. quiero que tengan el desktop que se esta usando. aveces es mate, otro veces es kde. que eso quede reflajado. vamos con odd caveman"

L3 Evidence, thinkcentre live: `/proc/acpi/thermal_zone` absent, so `${acpitemp}` renders 0; coretemp `/sys/class/hwmon/hwmon1/temp1_input` reports 54000. No `fan*` channel exists in any hwmon (nvme, coretemp, iwlwifi), so Fan is always `n/a`. Intel iGPU exposes no hwmon, so GPU is always `n/a`. `/home` is not a separate filesystem (same `nvme0n1p3` xfs as `/`), so root and home duplicate 208G/458G; `/mnt/maqui-backup` (`sdb1`, 117G) is not shown. `conky-install-days` exits 1 and prints nothing because `set -euo pipefail` aborts on `find /var/log`, which exits 1 on unreadable directories.

L4 Evidence, architecture: `linux/home/conky-thinkcentre.nix` and `linux/home/conky-rog.nix` are 10.1K/10.4K near-duplicates that never read the `conkyConfig` special arg, so `hosts/*/conky-config.nix` is dead configuration. The two files differ only in the hardcoded interface name and the mount rows.

L5 Evidence, runtime desktop: this session reports `XDG_CURRENT_DESKTOP=KDE`; `hosts/thinkcentre/default.nix` sets `my.desktop.suite = null` and runs KDE through XRDP. `hosts/rog/default.nix` sets `my.desktop.suite = "mate"`. A build-time value cannot follow the session.

L6 Implementation: `linux/home/conky.nix` replaces both host modules. Storage, network and top-process columns are generated from `conkyConfig` and zipped into lines, so any mount count renders. `conky-cpu-temp` reads the coretemp/x86_pkg_temp/k10temp hwmon channel and falls back to thermal zones. `conky-desktop` reads `XDG_CURRENT_DESKTOP`/`DESKTOP_SESSION` and falls back to process detection. `conky-install-days` no longer aborts on `find` failure. Standalone `homeConfigurations` now receive `conkyConfig` from the host file in `flake.nix`, because the home module is shared with the NixOS-integrated path.

L7 Evidence, observed: `conky-cpu-temp` = 61°C, `conky-install-days` = 371, `conky-desktop` = `KDE Plasma` and, with `XDG_CURRENT_DESKTOP` set, `MATE`/`KDE Plasma`/`GNOME`/`Hyprland`. `conky-gpu-temps` and `conky-fan-speed` report `n/a`, which matches the hardware. thinkcentre storage column now lists `/`, `/boot` and `/mnt/maqui-backup`; rog lists `/`, `/home`, `/run/media/library`, `/run/media/stuff`.

L8 Evidence, gates: `nix eval .#homeConfigurations.thinkcentre.activationPackage.drvPath` ok, `nix eval .#homeConfigurations.rog.activationPackage.drvPath` ok, both `nixosConfigurations` toplevels evaluate, `nix flake check --no-build` prints `all checks passed!`.

L9 Note: `hosts/samsung/default.nix` imports the conky options module but never enables conky, and has no conky home module. It stays out of scope until the host actually runs conky.
