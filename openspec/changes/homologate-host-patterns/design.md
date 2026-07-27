# Design: homologate-host-patterns

## Technical Approach

Merge `darwin/default.nix` body into `hosts/mact2/default.nix`, adjust relative paths, delete `darwin/default.nix`, drop `../darwin` from `mkDarwinHost.nix` module list. Pure refactor — config identical, paths update only.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep split config | Two files for one host, breaks host pattern | Reject — all 4 hosts must be self-contained |
| Absorb into hosts/mact2 | Paths change from `./` to `../../darwin/` | Accept — exact config, only path prefix changes |

No new abstractions. No interface. One implementation. YAGNI.

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `hosts/mact2/default.nix` | Modify | Absorb ~70 lines from `darwin/default.nix`. Rewrite `./` → `../../darwin/` in 7 import paths |
| `darwin/default.nix` | Delete | Config moved into host file |
| `lib/mkDarwinHost.nix` | Modify | Remove line 32: `../darwin` import |

## Path Migration

`darwin/default.nix` uses `./system/`, `./services/`, `./home` — relative to `darwin/`. From `hosts/mact2/`, these become `../../darwin/system/`, `../../darwin/services/`, `../../darwin/home/`.

7 path rewrites total. No logic change. No new modules.

## Testing Strategy

`nix flake check --no-build` after change. Same config, same flake closure. If check passes, refactor is correct.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration

No migration. One commit, 3 files. `git revert` undoes everything.

## Open Questions

None.
