# elephant-files-ignore Specification

## Purpose

Define `ignored_dirs` configuration for elephant's `files` provider to exclude build artifacts, caches, and system noise from indexing, reducing index size from ~21K to <3K entries and elephant RSS from ~456 MB to <150 MB.

## Requirements

### Requirement: files.toml Configuration File

omarchy-nix SHALL provide `config/elephant/files.toml` containing an `ignored_dirs` list of Go-regex patterns matching directory path segments to exclude from elephant's `files` provider indexing.

The file SHALL include patterns for at minimum:

| Pattern | Target | Rationale |
|---------|--------|-----------|
| `/go/pkg/mod` | Go module cache | 92% of current index (19,491 of 21,192 rows) |
| `/node_modules` | Node.js dependencies | Common large tree |
| `/target` | Rust build output | Common large tree |
| `/__pycache__` | Python bytecode cache | Common noise |
| `/.venv` | Python virtual environments | Large, ephemeral |
| `/.cargo/registry` | Rust crate cache | Large, reproducible |
| `/.cargo/git` | Rust git checkouts | Large, reproducible |
| `/.local/share/Trash` | Desktop trash | Not user-searchable |
| `/.cache` | XDG cache directory | Ephemeral, not useful |

Patterns SHALL be Go regular expressions matched against full directory paths.

#### Scenario: files.toml exists after deployment

- GIVEN omarchy-nix is deployed to a host
- WHEN `home-manager switch` completes
- THEN `~/.config/elephant/files.toml` exists
- AND the file contains `ignored_dirs` with all listed patterns

#### Scenario: Pattern syntax is valid

- GIVEN `config/elephant/files.toml`
- WHEN elephant parses the file on startup
- THEN no parse errors occur
- AND elephant loads the `ignored_dirs` list successfully

### Requirement: Home Manager Deployment

omarchy-nix `modules/home-manager/default.nix` SHALL deploy `files.toml` via `home.file` following the existing pattern used by `calc.toml` and `desktopapplications.toml`.

The entry SHALL map `~/.config/elephant/files.toml` to `../../config/elephant/files.toml`.

#### Scenario: Deployment follows existing pattern

- GIVEN the `home.file` entries in `modules/home-manager/default.nix`
- WHEN inspected
- THEN `files.toml` entry is adjacent to `calc.toml` and `desktopapplications.toml` entries
- AND uses the same `source =` syntax

### Requirement: Flake Input Bump

The nixos-hosts repository SHALL update its `omarchy-nix` flake input to the commit containing the `files.toml` addition.

#### Scenario: Flake lock reflects new omarchy-nix

- GIVEN nixos-hosts `flake.lock` is updated
- WHEN `nix flake lock --update-input omarchy-nix` runs
- THEN the `omarchy-nix` entry points to the commit with `files.toml`

#### Scenario: Flake check passes

- GIVEN the bumped flake input
- WHEN `nix flake check --no-build` runs on nixos-hosts
- THEN the command exits with status 0

### Requirement: Performance Targets

After deployment and elephant restart, the following performance targets SHALL be met:

| Metric | Before | After |
|--------|--------|-------|
| elephant RSS | ~456 MB | <150 MB |
| Reindex time | 10-30s | <1s |
| Indexed file count | ~21,192 | <3,000 |
| fsnotify watches | ~13,053 | <2,000 |
| Walker `.` prefix search | 10-30s (timeout) | <500ms |

#### Scenario: Memory reduction after restart

- GIVEN `files.toml` is deployed on t14
- WHEN `systemctl --user restart elephant.service` runs and reindex completes
- THEN `systemctl --user status elephant.service` shows MemoryCurrent < 150 MB

#### Scenario: Index size reduction

- GIVEN `files.toml` is deployed and elephant has reindexed
- WHEN `sqlite3 ~/.cache/elephant/files.db "SELECT COUNT(*) FROM files;"` runs
- THEN the result is < 3,000

#### Scenario: Walker search is responsive

- GIVEN elephant is running with the new index
- WHEN the user triggers walker and types `.` followed by a filename query
- THEN results appear in < 500ms

### Requirement: No Regression on Existing Providers

The `files.toml` addition SHALL NOT affect elephant's `desktopapplications` or `calc` providers. Walker's `config.toml` SHALL remain unchanged.

#### Scenario: desktopapplications provider unaffected

- GIVEN `files.toml` is deployed
- WHEN the user searches for an application via walker
- THEN desktop application results appear identically to pre-change behavior

#### Scenario: walker config.toml unchanged

- GIVEN the change is applied
- WHEN `~/.config/walker/config.toml` is inspected
- THEN `max_results` remains 256
- AND no other walker settings are modified
