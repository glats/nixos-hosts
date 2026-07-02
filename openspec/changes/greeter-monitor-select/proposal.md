# Proposal: greeter-monitor-select (v2)

## Intent

ReGreet lands on the wrong monitor when t14 is docked. All Hyprland window-rule approaches are dead: `windowrulev2` returns a hard error since 0.53+; `windowrule monitor` has the same focus-stealing bugs (#8942, #9365, #8262) unfixed in 0.55+ Lua. The only viable path is script-based monitor disable via stable IPC.

## Deprecation Timeline

| Version | `windowrulev2` | `windowrule monitor` |
|---|---|---|
| 0.48 (2025-03) | Syntax break | Legacy syntax works |
| 0.53 (2026-02) | **Hard error** (#12847) | Same bugs as v2 |
| 0.55 (2026-05) | Removed; Lua is default | Lua backend = same broken code path |

## Scope

**In**: Extend `greetd-regreet-start` script; add `focusMonitor` option; set it for t14.
**Out**: User session layout, other hosts, upstream fix, nwg-hello, Lua migration.

## Approach

**Script-based monitor disable — the ONLY viable path.**

1. Retry `hyprctl monitors -j` until non-empty (10 × 0.1s)
2. Match target by `focusMonitor` substring via `jq contains`
3. `hyprctl keyword monitor <other>,disable` for non-target externals
4. `hyprctl dispatch focusmonitor <target>`
5. Existing eDP-1 disable + regreet + exit (unchanged)

**Evidence**: vaxerski endorses `monitor X,disable` (#4789). EndoliteMatrix/hyprland-dock-undock-automation uses identical pattern in production. All IPC commands stable since Hyprland 0.30.

**Alternatives dead**: B (windowrule — bugs unfixed), C (nwg-hello — Plan B, ~80 lines + new module), D (hyprlogin — not in nixpkgs), E (SDDM — Hyprland unsupported).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/modules/nixos/system.nix` | Modified | +20 lines: retry + jq match + disable loop |
| `omarchy-nix/config.nix` | Modified | +5 lines: `focusMonitor` option |
| `hosts/t14/default.nix` | Modified | +1 line: `focusMonitor = "LEN G24"` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `hyprctl monitors -j` empty at exec-once | Med | Retry loop; fall back to current behavior |
| Description substring mismatch | Low | Specific substring `"LEN G24"`; empty = safe fallback |
| `jq` missing from greeter PATH | Low | Already in `start-hyprland` env |

## Rollback

Remove `focusMonitor` line → script skips selection, current behavior preserved. Full revert: `git revert` on omarchy-nix submodule bump.

## Success Criteria

- [ ] Docked: ReGreet on DP-4 (Lenovo)
- [ ] Undocked: ReGreet on eDP-1 (no regression)
- [ ] `focusMonitor = ""`: unchanged on all hosts
- [ ] `nix flake check --no-build` passes
- [ ] Graceful degradation on `hyprctl`/`jq` failure

## Effort

~30 lines, 3 files, single commit.
