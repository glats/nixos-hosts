# Tasks: bash-to-go-migration

## Wave 1 — Scaffold + bias + pilot

- [ ] 1.1 Create `go.mod` (module path `github.com/glats/nixos-scripts`), `cmd/git-id/main.go`, `cmd/format-nix/main.go`, `internal/reporoot/` (NIXOS_REPO env → git rev-parse → ~/.nixos fallback, worktree flake-path rule) with table-driven tests, `internal/ui/` (colors/headers/die/confirm — port of `bin/lib/common.sh`).
- [ ] 1.2 Rewrite `pkgs/nixos-scripts/default.nix` as `buildGoModule` with `lib.fileset` whitelist (go.mod, go.sum, cmd/, internal/ only), enumerated `subPackages`, `postFixup` wrapProgram for device-link (qrencode), `vendorHash` resolved via fakeHash → `got:` loop. Bash originals still installed alongside until wave cutover.
- [ ] 1.3 Add `shared/rules/go-scripts.md` (Go mandate + bash prohibition + MCP-research-first recipe + repo verification conventions, ≤30 lines).
- [ ] 1.4 Wire bias: append fragment to `agentsMdSources` default in `shared/ai-assets.nix`; add `"subagent": ["../rules/go-scripts.md"]` and append to `gentle-orchestrator` in `shared/opencode/local-agent-overlays.json`.
- [ ] 1.5 Update repo `AGENTS.md`: Go rule in "When Coding" + "Critical Rules", documented exceptions (test-tmux-resume, webcam), go.mod/cmd/internal layout note.
- [ ] 1.6 Parity check git-id + format-nix side-by-side (exit codes, flags, outputs); cutover commit deletes `bin/git-id`, `bin/format-nix`.
- [ ] 1.7 Verify: `go test ./...`, `format-nix && nix flake check --no-build`, inspect store source of `nixos-scripts` (no secrets/ paths), build one host toplevel.

## Wave 2 — WireGuard unification

- [ ] 2.1 Implement `internal/wg/`: marker-based parse/mutate of declarative `wireguard.nix` (replaces awk surgery + python3 regex), PSK generation via `wg genpsk`, sops decrypt hook for thinkpad generate — table-driven tests first.
- [ ] 2.2 Implement `cmd/wg-peer/main.go` with subcommands `add`, `remove`, `generate`, `list` (behavioral parity with the three bash siblings + listing).
- [ ] 2.3 Grep callers of add-wireguard-peer / remove-wireguard-peer / generate-thinkpad-wireguard; update any references; update `docs/wg-peer.md` to subcommand surface.
- [ ] 2.4 Parity check per subcommand on a scratch branch config; cutover commit deletes the three bash siblings.
- [ ] 2.5 Verify: `go test ./...`, `format-nix && nix flake check --no-build`.

## Wave 3 — Workflow scripts

- [ ] 3.1 `internal/gitutil/` (worktree list/create/remove, branch guards) + `internal/sopsutil/` (sops/age-keygen/ssh-to-age wrappers) with tests.
- [ ] 3.2 Port `nixos-build-all`, `code-work`, `linkctl` (preserve sudo re-exec via argv0 resolution), `compare-palette`, `device-link` (qrencode shell-out; keep wrapProgram), `export-mate-config`, `sops-rotate-keys`.
- [ ] 3.3 Parity checks; cutover commit deletes those 7 bash scripts.
- [ ] 3.4 Verify: `go test ./...`, `format-nix && nix flake check --no-build`, darwin eval of `nixos-scripts` (mact2).

## Wave 4 — Critical scripts

- [ ] 4.1 Port `netdiag` (Go: /sys/class/net + /proc reading, shell-out to ip/ethtool/nettools/curl); rewrite `hosts/t14/default.nix` — remove writeShellApplication block, netdiag reaches PATH via packaged nixos-scripts.
- [ ] 4.2 Port `install-opencode-auth-seed`, `sync-opencode-remote` (ssh/rsync/tar orchestration), `ai-backup` (tar.zst + sqlite3 .backup shell-out — no cgo).
- [ ] 4.3 Parity checks; cutover commit deletes those 4 bash scripts.
- [ ] 4.4 Verify: `go test ./...`, `format-nix && nix flake check --no-build`, t14 toplevel build (netdiag decoupling).

## Wave 5 — nixos-build + finale

- [ ] 5.1 Implement `internal/nixbuild/` (platform detect, nh/nom detect, subcommand dispatch, worktree flake-path) + `cmd/nixos-build/main.go` — full parity with 319-line bash contract (8 subcommands, --raw, --no-nom, darwin branch).
- [ ] 5.2 Parity gate: run `nixos-build safe` (or check+build+dry) end-to-end with Go binary on t14; compare sequencing and exit codes against bash contract.
- [ ] 5.3 Cutover commit: delete `bin/nixos-build` + `bin/lib/common.sh` + any residual bash; `bin/` keeps ONLY test-tmux-resume + webcam.
- [ ] 5.4 Final verification: `go test ./... && format-nix && nix flake check --no-build` for all hosts; t14 canary switch; update AGENTS.md if wording drifted.

## Cross-cutting (every wave)

- [ ] No `secrets/` path ever appears in the derivation's store source.
- [ ] Binary names verbatim; usage()/exit-code contract preserved.
- [ ] Each wave = one reviewable PR ≤ ~400 lines (chained: W1→W5).
