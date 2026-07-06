# Design: omarchy-hyprland-regreet-refactor

> **Host**: t14 only (Omarchy/Hyprland laptop)
> **Approach**: C — Gradual Cleanup (from exploration)
> **Review budget**: 3 rounds (thorough)
> **Delivery**: single PR (nixos-hosts) + prerequisite PR (omarchy-nix)
> **Artifact store**: hybrid (filesystem + engram)

---

## 0. Verification Baseline (nix-verify skill)

Every NixOS / Home Manager option referenced in this design was verified to exist
before writing. Verification method and findings:

| Option / package | Verified via | Result |
|---|---|---|
| `boot.loader.systemd-boot.enable` | `nix(action=info, source=nixos, type=option)` | bool, default false |
| `boot.loader.systemd-boot.configurationLimit` | `nix(action=info, source=nixos, type=option)` | null or signed int, default null |
| `boot.loader.efi.canTouchEfiVariables` | `nix(action=info, source=nixos, type=option)` | bool, default false |
| `boot.plymouth.enable` | `nix(action=search, source=nixos, type=options)` | bool |
| `boot.consoleLogLevel` | `nix(action=info, source=nixos, type=option)` | signed int, default 4 |
| `boot.initrd.verbose` | `nix(action=info, source=nixos, type=option)` | bool, default true |
| `boot.kernelParams` | `nix(action=info, source=nixos, type=option)` | list of string |
| `boot.kernelPackages` | `nix(action=info, source=nixos, type=option)` | raw, e.g. `pkgs.linuxPackages_zen` |
| `boot.shell_on_fail` | (kernel param, not a NixOS option) | goes in `boot.kernelParams` |
| `services.hyprsunset.enable` | GitHub `search_code` repo:nix-community/home-manager `modules/services/hyprsunset.nix` | exists; `mkEnableOption` |
| `services.hyprsunset.settings` | same file (read in full) | attrset; `profile` is a **list** of attrsets; rendered via `lib.hm.generators.toHyprconf`; HM owns `xdg.configFile."hypr/hyprsunset.conf"` AND `systemd.user.services.hyprsunset` |
| `services.hyprsunset.package` | same file | `mkPackageOption pkgs hyprsunset` |
| `pkgs.hyprsunset` | `nix(action=info, source=nixos, type=package)` | version 0.3.3, BSD-3 |
| `systemd.user.services.*` | (used throughout t14 HM config already) | standard HM option |

**MCP calibration note**: the `nixos` MCP `home-manager` source search returned
"no options found" for `hyprsunset`, `services`, and even `hypridle` — even
though t14 already uses `services.hypridle.settings` and
`systemd.user.services.waybar` successfully. The HM search index in the MCP is
incomplete. `services.hyprsunset` was therefore confirmed via GitHub code
search + reading the actual module file, which is authoritative.

---

## 1. Architecture Overview

### 1.1 Boot configuration (t14)

**Current**: t14 imports `modules/features/boot.nix` directly and sets
`boot-settings.enable = true`. The `boot-settings` module wraps standard
`boot.*` options behind a custom `options.boot-settings` interface with
boolean toggles (`includeAcpiOsi`, `includePoweroffFix`, `includeDiagLogging`).
t14 uses none of the conditional toggles — it gets the static default set
(systemd-boot, plymouth, zen kernel, quiet/splash/loglevel=3 params).

**Target**: t14 stops importing `modules/features/boot.nix` and stops setting
`boot-settings.enable`. The exact `boot.*` options the wrapper would have
applied are inlined directly into `hosts/t14/default.nix`. The
`modules/features/boot.nix` **module file itself is NOT deleted** — see
Section 3.2 (critical deviation from the proposal wording).

### 1.2 Hyprsunset (t14 + omarchy-nix upstream)

**Current**: two layers both write `xdg.configFile."hypr/hyprsunset.conf"` and
define `systemd.user.services.hyprsunset`:
- omarchy-nix `modules/home-manager/hyprsunset.nix`: default identity profile
  at 07:00 + a manual systemd unit (Restart=on-failure, RestartSec=3).
- t14 `hosts/t14/home/hypr/hyprsunset.nix`: overrides the config file with a
  progressive warming schedule (07:00/18:00/19:30/21:00/23:00) via raw
  `xdg.configFile`. Does not touch the systemd unit (inherits omarchy's).

**Target**: both layers migrate to the HM `services.hyprsunset` module, which
is the single owner of `xdg.configFile."hypr/hyprsunset.conf"` and the systemd
unit:
- omarchy-nix upstream PR: `modules/home-manager/hyprsunset.nix` becomes a
  thin `services.hyprsunset = { enable = lib.mkDefault true; settings.profile = lib.mkDefault [...]; }`.
- t14: `hypr/hyprsunset.nix` sets `services.hyprsunset.settings.profile =
  lib.mkForce [...]` with the progressive schedule. The raw `xdg.configFile`
  block is deleted entirely.

### 1.3 Waybar systemd unit (t14)

**Current**: `hosts/t14/home/default.nix` defines a manual
`systemd.user.services.waybar` with aggressive restart limits
(`StartLimitBurst = 20`, `StartLimitIntervalSec = "5s"`, `RestartSec = "100ms"`).

**Verified finding**: omarchy-nix's `modules/home-manager/waybar.nix` does NOT
define a waybar systemd unit — it only installs the package and static config
files. There is therefore no upstream unit to consolidate with; t14's unit is
the sole service definition and cannot be removed.

**Target**: keep the unit (it is already in the declarative
`systemd.user.services` form the proposal asks for). Change is limited to
tightening the restart limit to a sane value and adding a comment documenting
why a custom unit exists (omarchy-nix ships no waybar unit).

### 1.4 Greeter launch script (omarchy-nix upstream)

**Current**: omarchy-nix `modules/nixos/system.nix` builds the greeter script
as `greeterScript = pkgs.writeShellScript "greetd-regreet-start" ''...''` in a
`let` binding, referenced via `exec-once = ${greeterScript}`. The script:
- polls `hyprctl monitors -j` 10×100ms (1s budget) with all stderr suppressed
  to `/dev/null`;
- performs monitor selection + internal-panel disable;
- launches `regreet` then `hyprctl dispatch exit`.

**Correction to exploration**: the exploration called this "140 lines of
embedded bash". The actual script is ~45 lines (system.nix lines 195–240) and
is already wrapped in `pkgs.writeShellScript` (not raw embedded text). The
improvements are still valid: convert to `writeShellScriptBin` (PATH-
installable, independently testable), extend the monitor-enumeration timeout
to 2s, and add stderr diagnostic logging.

**Target**: `pkgs.writeShellScriptBin "greetd-regreet-start"` (binary at
`$out/bin/greetd-regreet-start`), 2s enumeration timeout (20×100ms) with a
warning logged to stderr on timeout, and stderr logging at each phase.
Referenced from Hyprland config as
`exec-once = ${greeterScript}/bin/greetd-regreet-start`.

### 1.5 Opacity windowrule (t14)

**Current**: `hosts/t14/home/hypr/input.nix` appends, via `lib.mkAfter`, a
blanket `windowrule = opacity 1.0 1.0, match:class .*` that forces full
opacity on every window, defeating omarchy's per-app opacity theme system. It
is unconditional.

**Target**: gate the rule behind a `let` boolean `forceFullOpacity` (default
`true` to preserve current behaviour). When `false`, the rule is omitted and
omarchy's per-app opacity rules take effect. The `mkAfter` is retained when
enabled so the rule still wins over omarchy's `extraConfig`.

### 1.6 WLR_RENDERER env (t14)

**Current**: `hosts/t14/home/hypr/looknfeel.nix` sets
`env = [ "WLR_RENDERER_ALLOW_SOFTWARE,0" ]`.

**Target**: removed. Obsolete on Hyprland 0.54+ with the AMD Phoenix iGPU
(Hyprland's own render backend selection no longer honours this legacy
wlroots env var, and software rendering is never selected on this hardware).

---

## 2. File-by-File Before/After

### 2.1 `hosts/t14/home/hypr/looknfeel.nix` — remove obsolete env

**Before** (lines 18–23):
```nix
  wayland.windowManager.hyprland.settings = {
    # T14: AMD Phoenix 3 APU — enable basic anti-aliasing
    # for crisp text without performance overhead.
    env = [
      "WLR_RENDERER_ALLOW_SOFTWARE,0"
    ];
```

**After**:
```nix
  wayland.windowManager.hyprland.settings = {
    # No env overrides: WLR_RENDERER_ALLOW_SOFTWARE,0 was removed — it is
    # obsolete on Hyprland 0.54+ (the wlroots render-backend selection hook
    # it addressed no longer exists), and the AMD Phoenix iGPU never selects
    # software rendering.  No replacement needed.
```

**Rationale**: Hyprland 0.54+ dropped the wlroots-era software-renderer
fallback path that this env var gated. The AMD Phoenix 3 APU has a working
radeonsi driver; software rendering is never selected. The var is pure noise.
Verified: no NixOS/HM option is involved (it is a raw Hyprland `env` entry).

### 2.2 `hosts/t14/home/hypr/input.nix` — gate opacity windowrule

**Before** (full file):
```nix
{ lib, ... }:

{
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = lib.mkForce "es,latam";
    kb_options = lib.mkForce "grp:alt_shift_toggle";
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
    windowrule = opacity 1.0 1.0, match:class .*
  '';
}
```

**After** (full file):
```nix
# T14 Hyprland input — keyboard layout override + optional full-opacity gate.
# All other input settings (touchpad, gestures, windowrules, opacity) are
# owned by omarchy-nix upstream.  The full-opacity override below is gated so
# it can be disabled to restore omarchy's per-app translucent opacity rules.
{ lib, ... }:

let
  # Force full opacity (1.0/1.0) on every window, overriding omarchy's
  # per-app opacity theme system.  Set to false to restore omarchy's
  # translucent window rules (0.97/0.9 etc).
  forceFullOpacity = true;
in
{
  wayland.windowManager.hyprland.settings.input = {
    kb_layout = lib.mkForce "es,latam";
    kb_options = lib.mkForce "grp:alt_shift_toggle";
  };

  # When enabled, mkAfter ensures this rule comes after ALL of omarchy's
  # extraConfig and wins.  omarchy's per-app rules tag windows with
  # `-default-opacity` to opt out, so a plain `match:tag default-opacity`
  # rule alone is insufficient — the match-all is required to force every
  # window opaque.
  wayland.windowManager.hyprland.extraConfig =
    lib.optionalString forceFullOpacity (lib.mkAfter ''
      windowrule = opacity 1.0 1.0, match:class .*
    '');
}
```

**Why a `let` boolean, not a module option**: this is a single-host override
file. Introducing a `lib.mkOption` here would require an `options` attrset and
a config wrapper for one boolean — more machinery than the codebase uses for
host-local toggles (compare `my.desktop.suite`, which lives in a shared
module, not a host file). A `let` binding is editable in-place and matches
the file's existing top-level style. The proposal's "configurable boolean"
requirement is satisfied.

**Why `lib.optionalString` + `lib.mkAfter`**: `lib.optionalString false`
yields `""`, adding no `extraConfig` (omarchy's rules win). `lib.optionalString
true (lib.mkAfter ...)` yields the priority-annotated string so the rule
still appends after omarchy's `extraConfig`. `lib.mkIf` is not used because
`extraConfig` is a plain string value, not a config attrset.

### 2.3 `hosts/t14/default.nix` — inline boot config, drop boot-settings

**Before** (import block, lines 52–55):
```nix
    # === BOOT ===
    # Required: the system will not boot without bootloader configured.
    ../../modules/features/boot.nix
```
**Before** (lines 117–118):
```nix
  # Enable the imported boot module (systemd-boot, plymouth, zen kernel)
  boot-settings.enable = true;
```

**After** (import block — the boot.nix import line is removed; the
`# === BOOT ===` comment is replaced):
```nix
    # === BOOT ===
    # Boot config is inlined below (systemd-boot, plymouth, zen kernel).
    # The shared modules/features/boot.nix (boot-settings) is NOT imported —
    # rog/thinkcentre still use it, but t14 inlines its own static set.
```
*(The `../../modules/features/boot.nix` line is deleted.)*

**After** (lines 117–118 replaced by an inlined boot block; see Section 5.1
for the exact expression):
```nix
  # === BOOT (inlined from the former boot-settings.enable wrapper) ===
  # t14 needs only the static default set (no ACPI OSI / poweroff fix /
  # diag logging toggles), so the wrapper module adds no value here.
  # rog/thinkcentre keep using modules/features/boot.nix because they rely
  # on its conditional toggles (includeAcpiOsi, includeDiagLogging, ...).
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 3;
    };
    loader.efi.canTouchEfiVariables = true;
    plymouth.enable = true;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "vt.global_cursor_default=0"
    ];
  };
```

**Rationale**: t14 uses none of the wrapper's conditional toggles
(`includeAcpiOsi`, `includePoweroffFix`, `includeDiagLogging` are all unset,
so all `lib.optionals` branches evaluate to `[ ]`). The wrapper therefore
reduces to a fixed `boot.*` block that is clearer inlined at the host. The
existing `boot.initrd.supportedFilesystems = [ "xfs" ]` and
`boot.extraModprobeConfig` lines (further down in default.nix) are
unrelated and stay; they merge with this `boot = { ... }` attrset normally.
No `lib.mkForce` is needed because no other module on t14 sets these boot
keys (omarchy-nix's `seamless_boot` is not enabled on t14).

### 2.4 `hosts/t14/home/hypr/hyprsunset.nix` — migrate to HM module

**Before** (full file): raw `xdg.configFile."hypr/hyprsunset.conf".text`
with 6 `profile { ... }` blocks (one is a duplicate 07:00 copy-paste
artifact) and a comment explaining the HM module is not used to avoid
conflicting with omarchy-nix's manual unit.

**After** (full file):
```nix
# T14 Hyprsunset — progressive blue-light filter schedule.
#
# Migrated from raw xdg.configFile to the Home Manager
# services.hyprsunset module (upstream HM: modules/services/hyprsunset.nix).
# The HM module owns BOTH the config file (rendered via
# lib.hm.generators.toHyprconf) and the systemd user service, so this file
# only declares the schedule.
#
# Prerequisite: omarchy-nix's modules/home-manager/hyprsunset.nix must have
# migrated to services.hyprsunset (lib.mkDefault) so it no longer writes a
# competing xdg.configFile or systemd unit.  This is done in the companion
# omarchy-nix PR; until that is merged and the flake input updated, this
# file must NOT be applied (it would duplicate the config file path).
#
# The duplicate 07:00 identity block from the old raw config (a copy-paste
# artifact) is dropped — a single identity profile is sufficient.
{ lib, ... }:

{
  services.hyprsunset = {
    enable = true;
    settings.profile = lib.mkForce [
      { time = "07:00"; identity = true; }
      { time = "18:00"; temperature = 4500; }
      { time = "19:30"; temperature = 4000; }
      { time = "21:00"; temperature = 3500; }
      { time = "23:00"; temperature = 3000; }
    ];
  };
}
```

**Why `lib.mkForce` on `settings.profile`**: omarchy-nix's migrated module
sets `settings.profile = lib.mkDefault [ { time = "07:00"; identity = true; } ]`
(priority 1000). t14's `lib.mkForce` (priority 50) replaces it with the full
progressive schedule. `enable` is left as plain `true` (omarchy's
`lib.mkDefault true` and this `true` agree). No other `settings` keys are set
by either side, so there is no merge conflict.

**Why the duplicate 07:00 block is dropped**: the old raw config had two
identical `profile { time=07:00 identity=true }` blocks (noted in the original
file's own comment as a copy-paste artifact). The HM module renders the
`profile` list verbatim, so a single entry is correct and the duplicate is
dead.

### 2.5 `hosts/t14/home/default.nix` — waybar unit tightening

**Before** (lines 50–70): a `systemd.user.services.waybar` block with
`StartLimitBurst = 20; StartLimitIntervalSec = "5s"; RestartSec = "100ms";`
and no explanatory comment.

**After** (lines 50–70): same structure (already declarative
`systemd.user.services`), with a tightened, sane restart limit and a comment:
```nix
  # Waybar systemd user service.
  # omarchy-nix's waybar HM module installs only the package + static config
  # files — it does NOT ship a systemd unit — so this is the sole service
  # definition and cannot be removed.  Restart=always + a short RestartSec
  # recover waybar quickly when it crashes on monitor hotplug (a known
  # Hyprland multi-monitor race).  The previous StartLimitBurst=20 in 5s was
  # overly permissive (would hammer-restart 20 times); 5 in 10s still recovers
  # fast but gives systemd a sane back-off before the unit is stopped.
  systemd.user.services.waybar = {
    Unit = {
      Description = "Waybar status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = [ "WAYLAND_DISPLAY" ];
      StartLimitBurst = 5;
      StartLimitIntervalSec = "10s";
    };
    Service = {
      ExecStart = "${pkgs.waybar}/bin/waybar";
      Restart = "always";
      RestartSec = "100ms";
      StandardOutput = "null";
      StandardError = "journal";
      SyslogIdentifier = "waybar";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
```

**Rationale**: verified that omarchy-nix `modules/home-manager/waybar.nix`
does not define a `systemd.user.services.waybar` (it only sets `home.packages`
+ static `home.file`/`xdg.configFile`). So there is no redundancy to remove —
the unit is already in the target declarative form. The only real change is
reducing the aggressive 20-restarts-in-5s limit to 5-in-10s and documenting
why the unit exists. This honours the proposal's "simplify" intent without a
hollow structural rewrite.

### 2.6 `hosts/t14/home/omarchy.nix` — architecture documentation comments

**Change**: add a documentation comment block near the top of the file
(after the existing header, before `imports = [`) explaining the
Hyprland-as-greeter-compositor architecture decision, so future readers
understand WHY the greeter bypasses the standard NixOS session-file
mechanism.

**After** (insert after the existing module header comment, before `{ config
... }`):
```nix
# === GREETER ARCHITECTURE (decision record) ===
# t14 uses ReGreet (GTK greeter) running INSIDE a minimal Hyprland session,
# not cage and not the standard NixOS wayland-sessions file mechanism.
# This is intentional: Hyprland as the greeter compositor exposes the
# keyboard-layout toggle (Alt+Shift, es<->latam) at the LOGIN screen, which
# cage cannot do.  The trade-off is a custom /etc/greetd/hyprland.conf
# (generated by omarchy-nix:modules/nixos/system.nix) and a launch script
# (greetd-regreet-start) that handles monitor selection before regreet
# starts.  The NixOS-wiki-recommended tuigreet --sessions approach is
# deliberately NOT used because it would lose the login-screen layout
# toggle.  Do not "fix" this to cage/session-files without confirming the
# layout-toggle requirement is still valid.
```

No functional change to `omarchy.nix` — comment only.

### 2.7 omarchy-nix `modules/nixos/system.nix` — greeter script extraction

**Before** (lines 195–263): `greeterScript` is a `let` binding built with
`pkgs.writeShellScript "greetd-regreet-start" ''...''`, with 10×100ms monitor
polling, all stderr suppressed, and referenced as
`exec-once = ${greeterScript}`.

**After** (the `let` binding changes to `writeShellScriptBin` with a 2s
timeout and stderr logging; the `exec-once` reference adds `/bin/`):
```nix
      greeterScript = pkgs.writeShellScriptBin "greetd-regreet-start" ''
        # ── Phase 1: monitor selection ──────────────────────────────
        # Logs to stderr (captured by Hyprland/greetd journal). 2s budget
        # (20 × 100ms) for Hyprland monitor enumeration — up from the old
        # 1s (10 × 100ms) which occasionally raced on cold boot.
        FOCUS='${cfg.greeter.focusMonitor}'

        if [ -n "$FOCUS" ]; then
          enumerated=0
          for _ in $(seq 1 20); do
            if ${pkgs.hyprland}/bin/hyprctl monitors -j 2>/dev/null \
              | ${pkgs.jq}/bin/jq -e 'length > 0' >/dev/null 2>&1; then
              enumerated=1
              break
            fi
            sleep 0.1
          done
          if [ "$enumerated" -eq 0 ]; then
            echo "[greetd-regreet-start] WARNING: monitor enumeration timed out after 2s" >&2
          fi

          TARGET_MON=$(${pkgs.hyprland}/bin/hyprctl monitors all -j 2>/dev/null \
            | ${pkgs.jq}/bin/jq -r --arg d "$FOCUS" \
              '.[] | select((.description // "") | contains($d)) | .name' \
            | head -1)

          if [ -n "$TARGET_MON" ] && [ "$TARGET_MON" != "null" ]; then
            echo "[greetd-regreet-start] focusing monitor: $TARGET_MON" >&2
            for m in $(${pkgs.hyprland}/bin/hyprctl monitors all -j 2>/dev/null \
              | ${pkgs.jq}/bin/jq -r '.[].name'); do
              case "$m" in
                eDP-*) ;;
                "$TARGET_MON") ;;
                *) ${pkgs.hyprland}/bin/hyprctl keyword monitor "$m,disable" >/dev/null 2>&1 ;;
              esac
            done
            ${pkgs.hyprland}/bin/hyprctl dispatch focusmonitor "$TARGET_MON" >/dev/null 2>&1
          else
            echo "[greetd-regreet-start] WARNING: no monitor matched focus '$FOCUS'" >&2
          fi
        fi

        # ── Phase 2: internal panel disable ─────────────────────────
        for s in /sys/class/drm/card*-*/status; do
          case "$s" in *-eDP-*) continue;; esac
          read -r st < "$s" 2>/dev/null
          if [ "$st" = connected ]; then
            echo "[greetd-regreet-start] external display connected; disabling eDP-1" >&2
            ${pkgs.hyprland}/bin/hyprctl keyword monitor eDP-1,disable
            break
          fi
        done

        # ── Phase 3: launch greeter ─────────────────────────────────
        echo "[greetd-regreet-start] launching regreet" >&2
        ${pkgs.regreet}/bin/regreet
        ${pkgs.hyprland}/bin/hyprctl dispatch exit
      '';
```
And the `exec-once` line (in the `in ''...''` body) changes from:
```
${monitorBlock}${cursorEnv}${wayvncExec}exec-once = ${greeterScript}
```
to:
```
${monitorBlock}${cursorEnv}${wayvncExec}exec-once = ${greeterScript}/bin/greetd-regreet-start
```

**Why `writeShellScriptBin` over `writeShellScript`**: `writeShellScriptBin`
places the binary at `$out/bin/greetd-regreet-start`, making it PATH-
installable and independently testable (`greetd-regreet-start` can be run from
a shell for debugging, once `HYPRCTL`/monitor state is available). The
`/bin/` suffix on the `exec-once` reference is the only call-site change.

**Why 2s not 1s**: the old 1s (10×100ms) budget occasionally lost the race on
cold boot when the DRM subsystem was slow to enumerate. 2s (20×100ms) is a
safe margin with a warning emitted if still exceeded. The script is
non-blocking on timeout — it proceeds with whatever monitors are present,
matching current fallback behaviour.

**Why stderr logging**: the old script suppressed all stderr with
`2>/dev/null`, so a silent monitor-detection failure left no trace. The new
script emits phase progress and warnings to stderr (fd 2), which greetd/Hyprland
forward to the journal. Functional `hyprctl` stderr on the hot-path
monitor-disable calls is still suppressed (those are noisy and expected to
succeed), but diagnostic `echo ... >&2` lines are added at each phase
boundary.

**Repo boundary**: this change is in the **omarchy-nix** repo
(`/home/glats/repos/omarchy-nix/modules/nixos/system.nix`). It ships as a
companion PR to omarchy-nix (glats owns the repo — full push access per
AGENTS.md). The nixos-hosts `omarchy-nix` flake input is bumped after the PR
merges.

### 2.8 omarchy-nix `modules/home-manager/hyprsunset.nix` — migrate to HM module

**Before** (full file): raw `xdg.configFile."hypr/hyprsunset.conf".text`
(default identity at 07:00) + a manual `systemd.user.services.hyprsunset`
(Restart=on-failure, RestartSec=3, WantedBy=graphical-session.target).

**After** (full file):
```nix
# Hyprsunset — blue-light filter.
# Migrated from raw xdg.configFile + manual systemd unit to the Home Manager
# services.hyprsunset module, which owns BOTH the config file (rendered via
# lib.hm.generators.toHyprconf) and the systemd user service.  Hosts override
# services.hyprsunset.settings.profile (lib.mkForce) for custom schedules.
{ lib, ... }:

{
  services.hyprsunset = {
    enable = lib.mkDefault true;
    settings.profile = lib.mkDefault [
      { time = "07:00"; identity = true; }
    ];
  };
}
```

**Rationale**: the HM `services.hyprsunset` module is the canonical owner of
both `xdg.configFile."hypr/hyprsunset.conf"` and
`systemd.user.services.hyprsunset` (verified by reading the module source).
Keeping omarchy-nix's manual definitions would create duplicate-path
conflicts. `lib.mkDefault` on both `enable` and `settings.profile` lets hosts
(t14) override cleanly. The HM module's defaults differ slightly from the old
manual unit (Restart=always/RestartSec=10 vs on-failure/3;
WantedBy=`config.wayland.systemd.target` vs `graphical-session.target`) — the
HM defaults are correct for Hyprland sessions (`wayland.systemd.target`
resolves to `hyprland-session.target`), so this is an improvement, not a
regression.

**Repo boundary**: omarchy-nix repo, companion PR (same as 2.7).

---

## 3. Removals (with justification)

### 3.1 `WLR_RENDERER_ALLOW_SOFTWARE,0` from `hypr/looknfeel.nix`

- **What**: the single `env = [ "WLR_RENDERER_ALLOW_SOFTWARE,0" ]` entry.
- **Why removed**: obsolete on Hyprland 0.54+ with the AMD Phoenix iGPU. The
  wlroots-era software-renderer fallback path this gated no longer exists in
  modern Hyprland, and the radeonsi driver on this APU never selects software
  rendering. Pure config noise.
- **Replacement**: none. The `env` list becomes empty and is deleted.

### 3.2 `boot-settings.enable = true` from `hosts/t14/default.nix`

- **What**: the `boot-settings.enable = true;` line and the
  `../../modules/features/boot.nix` import.
- **Why removed from t14**: t14 uses none of the wrapper's conditional
  toggles, so the wrapper reduces to a fixed `boot.*` block that is clearer
  inlined at the host. Satisfies proposal success criterion #5
  ("`boot-settings.enable` no longer referenced in t14 config").
- **CRITICAL — the `modules/features/boot.nix` module file is NOT deleted.**
  This deviates from the proposal's file-column wording ("remove wrapper
  module"). Verified via repo grep: `boot-settings` is used by **three** hosts:
  - `hosts/t14/default.nix:118` — `boot-settings.enable = true;`
  - `hosts/rog/default.nix:61` — `boot-settings = { enable=true; includeAcpiOsi=true; includePoweroffFix=true; includeDiagLogging=true; };`
  - `hosts/thinkcentre/default.nix:27` — `boot-settings = { enable=true; includeAcpiOsi=false; };`
  Deleting the module would break rog and thinkcentre (which rely on its
  conditional toggles). The module stays; only t14 stops consuming it. This
  is the safe, correct interpretation and still meets the success criterion.

### 3.3 Duplicate `profile { time=07:00 identity=true }` block (hyprsunset)

- **What**: the second identical 07:00 identity block in the old raw
  hyprsunset config (a copy-paste artifact acknowledged in the file's own
  comment).
- **Why removed**: dead duplicate. The migrated `services.hyprsunset.settings.profile`
  list contains a single 07:00 identity entry.

### 3.4 Raw `xdg.configFile."hypr/hyprsunset.conf"` + manual systemd unit (omarchy-nix)

- **What**: omarchy-nix's manual `xdg.configFile` + `systemd.user.services.hyprsunset`.
- **Why removed**: replaced by the HM `services.hyprsunset` module, which owns
  both. Keeping both would duplicate the config file path and the systemd
  unit name.

---

## 4. Replacements (with option paths)

| Old | New | Option path (verified) |
|---|---|---|
| `boot-settings.enable = true` (t14) + `boot.nix` import | inlined `boot.*` block | `boot.loader.systemd-boot.enable`, `boot.loader.systemd-boot.configurationLimit`, `boot.loader.efi.canTouchEfiVariables`, `boot.plymouth.enable`, `boot.consoleLogLevel`, `boot.initrd.verbose`, `boot.kernelPackages`, `boot.kernelParams` |
| raw `xdg.configFile."hypr/hyprsunset.conf"` (t14 + omarchy-nix) | `services.hyprsunset.settings.profile` | `services.hyprsunset.enable`, `services.hyprsunset.settings` (HM module `modules/services/hyprsunset.nix`) |
| manual `systemd.user.services.hyprsunset` (omarchy-nix) | HM module-owned unit | (created by `services.hyprsunset` config block) |
| `pkgs.writeShellScript "greetd-regreet-start"` | `pkgs.writeShellScriptBin "greetd-regreet-start"` | Nix stdlib (`pkgs.writeShellScriptBin`) |
| unconditional `mkAfter` opacity windowrule | `let forceFullOpacity` boolean-gated `mkAfter` | `wayland.windowManager.hyprland.extraConfig` (HM, already in use) |
| waybar `StartLimitBurst = 20` / `5s` | `StartLimitBurst = 5` / `10s` | `systemd.user.services.waybar` (HM, unchanged structure) |

---

## 5. New Configurations (exact Nix expressions)

### 5.1 Boot options block for `hosts/t14/default.nix`

Replaces the old `boot-settings.enable = true;` line (line 118). Merges
harmlessly with the existing `boot.initrd.supportedFilesystems` and
`boot.extraModprobeConfig` lines below it (Nix attrset merge):

```nix
  # === BOOT (inlined from the former boot-settings.enable wrapper) ===
  boot = {
    loader.systemd-boot = {
      enable = true;
      configurationLimit = 3;
    };
    loader.efi.canTouchEfiVariables = true;
    plymouth.enable = true;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelPackages = pkgs.linuxPackages_zen;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "vt.global_cursor_default=0"
    ];
  };
```

This is byte-for-byte the same set of options the wrapper applied for t14
(all `lib.optionals` branches evaluate to `[ ]` because t14 sets none of the
conditional toggles). Verified options: see Section 0.

### 5.2 Gated full-opacity windowrule (`hosts/t14/home/hypr/input.nix`)

See Section 2.2 — the full file is the new configuration. The gate is a `let
forceFullOpacity = true;` boolean. Toggle to `false` to restore omarchy's
per-app opacity theme rules.

### 5.3 Greeter script as standalone `writeShellScriptBin` (omarchy-nix)

See Section 2.7 — the full target script with 2s timeout (20×100ms) and
stderr logging at each phase. Called from Hyprland config as
`exec-once = ${greeterScript}/bin/greetd-regreet-start`.

---

## 6. Module Import Changes

### 6.1 `hosts/t14/default.nix` imports

**Removed**:
```nix
    ../../modules/features/boot.nix
```

**Added**: nothing. The boot config is inlined (Section 5.1).

**Net effect**: `modules/features/boot.nix` is no longer in t14's import
list. The module file itself is untouched (rog/thinkcentre still import it
via `modules/profiles/base.nix` or directly).

### 6.2 omarchy-nix `modules/home-manager/hyprsunset.nix`

No import-list change — the file is rewritten in place (Section 2.8) from raw
`xdg.configFile` + manual systemd unit to a thin `services.hyprsunset`
declaration. It remains imported by `modules/home-manager/default.nix`.

### 6.3 `hosts/t14/home/default.nix` imports

No change. `./hypr/hyprsunset.nix` stays imported (its body changes per
Section 2.4, but the import line is unchanged).

### 6.4 `hosts/t14/home/omarchy.nix` imports

No change. Only a documentation comment is added (Section 2.6).

---

## 7. Testing / Verification Plan

Per the proposal's risk ordering (lowest → highest), each change is a separate
commit with its own verification. All commands run from the repo root
(`/home/glats/.nixos`) unless noted. The omarchy-nix changes (2.7, 2.8) are in
`/home/glats/repos/omarchy-nix` and verified there first, then the flake input
is bumped.

### 7.1 After each commit (universal)

```bash
format-nix                                      # format the repo
nix flake check --no-build                      # must exit 0
nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link  # t14 builds
```
And confirm non-t14 hosts are untouched:
```bash
nixos-build dry 2>&1 | grep -E '^(t14|rog|thinkcentre|mact2)' # only t14 should show boot/hypr deltas
```

### 7.2 Change: remove `WLR_RENDERER_ALLOW_SOFTWARE` (2.1)

- `nix flake check --no-build` passes.
- `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds.
- **Runtime verify**: `nixos-build`, log into Hyprland, confirm text rendering
  is unchanged (no software-renderer fallback). `hyprctl version` shows 0.54+.

### 7.3 Change: gate opacity windowrule (2.2)

- `nix flake check --no-build` passes.
- With `forceFullOpacity = true` (default): build + `nixos-build`, log in,
  confirm all windows are fully opaque (current behaviour preserved).
- With `forceFullOpacity = false` (test toggle): build + `nixos-build`, log in,
  confirm omarchy's per-app translucency is restored (terminals ~0.97, etc.).
  This is a verification-only toggle; commit ships with `true`.

### 7.4 Change: inline boot config (2.3)

- `nix flake check --no-build` passes.
- `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds.
- **Diff the generated kernel cmdline** to prove no regression:
  ```bash
  # Before commit (current generation):
  cat /run/current-system/kernel-params 2>/dev/null | tr ' ' '\n' | sort > /tmp/boot-before.txt
  # After rebuild to a new generation without switching:
  nixos-rebuild build --flake .#t14
  nix-store -qb $(nixos-rebuild build --flake .#t14 --print-out-paths 2>/dev/null) kernel-params 2>/dev/null
  ```
  Or more simply, inspect the built toplevel's `kernel-params` and compare
  the set is identical (quiet, splash, loglevel=3, etc.). The only
  acceptable difference is none.
- **Reboot test** (do last in this group): `nixos-build`, reboot, confirm
  systemd-boot menu appears, plymouth splash shows, boot is quiet, system
  comes up. `journalctl -b | grep -iE 'plymouth|systemd-boot'` for sanity.

### 7.5 Change: waybar unit tightening (2.5)

- `nix flake check --no-build` passes.
- `nix build .#homeConfigurations.glats@t14.activationPackage --no-link`
  succeeds.
- **Runtime verify**: `nixos-build`, log in, `systemctl --user status waybar`
  shows active. Simulate a crash: `pkill -9 waybar`, confirm it restarts
  within ~100ms. Repeat 6× rapidly to confirm the 5-in-10s limit stops the
  unit after 5 restarts (then `systemctl --user start waybar` to recover).

### 7.6 Change: hyprsunset migration (2.4 + omarchy-nix 2.8) — blocked on omarchy-nix PR

**Ordering**: omarchy-nix PR (2.8) merges first → flake input bumped → then
nixos-hosts change (2.4) applies.

- omarchy-nix side: `nix flake check --no-build` in `/home/glats/repos/omarchy-nix`.
- After flake bump + nixos-hosts change:
  - `nix flake check --no-build` passes.
  - `nix build .#homeConfigurations.glats@t14.activationPackage --no-link`.
- **Conflict check**: confirm only ONE `hyprsunset.conf` source exists:
  ```bash
  nix build .#homeConfigurations.glats@t14.activationPackage --no-link --print-out-paths
  # inspect the activation package for xdg.configFile."hypr/hyprsunset.conf"
  # — there must be exactly one source derivation (the HM module's), not two.
  ```
- **Runtime verify**: `nixos-build`, log in, `systemctl --user status
  hyprsunset` is active (Restart=always now, RestartSec=10). At 23:00 local
  time (or via `systemctl --user restart hyprsunset` + manual time check)
  confirm the progressive warming applies: `cat ~/.config/hypr/hyprsunset.conf`
  shows the 5-profile schedule with no duplicate 07:00 block.

### 7.7 Change: greeter script extraction (omarchy-nix 2.7) — HIGHEST RISK, done last

- omarchy-nix side: `nix flake check --no-build` in the omarchy-nix repo.
- **Pre-flight VT fallback** (before any greeter rebuild): confirm the
  `systemd.mask=greetd.service` escape hatch works by appending it to the
  kernel cmdline at the systemd-boot menu (edit entry, append, boot). Confirm
  a VT login prompt appears. This is the recovery path if the greeter breaks.
- After bumping the flake input:
  - `nix flake check --no-build` passes.
  - `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link`.
- **Script testability**: the script is now `writeShellScriptBin`, so its
  binary path can be inspected:
  ```bash
  nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link --print-out-paths
  # locate the greetd-regreet-start binary in the built toplevel's etc/greetd
  # references and confirm it is under a /bin/ path
  ```
- **Runtime verify (greeter)**: `nixos-build`, reboot. The greeter Hyprland
  session must start, regreet must appear, monitor selection must place it on
  the configured focus monitor (LEN G24). Log in normally. Check
  `journalctl -b _COMM=Hyprland --since "5 min ago" | grep greetd-regreet-start`
  (or `journalctl -u greetd`) for the new stderr log lines:
  - `[greetd-regreet-start] focusing monitor: ...` (or the WARNING lines if
    detection failed).
- **Timeout verify**: if a cold boot is available, confirm the 2s enumeration
  does not hang the greeter (the warning line should appear only if
  enumeration genuinely failed).

### 7.8 Final whole-PR verification

- `nix flake check --no-build` passes for the whole flake.
- `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds.
- `nixos-build dry` reports changes ONLY on t14 (no rog/thinkcentre/mact2
  deltas) — except the omarchy-nix flake-input bump, which is shared but
  functionally affects only t14's greeter/hyprsunset paths.
- `git diff --stat` reviewed; total additions+deletions stays within the
  400-line review budget (forecast: well under — mostly edits, no new files
  except the design/tasks docs).

---

## 8. Migration / Sequencing

The single nixos-hosts PR is ordered by risk (lowest first), one commit per
change. The omarchy-nix companion PR (2.7 + 2.8) must merge BEFORE the
nixos-hosts commits that depend on it (2.4 hyprsunset, and the flake bump
that carries 2.7).

```
omarchy-nix PR (merge first):
  1. hyprsunset HM module migration (2.8)
  2. greeter script extraction (2.7)
        │
        ▼  (bump omarchy-nix flake input in nixos-hosts)
nixos-hosts PR (single PR, ordered commits):
  1. remove WLR_RENDERER_ALLOW_SOFTWARE (2.1)            ← lowest risk
  2. gate opacity windowrule (2.2)
  3. inline boot config, drop boot-settings (2.3)
  4. waybar unit tightening (2.5)
  5. omarchy.nix architecture comment (2.6)
  6. hyprsunset HM migration (2.4)                       ← needs flake bump
  7. (flake bump commit if not already in step 6)
```

Rollback per commit via `git revert`; system rollback via
`nixos-build --rollback` to the previous generation. Greeter changes have the
`systemd.mask=greetd.service` VT fallback (tested in 7.7 pre-flight).

---

## 9. Open Questions / Decisions Requiring Sign-off

1. **boot-settings module deletion (deviation)**: the proposal's file column
   says "remove wrapper module" but rog + thinkcentre depend on it. This
design keeps the module and only removes t14's usage. Confirm this is
acceptable (recommended: yes — it meets success criterion #5 without breaking
two hosts).

2. **omarchy-nix PR scope**: this design includes two omarchy-nix changes
   (greeter script, hyprsunset). They are prerequisite to the nixos-hosts PR.
   Confirm the omarchy-nix companion PR is in scope for this change (the
   proposal already lists omarchy-nix system.nix in scope, so assumed yes).

3. **waybar "simplification" is minor**: verified that omarchy-nix ships no
   waybar systemd unit, so the custom unit cannot be removed. The change is
   limited to restart-limit tightening + a comment. Confirm this satisfies
   the proposal's "simplify waybar unit" item (recommended: yes — the unit is
   already in the target declarative form).
