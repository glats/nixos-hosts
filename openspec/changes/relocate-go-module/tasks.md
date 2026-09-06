# Tasks: relocate-go-module

- [x] 1. `git mv go.mod go.sum cmd internal` → `pkgs/nixos-scripts/`; `git add` immediately (flake source only sees tracked files).
- [x] 2. Simplify `pkgs/nixos-scripts/default.nix`: drop `lib.fileset` whitelist → `src = ./.;`; subPackages unchanged (relative paths same); remove now-dead comments about whitelisting.
- [x] 3. Update `shared/rules/go-scripts.md`: paths `cmd/` → `pkgs/nixos-scripts/cmd/`, `internal/` → `pkgs/nixos-scripts/internal/`; add the shared-functions rule (logic used by ≥2 scripts lives in internal/, never copied between cmd/); verification command with `-C`.
- [x] 4. Update `AGENTS.md`: Project Structure block, When Coding #9, Critical Rules #8, Development table (`go -C pkgs/nixos-scripts test ./...`).
- [x] 5. Verify: `go -C pkgs/nixos-scripts test ./...`, `format-nix`, `nix flake check --no-build`, `nix build .#nixos-scripts`, store source = package dir content (no root files, no secrets), commit.
