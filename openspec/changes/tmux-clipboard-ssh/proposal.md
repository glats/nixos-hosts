# Proposal: tmux-clipboard-ssh

## Intent

Make tmux copy-mode write to the **local** terminal's clipboard identically local and over SSH (e.g. `rog` → `mact2`). Linux pipes to `xclip`, Darwin to `pbcopy` — both touch the *remote* clipboard only.

## Scope

**In**: add `set -s set-clipboard on` and `@override_copy_command` to `shared/tmux.nix`; delete 5 `xclip` `copy-pipe-and-cancel` from `home-linux/tmux.nix`; delete 5 `pbcopy` `copy-pipe-and-cancel` from `home-darwin/tmux.nix`; pin `clipboard-write = allow` in both ghostty configs.

**Out**: SSH config (OSC 52 rides the byte stream); `pkgs.xclip` removal (neovim/scripts need it); `clipboard-read` from default `ask` (security); other terminals (Alacritty/WezTerm/foot/iTerm2/WT — OSC 52 native, no repo config); `wl-clipboard` for t14 (follow-up).

## Non-Goals

Multi-clipboard sync. Remote → local clipboard read (paste into remote tmux).

## Approach

Replace `xclip` / `pbcopy` `copy-pipe-and-cancel` bindings with tmux's built-in OSC 52 path, and override tmux-yank's clipboard command via `@override_copy_command` so it emits OSC 52 instead of piping to xclip/pbcopy. The explicit pipes *suppress* `set-clipboard on` on the hot keys; deleting them unlocks it for tmux's own bindings, and the override covers tmux-yank's. `allow-passthrough on` is already set; Ghostty supports OSC 52 by default. Terminals get explicit settings for a reviewable contract (ghostty only; kitty's default already permits OSC 52 writes). One mechanism works local and over SSH; no SSH change.

## Capabilities

- **New `tmux-clipboard`**: tmux copy-mode writes to the local terminal's clipboard via OSC 52, identical local and over SSH.
- **Modified**: None (existing `home-manager` spec covers the no-host-conditionals invariant only — untouched here).

## Affected Areas

| File | Δ | Change |
|------|---|--------|
| `shared/tmux.nix` | +2 | `set -s set-clipboard on` + `@override_copy_command` |
| `home-linux/tmux.nix` | -5 | drop xclip `copy-pipe-and-cancel` |
| `home-darwin/tmux.nix` | -5 | drop pbcopy `copy-pipe-and-cancel` |
| `home-linux/ghostty.nix` | +1 | `clipboard-write = allow` |
| `home-darwin/ghostty.nix` | +1 | `clipboard-write = allow` |

Total +4 / -10 across 5 files. Single PR, no chaining. **Workstream 3** = verification (in Success Criteria).

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| MATE Terminal (VTE) does NOT implement OSC 52 | Confirmed | VTE upstream refuses since 2018. Use ghostty/kitty/alacritty for SSH (already installed on all hosts). Documented as known limitation. |
| Local clipboard regression | Low | Manual smoke tests on all 4 hosts |
| Ghostty bump flips `clipboard-write` default | Low | Explicit pin locks the contract |
| `@override_copy_command` order fragile | Low | Place in `shared/tmux.nix` before yank plugin sourced; verify with `tmux info` |

## Open Questions (resolved — see exploration.md appendices)

1. **MATE Terminal OSC 52** → **Resolved: NOT supported.** VTE 0.82.3 does not implement the OSC 52 handler (parser only, no-op). No gsettings key exists. Mitigation: use ghostty/kitty for SSH sessions from rog/thinkcentre.
2. **Kitty on SSH path** → **Resolved: no config change needed.** Modern kitty default (`write-clipboard write-primary`) already permits OSC 52 writes. The proposed `clipboard_control = write` was invalid syntax. No kitty change required.
3. **tmux-yank `prefix-y`** → **Resolved: `@override_copy_command` required.** tmux-yank binds `y`/`Enter` with explicit `copy-pipe-and-cancel` to xclip/pbcopy, suppressing `set-clipboard on`. Set `@override_copy_command` in `shared/tmux.nix` (before plugins) with a portable OSC 52 shell emitter.

## Dependencies

Ghostty ≥ 1.0 (pinned via flake — confirmed). tmux ≥ 3.2 in nixpkgs (current 3.4+). No new packages; no flake input changes.

## Rollback Plan

Single PR. `nixos-rebuild switch --rollback` (NixOS) / `darwin-rebuild switch --rollback` (mact2) restores the previous `tmux.conf` atomically. No data migration; no state.

## Success Criteria

- [ ] `nix flake check --no-build` passes for `rog`, `thinkcentre`, `t14`, `mact2`.
- [ ] `rog` → SSH `mact2` → tmux → `y`: text lands in `rog`'s local clipboard.
- [ ] `mact2` → SSH `rog` → tmux → `y`: text lands in `mact2`'s local clipboard.
- [ ] `rog` → SSH `thinkcentre` → tmux → `y`: text lands in `rog`'s local clipboard.
- [ ] Local copy works on all 4 hosts; mouse-drag copy works local + over SSH.
- [ ] `tmux info | grep copy-command` returns empty/default (xclip / pbcopy not in the copy path).
