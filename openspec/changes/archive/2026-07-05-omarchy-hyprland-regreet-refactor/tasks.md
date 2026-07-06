# Tasks: omarchy-hyprland-regreet-refactor

> **Host**: t14 only (Omarchy/Hyprland laptop)
> **Delivery**: single PR (nixos-hosts) + companion PR (omarchy-nix)
> **Review budget**: 3 rounds (thorough)
> **Adjusted scope**: boot-settings consolidation OUT. Hyprsunset migration INCLUDED (user override).
> **Source of truth**: design.md (Section 2 file-by-file before/after), user-adjusted scope

---

## Review Workload Forecast

- `Decision needed before apply: No`
- `Chained PRs recommended: No`
- `400-line budget risk: Low`

**Rationale**: After scope reduction (boot-settings removed), the nixos-hosts PR comprises 5 small file edits (one deletion, one conditional gate, one number change + comment, one hyprsunset config migration, one comment block). The omarchy-nix companion PR includes greeter script extraction (~50 lines refactor) + hyprsunset HM module migration (~40 line deletion). Both repos well under 100 lines each. The nixos-hosts changes are well under 150 lines total.

---

## Scope Reminder

### In Scope

| # | Change | File(s) |
|---|--------|---------|
| 1 | Remove `WLR_RENDERER_ALLOW_SOFTWARE,0` | `hosts/t14/home/hypr/looknfeel.nix` |
| 2 | Gate full-opacity windowrule behind `let` boolean | `hosts/t14/home/hypr/input.nix` |
| 3 | Tighten waybar StartLimitBurst + add comment | `hosts/t14/home/default.nix` |
| 4 | Extract greeter script to `writeShellScriptBin`, add 2s timeout + stderr logging | omarchy-nix `modules/nixos/system.nix` |
| 5 | Migrate hyprsunset from raw config to `services.hyprsunset` in omarchy-nix | omarchy-nix `modules/home-manager/hyprsunset.nix` |
| 6 | Migrate t14 hyprsunset from raw config to `services.hyprsunset.settings` | `hosts/t14/home/hypr/hyprsunset.nix` |
| 7 | Add Hyprland-as-greeter-compositor architecture doc | `hosts/t14/home/omarchy.nix` |

### Out of Scope (user decision during proposal review)

- **boot-settings consolidation** — `boot-settings.enable = true` stays on t14. `modules/features/boot.nix` is NOT deleted.

---

## Dependencies

- **Phase 4 (Integration)** depends on the **omarchy-nix companion PR (Phases 3 + 4)** being merged and the nixos-hosts flake input bumped.
- **Phase 5 (Hyprsunset migration in t14)** depends on the omarchy-nix companion PR (Phase 4) being merged — the HM module `services.hyprsunset` must be enabled by omarchy-nix before t14 can override its settings.
- **Phase 1 and Phase 2** are independent — no omarchy-nix dependency.
- The omarchy-nix repo is at `/home/glats/repos/omarchy-nix`. glats has full push access (per AGENTS.md).

---

## Phase 1: Low-Risk Hyprland Config Cleanup

These changes are deletions or single-boolean gates with no omarchy-nix dependency and no impact on the boot path or login flow. They can be applied and verified in any order.

---

### 1.1 Remove obsolete `WLR_RENDERER_ALLOW_SOFTWARE,0` env var

**File**: `hosts/t14/home/hypr/looknfeel.nix`

**What**: Delete the `env = [ "WLR_RENDERER_ALLOW_SOFTWARE,0" ]` entry from `wayland.windowManager.hyprland.settings`. This env var is obsolete on Hyprland 0.54+ with the AMD Phoenix iGPU — the wlroots-era software-renderer fallback path it gated no longer exists in modern Hyprland.

**Design reference**: design.md Section 2.1, Section 3.1.

**Before** (lines 18-23):
```nix
    env = [
      "WLR_RENDERER_ALLOW_SOFTWARE,0"
    ];
```

**After**: Delete the entire `env` attribute (do NOT leave an empty `env = [];`). If `env` was the only key in the `settings` block, the block structure stays; only the `env` line is removed.

**Spec reference**: REQ-HC-001 (REMOVED).

**Verification**:
- [ ] `format-nix` on `looknfeel.nix`
- [ ] `nix flake check --no-build` passes for t14
- [ ] `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link` succeeds
- [ ] `grep -r WLR_RENDERER_ALLOW_SOFTWARE hosts/t14` returns no matches

---

### 1.2 Gate full-opacity windowrule behind configurable `let` boolean

**File**: `hosts/t14/home/hypr/input.nix`

**What**: Replace the unconditional `lib.mkAfter` block that forces opacity 1.0 on all windows with a conditional gate using a `let` boolean (`forceFullOpacity`). When `forceFullOpacity = true` (default), the `mkAfter` windowrule still applies and defeats omarchy's per-app opacity rules. When `false`, the rule is suppressed and omarchy's translucency rules take effect.

**Design reference**: design.md Section 2.2 (full file after), Section 2.2 rationale explaining why `let` not a module option.

**After** (full file):
```nix
# T14 Hyprland input -- keyboard layout override + optional full-opacity gate.
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
  # rule alone is insufficient -- the match-all is required to force every
  # window opaque.
  wayland.windowManager.hyprland.extraConfig =
    lib.optionalString forceFullOpacity (lib.mkAfter ''
      windowrule = opacity 1.0 1.0, match:class .*
    '');
}
```

**Why `lib.optionalString` + `lib.mkAfter`**: `lib.optionalString false` yields `""` (no `extraConfig`, omarchy wins). `lib.optionalString true (lib.mkAfter ...)` yields the priority-annotated string so the rule appends after omarchy's `extraConfig`. `lib.mkIf` is not used because `extraConfig` is a plain string value, not a config attrset.

**Spec reference**: REQ-HC-002 (MODIFIED).

**Verification**:
- [ ] `format-nix` on `input.nix`
- [ ] `nix flake check --no-build` passes for t14
- [ ] `nix build .#homeConfigurations.glats@t14.activationPackage --no-link` succeeds
- [ ] With `forceFullOpacity = true` (default): confirm the `windowrule = opacity 1.0 1.0, match:class .*` appears in the generated Hyprland config at the end of `extraConfig`
- [ ] Toggle `forceFullOpacity = false`, rebuild, confirm the windowrule is absent from generated config

---

## Phase 2: Systemd Unit and Documentation

These changes are independent of omarchy-nix and affect only the t14 host. No boot or login impact.

---

### 2.1 Tighten waybar systemd unit restart limits and add documentation comment

**File**: `hosts/t14/home/default.nix`

**What**: Reduce the aggressive `StartLimitBurst = 20` / `StartLimitIntervalSec = "5s"` to `StartLimitBurst = 5` / `StartLimitIntervalSec = "10s"`, and add a comment explaining why the custom unit exists (omarchy-nix ships no waybar systemd unit — it only installs the package and static config files). The unit structure stays declarative (`systemd.user.services.waybar`) — it is already in the target form.

**Design reference**: design.md Section 1.3 (verified finding), Section 2.5 (before/after).

**Key finding from design**: omarchy-nix's `modules/home-manager/waybar.nix` does NOT define a `systemd.user.services.waybar` unit. t14's unit is the sole definition. There is no upstream unit to consolidate with or remove. The change is limited to restart-limit tightening and documentation.

**Before** (current StartLimitBurst/Interval):
```nix
StartLimitBurst = 20;
StartLimitIntervalSec = "5s";
```

**After** (tightened):
```nix
StartLimitBurst = 5;
StartLimitIntervalSec = "10s";
```

Plus add this comment block before the `systemd.user.services.waybar` line:
```nix
  # Waybar systemd user service.
  # omarchy-nix's waybar HM module installs only the package + static config
  # files -- it does NOT ship a systemd unit -- so this is the sole service
  # definition and cannot be removed.  Restart=always + a short RestartSec
  # recover waybar quickly when it crashes on monitor hotplug (a known
  # Hyprland multi-monitor race).  The previous StartLimitBurst=20 in 5s was
  # overly permissive (would hammer-restart 20 times); 5 in 10s still recovers
  # fast but gives systemd a sane back-off before the unit is stopped.
```

**Spec reference**: REQ-WB-001 (MODIFIED) — simplified given design verification that omarchy-nix ships no waybar unit.

**Verification**:
- [ ] `format-nix` on `default.nix`
- [ ] `nix flake check --no-build` passes for t14
- [ ] `nix build .#homeConfigurations.glats@t14.activationPackage --no-link` succeeds
- [ ] Inspect generated unit: `systemctl --user cat waybar` shows `StartLimitBurst=5` and `StartLimitIntervalSec=10s`
- [ ] Runtime test: `pkill -9 waybar`, confirm it restarts within ~100ms. Repeat 6x rapidly — confirm the unit is stopped after 5 restarts in 10s (systemd's built-in rate limiting).
- [ ] `systemctl --user start waybar` recovers the service normally

---

### 2.2 Add Hyprland-as-greeter-compositor architecture documentation in omarchy.nix

**File**: `hosts/t14/home/omarchy.nix`

**What**: Add a documentation comment block near the top of the file (after the existing module header comment, before `{ config ... }`) explaining the Hyprland-as-greeter-compositor architecture decision. This documents WHY ReGreet runs inside Hyprland instead of cage — the keyboard layout toggle (Alt+Shift, es<->latam) at the login screen is a hard requirement that cage cannot fulfill.

**Design reference**: design.md Section 2.6 (exact comment block), Section 2.6 rationale.

**After** (insert after the file header comment, before the `{ config ... }` lambda):
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
#
# Recovery: if the greeter fails, append systemd.mask=greetd.service to the
# kernel cmdline at the systemd-boot menu to skip greetd and drop to a VT
# login prompt.  The system keymap (la-latin1) is active on VTs.
```

**Spec reference**: REQ-HC-003 (ADDED), REQ-GS-005 (documentation of VT fallback).

**Verification**:
- [ ] `format-nix` on `omarchy.nix` — nixfmt preserves multi-line `#` comments
- [ ] `nix flake check --no-build` passes for t14
- [ ] `nix build .#homeConfigurations.glats@t14.activationPackage --no-link` succeeds
- [ ] Read the file to confirm the comment block is present and correctly positioned (before imports, after module doc header)

---

## Phase 3: Omarchy-Nix Companion PR (Hyprsunset Migration + Greeter Script)

All changes in this phase go into a single omarchy-nix companion PR. Both tasks are in the omarchy-nix repository at `/home/glats/repos/omarchy-nix`.

---

### 3.1 Migrate omarchy-nix hyprsunset module from raw config to `services.hyprsunset`

**Repository**: `/home/glats/repos/omarchy-nix`
**File**: `modules/home-manager/hyprsunset.nix`

**What**: Replace the current raw config approach (`xdg.configFile."hypr/hyprsunset.conf"` + `systemd.user.services.hyprsunset`) with the Home Manager `services.hyprsunset` module. This lets per-host configs (like t14) override settings via `services.hyprsunset.settings` without raw config conflicts.

**Why**: The HM module `services.hyprsunset` owns both the config file AND the systemd unit internally. Using raw config alongside it would create duplicate-path conflicts. By migrating omarchy-nix to use the HM module as the source of truth, hosts get a clean `services.hyprsunset.settings` interface to customize.

**Before** (current raw config approach — two manual blocks):
```nix
xdg.configFile."hypr/hyprsunset.conf".text = ''
  profile { time = 07:00; identity = true; }
'';
systemd.user.services.hyprsunset = { ... };
```

**After** (HM module):
```nix
services.hyprsunset = {
  enable = lib.mkDefault true;
  settings.profile = [
    { time = "07:00"; identity = true; }
  ];
};
```

Use `lib.mkDefault` so per-host configs can override `enable` or `settings`.

**Verification** (in omarchy-nix repo):
- [ ] `nix flake check --no-build` passes
- [ ] `nix build .#homeManagerModules.default --no-link` (or equivalent build target) succeeds
- [ ] `grep -c "xdg.configFile.*hyprsunset" modules/home-manager/hyprsunset.nix` returns 0 (raw config removed)
- [ ] `grep "services.hyprsunset" modules/home-manager/hyprsunset.nix` confirms HM module usage

---

### 3.2 Extract greeter script to `writeShellScriptBin` with 2s timeout and stderr logging

**CRITICAL**: The greeter is the ONLY path to graphical login. A broken greeter bricks the login screen.

**Repository**: `/home/glats/repos/omarchy-nix`
**File**: `modules/nixos/system.nix`

**What**: Convert the existing `greeterScript = pkgs.writeShellScript "greetd-regreet-start" ...` let-binding to `pkgs.writeShellScriptBin "greetd-regreet-start"`. This gives the script a named derivation visible in `/nix/store/` as `*-greetd-regreet-start/bin/greetd-regreet-start`, making it independently testable and debuggable. Also:
1. Extend the monitor enumeration polling loop from 10x100ms (1s) to 20x100ms (2s total timeout)
2. Add stderr logging at each phase boundary (enumeration, panel disable, regreet launch)
3. Add a WARNING log to stderr if enumeration times out
4. Update the `exec-once` reference from `${greeterScript}` to `${greeterScript}/bin/greetd-regreet-start`

**Design reference**: design.md Section 2.7 (full after script), Section 2.7 rationale for 2s timeout and stderr logging.

**Key code changes** (in `system.nix`):

1. Change the `let greeterScript =` line to use `writeShellScriptBin`:
```nix
greeterScript = pkgs.writeShellScriptBin "greetd-regreet-start" ''
```

2. Inside the script body, replace the monitor enumeration loop (line ~204-212) with 2s budget and stderr warning:
```bash
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
```

3. Add phase-boundary stderr logging (add `echo ... >&2` lines before/after each phase):
```bash
# Phase 1: monitor selection
# ... (existing TARGET_MON logic with stderr logging added)

# Phase 2: internal panel disable
echo "[greetd-regreet-start] checking external displays" >&2
# ... (existing panel disable logic)
echo "[greetd-regreet-start] panel disable done" >&2

# Phase 3: launch greeter
echo "[greetd-regreet-start] launching regreet" >&2
# ... (existing regreet + hyprctl dispatch exit)
```

4. Update the `exec-once` reference in the `in ''...''` config string body:
```
exec-once = ${greeterScript}/bin/greetd-regreet-start
```

**Spec references**: REQ-GS-001 (MODIFIED — extract to standalone script), REQ-GS-002 (ADDED — 2s timeout), REQ-GS-003 (ADDED — stderr logging).

**Verification** (in omarchy-nix repo):
- [ ] `nix flake check --no-build` in `/home/glats/repos/omarchy-nix` passes
- [ ] `nix build .#nixosModules.default --no-link` succeeds (or equivalent omarchy-nix build target)
- [ ] Verify the script binary path: build the module and locate `greetd-regreet-start` — it must be under `*/bin/greetd-regreet-start`, not a bare hash
- [ ] Inspect the generated script: `nix-store -q $(nix-build ...)/bin/greetd-regreet-start` is a readable shell script with the 2s loop and stderr `echo` lines
- [ ] `grep "writeShellScriptBin\|greetd-regreet-start/bin" modules/nixos/system.nix` confirms the change

**Pre-flight VT fallback test** (BEFORE switching to the new greeter):
- [ ] Boot t14, edit the kernel cmdline at the systemd-boot menu (press `e`), append `systemd.mask=greetd.service`, boot. Confirm a VT login prompt appears. This is the recovery path if the greeter breaks.

**Runtime verify** (AFTER switching to the new config):
- [ ] `nixos-build`, reboot. The greeter Hyprland session must start, ReGreet must appear on the configured focus monitor (LEN G24).
- [ ] `journalctl -b _COMM=Hyprland --since "5 min ago" | grep greetd-regreet-start` (or `journalctl -u greetd`) shows the new stderr log lines (phase start/completion messages).
- [ ] If enumeration is fast, no WARNING appears. On a cold boot with slow DRM, the WARNING should still not appear with the 2s budget (1s was borderline; 2s should be ample).

---

### 3.3 PR the omarchy-nix changes and merge

**Repository**: `/home/glats/repos/omarchy-nix`

**What**: Create a branch, commit both the hyprsunset migration AND the greeter script extraction as a single companion PR, push, open a PR on the omarchy-nix repo, review, and merge. glats owns the repo with full push access.

**Verification** (GitHub):
- [ ] Branch created: `refactor/hyprsunset-greeter-script` (or similar)
- [ ] PR opened against omarchy-nix `main` branch
- [ ] PR description references the nixos-hosts SDD change name (`omarchy-hyprland-regreet-refactor`) for traceability
- [ ] PR includes both commits: hyprsunset migration + greeter script extraction
- [ ] PR merged to `main`

---

## Phase 4: Hyprsunset Migration in t14 (nixos-hosts, depends on Phase 3 merge)

This change depends on the omarchy-nix companion PR (Phase 3) being merged -- the HM module `services.hyprsunset` must be enabled by omarchy-nix before t14 can override its settings.

---

### 4.1 Migrate t14 hyprsunset from raw config to `services.hyprsunset.settings`

**File**: `hosts/t14/home/hypr/hyprsunset.nix`

**What**: Replace the raw `xdg.configFile."hypr/hyprsunset.conf"` with Home Manager's `services.hyprsunset.settings`. This uses the HM module (now enabled by omarchy-nix after Phase 3.1) to declaratively configure the progressive blue-light filter schedule, without raw config conflicts.

**Why**: The HM `services.hyprsunset` module provides a type-safe `settings.profile` interface (list of attrsets, rendered via `lib.hm.generators.toHyprconf`). Using it means t14 overrides omarchy-nix's defaults cleanly via the module system instead of fighting over a raw config file. `lib.mkForce` ensures t14's profile wins over omarchy-nix's default.

**Design reference**: design.md Section 2.3 (verified `services.hyprsunset.settings.profile` type).

**Before** (raw config -- `xdg.configFile`):
```nix
xdg.configFile."hypr/hyprsunset.conf".text = ''
  profile { time = 07:00; identity = true; }
  profile { time = 07:00; identity = true; }
  profile { time = 18:00; temperature = 4500; }
  profile { time = 19:30; temperature = 4000; }
  profile { time = 21:00; temperature = 3500; }
  profile { time = 23:00; temperature = 3000; }
'';
```

**After** (HM module -- `services.hyprsunset.settings`):
```nix
{ lib, ... }:

{
  services.hyprsunset.settings.profile = lib.mkForce [
    { time = "07:00"; identity = true; }
    { time = "18:00"; temperature = 4500; }
    { time = "19:30"; temperature = 4000; }
    { time = "21:00"; temperature = 3500; }
    { time = "23:00"; temperature = 3000; }
  ];
}
```

Note: the duplicate `07:00 identity=true` profile (copy-paste artifact in the old raw config) is intentionally removed. One is sufficient.

**Spec reference**: REQ-HS-003 (ADDED), REQ-HS-001 (MODIFIED).

**Verification**:
- [x] `format-nix` on `hyprsunset.nix`
- [x] `nix flake check --no-build` passes for t14 (after omarchy-nix flake bump)
- [x] `nix build .#homeConfigurations.glats@t14.activationPackage --no-link` succeeds (NixOS-integrated HM via toplevel; standalone HM has pre-existing `home.hyprdynamicmonitors` issue unrelated to this change)
- [x] `grep -c "xdg.configFile.*hyprsunset" hosts/t14/home/hypr/hyprsunset.nix` returns 0
- [x] `grep "services.hyprsunset" hosts/t14/home/hypr/hyprsunset.nix` confirms HM module usage
- [ ] Generated hyprsunset.conf at `~/.config/hypr/hyprsunset.conf` contains the 5 profiles (no duplicates) -- requires runtime deploy on t14

---

## Phase 5: Integration and Final Verification (nixos-hosts)

This phase integrates the merged omarchy-nix companion PR into nixos-hosts via a flake input bump and runs full-system verification including the greeter recovery test.

---

### 5.1 Bump omarchy-nix flake input in nixos-hosts

**File**: `flake.lock` (auto-updated by `nix flake lock --update-input`)

**What**: After the omarchy-nix companion PR (Phase 3) is merged, update the nixos-hosts `omarchy-nix` flake input to point to the merged commit.

**Steps**:
```bash
nix flake lock --update-input omarchy-nix
```

**Verification**:
- [x] `nix flake check --no-build` passes for t14
- [x] `nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link` succeeds
- [x] `git diff flake.lock` shows the omarchy-nix revision updated to include the greeter script extraction commit (`7e34e85...` -> `e37c3d2...`)
- [x] Grep the built toplevel for `greetd-regreet-start` to confirm the script path has the `/bin/` component (confirmed via build log showing `greetd-regreet-start.drv`)

---

### 5.2 Greeter recovery test (VT fallback)

**What**: Confirm the VT escape hatch works with the NEW greeter script. This is the final safety-net verification before declaring the change complete.

**Steps**:
1. Boot t14 normally with the new greeter (after Phase 4.1 flake bump + rebuild)
2. Confirm ReGreet appears on the login screen
3. Reboot, edit the systemd-boot entry (`e` key), append `systemd.mask=greetd.service` to the kernel cmdline line
4. Boot — confirm a VT login prompt appears (greetd is masked, no graphical greeter)
5. Log in as glats, verify the system is fully functional
6. Reboot normally (without the kernel param) — confirm the greeter is back

**Verification**:
- [ ] With `systemd.mask=greetd.service`: VT login prompt appears
- [ ] User can log in and run commands
- [ ] Without the kernel param: ReGreet login screen appears normally
- [ ] This recovery path is documented in `hosts/t14/home/omarchy.nix` (from Phase 2.2)

---

### 5.3 Final whole-PR verification

**What**: Run the complete verification suite for the assembled nixos-hosts PR (all Phase 1 + Phase 2 + Phase 4 + Phase 5.1 commits together).

**Steps**:
```bash
format-nix
nix flake check --no-build
nix build .#nixosConfigurations.t14.config.system.build.toplevel --no-link
nix build .#homeConfigurations.glats@t14.activationPackage --no-link
nixos-build dry
```

**Verification checklist**:
- [x] `nix flake check --no-build` exits 0
- [x] `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds
- [x] `nix build .#homeConfigurations.glats@t14.activationPackage` succeeds (via NixOS-integrated HM path; standalone HM has pre-existing `home.hyprdynamicmonitors` issue)
- [x] `nixos-build dry` shows deltas ONLY on t14 -- no rog/thinkcentre/mact2 changes (only `home-manager-glats.service` restart)
- [x] `git diff --stat` total additions+deletions is under 400 lines (16 insertions, 52 deletions = 68 total)
- [x] `grep -r WLR_RENDERER_ALLOW_SOFTWARE hosts/` returns only a comment reference (env var was removed in Phase 1.1)
- [x] `grep -r "xdg.configFile.*hyprsunset" hosts/t14/` returns no matches (hyprsunset uses HM module now)
- [x] `grep "services.hyprsunset" hosts/t14/home/hypr/hyprsunset.nix` confirms HM module usage
- [x] Omarchy-nix flake input revision in `flake.lock` points to the merged Phase 3 commit (`e37c3d23183db`)

---

## Out of Scope (recorded for traceability)

| Item | Status | Reason |
|------|--------|--------|
| boot-settings consolidation | **OUT** | User decision during proposal review. `boot-settings.enable = true` stays on t14. `modules/features/boot.nix` is NOT deleted (rog/thinkcentre still use it). |

---

## Commit Plan (nixos-hosts PR only)

Ordered by risk (lowest first), one commit per task. Omarchy-nix companion PR ships separately with both hyprsunset and greeter commits.

```
Commit 1: remove WLR_RENDERER_ALLOW_SOFTWARE (Phase 1.1)
Commit 2: gate full-opacity windowrule (Phase 1.2)
Commit 3: tighten waybar restart limits (Phase 2.1)
Commit 4: add greeter architecture documentation (Phase 2.2)
Commit 5: migrate hyprsunset to services.hyprsunset.settings (Phase 4.1) -- after omarchy-nix PR merges
Commit 6: bump omarchy-nix flake input (Phase 5.1) -- after omarchy-nix PR merges
```

Each commit is independently verifiable and revertible. Rollback per commit via `git revert`. System rollback via `nixos-build --rollback`.

---

## Recovery

The greeter is the ONLY path to graphical login. The escape hatch is documented in `hosts/t14/home/omarchy.nix` (Phase 2.2) and verified in Phase 4.2:

1. Reboot, press `e` at the systemd-boot menu to edit the kernel cmdline
2. Append `systemd.mask=greetd.service`  
3. Boot — the system drops to a VT login prompt (greetd is masked)
4. Log in as glats, fix the configuration, rebuild, reboot normally
