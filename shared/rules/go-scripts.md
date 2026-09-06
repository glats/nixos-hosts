## Go-Only Operational Scripts (MANDATORY)

All operational/system scripts in this NixOS repo are written in **Go**, never
bash. This binds every OpenCode agent (orchestrator, subagents, build/plan)
and Claude Code.

- New or modified operational tooling lives in the Go module at
  `pkgs/nixos-scripts/`: `cmd/<binary-name>/main.go` (thin entry: flag
  parsing + dispatch only) + shared logic in `internal/` (`reporoot`, `ui`,
  `gitutil`, `wg`, `nixbuild`). One `go.mod` inside the package dir — source,
  tests and derivation co-located.
- **Shared functions**: logic used by ≥2 scripts lives in `internal/` and is
  imported by both — never copied between `cmd/` entries. A new script
  should be one thin `cmd/<name>/main.go` reusing existing `internal/`
  packages; only genuinely new logic gets new internal code (with tests).
- Do NOT create new `.sh` files or inline bash for operational logic.
  Documented exceptions: `bin/test-tmux-resume` (tests a zsh function) and
  `bin/webcam` (already unpackaged).
- Binaries ship via `pkgs/nixos-scripts` (`buildGoModule`, `src = ./.` —
  the module dir is its own sandbox; `secrets/` can never enter). Every
  host switch recompiles all binaries and runs `go test ./...` in
  checkPhase.
- Before implementing, verify with MCP: `nixos_nix` for packages/options,
  GitHub search for prior art, context7/exa for library docs. Never guess
  APIs or option paths.
- Parity first: when porting a bash script, preserve the binary name, flags,
  exit codes and key output strings; add `go test` coverage for parsing
  logic before cutover.
- Verify before done: `go -C pkgs/nixos-scripts test ./... && format-nix &&
  nix flake check --no-build`. For iteration use `nix develop` (toolchain)
  or `go -C pkgs/nixos-scripts run ./cmd/<name>`; deployed binaries are
  always the Nix-built ones.
