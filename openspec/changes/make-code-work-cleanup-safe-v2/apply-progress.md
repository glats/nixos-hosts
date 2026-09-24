# Apply Progress: make-code-work-cleanup-safe-v2

## Status

Implementation and the user-authorized direct-master delivery are complete. Nix evaluation and flake-check tasks remain blocked by unrelated pre-existing worktree changes; focused and Go-suite evidence passed.

## Completed Tasks

- [x] 1.1–1.3 Legacy flag helper dispatch and RED no-deletion coverage.
- [x] 2.1–2.6 Non-destructive `--done`, safe cleanup guidance, removed `hasUpstream`, updated help, and preserved destructive `--abort` coverage.
- [x] 3.1 Linux shell wrapper split.
- [x] 4.1 Go test suite.
- [x] 4.2 Nix formatting.

## Pending Verification

- [ ] 4.3 Home Manager and NixOS evaluations: blocked by an unrelated duplicate `home.file` definition in `shared/opencode/runtime-config.nix`.
- [ ] 4.4 `nix flake check --no-build`: blocked by unrelated untracked `pkgs/opencode-v2/` required by pre-existing modifications to `lib/packages.nix`.
- [x] 4.5 Commit and push: completed under the user's explicit direct-master authorization despite the unrelated verification blockers.

## Work Unit Evidence

| Work unit | Focused test command and exact result | Runtime harness command/scenario and exact result | Rollback boundary |
|---|---|---|---|
| Go legacy flags | `go -C pkgs/nixos-scripts test ./cmd/code-work -run '^TestLegacyDoneDoesNotDeleteAndAbortDiscards$' -count=1` — RED failed before implementation because dirty `--done` exited 1; GREEN passed after implementation (`ok`, 0.907s). | Helper subprocess creates real legacy worktrees. `--done` on a dirty, committed, no-upstream branch exits 0 and preserves directory, HEAD, and branch ref; `--abort` removes its directory and branch. | Revert `pkgs/nixos-scripts/cmd/code-work/main.go` and `main_test.go`. |
| Linux shell wrapper | `nix fmt -- linux/home/shell.nix` — passed; 1 file processed, 0 changes. | Static wrapper review: `--done` directly invokes the command, while only `--abort` captures the main root and changes back after deletion. | Revert `linux/home/shell.nix`. |

## Full Verification

- `go -C pkgs/nixos-scripts test ./...` — passed; `cmd/code-work` passed in 6.256s and all tested packages passed.
- `nix eval .#homeConfigurations.rog.activationPackage.drvPath` and `.#t14` plus `nix eval .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` — failed before evaluating this change because `shared/opencode/runtime-config.nix` has duplicate `home.file` definitions at lines 131 and 159.
- `nix flake check --no-build` — failed before evaluating this change because pre-existing `lib/packages.nix` references untracked `pkgs/opencode-v2/`.

## Deviations

None. The Nix verification blockers are outside this change's allowed implementation scope and were left untouched.
