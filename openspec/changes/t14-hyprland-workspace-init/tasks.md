# Tasks: t14-hyprland-workspace-init

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~12 net (monitors.nix: ~6 inlined into 2 functions + 4 eDP-1 lines; monitor-lid-validator.sh: +1) |
| 400-line budget risk | Low |
| Chained PRs recommended | No (single repo, well under budget) |
| Suggested split | 1 single direct-to-main commit per file (2 commits total) |
| Delivery strategy | direct commits on main (per session config) |
| Chain strategy | size-exception (under 400-line review budget) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| WU | Goal | File | Lines | Acceptance |
|----|------|------|-------|------------|
| WU1 | Refactor `mkWorkspaceRules` with `lib.imap1` to emit `default:true` on first workspace and `persistent:true` on all | `hosts/t14/home/hypr/monitors.nix` | ~3 inside the inner map (replace `map (w: …)` with `lib.imap1 (idx: w: …)`) | SPEC: REQ-DEFAULT, REQ-PERSIST |
| WU2 | Add eDP-1 workspace rules (1, 2, 3) inside `# hyprlang if ENABLE_LAPTOP` block | `hosts/t14/home/hypr/monitors.nix` | +4 lines (3 `workspace = …, monitor:eDP-1, …` + 1 optional blank) | SPEC: REQ-EDP-1 |
| WU3 | Add `hyprctl reload` at the end of `apply()` | `hosts/t14/home/scripts/monitor-lid-validator.sh` | +1 line after the `case`/`esac` | SPEC: REQ-RELOAD, mitigates issue #5464 |

## Phase 1: Workspace-rule refactor in monitors.nix (WU1)

- [x] 1.1 In `hosts/t14/home/hypr/monitors.nix` lines 16–24, replace the inner `map (w: "${toString w}, monitor:desc:${monitor}") workspaces` with `lib.imap1 (idx: w: "${toString w}, monitor:desc:${monitor}, default:${lib.boolToString (idx == 1)}, persistent:true") workspaces`
- [x] 1.2 Verify: read back the function; confirm `imap1` returns 1-based index, `default:true` only on `idx == 1`, `persistent:true` on all entries
- [x] 1.3 Verify: `nix flake check --no-build` builds the t14 toplevel

## Phase 2: eDP-1 workspace rules (WU2)

- [x] 2.1 In `hosts/t14/home/hypr/monitors.nix`, locate the `# hyprlang if ENABLE_LAPTOP` block in `extraConfig` (currently line 48)
- [x] 2.2 Inside that block (before the `monitor = eDP-1, preferred, …` line at line 49), insert:
  ```
  workspace = 1, monitor:eDP-1, default:true, persistent:true
  workspace = 2, monitor:eDP-1, persistent:true
  workspace = 3, monitor:eDP-1, persistent:true
  ```
- [x] 2.3 Verify: confirm the new lines sit inside the `ENABLE_LAPTOP` conditional, NOT the `!ENABLE_LAPTOP` block

## Phase 3: Daemon reload in monitor-lid-validator.sh (WU3)

- [x] 3.1 In `hosts/t14/home/scripts/monitor-lid-validator.sh`, in `apply()` (lines 41–47), add one line `hyprctl reload` immediately after the `case`/`esac` block (line 46) and before the closing `}` (line 47)
- [x] 3.2 Verify: `bash -n hosts/t14/home/scripts/monitor-lid-validator.sh` to confirm syntax
- [x] 3.3 Verify: re-read `apply()`; confirm `hyprctl reload` runs in BOTH `closed` and `*` branches (it is unconditional, after the case)

## Phase 4: Format and commit (direct to main)

- [x] 4.1 Run `format-nix` (per AGENTS.md) to format `hosts/t14/home/hypr/monitors.nix`; re-read to confirm `nixfmt` re-flow is sane
- [x] 4.2 Run `nix flake check --no-build` (per AGENTS.md "before finishing" rule)
- [x] 4.3 Commit WU1 + WU2 as a single commit on `main`: `feat(t14-hyprland): add default+persistent flags to workspace rules` (touches `monitors.nix`) — **split into 2 commits per orchestrator instruction: WU1 = `refactor(t14): add default+persistent flags to workspace rules`, WU2 = `feat(t14): bind workspaces 1-3 to eDP-1 in undocked layout`**
- [x] 4.4 Commit WU3 on `main`: `fix(t14-hyprland): reload hyprland after monitor layout apply` (touches `monitor-lid-validator.sh`)

## Phase 5: Manual verification on t14 (post-merge)

- [ ] 5.1 **SPEC: Docked startup** — with dock connected, `nixos-rebuild switch` + logout; `hyprctl workspaces` shows workspace 1 on `desc:AOC 24P1W1 OTNQ4HA000101`, 2 on Lenovo, 3 on AOC 2470W
- [ ] 5.2 **SPEC: Undocked startup** — undock, restart Hyprland; `hyprctl workspaces` shows workspace 1 on `eDP-1`
- [ ] 5.3 **SPEC: Persistent across empty** — move all windows off workspace 2; confirm it remains in Waybar and `hyprctl dispatch workspace 2` works
- [ ] 5.4 **SPEC: Dock event** — start undocked, plug dock; `journalctl --user -u monitor-lid-validator` shows `apply` + reload; workspaces re-assign to externals
- [ ] 5.5 **SPEC: Lid close** — docked + lid open, close lid; eDP-1 disables, externals move to y=0, no workspace loss
