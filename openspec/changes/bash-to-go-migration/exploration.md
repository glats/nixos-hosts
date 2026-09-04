# Exploration: bash-to-go-migration

## Current State

### Script inventory (23 scripts, ~3,600 lines + lib/common.sh 41 lines)

| Script | Lines | Complexity | Notes |
|---|---|---|---|
| `nixos-build` | 319 | **High** | Critical path; flags, platform split, `nh`/`nom` detection, 8 subcommands. Flake app entry (flake.nix:211). |
| `sync-opencode-remote` | 365 | **High** | rsync/tar over ssh, remote orchestration. |
| `ai-backup` | 275 | **High** | tar.zst + sqlite3 `.backup` snapshots + ssh. IS packaged (pkgs/nixos-scripts/default.nix). |
| `code-work` | 314 | **Medium** | Worktree lifecycle; git plumbing. |
| `install-opencode-auth-seed` | 281 | **Medium** | NOT packaged — auth bootstrap. |
| `netdiag` | 246 | **High coupling** | NOT packaged; `builtins.readFile` into t14 `writeShellApplication` (hosts/t14/default.nix:285) with runtimeInputs bc/curl/ethtool/iproute2/nettools. |
| `sops-rotate-keys` | 205 | **Medium** | age-keygen/ssh-to-age/sops subprocesses; heredoc recovery guide. |
| `export-mate-config` | 184 | **Medium** | |
| `device-link` | 180 | **Medium** | qrencode wrapped (packaging). |
| `wg-peer` | 149 | **Medium-High** | Declarative peer mgmt via awk on wireguard.nix markers; calls nixos-build, nix fmt. |
| `compare-palette` | 141 | **Low-Medium** | |
| `nixos-build-all` | 117 | **Low-Medium** | |
| `linkctl` | 105 | **Medium** | auto-sudo re-exec (mact2 system linkctl, hosts/mact2/default.nix:97-99). |
| `format-nix` | 94 | **Low** | find + nix fmt loop. |
| `generate-thinkpad-wireguard` | 86 | **Medium** | sops decrypt + python3 inline regex to edit a nix file. |
| `remove-wireguard-peer` | 66 | **Medium** | awk block deletion. |
| `git-id` | 57 | **Trivial** | |
| `add-wireguard-peer` | 51 | **Trivial** | wg genpsk, heredoc template. |
| `opencode2` | 31 | **Trivial** | launcher. |
| `opencode-home` | 41 | **Trivial** | launcher. |
| `test-tmux-resume` | 253 | **N/A — DO NOT migrate** | Regression harness; extracts zsh function from shared/shell-aliases.nix at runtime. Not packaged. Tests shell behavior; meaningless in Go. |
| `webcam` | 42 | **EXCLUDED** | Already dropped from packaging (comment line 80). |

**Packaged set** (18 in pkgs/nixos-scripts/default.nix): code-work, add-wireguard-peer, ai-backup, compare-palette, export-mate-config, format-nix, git-id, generate-thinkpad-wireguard, linkctl, nixos-build, nixos-build-all, opencode2, opencode-home, remove-wireguard-peer, sops-rotate-keys, sync-opencode-remote, wg-peer, device-link + lib/common.sh.

**NOT packaged** (4): netdiag (readFile-embedded in t14), install-opencode-auth-seed, test-tmux-resume, webcam.

### Packaging wiring

`pkgs/nixos-scripts/default.nix` = stdenvNoCC.mkDerivation, copies each script, wrapProgram device-link with qrencode. Consumed by:
- lib/packages.nix:24 (commonPackages, linux + darwin)
- overlays/linux.nix + overlays/darwin.nix (inherit from self.packages)
- flake.nix:211 (apps.x86_64-linux.nixos-build → nixos-scripts/bin/nixos-build)
- linux/home/shell.nix:9 + darwin/home/shell.nix:3 (home.packages)
- hosts/mact2/default.nix:99 (systemPackages)

Direct bin/ path references: flake.nix:211, hosts/t14/default.nix:285 (readFile netdiag), hosts/mact2/default.nix:97 (linkctl), hosts/rog/default.nix:213 (comment). No go.mod exists in repo.

### Existing buildGoModule precedent

pkgs/gentle-ai and pkgs/engram: buildGoModule + subPackages cmd/<binary> + fixed vendorHash + doCheck=false. Both pre-vendored via flake inputs. The new derivation differs: src = local repo with filtered source.

### Bias injection matrix (5 layers)

| Layer | File | Today | Gap |
|---|---|---|---|
| 1. repo AGENTS.md | ./AGENTS.md | exists, repo-scoped | add Go rule |
| 2. AGENTS.md fragments | shared/ai-assets.nix:32-39 agentsMdSources | gentle-ai AGENTS.md + explore-mcp.md + output-format.md | add go-scripts fragment |
| 3. OpenCode instruction overlays | shared/opencode/agents.nix:102-108 + local-agent-overlays.json | only gentle-orchestrator; **instructionOverlays.subagent undefined** | **all subagents (sdd-apply, sdd-explore, explore, review-\*) get zero local rules today** |
| 4. runtime AGENTS.md gen | shared/opencode/runtime-config.nix:236 | concatenates layer 2 | automatic once layer 2 updated |
| 5. CLAUDE.md gen | shared/claude-code.nix:274 | concatenates layer 2 | automatic once layer 2 updated |

agents.nix:102-108 logic: gentle-orchestrator → instructionOverlays.gentle-orchestrator; mode=subagent → instructionOverlays.subagent (or []); others → []. Overlays are readFile'd at build time and PREPENDED to agent prompts (line 130).

## Research Findings (MCP-verified)

1. **Go in nixpkgs**: top-level `go` resolves to 1.25.x/1.26.x toolchains; zero pinning effort for nixos-26.05.
2. **buildGoModule multi-binary**: `subPackages = [ "cmd/<name>" ... ]` one entry per binary — exact in-repo pattern (gentle-ai, engram). go.mod must be at source root. `vendorHash` loop: fakeHash → build → paste `got:` hash. Alternative: committed vendor/ + vendorHash=null (rejected: bloats repo; deps near-zero).
3. **project-layout** (golang-standards, verified): cmd/<name>/main.go thin entry + internal/ for private shared code (compiler-enforced). Fits 16-18 binaries + shared logic.
4. **Prior art**: go-monk/from-bash-to-go (stdlib replaces curl/awk/jq; no external deps, cross-compile); kennethnym packaging Go CLI as flake with vendorHash=fakeHash; r/NixOS multi-cmd buildGoModule thread.

## Proposed Approach

Root go.mod + standard layout:
```
go.mod, go.sum
cmd/<name>/main.go          # one per migrated binary, thin main
internal/
  reporoot/    # repo-root/worktree detection
  ui/          # color/header/die/confirm (replaces lib/common.sh)
  gitutil/     # worktree/branch helpers (code-work, sops-rotate-keys)
  sopsutil/    # sops/age-keygen/ssh-to-age wrappers
  wg/          # WireGuard declarative peer mgmt (wg-peer + 3 siblings)
  nixbuild/    # nixos-build dispatch logic
```

pkgs/nixos-scripts/default.nix → buildGoModule:
- src = filtered (fileset/cleanSourceWith): ONLY go.mod, go.sum, cmd/, internal/. NEVER secrets/ or .sops.yaml — non-negotiable.
- subPackages = [ "cmd/..." ] for all migrated binaries
- vendorHash via fakeHash loop
- keep makeWrapper/wrapProgram for device-link (qrencode); Go shells out to runtime tools as bash did

Bias injection (5 layers):
1. New fragment shared/rules/go-scripts.md: "operational tooling = Go, never bash" + MCP-research-first recipe (nixos_nix for options/packages, github for prior art, context7/exa for docs) + repo conventions (cmd/, internal/, pkgs wiring, format-nix && nix flake check --no-build)
2. Append to agentsMdSources default (shared/ai-assets.nix)
3. NEW key "subagent": ["../rules/go-scripts.md"] in instructionOverlays (local-agent-overlays.json) — reaches every subagent
4. Append to instructionOverlays.gentle-orchestrator
5. Repo AGENTS.md: rule in When Coding + Critical Rules + documented bash exceptions

Cutover: waves trivial→medium→high; nixos-build last behind safe-workflow parity gate. Bash removed per-wave at cutover (not big-bang).

## Resolved Decisions (orchestrator, from open questions)

1. **Single package**: keep one `nixos-scripts` buildGoModule (all consumers unchanged; minimal churn).
2. **vendorHash loop** (no committed vendor/; deps near-zero, mostly stdlib).
3. **netdiag migrates**: Go binary replaces t14's writeShellApplication block entirely (remove readFile coupling; binary reaches PATH via existing package wiring; ethtool/iproute2/nettools stay as system packages).
4. **test-tmux-resume stays bash** — documented intentional exception (tests a zsh function's behavior; meaningless in Go).
5. **webcam stays bash** — already excluded from packaging.
6. **Wave order**: trivial first (pilot: git-id + format-nix), medium, high last.
7. **Overlay scope**: go-scripts rule to ALL subagents including explore/review-* (they emit planning guidance; write-denied but rule shapes recommendations).
8. **Parity gate**: behavioral parity (exit codes + key outputs + flags preserved), not byte-identical output.

## Constraints & Risks

- **Source filtering**: secrets/ must never enter build sandbox. Whitelist cmd/, internal/, go.{mod,sum} only.
- **vendorHash loop**: one-time with stdlib-heavy deps; re-loop on dep changes.
- **mact2 x86_64-darwin**: CGO_ENABLED=0 pure Go cross-compiles trivially; matches gentle-ai/engram platforms. ai-backup keeps sqlite3 as shell-out (no cgo driver).
- **nixos-build criticality**: flake app + deploy tool for 4 hosts. Last wave, gated on `nixos-build safe` parity pass.
- **Bash constructs needing explicit Go ports**: awk block surgery (wg-peer, remove-wireguard-peer), python3 inline regex (generate-thinkpad-wireguard), mapfile+null-delimited find (format-nix), mktemp/trap patterns, heredoc templates, linkctl sudo re-exec (argv0 resolution).
- **Runtime tool resolution**: qrencode (device-link), sops/age (sops scripts), wg tools, ssh — Go uses os/exec with PATH as bash did; wrapProgram kept where needed.
