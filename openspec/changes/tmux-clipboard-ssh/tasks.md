# Tasks: tmux-clipboard-ssh

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | +4 / -10 (~14-16 net across 5 files) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR with 5 ordered commits |
| Estimated review time | ~15-20 min (config-only, no logic) |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | OSC 52 unified clipboard | PR 1 | 5 commits, all `.nix`, no flake input changes; rollback = `nixos-rebuild switch --rollback` |

## Phase 1: Foundation (shared tmux)

- [x] **1.1** Add OSC 52 trigger to `shared/tmux.nix`. **Files**: `shared/tmux.nix` (+2). **Do**: insert `set -s set-clipboard on` and `set -g @override_copy_command "printf '\033]52;c;%s\033\\' \"$(base64 | tr -d '\n')\" >/dev/tty"` immediately after `set -g allow-passthrough on` (line 14). ST terminator matches tmux's native `set-clipboard` output; `tr -d '\n'` keeps `base64` portable (GNU + BSD); `/dev/tty` writes past the tmux pipe consumer. **Verify**: `nix fmt -- shared/tmux.nix`; `nix flake check --no-build` passes; `tmux info | grep -A1 copy-command` (after switch) returns the OSC 52 emitter, not empty.

## Phase 2: Platform tmux cleanup (depends on 1.1)

- [x] **2.1** Drop xclip bindings from `home-linux/tmux.nix`. **Files**: `home-linux/tmux.nix` (~-7). **Do**: replace `lib.mkForce (sharedExtraConfig + '' ... '')` with `lib.mkForce sharedExtraConfig`, removing the 5 `bind -T copy-mode[-vi] ... copy-pipe-and-cancel "xclip -i -selection clipboard"` lines (51-55) plus the comment header. xclip stays in `modules/base/profiles/base.nix` (still used by neovim, rofi, scripts). **Verify**: `nix flake check --no-build` passes; after `home-manager switch`, `tmux info | grep copy-command` shows the OSC 52 emitter (not xclip); local copy still works (xclip not on hot path).

- [x] **2.2** Drop pbcopy bindings from `home-darwin/tmux.nix`. **Files**: `home-darwin/tmux.nix` (-5). **Do**: remove the 5 `bind -T copy-mode[-vi] ... copy-pipe-and-cancel "pbcopy"` lines (64-68); keep `set -s set-clipboard on` (line 62, harmless duplicate after shared adds it) and `bind -T copy-mode-vi v send -X begin-selection` (line 63). **Verify**: `darwin-rebuild check` passes; after `darwin-rebuild switch`, `tmux info | grep copy-command` shows the OSC 52 emitter (not pbcopy); local copy on mact2 still works.

## Phase 3: Terminal hardening (independent of phases 1-2)

- [x] **3.1** Pin `clipboard-write` in `home-linux/ghostty.nix`. **Files**: `home-linux/ghostty.nix` (+1). **Do**: add `clipboard-write = "allow";` (Nix string, trailing semicolon) to the `programs.ghostty.settings` attrset alongside the existing keys (lines 23-31). Locks the contract against future ghostty default flips. **Verify**: `nix flake check --no-build` passes; `cat ~/.config/ghostty/config | grep clipboard-write` shows the pin on rog, thinkcentre, t14.

- [x] **3.2** Pin `clipboard-write` in `home-darwin/ghostty.nix`. **Files**: `home-darwin/ghostty.nix` (+1). **Do**: add `clipboard-write = allow` (unquoted, raw ghostty config syntax, no semicolon) to the `home.file."Library/Application Support/com.mitchellh.ghostty/config".text` block (line 4). **Verify**: `darwin-rebuild check` passes; `cat "~/Library/Application Support/com.mitchellh.ghostty/config" | grep clipboard-write` shows the pin on mact2.

## Phase 4: Verification (depends on 1.1, 2.1, 2.2, 3.1, 3.2)

- [x] **4.1** Static validation. **Do**: run `nix flake check --no-build` for all 4 hosts (`#rog`, `#thinkcentre`, `#t14`, `#mact2`); run `nix fmt -- shared/tmux.nix home-linux/tmux.nix home-darwin/tmux.nix home-linux/ghostty.nix home-darwin/ghostty.nix`. **Verify**: all `nix flake check` invocations exit 0; `nix fmt` reports no changes on already-formatted files.

- [ ] **4.2** Manual smoke tests per `design.md` Test Plan. **Do**: (a) local ghostty -> tmux -> `y` -> paste on each of rog, thinkcentre, t14, mact2; (b) `rog` -> SSH `mact2` -> tmux -> `y`, paste back in rog; (c) `mact2` -> SSH `rog` -> tmux -> `y`, paste back in mact2; (d) `rog` -> SSH `thinkcentre` -> tmux -> `y`, paste back in rog; (e) mouse-drag copy in tmux on all 4 hosts; (f) `tmux info | grep copy-command` on all 4 hosts. **Verify**: all 6 scenarios show text in the SSH *client*'s clipboard (not the remote); copy-command resolves to the OSC 52 emitter. Note MATE Terminal caveat (VTE no-op, out of scope, documented in `exploration.md` Q1).
