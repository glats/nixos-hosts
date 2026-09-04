## Go-Only Operational Scripts (MANDATORY)

All operational/system scripts in this NixOS repo are written in **Go**, never
bash. This binds every OpenCode agent (orchestrator, subagents, build/plan)
and Claude Code.

- New or modified operational tooling → `cmd/<binary-name>/main.go` (thin
  entry: flag parsing + dispatch only) + shared logic in `internal/`
  (`reporoot`, `ui`, `gitutil`, `sopsutil`, `wg`, `nixbuild`). One `go.mod`
  at the repo root, standard layout.
- Do NOT create new `.sh` files or inline bash for operational logic.
  Documented exceptions: `bin/test-tmux-resume` (tests a zsh function) and
  `bin/webcam` (already unpackaged).
- Binaries ship via `pkgs/nixos-scripts` (`buildGoModule`; source whitelist is
  ONLY `go.mod`, `go.sum`, `cmd/`, `internal/` — never `secrets/`).
- Before implementing, verify with MCP: `nixos_nix` for packages/options,
  GitHub search for prior art, context7/exa for library docs. Never guess
  APIs or option paths.
- Parity first: when porting a bash script, preserve the binary name, flags,
  exit codes and key output strings; add `go test` coverage for parsing
  logic before cutover.
- Verify before done: `go test ./... && format-nix && nix flake check --no-build`.
