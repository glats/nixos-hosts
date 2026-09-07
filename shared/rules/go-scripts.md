## Go-Only Operational Scripts (MANDATORY)

All operational scripts in this repo are **Go, never bash** — this binds
every OpenCode agent (orchestrator, subagents, build/plan) and Claude Code.

**Scope.** The ban is on shell scripts, not on artifacts whose native
language is not a script: Nix expressions stay Nix, out-of-tree kernel
modules are C by nature (derivation in `pkgs/` + `boot.extraModulePackages`),
third-party upstream code stays upstream. Rule of thumb: an executable CLI
that orchestrates commands → Go; kernel code, Nix modules, assets → native
form.

**Where code lives.** The Go module is `pkgs/nixos-scripts/` — source, tests
and derivation co-located (`buildGoModule`, `src = ./.`). Thin
`cmd/<name>/main.go` entries (flag parsing + dispatch only); shared logic in
`internal/` (`reporoot`, `gitutil`, `wg`, `nixbuild`). Logic used by ≥2
scripts lives in `internal/`, never copied between `cmd/`; genuinely new
logic lands there too, with tests. Every host switch recompiles all binaries
and runs the test suite in checkPhase — deployed binaries are always the
Nix-built ones; `nix develop` / `go -C pkgs/nixos-scripts run ./cmd/<name>`
is dev iteration only.

**Exceptions** (the only bash allowed): `bin/test-tmux-resume` (tests a zsh
function) and `bin/webcam`.

**Workflow.** Verify before implementing: MCP (`nixos_nix` for
packages/options, GitHub for prior art, context7/exa for docs) — never guess
APIs or option paths. When porting bash, keep the binary name, flags, exit
codes and key outputs, with `go test` coverage for parsing before cutover.
Done means:
`go -C pkgs/nixos-scripts test ./... && format-nix && nix flake check --no-build`.
