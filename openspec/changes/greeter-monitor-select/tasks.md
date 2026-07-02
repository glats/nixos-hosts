# Tasks: greeter-monitor-select — script-based monitor selection for t14 ReGreet

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~30 net (omarchy-nix: ~25; nixos-hosts: +1 + flake.lock auto) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | 1 omarchy-nix PR (2 commits) → 1 nixos-hosts PR (1 commit) |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Repo | Base |
|------|------|------|------|
| 1 | `focusMonitor` option surface in `omarchy.greeter` | omarchy-nix | main |
| 2 | Monitor selection phase in `greetd-regreet-start` | omarchy-nix | main |
| 3 | Set `focusMonitor = "LEN G24"` on t14 + flake bump | nixos-hosts | master |

## Phase 1: Option surface (omarchy-nix, commit 1 of 2) — REQ-4

- [ ] 1.1 In `/home/glats/repos/omarchy-nix/config.nix`, inside the `greeter` submodule options block, add `focusMonitor = lib.mkOption { type = lib.types.str; default = ""; ... }` AFTER the `monitors` option (line 329) and BEFORE the `cursor` submodule (line 331). Description must note: matches `description` field from `hyprctl monitors -j` via `jq contains`; empty string = pre-change behavior. Verify: `nix flake check --no-build` inside omarchy-nix passes.

## Phase 2: Wire behavior (omarchy-nix, commit 2 of 2) — REQ-1, REQ-2, REQ-3, REQ-4

- [ ] 2.1 In `/home/glats/repos/omarchy-nix/modules/nixos/system.nix`, modify `greeterScript` (lines 196-207) to insert a "PHASE 1: Monitor selection" block BEFORE the existing `/sys/class/drm` loop. Body follows the design.md script sketch (lines 85-115): set `FOCUS=${cfg.greeter.focusMonitor}`, guard with `if [ -n "$FOCUS" ]`, retry `${pkgs.hyprland}/bin/hyprctl monitors -j` 10×0.1s guarded by `${pkgs.jq}/bin/jq -e 'length > 0'`, pipe through `${pkgs.jq}/bin/jq -r --arg d "$FOCUS" '.[] | select((.description // "") | contains($d)) | .name' | head -1` for `TARGET_MON`, iterate `.[].name` and `${pkgs.hyprland}/bin/hyprctl keyword monitor "$m,disable"` for non-`eDP-*` non-target monitors, then `${pkgs.hyprland}/bin/hyprctl dispatch focusmonitor "$TARGET_MON"`. All `hyprctl`/`jq` calls redirect `2>/dev/null`. Verify: `nix flake check --no-build` inside omarchy-nix passes.

## Phase 3: Enable on t14 (nixos-hosts) — REQ-5

- [ ] 3.1 In `/home/glats/.nixos/hosts/t14/default.nix`, inside `greeter = { ... }` (line 180), add `focusMonitor = "LEN G24";` immediately after `type = "regreet";` (line 181) with a one-line comment noting it matches `"Lenovo Group Limited LEN G24-10 U5B4GWF1"` in the existing `monitors` list.
- [ ] 3.2 From `/home/glats/.nixos`, run `nix flake lock --update-input omarchy-nix` (no edit to `flake.nix` — input already tracks main).
- [ ] 3.3 From `/home/glats/.nixos`, run `format-nix` (per AGENTS.md) and `nix flake check --no-build` (per AGENTS.md "before finishing" rule).

## Phase 4: User-side verification (manual, on t14) — REQ-1..5

- [ ] 4.1 Docked (SC-1.1, SC-2.1): dock Lenovo + AOC, `nixos-rebuild switch`, confirm regreet on Lenovo G24-10 (DP-4), AOC disabled via `hyprctl monitors`.
- [ ] 4.2 Undocked (SC-4.2): undock, `nixos-rebuild switch`, confirm regreet on eDP-1, selection phase no-ops.
- [ ] 4.3 Empty (SC-4.1): temporarily `focusMonitor = "";`, `nixos-rebuild switch`, confirm no selection runs; restore `"LEN G24"`.
- [ ] 4.4 Spot-check the generated script (`cat /nix/store/.../bin/greetd-regreet-start` or `which greetd-regreet-start | xargs cat`) — confirm selection phase present and `FOCUS=LEN G24` literal baked in.
