# Design: tmux-resurrect-continuum-config

## Technical Approach

Pure config addition across 3 files. No new modules, no structural changes. Continuum wraps resurrect (auto-save/restore), so it must be declared after resurrect in every plugin list. All `@continuum-*` options go in `shared/tmux.nix` `extraConfig` so both platforms inherit them. Darwin gets an additional commented auto-boot skeleton since macOS requires manual `boot.sh` setup.

## Architecture Decisions

| Decision | Choice | Alternative | Rationale |
|----------|--------|-------------|-----------|
| Plugin management on Linux | Keep nixpkgs (`pkgs.tmuxPlugins.continuum`) | Migrate to TPM | Proposal scoped out TPM migration; nixpkgs is the established pattern |
| Option location | `shared/tmux.nix` `extraConfig` | Per-platform files | Options are platform-agnostic; shared avoids duplication |
| `@continuum-boot` default | Commented out (Darwin only) | Enabled by default | Requires manual `boot.sh` on macOS; enabling blindly would break |
| `@resurrect-processes` value | `'opencode'` only | Include nvim, other procs | nvim is in resurrect's compiled-in defaults; only non-default procs need listing |

## File Map

| File | Action | Lines Changed | Description |
|------|--------|---------------|-------------|
| `shared/tmux.nix` | Modify | +8 after line 66 | Add `@continuum-*` options + `@resurrect-processes` |
| `home-linux/tmux.nix` | Modify | +1 after line 38 | Add `continuum` to nixpkgs plugin list |
| `home-darwin/tmux.nix` | Modify | +5 after line 66 | Add TPM plugin decl + commented auto-boot skeleton |

## Insertion Points (Precise Diff Plan)

### 1. `shared/tmux.nix` — after line 66

**Context (lines 64-68):**
```
64:       set -g message-command-style "bg=#${config.colorScheme.palette.base02},fg=#${config.colorScheme.palette.base0D}"
65:
66:       set -g @resurrect-capture-pane-contents 'on'
67:
68:       # Universal bindings
```

**Insert between lines 66 and 67:**
```nix
      # tmux-continuum: continuous saving + restore
      set -g @continuum-save-interval '15'
      set -g @continuum-restore-on-startup on
      set -g @continuum-boot-options 'alacritty'
      set -g @continuum-save-on-close on
      # Resurrect process list: nvim already in defaults; add opencode for bare relaunch
      set -g @resurrect-processes 'opencode'
```

### 2. `home-linux/tmux.nix` — after line 38

**Context (lines 37-42):**
```
37:     plugins = lib.mkForce (with pkgs.tmuxPlugins; [
38:       resurrect
39:       sessionist
40:       yank
41:       vim-tmux-navigator
42:     ]);
```

**Insert between lines 38 and 39:**
```nix
      continuum
```

Result:
```nix
    plugins = lib.mkForce (with pkgs.tmuxPlugins; [
      resurrect
      continuum
      sessionist
      yank
      vim-tmux-navigator
    ]);
```

### 3. `home-darwin/tmux.nix` — after line 66

**Context (lines 64-71):**
```
64:       # TPM plugin declarations
65:       set -g @plugin 'tmux-plugins/tpm'
66:       set -g @plugin 'tmux-plugins/tmux-resurrect'
67:       set -g @plugin 'tmux-plugins/tmux-sessionist'
68:       set -g @plugin 'tmux-plugins/tmux-yank'
69:       set -g @plugin 'christoomey/vim-tmux-navigator'
70:
71:       set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.config/tmux/plugins"
```

**Insert between lines 66 and 67:**
```
      set -g @plugin 'tmux-plugins/tmux-continuum'
```

**Insert between lines 69 and 70 (before blank line, after last plugin):**
```
      # Auto-boot on macOS (requires manual setup):
      # 1. Run: ~/.config/tmux/plugins/continuum/boot.sh
      # 2. Uncomment: set -g @continuum-boot on
      # set -g @continuum-boot on
```

## Option Contract

Exact `set -g` lines added to `shared/tmux.nix` `extraConfig`:

| Option | Value | Purpose |
|--------|-------|---------|
| `@continuum-save-interval` | `'15'` | Auto-save every 15 minutes |
| `@continuum-restore-on-startup` | `on` | Auto-restore last session on `tmux` launch |
| `@continuum-boot-options` | `'alacritty'` | Terminal for continuum auto-boot |
| `@continuum-save-on-close` | `on` | Save state when tmux server exits |
| `@resurrect-processes` | `'opencode'` | Additional processes for resurrect to relaunch |

## Platform Differences

| Aspect | Linux (`home-linux/tmux.nix`) | Darwin (`home-darwin/tmux.nix`) |
|--------|-------------------------------|----------------------------------|
| Plugin declaration | `continuum` in `pkgs.tmuxPlugins` list (line 39) | `set -g @plugin 'tmux-plugins/tmux-continuum'` (TPM, line 67) |
| Plugin installation | Nix builds it; available at activation | TPM `install_plugins` clones from GitHub |
| `extraConfig` priority | `lib.mkForce sharedExtraConfig` — options propagate automatically | Inline `extraConfig` — shared options arrive via `imports = [ ../shared/tmux.nix ]` merge |
| Auto-boot skeleton | Not added (out of scope for Linux) | Commented block after TPM declarations |

## Ordering Constraints

1. **Plugin list order**: `continuum` MUST follow `resurrect` on both platforms. Continuum wraps resurrect's save/restore; loading it first would reference resurrect functions before they exist.
2. **`extraConfig` order**: `@continuum-*` options are placed after `@resurrect-capture-pane-contents` (line 66 in shared). tmux processes `set -g` lines sequentially; options must appear after the plugin is sourced. On Linux, plugins are sourced by HM before `extraConfig` is emitted. On Darwin, TPM plugins are declared in `extraConfig` itself (lines 65-69) and sourced by `run -b ... tpm` (line 74), which runs after all `set -g` lines — so option placement before or after plugin declarations is functionally equivalent, but grouping them after resurrect options is cleaner.
3. **No ordering dependency** between `@continuum-*` options and `@resurrect-processes` — they are independent plugin configs.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Validation | `nix flake check --no-build` | Catches syntax/type errors in all 3 files |
| Manual (Linux) | `tmux show-options -g \| grep continuum` | Verify options are set after rebuild |
| Manual (Darwin) | `ls ~/.config/tmux/plugins/tmux-continuum/` | Verify TPM cloned the plugin |
| Manual (both) | Create session → kill server → restart | Verify auto-restore works |

## Migration / Rollout

No migration required. Pure additive config. Existing resurrect data in `~/.tmux/resurrect/` is untouched. First activation installs continuum; first auto-save occurs 15 minutes after tmux starts.

## Open Questions

None.
