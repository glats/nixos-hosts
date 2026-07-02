# Tasks: tmux-resurrect-continuum-config

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~14 lines across 3 files |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception (trivially under 400-line budget) |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | All 3-file config change + validation | PR 1 (direct to main) | Trivially under 400-line budget; spec scenarios from spec.md "Verification Scenarios" |

## Phase 1: Shared base config

- [ ] 1.1 Add 4 `@continuum-*` options + 1 `@resurrect-processes` line (6 lines total) to `shared/tmux.nix` `extraConfig` after current line 66, per design §1 insertion plan
- [ ] 1.2 Verify: read `shared/tmux.nix` lines 64-75 and confirm all 5 new `set -g` lines appear in order (4 continuum + 1 resurrect-processes)

## Phase 2: Linux plugin declaration

- [ ] 2.1 Add `continuum` to nixpkgs plugin list in `home-linux/tmux.nix` between current lines 38 and 39 (immediately after `resurrect`), per design §2
- [ ] 2.2 Verify: read `home-linux/tmux.nix` lines 37-43 and confirm `continuum` directly follows `resurrect` (order matters: continuum wraps resurrect)

## Phase 3: Darwin plugin declaration + auto-boot skeleton

- [ ] 3.1 Add `set -g @plugin 'tmux-plugins/tmux-continuum'` to `home-darwin/tmux.nix` between current lines 66 and 67 (after `tmux-resurrect`), per design §3
- [ ] 3.2 Add 4-line commented auto-boot skeleton to `home-darwin/tmux.nix` between current lines 69 and 70 (after last plugin decl, before blank line), per design §3
- [ ] 3.3 Verify: read `home-darwin/tmux.nix` lines 64-75; confirm TPM decl present and all 4 auto-boot lines start with `#` (inactive per spec)

## Phase 4: Validation

- [ ] 4.1 Run `nix flake check --no-build` — must exit 0 (validates all 3 files)
- [ ] 4.2 Run `format-nix` to format the 3 modified .nix files
- [ ] 4.3 (Post-apply, Linux) `home-manager switch` on one Linux host, then verify `tmux show-options -g | grep -E 'continuum|resurrect-processes'` returns all 5 options (spec scenarios 1+2)
- [ ] 4.4 (Post-apply, Darwin) `darwin-rebuild switch` on mact2, then verify `ls ~/.config/tmux/plugins/tmux-continuum/` shows cloned repo
- [ ] 4.5 (Post-apply, either) Create panes, wait 15 min, `tmux kill-server`, `tmux` — auto-restore should fire (spec scenarios: auto-save + auto-restore)
