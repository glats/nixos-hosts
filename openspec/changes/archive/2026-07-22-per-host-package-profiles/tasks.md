# Tasks: Per-Host Package Profiles

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~17 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Remove from shared profiles

- [x] 1.1 `linux/system/base/profiles/core.nix`: remove `asus-fan-control`, `pipewire-module-xrdp` (lines 87-88), update comment on line 86
- [x] 1.2 `linux/system/base/profiles/media.nix`: remove `intel-vaapi-driver`, `libva-vdpau-driver` (lines 39-40)

## Phase 2: Add to hosts

- [x] 2.1 `hosts/rog/default.nix`: add `environment.systemPackages` with all 4 packages before closing `}`
- [x] 2.2 `hosts/thinkcentre/default.nix`: add `environment.systemPackages` with 3 packages (no asus-fan-control) before closing `}`

## Phase 3: Verify

- [x] 3.1 Run `format-nix` then `nix flake check --no-build`

## Rollback

`git revert` — identical resolved packages before/after.
