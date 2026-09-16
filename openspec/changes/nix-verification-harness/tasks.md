# Tasks: Nix Verification Harness

All work happens inside the `nix-verification-harness` worktree. `format-nix` is FORBIDDEN here (targets `/etc/nixos` = main checkout); every format/eval/check command is cwd-scoped to the worktree.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ≈3,000–8,000 (≈95% is the blame-ignored treewide reformat of ~400 files; logic + docs ≈250–350) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 formatter+parity → PR 2 reformat → PR 3 blame-ignore → PR 4 checks+docs+verification |
| Delivery strategy | ask-on-risk |
| Chain strategy | stacked-to-main |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Formatter wiring + format-nix --check parity + Go tests | PR 1 | `go -C pkgs/nixos-scripts test ./...` | `nix flake check --no-build` from worktree (legacy checks unchanged) | Revert `flake.nix` formatter lines + Go files; independent of 2–4 |
| 2 | Treewide RFC-166 reformat (format-only) | PR 2 | `nix fmt -- --ci` (exit 0 after) | Bare `nix fmt` from worktree root (can't run in CI) | Revert format commit; old style restored, blame-ignore not yet present |
| 3 | `.git-blame-ignore-revs` entry | PR 3 | `git show <hash> --stat` | `git blame` on a reformatted file with `blame.ignoreRevsFile` set | Delete/revert `.git-blame-ignore-revs` |
| 4 | Checks simplification + format check + AGENTS.md + config + final tier-3 | PR 4 | `nix flake check --no-build` | Full verification matrix from worktree cwd | Revert checks block + `AGENTS.md` + `openspec/config.yaml` |

## Phase 1: Formatter Wiring and format-nix Parity (Commit 1)

- [x] 1.1 [AGENT] Swap the three `formatter.<system>` lines in `flake.nix` from `nixpkgs-fmt` to `nixpkgs.legacyPackages.<system>.nixfmt-tree` (per `design.md` (read-only)); do NOT touch `checks.x86_64-linux` yet and do NOT run `nix fmt` on the tree — it stays intentionally unformatted until Commit 2.
- [x] 1.2 [AGENT] RED test (threat-matrix Git repository selection): extend `pkgs/nixos-scripts/cmd/format-nix/main_test.go` with hermetic tests proving a check copy lands inside the repo root with `.nix` suffix / `.format-nix-` prefix and that `nixFiles` skips `.format-nix-*` entries; MUST fail against the current extensionless `/tmp` copy and current walk. RED observed: `createCheckCopy` undefined before production implementation.
- [x] 1.3 [AGENT] Production fix in `pkgs/nixos-scripts/cmd/format-nix/main.go`: extract a repo-root `os.CreateTemp(".", ".format-nix-*.nix")` copy helper used by `checkFile`, skip `.format-nix-*` in `nixFiles` (keeping `.git`/`.worktrees` exclusions), and rename the anti-pattern line in `helpText` to the new formatter binary (`nixfmt-tree <path>`); preserve messages and exit codes.
- [x] 1.4 [AGENT] Verify Commit 1: `go -C pkgs/nixos-scripts test ./...` green; `nix eval .#nixosConfigurations.t14.config.system.build.toplevel.drvPath` ok; `nix flake check --no-build` ok (legacy toplevel checks unchanged); commit as `feat(format): wire nixfmt-tree formatter + format-nix --check parity`.

## Phase 2: Treewide Reformat (Commit 2)

- [x] 2.1 [AGENT] Run bare `nix fmt` once from the worktree root (reformats every tracked `.nix` file via treefmt; untracked `openspec/` dir untouched). Evidence: treefmt traversed 633 files, emitted 212, changed 116.
- [x] 2.2 [AGENT] Stage ONLY `.nix` paths (selective `git add`, never `-A` — keeps the untracked `openspec/changes/nix-verification-harness/` out of the format commit) and commit as `style(nix): treewide RFC-166 reformat`.
- [x] 2.3 [AGENT] Proof: `git show --stat HEAD` lists only `.nix` paths; `nix fmt -- --ci` exits 0; spot-check `git show HEAD -- flake.nix` for formatting-only hunks. Evidence: commit `39108ec54da921cccc4d09d457e2382d021a48a3`; 116 `.nix` paths; CI formatter reported 0 changed.

## Phase 3: Blame-Ignore Recording (Commit 3)

- [x] 3.1 [AGENT] Create `.git-blame-ignore-revs` containing the exact Commit-2 hash (`git rev-parse HEAD` captured before commit 3) with an optional comment line; commit as `chore(git): record RFC-166 reformat in blame-ignore`. Evidence: file records `39108ec54da921cccc4d09d457e2382d021a48a3`.

## Phase 4: Checks, Docs, Config, Final Verification (Commit 4)

- [x] 4.1 [AGENT] In `flake.nix`, delete the rog/thinkcentre/t14 entries from `checks.x86_64-linux` and add the single `format` derivation per `design.md` (read-only): `pkgs.runCommand "nix-format-check" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; }` running `cp -r ${self} source; chmod -R u+w source; cd source; treefmt --ci --walk filesystem --tree-root .; touch $out`.
- [x] 4.2 [AGENT] Update `AGENTS.md`: formatter = `nixfmt-tree` (RFC-166); tier-3 row worktree-safe (`format-nix && nix flake check --no-build` in main checkout, `nix fmt -- --ci && nix flake check --no-build` in worktrees); rewrite the ⚠️ checks note to state `nix flake check` evaluates `nixosConfigurations` only and document the darwinConfigurations + standalone homeConfigurations blind spot with targeted eval commands; add the never-`format-nix`-in-a-worktree rule to the formatting table.
- [x] 4.3 [AGENT] Update `openspec/config.yaml`: keep `testing.formatter: format-nix` and both `nix flake check --no-build` values; make `rules.apply.guidelines` worktree-safe (cwd-scoped `nix fmt` in worktrees instead of `format-nix`).
- [x] 4.4 [AGENT] Final tier-3 from the worktree: `nix fmt -- --ci` exit 0; `go -C pkgs/nixos-scripts test ./...`; `nix build .#nixos-scripts`; `nix flake check --no-build` (checks = format only); targeted evals — t14 toplevel, mact2 darwin toplevel, one standalone HM activationPackage — plus the full spec matrix: rog/thinkcentre toplevels, macm5 darwin toplevel, all five `homeConfigurations` activation drvPaths; optional `nix build .#checks.x86_64-linux.format` proves the derivation. Evidence: format CI, Go tests, scripts build, format derivation build, flake check, t14/rog/thinkcentre toplevel evals, and rog/thinkcentre/t14 HM evals passed. Darwin toplevel and Darwin standalone HM evals were attempted and are blocked on this x86_64-linux runner by cross-system platform mismatch.
- [x] 4.5 [AGENT] Commit 4 as `feat(checks): simplify flake checks + worktree-safe verification docs`.

## Cross-cutting

- [AGENT] Never run `format-nix` inside the worktree (it chdirs to `/etc/nixos`); every format/eval/check command runs from the worktree cwd.
- [AGENT] Rollback in reverse order (4→3→2→1); each commit is independently revertible and no host definition changes.
- [AGENT] No secrets in plaintext; no new bash scripts (Go-only policy); artifacts in English.

### Apply Evidence and Deviations

- Commit 1: `go -C pkgs/nixos-scripts test ./...`, targeted t14 drvPath eval, and legacy `nix flake check --no-build` passed.
- Commit 4: final commands were run from the worktree; `format-nix` was never invoked. Darwin evaluations remain environment-limited on this x86_64-linux runner; verify them on the corresponding Darwin hosts.
