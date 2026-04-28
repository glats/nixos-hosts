# Tasks: Gentle-AI NixOS Vanilla Integration

## Phase 0: Backup (Critical — blocks all phases)

- [ ] 0.1 Create timestamped backup dir `.atl/backups/pre-vanilla-{YYYYMMDD-HHMMSS}/`
- [ ] 0.2 Copy 14 categories: `hosts/`, `modules/`, `pkgs/`, `secrets/`, `.sops.yaml`, `flake.nix`, `flake.lock`, `lib/`, `bin/`
- [ ] 0.3 Generate `MANIFEST.md` with `sha256sum` of every backed-up file (exclude `.git/`)
- [ ] 0.4 Create `restore.sh` (chmod 755) with header, confirmation prompt, and checksum verification before overwrite
- [ ] 0.5 Create annotated git tag `pre-vanilla-migration` at HEAD with description
- [ ] 0.6 Run integrity verification: compare all MANIFEST checksums against originals, report mismatches

## Phase 1: Version Update (Depends on Phase 0)

- [ ] 1.1 Check current versions: `nix eval .#gentle-ai.version`, `rg version pkgs/gentle-ai/default.nix`
- [ ] 1.2 Update `pkgs/gentle-ai/default.nix`: set `version = "1.24.1"`, compute new `sha256` via `nix-prefetch-url`
- [ ] 1.3 Pin `gentle-ai-src` in `flake.nix` to tag `v1.24.1`: change `github:Gentleman-Programming/gentle-ai` → `github:Gentleman-Programming/gentle-ai/v1.24.1`
- [ ] 1.4 Update `flake.lock`: run `nix flake lock --update-input gentle-ai-src`
- [ ] 1.5 Build verify: `nix build .#gentle-ai` && `./result/bin/gentle-ai --version` shows `1.24.1`

## Phase 2: Skill Re-sync (Depends on Phase 1)

- [ ] 2.1 Build new assets: `nix build .#gentle-ai-assets`
- [ ] 2.2 Compare upstream vs local: diff `result/` skills against `modules/home/opencode/skills/`, log changed/new/removed skills
- [ ] 2.3 Check for name collisions between v1.24.1 upstream skills and 10 local extra skills (`caveman-*`, `nix-verify`, etc.)
- [ ] 2.4 If collision detected in 2.3: rename local skill before merge; if clean: no action needed (Nix overlay handles via `extraSkills`)
- [ ] 2.5 Update `modules/home/opencode/.last-sync` with current timestamp (2026-04-27)
- [ ] 2.6 Verify 10 extra local skills intact: count and diff against Phase 0 backup copies

## Phase 3: Validation (Depends on Phase 2)

- [ ] 3.1 Run `nix flake check` — must pass with zero errors
- [ ] 3.2 Dry-run build on rog: `nixos-rebuild dry-build --flake .#rog`
- [ ] 3.3 Dry-run build on thinkcentre: `nixos-rebuild dry-build --flake .#thinkcentre`
- [ ] 3.4 Verify skills deployed: `ls ~/.config/opencode/skills/` shows all 10 extra + upstream skills
- [ ] 3.5 Verify PERSONA.md starts with English-only rules (local prepend preserved)
- [ ] 3.6 Test opencode starts cleanly — no skill loading errors

## Phase 4: Documentation (Parallel with Phase 3)

- [ ] 4.1 Update `CHANGELOG.md` or create migration note: backup path, version delta (1.21.0→1.24.1), skill changes
- [ ] 4.2 Document update procedure: phase order, commands, prerequisites (clean git, nix available)
- [ ] 4.3 Document rollback: `restore.sh` usage and `git reset --hard pre-vanilla-migration`

## Phase 5: Cleanup

- [ ] 5.1 Run `format-nix` on all modified `.nix` files
- [ ] 5.2 Run final `nix flake check` after formatting
- [ ] 5.3 Optionally archive backup to long-term storage; flag as `verified`
