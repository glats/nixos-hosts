# Tasks: xrdp Compositor Configuration (picom removal, marco compositing)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~8 (5 deletions + 3 edits) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

```
Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low
```

## Phase 1: Remove picom from host module imports

- [x] 1.1 Remove `../../../home-linux/picom.nix` line from `hosts/rog/home/modules.nix` (line 9)
- [x] 1.2 Remove `../../../home-linux/picom.nix` line from `hosts/thinkcentre/home/modules.nix` (line 9)

## Phase 2: Enable marco compositing

- [x] 2.1 Change `compositing-manager = false` to `compositing-manager = true` in `modules/base/dconf.nix`
- [x] 2.2 Remove `locks` block (lines 19-21) from the same dconf database entry

## Phase 3: Format and verify

- [x] 3.1 Run `format-nix` to format changed files
- [x] 3.2 Run `nix flake check --no-build` to validate
