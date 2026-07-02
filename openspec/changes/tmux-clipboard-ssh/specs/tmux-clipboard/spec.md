# tmux-clipboard Specification

## Purpose

tmux copy-mode writes to the local terminal's clipboard via OSC 52 escape sequences, identical local and over SSH. No `xclip`/`pbcopy` in the tmux copy path.

## Requirements

### Requirement: REQ-1 — Local clipboard via OSC 52

tmux copy-mode selections SHALL write to the local terminal's clipboard via OSC 52 when running on the same host. The system MUST emit OSC 52 through the terminal byte stream without piping to external clipboard commands.

#### Scenario: Local copy on rog (MATE/X11)

- GIVEN tmux running in ghostty on rog
- WHEN the user selects text in copy-mode and presses `y`
- THEN the selected text appears in rog's local clipboard
- AND no `xclip` process is spawned by tmux

#### Scenario: Local copy on thinkcentre (MATE/X11)

- GIVEN tmux running in ghostty on thinkcentre
- WHEN the user selects text in copy-mode and presses `Enter`
- THEN the selected text appears in thinkcentre's local clipboard

#### Scenario: Local copy on t14 (Hyprland/Wayland)

- GIVEN tmux running in ghostty on t14
- WHEN the user selects text in copy-mode and presses `y`
- THEN the selected text appears in t14's local clipboard
- AND no `DISPLAY` or `WAYLAND_DISPLAY` dependency is required from tmux

#### Scenario: Local copy on mact2 (macOS)

- GIVEN tmux running in ghostty on mact2
- WHEN the user selects text in copy-mode and presses `y`
- THEN the selected text appears in mact2's local pasteboard

### Requirement: REQ-2 — SSH clipboard via OSC 52

tmux copy-mode selections over SSH SHALL write to the SSH client host's clipboard, not the remote host's. OSC 52 MUST ride the terminal byte stream in-band with no SSH-side configuration.

#### Scenario: rog → mact2 over SSH (ghostty client)

- GIVEN ghostty on rog, SSH into mact2, tmux running remotely
- WHEN the user selects text in copy-mode and presses `y`
- THEN the selected text appears in rog's local clipboard
- AND mact2's pasteboard is unchanged

#### Scenario: mact2 → rog over SSH (ghostty client)

- GIVEN ghostty on mact2, SSH into rog, tmux running remotely
- WHEN the user selects text in copy-mode and presses `y`
- THEN the selected text appears in mact2's local pasteboard
- AND rog's clipboard is unchanged

#### Scenario: rog → thinkcentre over SSH (ghostty client)

- GIVEN ghostty on rog, SSH into thinkcentre, tmux running remotely
- WHEN the user selects text in copy-mode and presses `Enter`
- THEN the selected text appears in rog's local clipboard

#### Scenario: SSH copy via kitty client

- GIVEN kitty on any Linux host, SSH into any remote, tmux running
- WHEN the user selects text in copy-mode and presses `y`
- THEN the selected text appears in the kitty host's local clipboard

### Requirement: REQ-3 — Terminal contract pinned

Ghostty config on every host (Linux and Darwin) SHALL explicitly pin `clipboard-write = allow`. This MUST be a reviewable setting, not a reliance on defaults.

#### Scenario: Ghostty clipboard-write on Linux hosts

- GIVEN `home-linux/ghostty.nix` evaluated for rog, thinkcentre, t14
- WHEN the generated ghostty config is read
- THEN `clipboard-write = allow` is present

#### Scenario: Ghostty clipboard-write on Darwin hosts

- GIVEN `home-darwin/ghostty.nix` evaluated for mact2
- WHEN the generated ghostty config is read
- THEN `clipboard-write = allow` is present

### Requirement: REQ-4 — tmux-yank OSC 52 path

tmux-yank's `y` (copy-mode) and `prefix-y` (normal mode) bindings SHALL emit OSC 52 instead of piping to `xclip`/`pbcopy`. The system MUST use `@override_copy_command` with a portable OSC 52 shell emitter.

#### Scenario: tmux-yank `y` binding emits OSC 52

- GIVEN tmux with tmux-yank loaded on any host
- WHEN the user presses `y` in copy-mode
- THEN the copy path emits an OSC 52 escape sequence to `/dev/tty`
- AND no `xclip` or `pbcopy` process is spawned

#### Scenario: tmux-yank `prefix-y` binding emits OSC 52

- GIVEN tmux with tmux-yank loaded on any host
- WHEN the user presses `prefix-y` in normal mode
- THEN the current command line is copied via OSC 52

#### Scenario: Mouse-drag copy emits OSC 52

- GIVEN tmux running on any host with mouse mode enabled
- WHEN the user mouse-drags to select text in tmux
- THEN the selection is copied via OSC 52 on `MouseDragEnd1Pane`

### Requirement: REQ-5 — No xclip/pbcopy in copy path

The tmux copy-command chain SHALL NOT involve `xclip` or `pbcopy`. `tmux info | grep copy-command` MUST return empty or default.

#### Scenario: Verify tmux copy-command is unset

- GIVEN the applied tmux configuration on any host
- WHEN `tmux info | grep copy-command` is executed
- THEN the output is empty or shows the default (no explicit copy-command)
- AND no `xclip` or `pbcopy` appears in any copy-pipe binding for `y`, `Enter`, or `MouseDragEnd1Pane`

### Requirement: REQ-6 — No regression on existing clipboard commands

`xclip` SHALL remain installed for non-tmux use (neovim, rofi, scripts). Other programs that depend on `xclip` MUST NOT break.

#### Scenario: xclip still available on Linux hosts

- GIVEN the applied NixOS configuration on rog, thinkcentre, or t14
- WHEN `which xclip` is executed
- THEN `xclip` is found in `$PATH`

#### Scenario: Neovim clipboard integration unaffected

- GIVEN neovim running on any Linux host
- WHEN the user yanks to the `+` register
- THEN neovim uses its own OSC 52 provider or xclip (independent of tmux config)

### Requirement: REQ-7 — nix flake check passes

All hosts SHALL validate under `nix flake check --no-build` with zero errors.

#### Scenario: Flake check after change

- GIVEN the complete tmux-clipboard-ssh change applied to the repo
- WHEN `nix flake check --no-build` is executed
- THEN the command exits with status 0
- AND no evaluation errors are reported for rog, thinkcentre, t14, or mact2

### Requirement: REQ-8 — MATE Terminal documented limitation

The change MUST NOT claim to fix clipboard over SSH when the client terminal is MATE Terminal. VTE does not implement the OSC 52 handler; this limitation SHALL be documented.

#### Scenario: MATE Terminal SSH copy silently fails

- GIVEN MATE Terminal on rog, SSH into mact2, tmux running remotely
- WHEN the user selects text in copy-mode and presses `y`
- THEN rog's clipboard is NOT updated (VTE ignores OSC 52)
- AND no error is shown to the user

#### Scenario: Documentation present

- GIVEN the change documentation (proposal, design, or spec)
- WHEN a reviewer reads the known limitations
- THEN MATE Terminal's VTE OSC 52 limitation is explicitly stated
- AND the mitigation (use ghostty/kitty for SSH sessions) is documented
