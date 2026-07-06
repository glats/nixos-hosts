# Proposal: Fix xterm-ghostty TERM errors on SSH between hosts

## Intent

Eliminate `can't find terminal definition for xterm-ghostty` errors in Home Manager activation scripts when SSHing between hosts. All inter-host SSH connections should produce no terminal-related errors regardless of the source terminal emulator.

## Scope

- **In scope**: Ghostty `term` configuration on Linux (t14/rog/thinkcentre); SSH `SetEnv TERM` entries on macOS (mact2) for rog and t14.
- **Out of scope**: Installing ghostty terminfo on macOS; modifying other terminal emulators (e.g., foot, Kitty); CI/CD or remote-execution scenarios.

## Capabilities

| ID | Capability | Verification |
|----|------------|-------------|
| C-01 | SSH from t14 to mact2 does not produce "can't find terminal definition" errors | `ssh mact2.local echo $TERM` returns `xterm-256color`; no stderr warnings |
| C-02 | SSH from mact2 to rog does not produce terminal errors | `ssh rog.local echo $TERM` succeeds without warnings |
| C-03 | SSH from mact2 to t14 does not produce terminal errors | `ssh t14.local echo $TERM` succeeds without warnings |
| C-04 | All Linux hosts (t14, rog, thinkcentre) report `TERM=xterm-256color` inside Ghostty | `echo $TERM` on each host returns `xterm-256color` |

## Approach

Two parallel changes:

1. **Linux Ghostty override (B)** — Set `term = "xterm-256color"` in `home-linux/ghostty.nix`. This fixes the root cause: Ghostty on Linux defaults to `xterm-ghostty` which macOS has no terminfo for. All SSH connections from any Linux host benefit immediately. All three Linux hosts (t14, rog, thinkcentre) share this config.

2. **macOS SSH SetEnv additions (D)** — Add `SetEnv TERM = "xterm-256color"` to the `rog.local` and `t14.local` entries in `home-darwin/ssh.nix`. This covers the reverse direction: when terminal emulators on macOS send a non-standard TERM value to Linux hosts, Linux receives the overridden value.

## Affected Areas

| File | Change |
|------|--------|
| `home-linux/ghostty.nix` | Add `term = "xterm-256color"` to `programs.ghostty.settings` |
| `home-darwin/ssh.nix` | Add `SetEnv = { TERM = "xterm-256color"; }` to `rog.local` and `t14.local` blocks |

## Risks

- **Low**: Overriding `term` in Ghostty may affect terminal detection by programs that check `TERM` for feature negotiation. `xterm-256color` is a widely-supported superset — regressions are unlikely.
- **None**: Both changes are config-only, no runtime daemons or services affected.

## Rollback Plan

Revert the two config additions and rebuild:

```bash
git checkout -- home-linux/ghostty.nix home-darwin/ssh.nix
nixos-build safe
```

(On mact2, run `darwin-rebuild switch` instead.)

## Dependencies

- Must be applied on both Linux hosts (via `nixos-build`) and macOS (via `darwin-rebuild`).
- No package or flake input changes.

## Success Criteria

All four capabilities (C-01 through C-04) pass on the next rebuild+SSH cycle:

1. `ssh mact2.local echo $TERM` — returns `xterm-256color`, no stderr
2. `ssh rog.local echo $TERM` — returns `xterm-256color`, no stderr
3. `ssh t14.local echo $TERM` — returns `xterm-256color`, no stderr
4. `echo $TERM` on each Linux host — returns `xterm-256color`
