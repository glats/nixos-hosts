## Verification Report

**Change**: regreeter-keyboard-layout
**Version**: N/A
**Mode**: Standard (Strict TDD inactive)
**Date**: 2026-07-15

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 11 |
| Tasks complete | 11 |
| Tasks incomplete | 0 |

### Build & Tests Execution

**omarchy-nix**: PASS

```
nix flake check --no-build  (in /home/glats/repos/omarchy-nix)
all checks passed!
```

**nixos-hosts**: BLOCKED (deployment sequencing issue, not implementation defect)

```
nix flake check --no-build  (in /home/glats/.nixos)
error: The option `omarchy.greeter.layoutIndicator' does not exist.
```

The t14 check fails because `flake.lock` resolves omarchy-nix to github:glats/omarchy-nix/main at commit `0e2439b` (2026-07-11), which predates the layoutIndicator changes. The local omarchy-nix repo has unpushed changes. A local path override confirmed t14 resolves correctly (documented in apply-progress). rog and thinkcentre checks pass (they don't use layoutIndicator).

**Coverage**: N/A (no test runner configured)

### Spec Compliance Matrix

All requirements verified via static code inspection (source exists in local repos; omarchy-nix changes not yet pushed to GitHub):

| Requirement | Scenario | Evidence | Result |
|-------------|----------|----------|--------|
| REQ-GLI-001 (P0) | Indicator visible on greeter startup | `system.nix:28-36` (layoutIndicatorScript), `system.nix:38-53` (waybarGreeterConfig with `custom/kb-layout`, `interval: 1`), `system.nix:324` (waybarExec), `system.nix:340-346` (environment.etc) | PASS |
| REQ-GLI-002 (P0) | Indicator updates after layout toggle | `system.nix:48` (`interval: 1` — worst case ~1s, well within the 2s requirement) | PASS |
| REQ-GLI-003 (P0) | Login form unaffected by indicator | `system.nix:40` (`layer: "bottom"`), `system.nix:42` (`height: 24`), `system.nix:327` (waybarExec before regreet exec-once, ReGreet centered) | PASS |
| REQ-GLI-004 (P1) | Submodule disabled by default | `config.nix:404` (`lib.mkEnableOption` — bool, default false) | PASS |
| REQ-GLI-004 (P1) | Submodule enabled on t14 | `t14/default.nix:237` (`layoutIndicator.enable = true`), `system.nix:323` (GTK_USE_PORTAL=0), `system.nix:324` (waybar exec-once), `system.nix:340-346` (environment.etc) | PASS |
| REQ-GLI-005 (P1) | Config at /etc/greetd/waybar-config | `system.nix:340-342` (`environment.etc."greetd/waybar-config".source`) | PASS |
| REQ-GLI-006 (P1) | GTK_USE_PORTAL=0 when enabled | `system.nix:323` (`gtkPortalEnv` gated on `layoutIndicator.enable`) | PASS |
| REQ-GLI-007 (P1) | Bottom layer-shell bar, 24px | `system.nix:40` (`layer: "bottom"`), `system.nix:42` (`height: 24`), `system.nix:41` (`position: "bottom"`) | PASS |
| REQ-GLI-008 (P1) | ReGreet startup delay 0.5s | `system.nix:235-237` (`sleep 0.5` gated on `layoutIndicator.enable`), `system.nix:324,327` (waybar exec-once before regreet exec-once) | PASS |
| REQ-GS-004 | Identical toggle in greeter and session | Greeter: `t14/default.nix:218` (`options = "grp:alt_shift_toggle"`); Session: `t14/home/hypr/input.nix:15-16` (`kb_layout = "es,latam"`, `kb_options = "grp:alt_shift_toggle"`) | PASS |

**Compliance summary**: 10/10 scenarios compliant.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|------------|--------|-------|
| waybar displays layout name at greeter | PASS | `custom/kb-layout` polls `hyprctl devices -j` every 1s via `greetd-kb-layout` script; labels "ES"/"LATAM" via shell case |
| Indicator updates within 2s of Alt+Shift | PASS | Poll interval 1s guarantees worst-case 1s latency |
| No interference with ReGreet form | PASS | `layer: bottom`, `height: 24`; bar at screen bottom, ReGreet centered, no overlap |
| Submodule enable/disable gate | PASS | All code paths gated on `cfg.greeter.layoutIndicator.enable` |
| Config files at /etc/greetd/ | PASS | waybar-config and waybar-style.css deployed via `environment.etc` |
| GTK_USE_PORTAL=0 in greeter | PASS | `env = GTK_USE_PORTAL,0` inserted in hyprland.conf template |
| Bottom dock bar at 24px | PASS | waybar config: `layer: "bottom"`, `height: 24` |
| Startup order: waybar before regreet | PASS | waybar exec-once line appears before regreet exec-once; greeter script sleeps 0.5s as Phase 0 |
| Keyboard consistency greeter/session | PASS | Both use `grp:alt_shift_toggle` with `es,latam` layouts |
| style option (extra CSS) | PASS | `config.nix:405-409` — `lib.types.lines`, injected into waybar stylesheet at `system.nix:59` |

### Coherence (Design)

| Decision | Followed? | Notes |
|----------|-----------|-------|
| Polling via `hyprctl devices -j` shell script | PASS | `system.nix:28-36` |
| Layout label via shell `case` on `.active_keymap` | PASS | `system.nix:31-35` — matches on `*Spanish*`, `*Latino*\|*Latin*` |
| Config at `/etc/greetd/` via `environment.etc` | PASS | `system.nix:340-346` |
| `GTK_USE_PORTAL=0` via `env =` in hyprland.conf | PASS | `system.nix:323` |
| Startup ordering via `exec-once` + 0.5s sleep | PASS | `system.nix:324` (waybarExec), `system.nix:235-237` (sleep), `system.nix:327` (template ordering) |
| Submodule follows wayvnc pattern | PASS | `config.nix:401-414` matches `config.nix:368-400` structure |

### Hallucination Check

All referenced paths verified as valid:

| Path | Validity |
|------|----------|
| `${pkgs.hyprland}/bin/hyprctl` | Valid — hyprland package provides hyprctl binary |
| `${pkgs.jq}/bin/jq` | Valid — jq package |
| `${pkgs.waybar}/bin/waybar` | Valid — waybar package |
| `${layoutIndicatorScript}/bin/greetd-kb-layout` | Valid — generated by `writeShellScriptBin` |
| `${pkgs.regreet}/bin/regreet` | Valid — regreet package |
| `/etc/greetd/waybar-config` | Valid — deployed by `environment.etc` |
| `/etc/greetd/waybar-style.css` | Valid — deployed by `environment.etc` |
| `/etc/greetd/hyprland.conf` | Valid — existing pattern for regreet greeter |

### Issues Found

**CRITICAL**: None

**WARNING**: 
- `nix flake check --no-build` for nixos-hosts t14 fails because `flake.lock` resolves omarchy-nix to github:glats/omarchy-nix/main (commit `0e2439b`, 2026-07-11), which predates the `layoutIndicator` submodule. The local omarchy-nix repo at `/home/glats/repos/omarchy-nix` has uncommitted/unpushed changes. Until omarchy-nix changes are pushed to GitHub and the lock file is updated, t14 cannot build. This is a deployment sequencing issue, not an implementation defect.

**SUGGESTION**: None

### Verdict

**PASS WITH WARNINGS**

All 11 tasks complete. All 10 spec scenarios compliant via static code inspection. Design decisions followed exactly. omarchy-nix flake check passes. nixos-hosts blocked on deployment ordering (push omarchy-nix changes, update lock file). No implementation defects found.
