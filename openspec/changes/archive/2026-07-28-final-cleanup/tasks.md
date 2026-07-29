# Tasks: final-cleanup

## Task 1: omarchy.nix mkForce audit (read-only)
- Audit all mkForce overrides in `hosts/t14/home/omarchy.nix`
- Compare against upstream omarchy-nix defaults
- **Result:** All overrides active. No changes needed.
- Commit: `chore(t14): audit omarchy.nix mkForce overrides — all active`

## Task 2: nix-vscode-extensions gate
- In `darwin/home/vscode.nix`: wrap extensions block with `pkgs.stdenv.hostPlatform.isDarwin`
- Add darwin-only comment on flake input in `flake.nix`
- Files: `darwin/home/vscode.nix`, `flake.nix`
- Commit: `fix(darwin): gate nix-vscode-extensions behind isDarwin`

## Task 3: providers-extra → shared/
- Move `darwin/home/opencode/providers-extra.nix` → `shared/opencode/providers-extra.nix`
- Update `shared/opencode/providers.nix` to merge extras via `builtins.pathExists`
- Files: `shared/opencode/providers-extra.nix` (new), `shared/opencode/providers.nix` (modified), `darwin/home/opencode/providers-extra.nix` (deleted)
- Commit: `refactor(shared): move providers-extra to shared/ for cross-platform use`

## Task 4: mcps-extra homeDirectory fix
- Replace `/Users/jcuzmar/` with `${config.home.homeDirectory}` in `darwin/home/opencode/mcps-extra.nix`
- Files: `darwin/home/opencode/mcps-extra.nix`
- Commit: `fix(darwin): replace hardcoded paths in mcps-extra with homeDirectory`

## Task 5: remote-desktop + spotlight-index audit (read-only)
- Audit 3 files for hardcoded paths and portability
- **Result:** All clean. No issues found.
- Commit: `docs: audit remote-desktop and spotlight-index for portability`
