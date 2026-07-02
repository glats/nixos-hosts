## Exploration: tmux-window-title-auto-update

### Current State

**Tmux configuration layout** (three files, layered):

- `shared/tmux.nix` — common base for both Linux and Darwin. Sets `set -gq set-titles on` (line 25) which enables outer-terminal title updates. Sets the auto-rename policy on line 49–51:
  ```
  setw -g automatic-rename on
  setw -g automatic-rename-format '#{b:pane_current_path}'
  ```
  The current `automatic-rename-format` is the basename of the pane's current working directory (e.g. `myproject`, `flake.nixos`). When a command runs in the pane, the basename does **not** change — the title still shows the folder the shell was sitting in when the command was launched. This is the behavior the user wants to change.

- `home-linux/tmux.nix` — Linux overlay. Uses `lib.mkForce` on `extraConfig` and `plugins` to neutralize omarchy's tmux module on t14. The forced `extraConfig` is re-evaluated from `shared/tmux.nix` via `sharedExtraConfig = (import ../shared/tmux.nix { inherit config; }).programs.tmux.extraConfig;`. So **edits to `shared/tmux.nix` propagate to all Linux hosts** (rog, thinkcentre, t14) because the `lib.mkForce` here makes Linux use the shared `extraConfig` exactly.

- `home-darwin/tmux.nix` — Darwin overlay. Does **not** use `lib.mkForce` on `extraConfig`. It defines its own `extraConfig` (TPM plugin declarations, terminal overrides) which Nix module-system MERGES with the shared `extraConfig`. So **edits to `shared/tmux.nix` also propagate to the macOS host** (mact2). The shared prefix runs first, then Darwin's TPM block.

- `home-linux/shared-modules.nix` and `home-darwin/shared-modules.nix` — each imports `./tmux.nix` (the platform file), which itself imports `../shared/tmux.nix`.

- `hosts/t14/home/omarchy.nix` (line 64) — explicitly imports `../../../home-linux/tmux.nix`, so t14 picks up the same `extraConfig` (after omarchy's tmux module is neutralized by `lib.mkForce`).

**User's shell** (confirmed by grep): `zsh` on every host. The Darwin default and `modules/base/zsh.nix` + `home-linux/shell.nix` + `home-darwin/shell.nix` all set `programs.zsh`. So when at a prompt, `pane_current_command` returns the string `"zsh"` (not `"bash"`). Any conditional comparing against the shell must use `zsh` (or a portable match-list).

**Status bar format** (line 60–61 of `shared/tmux.nix`):
```
setw -g window-status-format " #I:#W "
setw -g window-status-current-format " #I:#W "
```
`#W` is the window name (which is what `automatic-rename-format` controls). So whatever the auto-rename produces is what shows up in the status bar list, in the choose-tree menu, and in the outer terminal title (because `set-titles-string` defaults to `#{session_name}:#{window_index}:#{window_name}…`).

**`automatic-rename-interval` is NOT set.** tmux's default is 15 seconds. So the title may lag a command's start/finish by up to 15 s. Worth flagging in the proposal as a knob to consider lowering.

### Affected Areas

- `shared/tmux.nix` — single line to change (line 51: `automatic-rename-format`). One change here reaches rog, thinkcentre, t14 (via `home-linux/tmux.nix`'s `lib.mkForce sharedExtraConfig`) AND mact2 (via `home-darwin/tmux.nix`'s attrset merge on `extraConfig`). This is the only file that has to be touched.
- `home-linux/tmux.nix` — no change required. Its `lib.mkForce extraConfig = sharedExtraConfig` already picks up the new format string automatically. Confirmed by reading the file end-to-end.
- `home-darwin/tmux.nix` — no change required. Nix module system merges `extraConfig` strings, so the new `automatic-rename-format` line in the shared prefix is preserved alongside Darwin's TPM block.
- `hosts/t14/home/omarchy.nix` — no change required. t14's import of `home-linux/tmux.nix` carries the shared value through `lib.mkForce`.
- `modules/base/profiles/base.nix` — no change required (no shell or package dependency).
- `home-linux/window-status-format` line — may need a `#{=20:…}` trim if titles get long with combined folder + command. See Risks.

### Tmux Mechanisms

Three independent options govern window titles; understanding their separation is the whole point of this change.

| Option | Scope | Default | What it controls |
|---|---|---|---|
| `set-titles` (server) | `set -g set-titles on/off` | on (off in nixpkgs build? — irrelevant) | Whether tmux emits the OSC 0/2 escape sequence to set the **outer terminal emulator's title**. Already `on` in `shared/tmux.nix` line 25. |
| `set-titles-string` (server) | `set -g set-titles-string "…"` | `#{session_name}:#{window_index}:#{window_name}#{?window_flags,(#{window_flags}),}` | The format of the **outer terminal title** (what ghostty/kitty shows in their title bar). Uses `#W` (window name) by default, so it inherits the value of `automatic-rename-format` automatically. |
| `automatic-rename` (window) | `setw -g automatic-rename on/off` | on | Whether tmux auto-rewrites the window name based on the pane. |
| `automatic-rename-format` (window) | `setw -g automatic-rename-format "…"` | `#{pane_current_command}` (since tmux 3.2) | The format used when tmux renames the window. This is the **central knob for the desired behavior**. |
| `automatic-rename-interval` (window) | `setw -g automatic-rename-interval N` | 15 (seconds) | How often tmux polls and reapplies the format. Lower = snappier title updates. |

**Relevant format variables** (per tmux Formats wiki, https://github.com/tmux/tmux/wiki/Formats):

- `#{pane_current_path}` — full path of the pane's CWD (e.g. `/home/glats/.nixos`).
- `#{b:pane_current_path}` — **basename** of that path (e.g. `.nixos`). The `b:` modifier strips the directory.
- `#{pane_current_command}` — the foreground process of the pane. At a zsh prompt this is `zsh`. Inside `cargo build` it is `cargo`. Inside `vim` it is `vim`. This is exactly the "currently executing command" the user wants.
- `#{pane_in_mode}` — true if pane is in copy mode.
- `#{pane_dead}` — true if pane's process has exited (rare in interactive tmux).

**Format conditional** `#{?COND,TRUE_VAL,FALSE_VAL}`:
- Single-condition ternary. `COND` can itself be a format like `#{==:#{pane_current_command},zsh}` (the inner `==` returns `1` or `0`; the outer `?` picks one of the two branches). This is the idiomatic way to implement "show folder when idle, show command when running".

**Modifier recap** (from wiki):
- `b:variable` — basename of a path
- `d:variable` — directory of a path
- `=N:variable` — trim to N characters
- `=/N/format:variable` — trim to N with marker
- `pN:variable` — pad to N
- `s/from/to/flags:variable` — substitute
- `E:variable` — re-expand as format (lets you re-process a variable)

### Feasibility

**The desired behavior is achievable with one line in `shared/tmux.nix`.** tmux's `automatic-rename-format` supports any combination of the variables above, including a conditional switch that picks folder-vs-command based on whether the pane is at a shell prompt. The shell-detection threshold is the only piece that needs a deliberate choice (the user uses zsh, so the comparison must be `zsh`, not `bash`).

The feature does not require any package additions, any HM module option (none exists for `automatic-rename-format` — it is not in the `programs.tmux.*` option set), any shell hooks, any plugin, any SSH change, or any terminal-emulator change. tmux has had `automatic-rename` since 1.8 and the conditional format since 2.1+.

### Approaches

1. **Conditional switch (path at prompt, command while running)** — most idiomatic.
   ```
   setw -g automatic-rename-format '#{?#{==:#{pane_current_command},zsh},#{b:pane_current_path},#{pane_current_command}}'
   ```
   At a zsh prompt → title is `myproject`. Inside `vim` → title is `vim`. Inside `cargo build --release` → title is `cargo`.
   - Pros: matches the user's stated intent ("auto-change based on folder AND show command"); the title is always short; matches what the StackOverflow community recommends and what the tmux wiki examples show; pure-format (no `#(shell)` evaluation, so cheap and reliable); portable across zsh/bash/fish by adjusting the comparison string.
   - Cons: shows *one* piece of context, not both at once; the user said "AND" so the proposal should confirm this is the right interpretation. **For multi-shell hosts the comparison would need to be a list** — only `zsh` is needed in this repo.
   - Effort: **Lowest**. One line.

2. **Combined literal (folder + command, always)** — always show both.
   ```
   setw -g automatic-rename-format '#{b:pane_current_path}:#{pane_current_command}'
   ```
   At a zsh prompt → title is `myproject:zsh`. Inside `vim` → `myproject:vim`.
   - Pros: literally shows both pieces of info at the same time; no shell detection.
   - Cons: at idle the title redundantly says `myproject:zsh` (the trailing `:zsh` adds nothing); in long path names + long command names the title can overflow the 50-char `status-right-length`; the "AND" interpretation the user literally described.
   - Effort: **Lowest**. One line, but with a UX wart.

3. **Folder always, command suffix only when running** — most informationally dense.
   ```
   setw -g automatic-rename-format '#{b:pane_current_path}#{?#{!=:#{pane_current_command},zsh},:#{pane_current_command},}'
   ```
   At zsh prompt → `myproject`. Inside `vim` → `myproject:vim`. Inside `cargo build` → `myproject:cargo`.
   - Pros: shows the folder always (the original requirement, never lost); only adds the command when it's useful (not the shell itself); long-paths and long-commands can be trimmed with `#{=20:…}`; this is the closest to "AND" without the idle wart.
   - Cons: slightly more complex format string; still requires `zsh` in the comparison; needs `#{=N}` to keep width bounded if commands are long.
   - Effort: **Low**. One line, same complexity tier as #1.

4. **Pure shell-prompt hook (PROMPT_COMMAND / precmd / chpwd)** — bypass tmux auto-rename.
   ```
   # in .zshrc
   chpwd() { tmux set-window-option automatic-rename-format '#{b:pane_current_path}' }
   preexec() { tmux set-window-option automatic-rename-format '#{pane_current_command}' }
   ```
   - Pros: maximally flexible (any string you want, including project names from a tool like `git rev-parse`).
   - Cons: **disables `automatic-rename`** because manually setting a window's name via shell hook turns automatic-rename off (well-known tmux behavior — confirmed in the tmux-users thread cited below); requires per-shell config in zsh.nix and an opt-in for bash users; more moving parts.
   - Effort: **Medium**. Touches `home-linux/shell.nix` + `home-darwin/shell.nix` in addition to the tmux file.

5. **Status quo + a wrapper around `pane_current_path`** (e.g., dynamic git repo name).
   - Pros: shows the git repo name when in one, path otherwise.
   - Cons: not what the user asked for; rejected.

### Recommendation

Use **Approach 3** (folder always, command suffix only when running) as the primary path. Reasoning:

- The user's words "auto-change title based on folder AND show the currently executing command" are best read as "title shows folder always; when a command is running, also indicate which one". Approach 3 literally satisfies both halves of the AND without the idle wart of `:zsh`.
- It keeps the basename-only title at the prompt (so muscle memory from the current behavior survives), and layers command awareness on top.
- It is one line in `shared/tmux.nix` with no new files, no new options, no new packages.
- It is the format the StackOverflow/SuperUser and tmux-users communities converge on (the conditional `#{?cond,if,else}` pattern is the canonical tmux idiom for this).

Concrete recipe for the proposal phase:

- In `shared/tmux.nix` line 51, replace
  ```
  setw -g automatic-rename-format '#{b:pane_current_path}'
  ```
  with
  ```
  setw -g automatic-rename-format '#{=20:b:pane_current_path}#{?#{!=:#{pane_current_command},zsh},:#{=15:pane_current_command},}'
  ```
  - `#{=20:b:pane_current_path}` — basename of CWD trimmed to 20 chars (long folder names get a `…` marker from the `=/` variant, or hard-truncated from the `=` variant). The `=` modifier trims; use `=/20/…:` for a marker.
  - `#{?#{!=:#{pane_current_command},zsh},:#{=15:pane_current_command},}` — only when the foreground process is NOT `zsh`, append `:command` (trimmed to 15 chars). At the prompt, nothing is appended. Inside `vim`, the title becomes `myfolder:vim`.

- Optional: lower `automatic-rename-interval` to 5 (matches the existing `status-interval 5` on line 44) so the title updates within 5 s of a command's start/finish instead of 15 s:
  ```
  setw -gq automatic-rename-interval 5
  ```
  This is a one-line addition in the same `extraConfig` block.

- Verify: build with `nix flake check --no-build`, then on each host start a tmux session and exercise three states: (a) at the prompt, (b) inside `vim`, (c) inside `cargo build`. The title should be (a) folder, (b) folder:vim, (c) folder:cargo.

- Optionally also propose Approach 1 as the alternate behavior (path at prompt / command while running) in case the user actually wants the pure switch semantics. Confirm with the user during proposal.

### Risks

- **Width overflow in status bar**: the current `setw -g window-status-format " #I:#W "` (line 60) and the equivalent `window-status-current-format` (line 61) are unbounded. The `set -g status-right-length 50` (line 46) only constrains the right block. A 60-char `myproject:cargo build --release` title will wrap the status bar left side. Mitigated by the `#{=20:…}` and `#{=15:…}` trim modifiers in the recommended format. The proposal should note that long-running command invocations still have long argv (the `pane_current_command` is just the executable name, not the args, so this is bounded to ~15 chars in practice).
- **`pane_current_command` reflects foreground process, not argv**: at idle it is `zsh`; inside `vim foo.txt` it is `vim`; inside `cargo build --release` it is `cargo`. The user said "currently executing command" — the title will show the program name, not the full command line. This is a tmux limit, not a config one. If the user wants full argv, that requires a shell hook (Approach 4) which we are not recommending.
- **`automatic-rename-interval` defaults to 15 s**: today. With the default, the title will lag a command's start/finish by up to 15 s. Lowering to 5 s (matching `status-interval`) is a one-line change. **Mitigation: include `setw -gq automatic-rename-interval 5` in the recommended recipe.**
- **Shell detection assumes zsh**: the comparison `!=:pane_current_command,zsh` works because every host in this repo uses zsh (`programs.zsh` set in `modules/base/zsh.nix`, `home-linux/shell.nix`, `home-darwin/shell.nix`, plus omarchy-nix's default on t14). If anyone in the future switches to bash/fish, the `:bash` / `:fish` suffix will start showing at the prompt. Worth a comment in `shared/tmux.nix` explaining the `zsh` literal; future-proof by listing both zsh and a comment.
- **Plugins can override the title**: `tmux-resurrect` (in the plugin set on both platforms) and `tmux-rename-window` style plugins set the window name explicitly on session restore. If `automatic-rename-format` is set but the user names a window with `<prefix-,`, that name is preserved until the next `automatic-rename` tick (15 s by default). This is the desired behavior — no regression.
- **Outer terminal title**: `set -gq set-titles on` is already set. The default `set-titles-string` is `#{session_name}:#{window_index}:#{window_name}#{?window_flags,(#{window_flags}),}` — i.e., the outer title is `session:idx:NAME…`. Because the default uses `#{window_name}` (which is what `automatic-rename-format` sets), the outer title automatically follows the new format too. No `set-titles-string` change is needed. **Free win**.
- **`xclip` and other client-side status checks**: not affected. This is a pure tmux config change.
- **Review budget**: the change is one line in one file (plus optionally the `automatic-rename-interval` line). review_budget = 1. No chained PRs required. Single PR.
- **Format string parsing in older tmux versions**: nested `#{?#{==:…},…,…}` syntax requires tmux 2.1+. The repo's `programs.tmux.package` is from nixpkgs-unstable which is currently 3.4+ — no risk.
- **`allow-rename` window option**: tmux has a per-window `allow-rename` option that, when off, prevents ANY rename. The current `shared/tmux.nix` does not set it, so it defaults to on. No risk.

### Ready for Proposal

**Yes.** The proposal should:

1. Frame the change as "make tmux window titles reflect the active command without losing the current folder signal".
2. Recommend Approach 3 (folder always, command suffix only when running) with the `#{=20:…}:#{=15:…}` width-bounded format. Include `setw -gq automatic-rename-interval 5` for snappiness.
3. Note Approach 1 (path-or-command switch) as the alternative if the user wanted "either/or" semantics — confirm during proposal which they want.
4. List the workstream: edit `shared/tmux.nix` line 51 (one line); optional `automatic-rename-interval` line nearby; verify on each host (rog, thinkcentre, t14, mact2).
5. Note that the change auto-propagates to outer terminal title (via the default `set-titles-string`'s `#{window_name}`) — bonus.
6. Spec delta: one new requirement in the home-manager spec under "automatic window naming" describing the format string, with a scenario like "When the foreground process is not zsh, the title shows `folder:command`" and "When the foreground process is zsh, the title shows `folder`".

### Verification Path (proposal will refine)

- `nix flake check --no-build` — syntax + type check across all hosts.
- Manual smoke per host: open tmux, observe title at prompt, run `vim`, observe `:vim` suffix, exit, observe suffix gone, run `cargo build`, observe `:cargo`.
- Optional: in a tty that does not have OSC 52/0/2 support (rare today), the `set-titles-string` part is a no-op for the outer terminal but the in-tmux status bar still updates correctly.

### Key References

- tmux Formats wiki: <https://github.com/tmux/tmux/wiki/Formats> (variables and modifiers)
- tmux Advanced Use wiki (set-titles + automatic-rename section): <https://github.com/tmux/tmux/wiki/Advanced-Use>
- StackOverflow canonical answer with the conditional-switch pattern: <https://stackoverflow.com/questions/28376611/how-to-automatically-rename-tmux-windows-to-the-current-directory>
- tmux-users thread on combining folder + command in one title: <https://groups.google.com/g/tmux-users/c/ufob9kAWLFs>
