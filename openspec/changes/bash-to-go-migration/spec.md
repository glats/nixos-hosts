# Go Script Toolchain Specification

## Purpose

Define the Go-only operational script toolchain for the repo: standard multi-entry layout, filtered-source `buildGoModule` packaging, behavioral parity requirements, and the permanent AI bias that mandates Go over bash for operational tooling across OpenCode and Claude Code.

## Requirements

### 1. Requirement: Standard Go Module Layout

The repo root MUST contain `go.mod`/`go.sum`. Every operational script MUST live as `cmd/<binary-name>/main.go` with a thin entry that delegates to `internal/` packages. Shared logic MUST live under `internal/` (`reporoot`, `ui`, `gitutil`, `sopsutil`, `wg`, `nixbuild`) and MUST NOT be duplicated across `cmd/` entries. `main.go` files MUST NOT contain business logic beyond flag parsing and dispatch.

#### Scenario: Layout inspection [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the repo after any wave lands
- WHEN the module tree is inspected
- THEN `go.mod` exists at the root, every shipped binary has a `cmd/<name>/main.go`, and no `main.go` embeds shared helper logic that exists in `internal/`

### 2. Requirement: Filtered buildGoModule Packaging

`pkgs/nixos-scripts/default.nix` MUST build with `buildGoModule`. Its source MUST be a whitelist filter that includes ONLY `go.mod`, `go.sum`, `cmd/`, and `internal/` — `secrets/`, `.sops.yaml`, `.git`, `.worktrees`, and all other repo paths MUST be excluded. `subPackages` MUST enumerate every shipped `cmd/` entry. A valid `vendorHash` MUST be present. `device-link` MUST retain its qrencode `wrapProgram`.

#### Scenario: Source whitelist holds [hosts: rog, thinkcentre, t14, mact2]
- GIVEN the evaluated `nixos-scripts` derivation
- WHEN its source is realized and inspected
- THEN only `go.mod`, `go.sum`, `cmd/**`, `internal/**` are present
- AND no path under `secrets/` and no `.sops.yaml` exists in the store source

#### Scenario: Binaries ship for both platforms [hosts: rog, thinkcentre, t14, mact2]
- GIVEN `nix build .#nixos-scripts` on x86_64-linux and x86_64-darwin
- WHEN the output is inspected
- THEN every `subPackages` binary exists under `bin/` and `device-link` resolves `qrencode` at runtime

### 3. Requirement: Behavioral Parity Before Cutover

Each migrated script MUST preserve the bash original's observable behavior: subcommand/flag names, exit codes, and key outputs (including `usage()` text fidelity for user-invoked errors). The bash original MUST remain executable until its Go version passes parity on representative invocations; deletion happens only at that wave's cutover commit. `wg-peer` MUST expose `add`/`remove`/`generate`/`list` subcommands replacing the three retired sibling scripts, with `docs/wg-peer.md` updated in the same wave.

#### Scenario: Parity gate on critical script [hosts: rog, thinkcentre, t14]
- GIVEN the Go `nixos-build` replaces the bash original
- WHEN `nixos-build safe` runs end-to-end
- THEN check → build → dry → switch sequencing behaves identically (stop on first failure) and exit codes match the bash original's contract

#### Scenario: WireGuard surface unification [hosts: rog, thinkcentre]
- GIVEN `wg-peer` as a Go binary with subcommands
- WHEN `wg-peer add|remove|generate|list` run
- THEN each produces the same declarative `wireguard.nix` mutations as the retired bash siblings
- AND `docs/wg-peer.md` documents only the subcommand surface

### 4. Requirement: netdiag Decoupling on t14

`hosts/t14/default.nix` MUST NOT embed `bin/netdiag` via `builtins.readFile` into `writeShellApplication`. t14 MUST obtain `netdiag` from the packaged `nixos-scripts` binary set; `ethtool`, `iproute2`, and `nettools` remain available on PATH for runtime shell-outs.

#### Scenario: t14 netdiag is packaged [hosts: t14]
- GIVEN t14's evaluated configuration
- WHEN the `netdiag` resolution is inspected
- THEN no `writeShellApplication` block wraps `bin/netdiag`
- AND `netdiag` resolves to `${pkgs.nixos-scripts}/bin/netdiag`

### 5. Requirement: Five-Layer AI Bias (Go, Never Bash)

A rule fragment `shared/rules/go-scripts.md` MUST exist and mandate: operational tooling is written in Go under `cmd/`/`internal/`; bash is prohibited for new or modified operational scripts; before implementing, verify packages/options with MCP (`nixos_nix`) and search prior art (GitHub, context7, exa). The fragment MUST be injected through all five layers:

1. `agentsMdSources` default list (`shared/ai-assets.nix`) — feeds generated OpenCode AGENTS.md and CLAUDE.md on all hosts;
2. `instructionOverlays.subagent` (`shared/opencode/local-agent-overlays.json`) — prepended to every `mode=subagent` agent prompt (sdd-apply, sdd-explore, explore, review-*, jd-*);
3. `instructionOverlays.gentle-orchestrator` — prepended to the orchestrator prompt;
4. repo `AGENTS.md` — rule in "When Coding" and "Critical Rules" with the two documented exceptions (`bin/test-tmux-resume`, `bin/webcam`).

Generated agent prompts MUST embed the fragment content at build time.

#### Scenario: Bias reaches every AI surface [hosts: t14]
- GIVEN t14's built Home Manager generation
- WHEN the generated OpenCode AGENTS.md, generated CLAUDE.md, and every agent prompt (gentle-orchestrator, each sdd-*, explore, review-*) are inspected
- THEN the go-scripts mandate text is present in each
- AND no agent prompt is missing it

#### Scenario: Rule content codifies MCP-first [hosts: rog, thinkcentre, t14, mact2]
- GIVEN `shared/rules/go-scripts.md`
- WHEN its content is inspected
- THEN it mandates Go for operational scripts, prohibits bash, and prescribes MCP verification before implementation

### 6. Requirement: Tests and Verification Gate

Migrated logic with parsing risk (WireGuard marker surgery, repo-root/worktree detection, config text edits) MUST carry table-driven `go test` coverage, and `go test ./...` MUST pass before each wave's cutover. All changed Nix MUST be formatted and `nix flake check --no-build` MUST pass for all four hosts. t14 MUST build as canary with the Go `netdiag` in place.

#### Scenario: Verification gate per wave [hosts: rog, thinkcentre, t14, mact2]
- GIVEN a wave's implementation is complete
- WHEN `go test ./... && format-nix && nix flake check --no-build` runs
- THEN all three succeed
- AND a t14 build (`nix build .#nixosConfigurations.t14.config.system.build.toplevel`) succeeds when t14-coupled files changed

## Out of Scope

`bin/webcam` and `bin/test-tmux-resume` remain bash by documented exception. Upstream gentle-ai assets, provider routing, and host composition beyond the t14 netdiag block are excluded. No new script functionality beyond 1:1 parity.
