# Proposal: tmux-resurrect-continuum-config

## Intent

Add tmux-continuum plugin to both Linux and Darwin Home Manager configurations to enable automatic session saving and restoration. tmux-resurrect is already configured; continuum is the missing piece that makes the pair actually useful by auto-saving every 15 minutes and auto-restoring on tmux start.

## Scope

### In Scope
- Add `continuum` plugin to Linux plugin list (`home-linux/tmux.nix`)
- Add `tmux-continuum` TPM declaration to Darwin (`home-darwin/tmux.nix`)
- Add explicit `@continuum-*` configuration options to shared base (`shared/tmux.nix`):
  - `@continuum-save-interval '15'` (auto-save every 15 minutes)
  - `@continuum-restore-on-startup on` (auto-restore sessions when tmux starts)
  - `@continuum-boot-options 'alacritty'` (terminal to use for auto-boot)
  - `@continuum-save-on-close on` (save when terminal closes)
- Add `opencode` to `@resurrect-processes` (neovim already in default list; opencode needs explicit entry)
- Add commented auto-boot skeleton for Darwin (launchd structure only, user will test manually)

### Out of Scope
- Auto-boot on Linux (systemd integration) — follow-up if needed
- Functional auto-boot on Darwin (requires manual `boot.sh` step, not Nix-managed)
- Session-aware restore (e.g., `@resurrect-strategy-nvim 'session'`, `tmux-assistant-resurrect`) — user confirmed bare process relaunch is sufficient
- TPM migration on Linux (keep nixpkgs-based plugin management)

## Capabilities

> This section is the CONTRACT between proposal and specs phases.

### New Capabilities
None (pure configuration change, no new spec-level capabilities)

### Modified Capabilities
None (no existing specs to modify)

## Approach

Three-file edit following the established pattern where shared config lives in `shared/tmux.nix` and platform-specific plugin declarations live in the platform files:

1. **`home-linux/tmux.nix:37-42`** — Add `continuum` to the `pkgs.tmuxPlugins;` list after `resurrect`. Order matters: continuum wraps resurrect, so resurrect must be sourced first. The `lib.mkForce` on `extraConfig` (line 48) already re-evaluates `shared/tmux.nix`, so new `@continuum-*` options propagate automatically.

2. **`home-darwin/tmux.nix:65-69`** — Add `set -g @plugin 'tmux-plugins/tmux-continuum'` after `tmux-resurrect`. TPM's `install_plugins` script will clone it on the next activation.

3. **`shared/tmux.nix`** — Add continuum and resurrect options in `extraConfig` near the existing `@resurrect-capture-pane-contents` (line 66):
   ```text
   # tmux-continuum: continuous saving + restore
   set -g @continuum-save-interval '15'
   set -g @continuum-restore-on-startup on
   set -g @continuum-boot-options 'alacritty'
   set -g @continuum-save-on-close on
   # Resurrect process list: nvim already in defaults; add opencode for bare relaunch
   set -g @resurrect-processes 'opencode'
   ```

4. **`home-darwin/tmux.nix`** — Add commented auto-boot skeleton in extraConfig (before TPM plugin declarations):
   ```text
   # Auto-boot on macOS (requires manual setup):
   # 1. Run: ~/.config/tmux/plugins/continuum/boot.sh
   # 2. Uncomment: set -g @continuum-boot on
   # set -g @continuum-boot on
   ```

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `home-linux/tmux.nix` | Modified | Add `continuum` to plugin list (line 37-42) |
| `home-darwin/tmux.nix` | Modified | Add TPM plugin declaration (line 65-69) + commented auto-boot skeleton |
| `shared/tmux.nix` | Modified | Add `@continuum-*` and `@resurrect-processes` options (after line 66) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Plugin order on Linux: continuum loaded before resurrect | Low | Place `continuum` after `resurrect` in the list (line 38-39) |
| `@continuum-boot` requires manual launchd setup on Darwin | High | Document as commented skeleton; user tests manually |
| TPM activation requires network on Darwin | Low | Same risk as today; `install_plugins` has `|| true` fallback |
| Save interval too frequent/infrequent | Low | 15 min is the documented sane default; explicit config makes it easy to adjust |

## Rollback Plan

Revert the three-file commit:
```bash
git revert <commit-hash>
nixos-build  # or darwin-rebuild switch on mact2
```

No data loss: tmux sessions are saved in `~/.tmux/resurrect/` and `~/.tmux/sessions/`; removing the plugin does not delete these files.

## Dependencies

- `pkgs.tmuxPlugins.continuum` (nixpkgs, already available)
- `tmux-plugins/tmux-continuum` (GitHub, cloned by TPM on Darwin)

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] On Linux (rog/thinkcentre/t14): open tmux, create panes/windows, wait 15+ minutes, kill tmux server (`tmux kill-server`), restart tmux — sessions restore automatically
- [ ] On Darwin (mact2): same workflow; verify TPM cloned `tmux-continuum` to `~/.config/tmux/plugins/tmux-continuum/`
- [ ] `tmux show-options -g | grep continuum` shows the configured values
- [ ] Status line shows "Saved N seconds ago" indicator

## Effort Estimate

**Trivial** — ~12 lines of config across 3 files. Single commit direct to main, ~30 minutes including verification.
