# Tasks: T14 hyprctl reload causes resets on workspace switch

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~6 (1 deleted, 2 modified, 3 deleted) |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes — cross-repo (nixos-hosts + omarchy-nix) |
| Suggested split | PR 1 (omarchy-nix) → PR 2 (nixos-hosts, includes flake.lock bump) |
| Delivery strategy | ask-on-risk (guided — pause before apply) |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Remove reload sources in omarchy-nix (Tasks 2.1, 2.2) | PR 1 → main | Base: `main` of `glats/omarchy-nix`. Owner-push, fast turnaround. |
| 2 | Remove daemon reload + filter workspaces in nixos-hosts (Tasks 1.1, 1.2, 3.4) | PR 2 → main | Base: `main` of `glats/nixos-hosts`. Includes `flake.lock` bump pinning `omarchy-nix` to merged PR 1 commit. |

## Phase 1: nixos-hosts changes (independent of Phase 2)

- [ ] **1.1** Remove `hyprctl reload` from validator — file: `hosts/t14/home/scripts/monitor-lid-validator.sh` (delete line 47). Acceptance: `apply()` ends after the `case` block; no `hyprctl reload` line remains in file. Dependencies: none. Complexity: trivial.
- [ ] **1.2** Filter workspaces 1-3 from `mkWorkspaceRules` — file: `hosts/t14/home/hypr/monitors.nix` (line 23, inside `lib.imap1` call). Acceptance: `workspaces` becomes `(builtins.filter (w: w > 3) workspaces)`; `nix flake check --no-build` passes; external-monitor rules list contains only workspaces ≥ 4. Dependencies: none. Complexity: simple.

## Phase 2: omarchy-nix changes (independent of Phase 1)

- [ ] **2.1** Remove `monitoradded>>` reload handler — file: `bin/omarchy-hyprland-monitor-watch` (delete lines 9–11: pattern, `hyprctl reload`, `;;`). Acceptance: `monitorremoved>>` branch intact and unchanged; no `hyprctl reload` remains anywhere in the file. Dependencies: none. Complexity: trivial.
- [ ] **2.2** Capture waybar stderr — file: `modules/home-manager/hyprland/autostart.nix` (line 14). Acceptance: waybar launch line reads `"pkill -x waybar; uwsm-app -- waybar 2>>$HOME/.cache/waybar-stderr.log"`; all other exec-once entries unchanged. Dependencies: none. Complexity: simple.

## Phase 3: Verification & integration

- [ ] **3.1** Run `nix flake check --no-build` in nixos-hosts after Phase 1. Acceptance: command exits 0. Dependencies: 1.1, 1.2. Complexity: simple.
- [ ] **3.2** Run `format-nix` in nixos-hosts. Acceptance: no diffs reported on modified files. Dependencies: 3.1. Complexity: simple.
- [ ] **3.3** Run `nix flake check --no-build` in `/home/glats/repos/omarchy-nix` after Phase 2. Acceptance: command exits 0. Dependencies: 2.1, 2.2. Complexity: simple.
- [ ] **3.4** Bump `flake.lock` in nixos-hosts to pin `omarchy-nix` to PR 1 merged commit. Acceptance: `nix flake lock --update-input omarchy-nix` succeeds; new commit hash appears under the `omarchy-nix` node. Dependencies: PR 1 merged. Complexity: simple.
- [ ] **3.5** Re-run `nix flake check --no-build` in nixos-hosts after lock bump. Acceptance: command exits 0 against the new lock. Dependencies: 3.4. Complexity: simple.
- [ ] **3.6** Commit Phase 1 + Phase 3.4 changes together as PR 2 against nixos-hosts `main`. Acceptance: PR 2 commits contain only the two nixos-hosts source edits + lock bump; no stray files. Dependencies: 3.2, 3.5. Complexity: simple.
