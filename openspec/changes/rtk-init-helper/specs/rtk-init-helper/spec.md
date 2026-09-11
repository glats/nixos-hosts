# Specification: RTK Instruction Block Helper

## Requirement 1: Managed block upsert

The helper MUST use the distinct markers `<!-- rtk-init-managed v1 -->` and
`<!-- /rtk-init-managed -->`, append the canonical block when absent, replace
one stale managed block, and report an identical block as unchanged. Repeated
upserts MUST be byte-stable. (Hosts: rog, thinkcentre, t14, mact2)

## Requirement 2: Malformed marker refusal

If a target contains an unmatched marker or more than one managed block, the
helper MUST return an error and MUST NOT modify the file. (Hosts: all)

## Requirement 3: Check and removal semantics

`Check` MUST succeed only when exactly one current block exists, and MUST
identify missing or stale content on failure. `Remove` MUST remove only the
managed block and preserve all other bytes. Writes MUST be atomic and preserve
the target file mode. (Hosts: all)

## Requirement 4: CLI contract

`rtk-init` MUST support `--check`, `--remove`, and `--dry-run`, plus one
optional target path. Without a path it MUST manage repo-root `AGENTS.md` via
`internal/reporoot`. It MUST return exit code 0 on success and 1 on check
failure or error, with human-readable status lines. (Hosts: all)

## Requirement 5: Derivation wiring

The `nixos-scripts` derivation MUST expose `cmd/rtk-init` without adding an
external dependency or changing host imports. (Hosts: rog, thinkcentre, t14,
mact2)
