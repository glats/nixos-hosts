# Tasks: bash-to-go-migration

## Wave 1 — Scaffold + bias + pilot

- [x] 1.1 Create `go.mod` (module path `github.com/glats/nixos-scripts`), `cmd/git-id/main.go`, `cmd/format-nix/main.go`, `internal/reporoot/` (NIXOS_REPO env → git rev-parse → ~/.nixos fallback, worktree flake-path rule) with table-driven tests, `internal/ui/` (colors/headers/die/confirm — port of `bin/lib/common.sh`).
- [x] 1.2 Rewrite `pkgs/nixos-scripts/default.nix` as `buildGoModule` with `lib.fileset` whitelist (go.mod, go.sum, cmd/, internal/ only), enumerated `subPackages`, `postFixup` wrapProgram for device-link (qrencode). **vendorHash = null (zero deps — no loop needed)**. Bash originals coexist in postInstall until wave cutover.
- [x] 1.3 Add `shared/rules/go-scripts.md` (Go mandate + bash prohibition + MCP-research-first recipe + repo verification conventions, ≤30 lines).
- [x] 1.4 Wire bias: append fragment to `agentsMdSources` default in `shared/ai-assets.nix`; add `"subagent": ["../rules/go-scripts.md"]` and append to `gentle-orchestrator` in `shared/opencode/local-agent-overlays.json`.
- [x] 1.5 Update repo `AGENTS.md`: Go rule in "When Coding" + "Critical Rules", documented exceptions (test-tmux-resume, webcam), go.mod/cmd/internal layout note.
- [x] 1.6 Parity check git-id + format-nix side-by-side: usage/help/exit-codes identical, git-id functional on scratch repo (set + Already set), format-nix --check 397 files rc=0. **Cutover deletion pending user-approved commit.**
- [x] 1.7 Verify: `go test ./...` ok, `format-nix && nix flake check --no-build` ok, store source = only cmd/go.mod/go.sum/internal (no secrets/, no .sops.yaml, no bin/), `nix build .#nixos-scripts` ok (18 binaries + lib). Note: `bin/ai-backup` was untracked → staged (flake source excludes untracked files). Note: `.gitignore` legacy `cmd/` pattern removed.

## Wave 2 — WireGuard unification

- [x] 2.1 Implement `internal/wg/`: marker-based parse/mutate of declarative `wireguard.nix` (replaces awk surgery + python3 regex), PSK generation via `wg genpsk`, sops decrypt hook for thinkpad generate — table-driven tests first. (PSK gen not needed: wg-peer model B has no PSK for new peers; sops via `--extract`, zero deps.)
- [x] 2.2 Implement `cmd/wg-peer/main.go` with subcommands `add`, `remove`, `generate`, `list` (+`qr`, preserved from bash wg-peer).
- [x] 2.3 Grep callers of add-wireguard-peer / remove-wireguard-peer / generate-thinkpad-wireguard: only pkgs derivation references them. Legacy scripts were STALE (edited dead paths `modules/wireguard.nix` and `hosts/rog/services/wireguard.nix` — neither exists). Updated `docs/wg-peer.md` to subcommand surface + retirement note.
- [x] 2.4 Parity checks: usage byte-identical to old header, `list` against real module parses 5 peers with live handshake (improved timestamp vs bash truncation), invalid-name die path exact. Cutover commit deletes the three bash siblings.
- [x] 2.5 Verify: `go test ./...` ok, `format-nix && nix flake check --no-build` ok.

## Wave 3 — Workflow scripts

- [ ] 3.1 `internal/gitutil/` (worktree list/create/remove, branch guards) + `internal/sopsutil/` (sops/age-keygen/ssh-to-age wrappers) with tests.
- [ ] 3.2 Port `nixos-build-all`, `code-work`, `linkctl` (preserve sudo re-exec via argv0 resolution), `compare-palette`, `device-link` (qrencode shell-out; keep wrapProgram), `export-mate-config`, `sops-rotate-keys`.
- [ ] 3.3 Parity checks; cutover commit deletes those 7 bash scripts.
- [ ] 3.4 Verify: `go test ./...`, `format-nix && nix flake check --no-build`, darwin eval of `nixos-scripts` (mact2).

## Wave 4 — Critical scripts

- [x] 4.1 Port `netdiag` (Go: /sys/class/net + /proc reading, net/http replaces curl+bc; ip/ping/sudo+ethtool/resolvectl/nmcli still exec'd); rewrite `hosts/t14/default.nix` — remove writeShellApplication block, netdiag reaches PATH via packaged nixos-scripts (ethtool/iproute2/iputils/nettools already in core profile; nothing added).
- [x] 4.2 Port `install-opencode-auth-seed`, `sync-opencode-remote` (ssh/rsync/tar orchestration), `ai-backup` (tar.zst + sqlite3 .backup shell-out — no cgo).
- [x] 4.3 Parity checks; cutover commit deletes those 4 bash scripts. (Usage/help/error/dry-run/list parity done + bash-diffed byte-identical on rog; deleted in commit d47880c. Full fetch+decrypt+merge of the auth seed and the ssh/rsync legs remain cutover-side verification — no ssh/network runs allowed in apply.)
- [x] 4.4 Verify: `go test ./...`, `format-nix && nix flake check --no-build`, t14 toplevel build (netdiag decoupling). (All done — t14 toplevel BUILD succeeded with the decoupling in place.)

## Wave 5 — nixos-build + finale

- [x] 5.1 Implement `internal/nixbuild/` (platform detect, nh/nom detect, subcommand dispatch, worktree flake-path) + `cmd/nixos-build/main.go` — full parity with 319-line bash contract (8 subcommands, --raw, --no-nom, darwin branch). (Table-driven tests prove exact argv sequences for all 8 subcommands × {linux-nh, linux-raw, darwin} × {nom, no-nom}; usage + unknown-command outputs diff-identical to bash; one allowed `nixos-build check` Go run executed the contract path.)
- [ ] 5.2 Parity gate: run `nixos-build safe` (or check+build+dry) end-to-end with Go binary on t14; compare sequencing and exit codes against bash contract. (USER-GATED — do not run during apply; check path already proven, safe argv sequences proven by TestStepsLinuxNH/TestStepsLinuxRaw/TestStepsDarwin.)
- [x] 5.3 Cutover commit: deleted `bin/nixos-build` + `bin/lib/common.sh` + leftover bash wg-peer (commit 857a005); `bin/` keeps ONLY test-tmux-resume + webcam. Derivation is Go-only (17 cmd/ binaries, zero ../../bin references).
- [x] 5.4 Final verification: `go test ./... && format-nix && nix flake check --no-build` all pass; `nix build .#nixos-scripts` clean. Host switches + bias verification in generated opencode.json/CLAUDE.md remain (deploy step, user-gated).

## Cross-cutting (every wave)

- [x] No `secrets/` path ever appears in the derivation's store source. (Verified empirically in W1: store source = only cmd/go.mod/go.sum/internal.)
- [x] Binary names verbatim; usage()/exit-code contract preserved. (Byte-diffs per wave; deviations documented in package docs + commit messages.)
- [x] Each wave = one reviewable commit (chained W1→W5: 871f309, 000a2e2, a004bbe, d47880c, 857a005). Note: W3 exceeded the ~400-line target (9 scripts, ~1,100 lines) — accepted as one reviewable unit.
