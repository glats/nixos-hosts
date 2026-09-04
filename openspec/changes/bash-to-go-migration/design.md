# Design: bash-to-go-migration

## Technical Approach

One Go module at the repo root, one multi-binary derivation, five injection points for the bias.

### Module layout

```text
go.mod            module github.com/glats/nixos-scripts
go.sum
cmd/
  git-id/main.go            format-nix/main.go       opencode2/main.go
  opencode-home/main.go     add-wireguard-peer→(wg-peer sub)
  wg-peer/main.go           nixos-build-all/main.go  code-work/main.go
  linkctl/main.go           compare-palette/main.go  device-link/main.go
  export-mate-config/main.go  sops-rotate-keys/main.go  ai-backup/main.go
  install-opencode-auth-seed/main.go  sync-opencode-remote/main.go
  netdiag/main.go           nixos-build/main.go
internal/
  reporoot/   git rev-parse --show-toplevel + NIXOS_REPO env + .worktrees flake-path rule
  ui/         colors, headers, die(), confirm(), spinner-ish step logging (ex-common.sh)
  gitutil/    worktree list/create/remove, branch guards (code-work, sops-rotate-keys)
  sopsutil/   sops/age-keygen/ssh-to-age wrappers + ciphertext-only guarantees
  wg/         marker-based wireguard.nix parse/mutate (table-driven tests)
  nixbuild/   platform detect, nh/nom detect, subcommand dispatch (nixos-build, -all)
```

`main.go` = flag parsing + dispatch only. Binary names keep today's names verbatim (users/scripts break otherwise). `wg-peer` absorbs `add/remove/generate-thinkpad` as subcommands — the only intentional CLI-surface change, documented in `docs/wg-peer.md`.

### Packaging (pkgs/nixos-scripts/default.nix)

```nix
buildGoModule {
  pname = "nixos-scripts"; version = "1.0.0";
  src = lib.fileset.toSource {
    root = ../../.;
    fileset = lib.fileset.unions [ ../../go.mod ../../go.sum ../../cmd ../../internal ];
  };
  subPackages = [ "cmd/..." ];  # enumerated per shipped binary
  vendorHash = "sha256-...";    # fakeHash → got: loop, one-time
  nativeBuildInputs = [ makeWrapper ];
  postFixup = ''wrapProgram $out/bin/device-link --prefix PATH : ${lib.makeBinPath [ qrencode ]}'';
}
```

`lib.fileset` whitelist is the security boundary: `secrets/` cannot enter the store source. CGO_ENABLED=0 (pure Go) → darwin build is free; `ai-backup` shells out to `sqlite3` (no cgo driver). Consumers (`lib/packages.nix`, overlays, flake app, home.packages, mact2 systemPackages) keep the `nixos-scripts` name — zero consumer rewiring.

### Bias injection (5 layers, one fragment)

`shared/rules/go-scripts.md` (≤30 lines, static): mandate Go for operational tooling under `cmd/`/`internal/`; prohibit bash for new/modified scripts; the MCP-research-first recipe (`nixos_nix` for options/packages → GitHub prior art → context7/exa docs); repo conventions (`format-nix && nix flake check --no-build`, vendorHash loop, parity gate).

Wiring:
1. `shared/ai-assets.nix` → append fragment path to `agentsMdSources` default → flows to generated OpenCode AGENTS.md (`runtime-config.nix:236`) and CLAUDE.md (`claude-code.nix:274`) on all 4 hosts.
2. `shared/opencode/local-agent-overlays.json` → NEW `"subagent": ["../rules/go-scripts.md"]` under `instructionOverlays` → `agents.nix:105-106` prepends it to EVERY `mode=subagent` prompt (sdd-apply, sdd-explore, explore, review-*, jd-*).
3. Same JSON → append `"../rules/go-scripts.md"` to `instructionOverlays.gentle-orchestrator`.
4. Repo `AGENTS.md` → rule in "When Coding" + "Critical Rules" + the two exceptions (`bin/test-tmux-resume`, `bin/webcam`).

### Parity protocol (per wave)

1. Port with tests (`go test ./internal/wg`, `reporoot` table-driven).
2. Build both; run representative invocations side-by-side (exit codes, flags, key outputs).
3. Cutover commit: delete bash original(s) + update docs/callers (grep for name first).
4. `go test ./... && format-nix && nix flake check --no-build`; t14 canary build when t14-coupled files changed.

## Wave plan

| Wave | Contents | Bash deleted |
|---|---|---|
| W1 | scaffold, bias (all layers), cmd/git-id, cmd/format-nix | git-id, format-nix |
| W2 | internal/wg + cmd/wg-peer subcommands, docs/wg-peer.md | add/remove/generate siblings |
| W3 | nixos-build-all, code-work, linkctl, compare-palette, device-link, export-mate-config, sops-rotate-keys (+gitutil, sopsutil) | those 7 |
| W4 | netdiag (+t14 rewire), install-opencode-auth-seed, sync-opencode-remote, ai-backup | those 4 |
| W5 | nixos-build (+nixbuild) behind `safe` parity pass; delete lib/common.sh + residuals | nixos-build, common.sh |

## Key decisions

| Decision | Choice | Why |
|---|---|---|
| Package granularity | single `nixos-scripts` buildGoModule | zero consumer churn |
| Vendoring | vendorHash loop, no committed vendor/ | deps ≈ stdlib only |
| CLI surface | verbatim names; wg-peer subcommands only exception | minimize breakage |
| netdiag | packaged binary replaces writeShellApplication | kills readFile coupling |
| Bash exceptions | test-tmux-resume, webcam | documented, intentional |
| Go version | whatever `pkgs.go` resolves in nixos-26.05 | no pinning burden |

## Risks

Secrets leak → fileset whitelist + store-path inspection test. vendorHash churn → one-time loop. nixos-build regression → last wave + `safe` parity gate, bash retained until gate. Darwin → CGO off. awk/regex ports → table-driven tests before cutover.
