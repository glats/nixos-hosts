# Proposal: Fix tmux Color Inversion on SSH (rog→t14) & Unify Cross-Platform Config

## Intent

SSH from rog (ghostty, TERM=xterm-ghostty) to t14 renders tmux with wrong/inverted colors. Root cause: Linux tmux inherits HM default `default-terminal="screen"` (8-color) with no `terminal-overrides`, so hex colors in the base16 theme are approximated to the ANSI palette. Darwin already has the fix (`screen-256color` + `terminal-overrides`). This change moves the fix to shared config and cleans up related dead code.

## Scope

### In Scope
- Move `default-terminal` and `terminal-overrides` from `home-darwin/tmux.nix` to `shared/tmux.nix`
- Remove dead `SetEnv TERM` from `home-linux/ssh.nix`
- Remove duplicated settings from platform files after merge

### Out of Scope
- Plugin mechanism unification (nixpkgs vs TPM — fundamentally different)
- macOS clipboard bindings (platform-specific)
- escapeTime unification (open question — see below)

## Capabilities

### New Capabilities
None — this is a bug fix and config consolidation.

### Modified Capabilities
- `home-manager`: Reinforces the no-host-conditionals invariant by moving platform-independent tmux settings to `shared/tmux.nix`.

## Approach

1. **Add to `shared/tmux.nix` extraConfig** (top, before base16 theme):
   ```
   set -g default-terminal "screen-256color"
   set -as terminal-overrides ',xterm-ghostty:XT,xterm-kitty:XT,*:Tc'
   ```
   `Tc` enables 24-bit true color for all outer terminals. `XT` enables xterm-compatible features for ghostty/kitty.

2. **Remove from `home-darwin/tmux.nix` extraConfig**: the `set -g default-terminal` and `set -as terminal-overrides` lines (now in shared).

3. **Resolve dead SSH code**: Remove `SetEnv TERM = "xterm-256color"` from all hosts in `home-linux/ssh.nix`. With tmux terminal-overrides fixed, TERM forwarding is harmless — tmux handles color rendering regardless. Adding `AcceptEnv TERM` to openssh.nix is an alternative but introduces TERM spoofing surface for no benefit.

4. **Clean up**: No other duplicates to remove. The `lib.mkForce` in `home-linux/tmux.nix` stays (it neutralizes omarchy-nix on t14).

## Open Question: escapeTime

| Platform | Current | Rationale |
|----------|---------|-----------|
| Linux | 0 | Max ESC key responsiveness |
| Darwin | 10 | Compromise: responsive but tolerates escape sequences |

Options:
- **A**: Keep platform-specific (no change) — safest, each host optimized
- **B**: Unify to 0 — max responsiveness everywhere, may break rare escape sequences on macOS
- **C**: Unify to 10 — safe everywhere, slightly less responsive on Linux

**Recommendation**: Option A (keep separate). The values are deliberate and platform-justified.

## Affected Areas

| File | Impact | Description |
|------|--------|-------------|
| `shared/tmux.nix` | Modified | +2 lines: `default-terminal`, `terminal-overrides` |
| `home-darwin/tmux.nix` | Modified | -2 lines: remove `default-terminal`, `terminal-overrides` |
| `home-linux/ssh.nix` | Modified | -7 blocks: remove `SetEnv TERM` from all 7 host entries |

Total: +2 / -21 across 3 files.

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `screen-256color` terminfo missing on some host | Low | tmux package includes it; all hosts use nixpkgs tmux |
| Removing `SetEnv TERM` breaks non-tmux SSH sessions | Low | TERM forwarding (default SSH behavior) sends the real terminal type, which is better than forced `xterm-256color` |
| `,*:Tc` too broad | Low | Tc is a capability flag, not a behavior change — terminals that don't support Tc ignore it |

## Rollback Plan

Single commit. `nixos-build switch --rollback` (Linux) / `darwin-rebuild switch --rollback` (mact2) restores previous tmux.conf atomically. No state migration.

## Success Criteria

- [ ] `nix flake check --no-build` passes
- [ ] SSH rog→t14: tmux status bar shows correct base16 colors (black bg, blue accents)
- [ ] SSH rog→t14: `tmux info | grep terminal-features` shows RGB/Tc for xterm-ghostty
- [ ] Local tmux on all hosts (rog, t14, thinkcentre, mact2) renders correctly
- [ ] `grep -r 'SetEnv' home-linux/ssh.nix` returns no TERM matches
