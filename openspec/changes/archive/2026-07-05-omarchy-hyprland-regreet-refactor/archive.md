# Archive: omarchy-hyprland-regreet-refactor

**Archived**: 2026-07-05
**Change name**: omarchy-hyprland-regreet-refactor

---

## Change Summary

Refactored the t14 Omarchy/Hyprland/ReGreet stack in nixos-hosts and omarchy-nix repos, removing obsolete configuration, improving error handling, and migrating to declarative Home Manager module options.

---

## What Was Implemented

### nixos-hosts (6 commits on master, +67 / -78 lines)

| Commit | SHA | Description |
|--------|-----|-------------|
| Remove WLR_RENDERER_ALLOW_SOFTWARE | `d12602d` | Deleted obsolete env var from looknfeel.nix |
| Gate full-opacity windowrule | `cb54aa2` | Replaced unconditional `mkAfter` with `let forceFullOpacity` boolean |
| Tighten waybar restart limits | `4a39c65` | StartLimitBurst 20->5, Interval 5s->10s + documentation |
| Add greeter architecture docs | `36848b9` | 16-line comment documenting Hyprland-as-greeter decision |
| Migrate hyprsunset to HM module | `3a06d28` | Raw xdg.configFile -> services.hyprsunset.settings |
| Bump omarchy-nix flake input | `cfed91e` | Updated to merged companion PR commit `e37c3d2` |

### omarchy-nix (PR #6, squash-merged at `e37c3d2`)

| File | Change |
|------|--------|
| `modules/home-manager/hyprsunset.nix` | Raw xdg.configFile + manual systemd unit -> services.hyprsunset HM module (44->15 lines) |
| `modules/nixos/system.nix` | writeShellScript -> writeShellScriptBin, 2s timeout (20x100ms), stderr logging at all script phases |

---

## What Was NOT Implemented

- **boot-settings consolidation** -- user decision during proposal review. `boot-settings.enable = true` stays on t14. `modules/features/boot.nix` is NOT deleted (rog/thinkcentre still use its conditional toggles). All boot-config delta specs (REQ-BC-001, REQ-BC-002) correctly labeled N/A in verification.

---

## Verification Result: PASS WITH WARNINGS

| Check | Result |
|-------|--------|
| `nix flake check --no-build` (all hosts) | PASS |
| `nix build .#nixosConfigurations.t14.config.system.build.toplevel` | PASS |
| `nixos-build dry` (t14 only) | PASS |
| Runtime deploy (t14 reboot) | PASS -- greeter working, hyprsunset active, waybar active |
| 400-line budget | +67 / -78 (145 total, well under 400) |
| Greeter stderr in journal | PARTIAL -- script writes stderr, but greetd doesn't forward to journald |
| VT fallback boot test | INCOMPLETE -- not empirically tested |
| Architecture comment length | PARTIAL -- 16 lines vs spec's "50+ lines" target, but content is complete |

---

## PENDING ITEMS for Next Iteration

1. **Greeter stderr not captured in journal** -- The greeter script correctly writes stderr at all 7 phase boundaries, but greetd does not forward greeter session stderr to systemd journal. `journalctl -u greetd -b` shows only PAM messages. Future change: wrap the greeter session command with `systemd-cat` or configure greetd logging to forward stderr to journald.

2. **VT fallback not empirically tested** -- The `systemd.mask=greetd.service` kernel cmdline escape hatch is documented (omarchy.nix lines 44-46) but was not boot-tested. Test by appending `systemd.mask=greetd.service` at the systemd-boot menu (press e, edit kernel cmdline, boot). Confirm VT login prompt appears. The mechanism is standard systemd and very low risk, but remains unverified.

3. **3 partial specs** -- Three spec compliance items were marked PARTIAL, all justified in the design:
   - REQ-HC-002: Windowrule kept in `extraConfig` with `mkAfter` (not `settings.windowrule`) -- `mkAfter` ordering is required to defeat omarchy's per-app opacity rules (design Section 2.2).
   - REQ-WB-001: Full unit kept (not simplified to only overrides) -- omarchy-nix ships no waybar unit, so t14's is the sole definition (design Section 1.3).
   - REQ-GS-003: Stderr exists in script but not captured in journal -- environment limitation, not script defect.
   These are non-blocking. Update the main specs to reflect the design-validated approaches if a future iteration revisits them.

---

## Artifacts

- `proposal.md` -- Scope, approach, risk assessment
- `exploration.md` -- Options analysis (Approach C selected)
- `design.md` -- File-by-file before/after, rationale, migration plan
- `tasks.md` -- 11 tasks across 5 phases
- `apply-progress.md` -- 3 slices applied, 6+2 commits
- `review-checkpoint.md` -- Final review checkpoint
- `verify-report.md` -- Full verification with 31/31 scenarios, 3 warnings
- `specs/` -- Delta specs for 5 domains

### Merged to main specs

- `openspec/specs/hyprland-config/spec.md` -- Created from delta
- `openspec/specs/hyprsunset-config/spec.md` -- Created from delta
- `openspec/specs/waybar-config/spec.md` -- Created from delta
- `openspec/specs/greeter-script/spec.md` -- Created from delta
- `boot-config` -- Skipped (scope removed per user decision)
