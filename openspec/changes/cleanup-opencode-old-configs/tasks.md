# Tasks: Cleanup OpenCode Old Configs

## Phase 1: Script Removal

- [ ] 1.1 Delete `bin/sync-opencode-remote` — broken, references missing `opencode.json.base`
- [ ] 1.2 Delete `bin/sync-opencode-mac.sh` — outdated API model mappings
- [ ] 1.3 Delete `bin/setup-opencode-keychain-mac.sh` — all providers removed
- [ ] 1.4 Delete `bin/gentle-ai-tui` — bypasses Nix versioning

> **Parallel**: All 4 deletions are independent.

## Phase 2: Package Derivation

- [ ] 2.1 Remove `gentle-ai-tui` install lines (45-46) from `pkgs/nixos-scripts/default.nix`

## Phase 3: Module Cleanup

- [ ] 3.1 Remove `legacyFallback` option definition from `modules/home/opencode.nix`
- [ ] 3.2 Remove migration warning block from `modules/home/opencode.nix`
- [ ] 3.3 Remove `legacyFallback = false` line from `modules/home/opencode-profile.nix`

> **Parallel**: Tasks 3.1+3.2 target same file (sequential), 3.3 is independent.

## Phase 4: Validation

- [ ] 4.1 Run `format-nix` — ensure all .nix files pass nixfmt
- [ ] 4.2 Run `nix flake check` — no errors or warnings
- [ ] 4.3 Build `rog` host: `nixos-build dry`
- [ ] 4.4 Build `thinkcentre` host: `nixos-build dry`

> **Parallel**: 4.3 and 4.4 are independent (different hosts).
