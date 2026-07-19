# Proposal: Fix tmux-resurrect double-restore race

## Intent

`continuum.tmux` runs twice at tmux server start — once via Home Manager's plugin
`run-shell` (before extraConfig) and once manually in `extraConfig` (line 55 of
`home-linux/tmux.nix`). Both trigger `start_auto_restore_in_background()`. The
second restore's cleanup deletes `restore/pane_contents/` before the first
restore's shells finish reading pane content files, causing:

```
cat: '.../restore/pane_contents//pane-nixos:1.0': No such file or directory
```

Eliminate the duplicate `run-shell` while preserving the save-interval
status-right interpolation that gets overwritten by extraConfig's themed
`set -g status-right`.

## Scope

### In Scope

- `home-linux/tmux.nix` lines 50–56: replace the second `run-shell
  continuum.tmux` with a targeted `set -g status-right` that only re-adds the
  save interpolation
- Verified: Darwin config (`home-darwin/tmux.nix`) uses TPM — no double-run
  pattern, no fix needed

### Out of Scope

- Plugin list, shared config (`shared/tmux.nix`), continuum/resurrect options
- Patching continuum upstream or nixpkgs

## Capabilities

### New Capabilities

None

### Modified Capabilities

None — pure config fix, no spec-level behavior changes.

## Approach

Replace the manual `run-shell` (line 55) that re-runs continuum's full `main()`
with an inline `set -g status-right` that only re-adds the save interpolation:

```nix
# Before (line 55):
#   run-shell ${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux

# After:
set -g status-right "#(${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/scripts/continuum_save.sh) #{status-right}"
```

This replicates exactly what `add_resurrect_save_interpolation()` does in
`continuum.tmux:main()`. It runs synchronously during config processing, after
shared's `set -g status-right` overwrites the first continuum run's
interpolation. The `#{status-right}` format expands to the themed value from
shared, preserving all base16 colors.

**Idempotency safe**: The first continuum background run's
`add_resurrect_save_interpolation()` checks whether the interpolation is already
present before prepending. Our inline `set -g` runs first (synchronous config
processing), so the first continuum run sees it and skips — no double
interpolation.

**No second restore**: Without the second `run-shell continuum.tmux`, there is
no second call to `just_started_tmux_server()` → `start_auto_restore_in_background()`.
The race condition is eliminated.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/tmux.nix` L54-56 | Modified | Replace `run-shell *continuum.tmux` with inline status-right interpolation |
| `home-darwin/tmux.nix` | Verified (no change) | TPM-based, no double-run pattern |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `continuum_save.sh` path changes in future nixpkgs | Low | Same path pattern as existing `continuum.tmux` reference; both would break together |
| First continuum run's interpolation races with our inline set | Low | Continuum's `add_resurrect_save_interpolation()` has an idempotency check — skips if already present |

## Rollback Plan

Revert the changed lines to the current `run-shell
${pkgs.tmuxPlugins.continuum}/share/tmux-plugins/continuum/continuum.tmux`.
One-line revert. The race condition returns but status-right works as before.

## Dependencies

None

## Success Criteria

- [ ] Generated tmux.conf contains exactly ONE `run-shell .../continuum.tmux` (the HM-generated one)
- [ ] status-right includes `#(continuum_save.sh)` save-interval interpolation after config load
- [ ] No `cat: .../pane_contents//pane-*: No such file or directory` at tmux server start
- [ ] `nix flake check --no-build` passes for rog
