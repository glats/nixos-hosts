# Tasks: walker-es-lento

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~15 (11-line TOML + 3-line nix + flake.lock entry) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single commit per repo (omarchy-nix → nixos-hosts) |
| Delivery strategy | direct-commits-on-main |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Work Units

| Unit | Goal | Target repo | Notes |
|------|------|-------------|-------|
| 1 | Add `files.toml` + `home.file` entry | glats/omarchy-nix → main | User has direct push access |
| 2 | Bump `omarchy-nix` flake input | nixos-hosts → master | Depends on Unit 1 landing |
| 3 | Deploy + verify on t14 | t14 host | Out-of-band, post-merge |

## Phase 1: omarchy-nix — Add ignored_dirs

- [x] 1.1 Create `config/elephant/files.toml` in glats/omarchy-nix with `ignored_dirs` list containing all 9 Go-regex patterns: `/go/pkg/mod`, `/node_modules`, `/target`, `/__pycache__`, `/.venv`, `/.cargo/registry`, `/.cargo/git`, `/.local/share/Trash`, `/.cache`
- [x] 1.2 Edit `modules/home-manager/default.nix`: insert `".config/elephant/files.toml" = { source = ../../config/elephant/files.toml; };` block immediately after the `desktopapplications.toml` entry (around line 143), preserving existing indentation
- [x] 1.3 Commit both files in a single commit (message: "elephant: ignore build artifacts and caches in files provider") and push to `main`; capture the new commit SHA for Phase 2

## Phase 2: nixos-hosts — Bump flake input

- [x] 2.1 Run `nix flake lock --update-input omarchy-nix` from repo root; verify `flake.lock` now points to the commit from task 1.3
- [x] 2.2 Run `nix flake check --no-build` to validate flake integrity (must exit 0)
- [x] 2.3 Commit updated `flake.lock` (message: "flake: bump omarchy-nix (elephant files.toml)") and push to `master`

## Phase 3: Deploy + verify on t14

- [ ] 3.1 On t14: run `nixos-build` to build+switch; confirm `~/.config/elephant/files.toml` exists with all 9 patterns
- [ ] 3.2 On t14: `systemctl --user restart elephant.service` and wait for reindex; check `journalctl --user -u elephant.service -n 30` for "reindex complete" or absence of errors
- [ ] 3.3 On t14: verify success criteria — `systemctl --user status elephant.service | grep Memory` shows <150 MB; `sqlite3 ~/.cache/elephant/files.db "SELECT COUNT(*) FROM files;"` returns <3,000; walker `.` prefix search returns results in <500ms
- [ ] 3.4 On t14: confirm no regression — `~/.config/walker/config.toml` unchanged (max_results still 256), desktop applications still searchable via walker

## Notes

- omarchy-nix repo lives at `github.com/glats/omarchy-nix` (user has full push access per AGENTS.md); local clone path unknown — assume `git push` from clone dir
- `nixos-build` auto-detects worktree and `nh` vs `nixos-rebuild`; safe variant runs check→build→dry→switch
- `format-nix` is not strictly required here (TOML is not formatted, nix change is 3 lines, flake.lock is generated) — skip unless `nix fmt` flags the edit
- No tests, no docs, no migrations — verification is runtime-only on t14
