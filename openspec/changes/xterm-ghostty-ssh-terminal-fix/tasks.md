# Tasks — xterm-ghostty-ssh-terminal-fix

## Review Workload Forecast

- **Estimated changed lines**: ~4 additions, ~0 deletions
- **Decision needed before apply**: No
- **Chained PRs recommended**: No
- **400-line budget risk**: Low

## Phase 1: Linux Ghostty TERM Setting

### 1.1 Add `term` to Ghostty settings in `home-linux/ghostty.nix`

- **File**: `home-linux/ghostty.nix`
- **Change**: Add `term = "xterm-256color";` to the `programs.ghostty.settings` attrset (inside the `lib.mkForce` block).
- **Insert after**: `theme = "nix-colors";` (line 37) to keep alphabetical-ish grouping with theme-related settings.
- **Verify**: `nix flake check --no-build` must pass.

## Phase 2: macOS SSH SetEnv for rog.local and t14.local

### 2.1 Add `SetEnv` to `rog.local` host entry in `home-darwin/ssh.nix`

- **File**: `home-darwin/ssh.nix`
- **Change**: Add `SetEnv = { TERM = "xterm-256color"; };` to the `rog.local` host settings block (lines 30-34).
- **Note**: The entry already has `HostName`, `User`, `IdentityFile`. Add `SetEnv` as an additional attribute.

### 2.2 Add `SetEnv` to `t14.local` host entry in `home-darwin/ssh.nix`

- **File**: `home-darwin/ssh.nix`
- **Change**: Add `SetEnv = { TERM = "xterm-256color"; };` to the `t14.local` host settings block (lines 36-39).
- **Note**: The entry already has `HostName`, `User`, `IdentityFile`. Add `SetEnv` as an additional attribute.

## Phase 3: Validation

### 3.1 Format and check

- Run `format-nix` to format all Nix files.
- Run `nix flake check --no-build` to validate the flake.
- Verify both commands exit 0.

## Checklist

- [ ] 1.1 — `term` added to `home-linux/ghostty.nix`
- [ ] 2.1 — `SetEnv` added to `rog.local` in `home-darwin/ssh.nix`
- [ ] 2.2 — `SetEnv` added to `t14.local` in `home-darwin/ssh.nix`
- [ ] 3.1 — `format-nix` and `nix flake check --no-build` pass
