# Delta for Version Synchronization

## ADDED Requirements

### Requirement: Engram Version Pin

The `engram-src` flake input in `flake.nix` MUST be pinned to an explicit git tag (e.g., `v1.14.6`), not a branch reference or floating commit.

#### Scenario: Engram flake input uses version tag

- GIVEN `flake.nix` defines the `engram-src` input
- WHEN inspecting the input URL
- THEN it contains an explicit version tag (format: `github:Gentleman-Programming/engram/vX.Y.Z`)
- AND it does NOT reference a branch name like `master` or `main`

### Requirement: Engram Binary and Plugin Version Match

The engram binary version in `pkgs/engram/default.nix` MUST match the `engram-src` flake input tag. Both MUST be at `v1.14.6` after this change.

#### Scenario: Engram binary version matches plugin source tag

- GIVEN `pkgs/engram/default.nix` defines `version = "1.14.6"`
- WHEN inspecting `flake.nix` `engram-src.url`
- THEN the tag in the URL is `v1.14.6`

### Requirement: Engram Version Relationship Documentation

The `flake.nix` MUST include a comment documenting the relationship between `engram-src` and the `engram` binary version, so maintainers understand why they must stay in sync.

#### Scenario: Comment explains engram version coupling

- GIVEN a maintainer reads `flake.nix`
- WHEN they encounter the `engram-src` input
- THEN a comment above or beside it explains that the tag must match `pkgs/engram/default.nix` version

### Requirement: Engram Sync Marker

A `.last-sync` marker (or equivalent documentation) MUST reflect the current `engram-src` version, documenting that the binary and plugin are synchronized.

#### Scenario: Sync marker reflects engram version

- GIVEN the change is applied with `engram-src` pinned to `v1.14.6`
- WHEN inspecting the sync marker or version documentation
- THEN it reflects `v1.14.6` as the engram version
- AND both binary and plugin are documented as synchronized at this version
