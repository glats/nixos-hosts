# Proposal: bash-to-go-migration

## Intent

Make Go the only language for operational scripts in this repo. Root `go.mod` with the standard Go layout (`cmd/<name>/main.go` multi-entry + `internal/` shared packages), binaries shipped via a single `buildGoModule` `nixos-scripts` derivation in `pkgs/`, and a permanent "Go, never bash" bias injected into every AI surface: OpenCode (AGENTS.md, gentle-orchestrator, and ALL subagents including sdd-apply), Claude Code (CLAUDE.md), and the repo AGENTS.md — codifying the MCP-research-first pattern in the rule itself.

## Scope

### In Scope

- Root `go.mod`/`go.sum`; `cmd/` entry per migrated script; `internal/` packages: `reporoot`, `ui` (replaces `lib/common.sh`), `gitutil`, `sopsutil`, `wg`, `nixbuild`.
- `pkgs/nixos-scripts/default.nix`: `stdenvNoCC` copy → `buildGoModule` (filtered src whitelist: `go.mod`, `go.sum`, `cmd/`, `internal/` — never `secrets/`; `subPackages` per binary; `vendorHash` via fakeHash loop; `wrapProgram` preserved for `device-link` qrencode).
- Full migration of the 18 packaged bash scripts plus `netdiag` (24 total minus 2 exceptions), in waves: trivial pilot → wireguard unification → workflow → critical → `nixos-build` last.
- `netdiag`: Go binary replaces the t14 `writeShellApplication` block (`hosts/t14/default.nix:276-286`), removing the `builtins.readFile` coupling.
- WireGuard unification: `wg-peer` becomes one binary with `add`/`remove`/`generate`/`list` subcommands; `add-wireguard-peer`, `remove-wireguard-peer`, `generate-thinkpad-wireguard` retire.
- Bias injection (5 layers): new `shared/rules/go-scripts.md`; append to `agentsMdSources` (`shared/ai-assets.nix`); **new** `instructionOverlays.subagent` key in `shared/opencode/local-agent-overlays.json`; append to `instructionOverlays.gentle-orchestrator`; repo `AGENTS.md` rules + documented exceptions.
- Documented bash exceptions: `test-tmux-resume` (tests a zsh function; meaningless in Go) and `webcam` (already unpackaged).
- Update `docs/wg-peer.md` for subcommand surface; grep for hardcoded callers before each cutover.

### Out of Scope

- Upstream gentle-ai changes (bias is local to this repo's overlay assets).
- Migrating Nix expressions, `bin/webcam`, or `bin/test-tmux-resume`.
- New functionality beyond behavioral 1:1 parity (flags, exit codes, key outputs preserved).
- nixpkgs/Go version pinning beyond what `pkgs.go` resolves in nixos-26.05.

## Capabilities

### New Capabilities

- `go-script-toolchain`: Standard Go layout, filtered-source `buildGoModule` packaging, vendorHash loop, and the five-layer AI bias (Go over bash + MCP-research-first) across OpenCode agents and Claude Code.

### Modified Capabilities

- None; host composition and package consumers keep the `nixos-scripts` name.

## Approach

Five waves, each a reviewable PR (chained):

1. **W1 scaffold + bias + pilot** (~400 lines): `go.mod`, `cmd/git-id`, `cmd/format-nix`, `internal/{reporoot,ui}`, `buildGoModule` conversion (bash originals coexist until parity), 5-layer bias, AGENTS.md.
2. **W2 wireguard**: `cmd/wg-peer` subcommands + `internal/wg`; retire 3 bash siblings; update `docs/wg-peer.md`.
3. **W3 workflow**: `nixos-build-all`, `code-work`, `linkctl`, `compare-palette`, `device-link`, `export-mate-config`, `sops-rotate-keys` (+`internal/gitutil`, `internal/sopsutil`).
4. **W4 critical**: `netdiag` (+t14 rewire), `install-opencode-auth-seed`, `sync-opencode-remote`, `ai-backup`.
5. **W5 finale**: `nixos-build` (+`internal/nixbuild`) behind a `nixos-build safe` parity pass; delete residual bash in `bin/` and `lib/common.sh`; close exceptions in AGENTS.md.

Parity gate per wave: exit codes, flags, and key outputs match the bash original on representative invocations before bash files are deleted.

## Affected Areas

| Area | Impact |
|---|---|
| `go.mod`, `go.sum`, `cmd/`, `internal/` (new) | Go module with multi-entry layout |
| `pkgs/nixos-scripts/default.nix` | `stdenvNoCC` → `buildGoModule` |
| `shared/ai-assets.nix`, `shared/opencode/local-agent-overlays.json` | Bias injection (fragments + subagent overlay) |
| `AGENTS.md` (repo root) | Go rule in When Coding + Critical Rules |
| `hosts/t14/default.nix` | netdiag `writeShellApplication` removed |
| `docs/wg-peer.md` | Subcommand surface |
| `bin/` | Progressive bash deletion; `lib/` removed at W5 |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `secrets/` enters Go build sandbox | Low, highest impact | Whitelist filter (`lib.fileset`): only `go.mod`, `go.sum`, `cmd/`, `internal/`; verify with `nix build` + path inspection. |
| vendorHash loop churn | High initially, one-time | Stdlib-heavy code; recompute via fakeHash → `got:`. |
| `nixos-build` regression bricks deploys | Medium, highest impact | Last wave; parity gate on `nixos-build safe`; bash kept until gate passes. |
| darwin (mact2) build failure | Low | CGO_ENABLED=0 pure Go; matches gentle-ai/engram platforms; ai-backup shells out to sqlite3 (no cgo). |
| Awk/regex surgery bugs (wg peers, sops rotate) | Medium | `internal/wg` with table-driven `go test` on marker parsing before cutover. |
| Subagent overlay bloats every subagent prompt | Low | Fragment ≤ 30 lines, static. |

## Rollback Plan

Each wave is a separate commit range: `git revert` the wave restores the bash files (deleted only at that wave's cutover) and reverts the derivation; `pkgs.nixos-scripts` name never changes, so no consumer rewiring is needed for rollback. Bias layers revert independently (fragment + two JSON/Nix list edits) without touching code.

## Dependencies

- Go toolchain from nixpkgs 26.05 (`pkgs.go`), `buildGoModule` (in-repo precedents: gentle-ai, engram).
- Runtime tools unchanged: qrencode, sops, age-keygen, ssh-to-age, wg, git, rsync, sqlite3, ethtool/iproute2/nettools (netdiag).

## Success Criteria

- [ ] `pkgs/nixos-scripts` builds via `buildGoModule` on linux + darwin with whitelisted source (no `secrets/` in store paths).
- [ ] All 22 migratable scripts are Go binaries under `cmd/`; `bin/` contains only `test-tmux-resume` and `webcam` (+ nothing else); `lib/common.sh` deleted.
- [ ] `go test ./...` passes (marker parsing, reporoot, parity-critical helpers).
- [ ] Bias live: generated OpenCode AGENTS.md + CLAUDE.md contain the go-scripts rule; every subagent prompt embeds it (`instructionOverlays.subagent`); gentle-orchestrator prompt includes it; repo AGENTS.md documents it + the two exceptions.
- [ ] `format-nix && nix flake check --no-build` passes; t14 canary builds with Go `netdiag`.
