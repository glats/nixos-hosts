# Tasks: Rename btop theme to `glats` across all NixOS hosts

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~10 (3 file paths + 2 color_theme strings + 3 comment updates) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | single-pr-default |
| Chain strategy | size-exception (not needed; under budget) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Rename btop theme to `glats` on all Linux hosts | PR 1 | base: main; single commit; touches 3 files |

## Phase 1: Rename theme file path

- [x] 1.1 In `home-linux/btop-theme.nix` line 61, change `home.file."~/.config/btop/themes/nix-colors.theme"` → `home.file."~/.config/btop/themes/glats.theme"`
- [x] 1.2 In the header comment of `home-linux/btop-theme.nix` line 3, replace `nix-colors.theme` with `glats.theme`
- [x] 1.3 In `home-linux/btop-theme.nix`, add a one-line comment near the `home.file` attr noting that on t14 this path is also written by `inputs.omarchy-nix/modules/home-manager/btop.nix` from the byte-identical glats palette (convergence, not a conflict)

## Phase 2: Update `color_theme` references

- [x] 2.1 In `home-linux/btop-file.nix` line 17, change `color_theme = "nix-colors"` → `color_theme = "glats"` (rog, thinkcentre)
- [x] 2.2 In `home-linux/btop-file.nix` lines 12-13, update the inline comment to reference `glats` instead of `nix-colors`
- [x] 2.3 In `home-linux/btop-settings.nix` line 16, change `color_theme = lib.mkForce "nix-colors"` → `color_theme = lib.mkForce "glats"` (t14)
- [x] 2.4 In `home-linux/btop-settings.nix` line 8, update the inline comment to reference `glats` instead of `nix-colors`

## Phase 3: Verification

- [x] 3.1 Run `nix flake check --no-build` — must pass
- [x] 3.2 Run `format-nix` — no new formatting regressions
- [x] 3.3 Grep the repo for stray `nix-colors` references under `home-linux/btop*` and `hosts/*/home/omarchy.nix` — should return zero matches in btop scope
- [x] 3.4 Confirm no other `home.file."~/.config/btop/themes/..."` writers exist outside `home-linux/btop-theme.nix` and `inputs.omarchy-nix` (no third writer introduced)

## Phase 4: Rollback readiness

- [x] 4.1 Document in the apply-progress artifact that `home.file` overwrites any user-edited `nix-colors.theme` on next switch (per proposal risk row 2)
- [x] 4.2 Note in apply-progress that `nixos-rebuild switch --rollback` on the affected host restores the previous generation with `nix-colors.theme` and `color_theme = "nix-colors"`

## Notes

- Out of scope: visual parity drift between rog/thinkcentre and t14 (#1269); darwin `home-darwin/btop.nix` rename (per proposal).
- Post-apply (not blocking this change): on each host, run `ls ~/.config/btop/themes/` and `grep color_theme ~/.config/btop/btop.conf` to confirm `glats.theme` and `color_theme = "glats"` are active.
