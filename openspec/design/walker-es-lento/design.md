# Design: walker-es-lento

## Technical Approach

Add `ignored_dirs` configuration to elephant's `files` provider via a new `files.toml` in omarchy-nix, wire it through Home Manager using the existing `calc.toml` / `desktopapplications.toml` pattern, then bump the omarchy-nix flake input in nixos-hosts. Two repos, three file touches, zero new modules.

## Architecture Decisions

### Decision: ignored_dirs as Go regex patterns

**Choice**: TOML list of Go regex strings matched against full directory paths by elephant's `files` provider.

**Patterns and rationale**:

| Pattern | Target | Why |
|---------|--------|-----|
| `/go/pkg/mod` | Go module cache | 92% of current index (19,491 of 21,192 rows) |
| `/node_modules` | Node.js deps | Common large tree |
| `/target` | Rust build output | Common large tree |
| `/__pycache__` | Python bytecode | Common noise |
| `/.venv` | Python venvs | Large, ephemeral |
| `/.cargo/registry` | Rust crate cache | Large, reproducible |
| `/.cargo/git` | Rust git checkouts | Large, reproducible |
| `/.local/share/Trash` | Desktop trash | Not user-searchable |
| `/.cache` | XDG cache dir | Ephemeral, not useful |

**Alternatives considered**: Glob patterns (elephant uses Go regex, not glob). Whitelist approach (too fragile — new dirs would slip through). Upstream fix in omarchy (tracked in basecamp/omarchy#4597, not blocked on it).

### Decision: Skip max_results override

**Choice**: Leave walker `max_results = 256` unchanged.

**Rationale**: The bottleneck is file count (21K → <3K after `files.toml`), not result limit. Overriding `max_results` via `lib.mkForce` on `home.file.".config/walker/config.toml"` would duplicate the entire walker config and create maintenance burden (t14 misses future omarchy-nix walker updates). Not worth it.

### Decision: Deployment via home.file, not xdg.configFile

**Choice**: Use `home.file.".config/elephant/files.toml"` with `source =` syntax.

**Rationale**: Follows the exact pattern of `calc.toml` (line 138) and `desktopapplications.toml` (line 141). Consistent with existing elephant config deployment. `xdg.configFile` would also work but breaks the pattern.

## Data Flow

```
omarchy-nix/config/elephant/files.toml
         │
         │ home.file source
         ▼
~/.config/elephant/files.toml  (on t14 after nixos-build switch)
         │
         │ elephant reads on startup
         ▼
elephant files provider skips ignored_dirs during indexing
         │
         ▼
~/.cache/elephant/files.db  (index drops from 21K to <3K rows)
         │
         │ walker queries elephant
         ▼
Walker "." prefix search returns in <500ms (was 10-30s timeout)
```

## File Changes

| File | Repo | Action | Description |
|------|------|--------|-------------|
| `config/elephant/files.toml` | omarchy-nix | Create | `ignored_dirs` list with 9 Go regex patterns |
| `modules/home-manager/default.nix` | omarchy-nix | Modify | Add `home.file` entry after line 143 (after `desktopapplications.toml`) |
| `flake.lock` | nixos-hosts | Modify | Bump `omarchy-nix` input to new rev |

### Exact diff for modules/home-manager/default.nix

After line 143 (`".config/elephant/desktopapplications.toml"` block), insert:

```nix
    ".config/elephant/files.toml" = {
      source = ../../config/elephant/files.toml;
    };
```

### Exact content for config/elephant/files.toml

```toml
ignored_dirs = [
  "/go/pkg/mod",
  "/node_modules",
  "/target",
  "/__pycache__",
  "/.venv",
  "/.cargo/registry",
  "/.cargo/git",
  "/.local/share/Trash",
  "/.cache",
]
```

## Interfaces / Contracts

No new interfaces. The `files.toml` schema is defined by elephant's `files` provider (Go regex list under `ignored_dirs` key). Walker's `config.toml` remains unchanged.

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Syntax | `files.toml` parses correctly | `elephant` starts without errors after deploy |
| Deployment | File lands at correct path | `ls ~/.config/elephant/files.toml` after `nixos-build switch` |
| Performance | Index size, RSS, search latency | Commands in Verification Plan below |
| Regression | Existing providers unaffected | Walker still finds desktop apps and calc results |

## Migration / Rollout

**Deployment order**:

1. **omarchy-nix**: Commit `files.toml` + `home.file` entry → push to `main`
2. **nixos-hosts**: `nix flake lock --update-input omarchy-nix` → commit `flake.lock` → push to `main`
3. **t14**: `nixos-build switch` → `systemctl --user restart elephant.service`

**Rollback**:

- **omarchy-nix**: `git revert` the commit, push to `main`
- **nixos-hosts**: `nix flake lock --update-input omarchy-nix` (reverts to previous rev), `nixos-build switch`

No data migration. Elephant reindexes automatically on restart with new exclusions.

## Verification Plan

Run these commands on t14 after deploy + elephant restart:

```bash
# 1. File exists
ls -l ~/.config/elephant/files.toml

# 2. elephant RSS < 150 MB
systemctl --user status elephant.service | grep Memory

# 3. Index size < 3,000 rows
sqlite3 ~/.cache/elephant/files.db "SELECT COUNT(*) FROM files;"

# 4. Reindex time < 1s (check journal)
journalctl --user -u elephant.service -n 20 | grep -i reindex

# 5. Walker search is responsive (manual test)
# Open walker, type "." followed by a filename — results in <500ms

# 6. Flake check passes on nixos-hosts
nix flake check --no-build

# 7. Regression: desktop apps still searchable
# Open walker, search for "brave" or "firefox" — results appear
```

## Open Questions

None. All decisions resolved in proposal and spec.
