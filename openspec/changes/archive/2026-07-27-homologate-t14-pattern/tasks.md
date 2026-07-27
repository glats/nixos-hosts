# Tasks: Homologate t14 → rog Pattern

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~150 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Foundation — Strip t14 inline HM block

- [ ] 1.1 In `hosts/t14/default.nix`: remove the 14-line inline HM block, replace with one bridge import: `import ../../linux/system/base/home-manager.nix { inherit inputs; hostName = "t14"; }`

## Phase 2: Convert home/default.nix

- [ ] 2.1 Rewrite `hosts/t14/home/default.nix` from HM module set to list function `{ inputs }:`. Import shared-modules, filter out 4 excluded paths (theme, fontconfig, alacritty, gpg) via `builtins.filter`, append t14-specific modules (omarchy.nix, remote-desktop.nix, shell-gpt.nix, HDM)

## Phase 3: Absorb old default.nix body into omarchy.nix

- [ ] 3.1 Move waybar svc, kb scripts, HDM config, mouse-wiggle from old `home/default.nix` body into `hosts/t14/home/omarchy.nix` via inline imports. Remove 14 redundant paths and the `./default.nix` import

## Phase 4: Flake wiring + verify

- [ ] 4.1 Update `flake.nix`: t14 standalone HM uses `./home/default.nix { inherit inputs; }` + HDM
- [ ] 4.2 Verify: `nix flake check --no-build` passes, `nix build .#nixosConfigurations.t14.config.system.build.toplevel` builds

## Implementation Order

1 → 2 → 3 → 4. Each step depends on the previous. Phase 4 is verification.
