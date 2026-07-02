# Design: tmux-clipboard-ssh

## Technical Approach

Two cooperating mechanisms in `shared/tmux.nix`: tmux built-in `set -s set-clipboard on` triggers OSC 52 for default copy-pipe; `@override_copy_command` with a portable shell emitter covers tmux-yank's `y`/`Enter`/`prefix-y` bindings that would otherwise autodetect xclip/pbcopy. Remove the 10 explicit `copy-pipe-and-cancel` bindings (5 xclip Linux, 5 pbcopy Darwin). Pin `clipboard-write = allow` in ghostty configs. OSC 52 rides the terminal byte stream — works identically local and over SSH.

## Architecture Decisions

| Decision | Choice | Alt rejected | Why |
|----------|--------|-------------|-----|
| OSC 52 emitter | `printf '\033]52;c;%s\033\\' "$(base64 \| tr -d '\n')" >/dev/tty` | BEL terminator `\007` | ST (`ESC\`) matches tmux's native output; `tr -d '\n'` portable on GNU+BSD base64 |
| tmux-yank binding keys | `@override_copy_command` in shared before plugins | Drop explicit bindings only | tmux-yank re-binds `y`/`Enter` with its own `copy-pipe-and-cancel`, suppressing `set-clipboard on` |
| Kitty config | No change | `clipboard_control = write` (invalid token) | Default already permits writes; `= write` is invalid kitty syntax |
| MATE Terminal | Document limitation | Enable via gsettings | VTE 0.82.3 handler is no-op; no gsettings key exists |

## Data Flow

```
tmux copy-mode y/Enter/MouseDrag
    → @override_copy_command: printf ESC]52;c;<b64>ESC\ to /dev/tty
    → set-clipboard on: tmux emits same for default copy-pipe
    → allow-passthrough on (already set)
    → SSH byte stream (in-band, no config needed)
    → ghostty/kitty: clipboard-write allow → local clipboard
```

## File Changes

### `shared/tmux.nix` — ADD 2 lines after `allow-passthrough on` (line 14)

```
set -s set-clipboard on
set -g @override_copy_command "printf '\033]52;c;%s\033\\' \"$(base64 | tr -d '\\012')\" >/dev/tty"
```

Place before plugins source. HM's tmux module places `extraConfig` before plugin `run-shell` lines; on Darwin, shared extraConfig concatenates before TPM's `run -b`.

### `home-linux/tmux.nix` — REMOVE 5 xclip bindings (lines 50-56)

Replace:
```nix
extraConfig = lib.mkForce (sharedExtraConfig + ''
  # Linux clipboard (xclip) bindings for copy-mode
  bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
  bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
  bind -T copy-mode y send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
  bind -T copy-mode Enter send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
  bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel "xclip -i -selection clipboard"
'');
```
With:
```nix
extraConfig = lib.mkForce sharedExtraConfig;
```

### `home-darwin/tmux.nix` — REMOVE 5 pbcopy bindings (lines 64-68)

Remove the `copy-pipe-and-cancel "pbcopy"` block. Keep `set -s set-clipboard on` (line 62) and `v send -X begin-selection` (line 63). The five removed lines are `y`, `Enter`, `MouseDragEnd1Pane` in copy-mode and copy-mode-vi.

### `home-linux/ghostty.nix` — ADD `clipboard-write = "allow"` to settings

### `home-darwin/ghostty.nix` — ADD `clipboard-write = allow` to config text

## Ordering Constraint

`@override_copy_command` must be set before tmux-yank sources its bindings. In the generated `tmux.conf`, `extraConfig` always precedes plugin `run-shell` (both nixpkgs and TPM paths). Placing the override in `shared/tmux.nix` extraConfig (evaluated before either platform file's plugin sourcing) guarantees correct ordering.

## Test Plan

| Host | Scenario | Verify |
|------|----------|--------|
| rog / thinkcentre / t14 / mact2 | Local: ghostty → tmux → `y` → paste | Text in local clipboard |
| rog → mact2 (SSH) | ghostty → ssh mact2 → tmux → `y` | Text in rog clipboard |
| mact2 → rog (SSH) | ghostty → ssh rog → tmux → `y` | Text in mact2 clipboard |
| rog → thinkcentre (SSH) | ghostty → ssh nc → tmux → `y` | Text in rog clipboard |
| All hosts | Mouse-drag copy in tmux | Text via OSC 52 |
| All hosts | `tmux info \| grep copy-command` | Empty/default |
| All hosts | `nix flake check --no-build` | Passes |

**MATE Terminal caveat**: OSC 52 silently fails when SSH client is MATE Terminal (VTE no-op). Mitigation: SSH from ghostty/kitty (installed on all hosts). No config change possible; documented limitation.

## Rollback

`nixos-rebuild switch --rollback` / `darwin-rebuild switch --rollback`. Single atomic generation swap. No state, no migration.
