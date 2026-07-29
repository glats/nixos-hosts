# Design: final-cleanup

## Architecture

5 independent, low-risk cleanups. Each is a single commit. No inter-dependencies.

### Item 1: omarchy.nix mkForce audit

Upstream omarchy-nix `config.nix` defaults:
- `rotate_on_start` → `true` (t14 overrides to `false` — **keep**)
- `fonts.fontconfig.enable` → `true` in `fonts.nix` (t14 overrides to `false` — **keep**)
- `programs.starship.enable` → `true` in `starship.nix` (t14 overrides to `false` — **keep**)
- `programs.zsh.zplug.enable` → `true` in `zsh.nix` (t14 overrides to `false` — **keep**)
- `gtk.theme` → Adwaita-dark (t14 overrides to Materia-dark-compact — **keep**)
- `omarchy.fcitx5.enable` → `false` default (t14 overrides to `true` — **keep**)
- `omarchy.fonts.*` → `"monospace"` defaults (t14 overrides to custom — **keep**)

**Result: All 18 mkForce overrides are active and necessary.** No dead overrides found. Commit documents the audit with no code changes.

### Item 2: nix-vscode-extensions gate

Flake input `nix-vscode-extensions` fetched on all hosts. Only `darwin/home/vscode.nix` uses it. Gate with `pkgs.stdenv.hostPlatform.isDarwin` so Linux evals skip the extension list. Add comment on flake input noting darwin-only.

### Item 3: providers-extra → shared/

Move `darwin/home/opencode/providers-extra.nix` → `shared/opencode/providers-extra.nix`. Update `shared/opencode/providers.nix` to merge extras via `builtins.pathExists` guard. Both platforms gain 10 extra providers. No behavior change until `activeProviderName` targets one of them.

### Item 4: mcps-extra homeDirectory fix

Replace 2 hardcoded `/Users/jcuzmar/` paths in `darwin/home/opencode/mcps-extra.nix` with `${config.home.homeDirectory}`. 2-line change.

### Item 5: remote-desktop + spotlight-index audit

Read-only audit of 3 files. Report findings. No code changes unless issues found.

**linux/home/remote-desktop.nix** (316 lines):
- Hardcoded `/home/glats` in remmina.pref `datadir_path` (line 188) and desktop launcher `exec` paths (lines 269, 276, 283, 291, 304, 311). These are portable across linux hosts (all use `glats` user). Acceptable.
- `username = "glats"` in rdpDefaults (line 125). Intentional — RDP auth to specific hosts.
- `drive = "/home/glats"` in rdpDefaults (line 126). Intentional — RDP drive mapping.
- No issues found.

**darwin/home/remote-desktop.nix** (259 lines):
- Uses `config.home.username` for RDP username (line 19). Clean.
- No hardcoded paths. Well-structured C launcher pattern.
- No issues found.

**darwin/home/spotlight-index.nix** (144 lines):
- Uses `$HOME` throughout. Fully portable.
- Robust realpath resolution with fallback chain.
- Atomic swap with trash/backup pattern.
- No issues found.

## Verification

- `nix flake check --no-build` must pass
- Each commit independently revertible
