# Spec: tmux-resurrect-continuum-config

## Classification

**Pure configuration change.** No new or modified behavioral capabilities.
This change adds tmux-continuum options and extends the resurrect process list.
All behavior is provided by upstream plugins (tmux-continuum, tmux-resurrect);
this spec defines the expected configuration contract.

## Configuration Contract

The following tmux options MUST be set in the shared base config (`shared/tmux.nix`):

| Option | Value | Purpose |
|--------|-------|---------|
| `@continuum-save-interval` | `'15'` | Auto-save session state every 15 minutes |
| `@continuum-restore-on-startup` | `on` | Auto-restore last session when tmux server starts |
| `@continuum-boot-options` | `'alacritty'` | Terminal emulator for auto-boot (Darwin) |
| `@continuum-save-on-close` | `on` | Save session state when terminal window closes |
| `@resurrect-processes` | `'opencode'` | Add opencode to resurrect's bare-process relaunch list |

### Notes

- **nvim**: Already included in tmux-resurrect's default process list. No entry needed.
- **`@continuum-boot`**: MUST remain commented out on Darwin until user verifies manual `boot.sh` setup. A commented skeleton SHALL be present in `home-darwin/tmux.nix` extraConfig.
- **Plugin order (Linux)**: `continuum` MUST appear after `resurrect` in the nixpkgs plugin list (`home-linux/tmux.nix`) because continuum wraps resurrect.

## Platform Plugin Declarations

| Platform | File | Action |
|----------|------|--------|
| Linux | `home-linux/tmux.nix` | Add `pkgs.tmuxPlugins.continuum` after `resurrect` in plugin list |
| Darwin | `home-darwin/tmux.nix` | Add `set -g @plugin 'tmux-plugins/tmux-continuum'` TPM declaration |

## Verification Scenarios

### Scenario: Continuum options are set

- GIVEN a tmux server is running on any host (Linux or Darwin)
- WHEN `tmux show-options -g | grep continuum` is executed
- THEN output includes `@continuum-save-interval 15`
- AND output includes `@continuum-restore-on-startup on`
- AND output includes `@continuum-save-on-close on`

### Scenario: Resurrect process list includes opencode

- GIVEN a tmux server is running
- WHEN `tmux show-options -g | grep resurrect-processes` is executed
- THEN output includes `opencode` in the process list

### Scenario: Auto-save triggers after interval

- GIVEN tmux is running with at least one session containing panes
- WHEN 15 minutes elapse without manual intervention
- THEN `~/.tmux/resurrect/` contains an updated save file
- AND the status line shows a "Saved N seconds ago" indicator

### Scenario: Auto-restore on server restart

- GIVEN tmux sessions were previously saved by continuum
- WHEN the tmux server is killed (`tmux kill-server`) and restarted (`tmux`)
- THEN previous sessions, windows, and panes are restored automatically

### Scenario: Save on terminal close

- GIVEN tmux is running inside a terminal window
- WHEN the terminal window is closed
- THEN continuum saves the session state before the server exits

### Scenario: Darwin auto-boot skeleton is commented

- GIVEN the Darwin tmux configuration (`home-darwin/tmux.nix`)
- WHEN the file is inspected
- THEN a commented `# set -g @continuum-boot on` line is present
- AND the line is NOT active (prefixed with `#`)
