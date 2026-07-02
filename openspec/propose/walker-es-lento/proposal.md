# Proposal: walker-es-lento

## Intent

Walker (Omarchy desktop launcher on t14) is unusably slow. Root cause: elephant's `files` provider indexes ALL of `$HOME` with zero exclusions. 92% of 21,192 indexed files live in `~/go/pkg/mod/`. Elephant consumes 456 MB RSS, takes 10-30s to reindex on restart, and holds 13,053 fsnotify watches. No `files.toml` exists anywhere in omarchy-nix or nixos-hosts.

## Scope

### In Scope
- Add `config/elephant/files.toml` to omarchy-nix with `ignored_dirs` for build artifacts, caches, and system noise
- Wire it into `modules/home-manager/default.nix` via `home.file` (follows existing `calc.toml` / `desktopapplications.toml` pattern)
- Bump omarchy-nix flake input in nixos-hosts to pull the fix

### Out of Scope
- `max_results` override (deferred — see Approach; 256 is fine once files provider is fixed)
- Elephant WAL checkpoint tuning (separate concern, not the root cause)
- walker theme or keybind changes
- Upstream omarchy `files` provider fix (tracked in basecamp/omarchy#4597)

## Capabilities

### New Capabilities
- `elephant-files-ignore`: `ignored_dirs` configuration for elephant's files provider, excluding build caches and noise from indexing

### Modified Capabilities
None — no existing spec covers walker/elephant performance.

## Approach

**Part A — omarchy-nix (direct push to main)**

1. Create `config/elephant/files.toml` with `ignored_dirs` regex patterns:
   - `/go/pkg/mod` (Go module cache — 92% of current index)
   - `/node_modules`, `/target`, `/__pycache__`, `/.venv`
   - `/.cargo/registry`, `/.cargo/git`
   - `/.local/share/Trash`, `/.cache`
2. Add `home.file` entry in `modules/home-manager/default.nix` after line 143 (after `desktopapplications.toml`):
   ```nix
   ".config/elephant/files.toml" = {
     source = ../../config/elephant/files.toml;
   };
   ```

**Part B — nixos-hosts (direct commit to main)**

1. Bump `omarchy-nix` flake input to new rev (`nix flake lock --update-input omarchy-nix`)

**`max_results` decision: SKIP.** The user initially wanted `max_results = 64` for t14, but analysis shows `max_results = 256` was never the bottleneck — the files provider indexing 20K entries was. After the `files.toml` fix, indexed files drop from ~21K to ~1.7K, making 256 results trivially fast. Overriding `max_results` via `lib.mkForce` on `home.file.".config/walker/config.toml"` would duplicate the entire walker config and create a maintenance burden (t14 misses future omarchy-nix walker updates). Not worth it.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `omarchy-nix/config/elephant/files.toml` | New | `ignored_dirs` list for files provider |
| `omarchy-nix/modules/home-manager/default.nix` | Modified | Add `home.file` entry (~3 lines) |
| `nixos-hosts/flake.lock` | Modified | Bump omarchy-nix rev |

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Regex false positives (e.g. `/target` matches unintended paths) | Low | Patterns are Go regex anchored to path segments; `/target` only matches directory named `target` |
| User must restart elephant after deploy | Certain | Document in commit message; `systemctl --user restart elephant.service` |
| Upstream omarchy adds its own `files.toml` later | Low | Our file becomes the default; upstream would likely converge on similar exclusions |

## Rollback Plan

**omarchy-nix**: `git revert` the commit adding `files.toml` + the `home.file` entry. Push to main.
**nixos-hosts**: `nix flake lock --update-input omarchy-nix` to revert to previous rev. `nixos-build switch`.

## Dependencies

- User must run `systemctl --user restart elephant.service` on t14 after deploy to trigger reindex with new exclusions
- omarchy-nix push must land before nixos-hosts flake bump

## Success Criteria

- [ ] `~/.config/elephant/files.toml` exists on t14 after `nixos-build switch`
- [ ] elephant RSS drops from ~456 MB to <150 MB after restart + reindex
- [ ] Reindex time drops from 10-30s to <1s
- [ ] `sqlite3 ~/.cache/elephant/files.db "SELECT COUNT(*) FROM files;"` returns <3,000 (from 21,192)
- [ ] Walker `.` prefix file search returns results instantly
- [ ] `nix flake check --no-build` passes on nixos-hosts
