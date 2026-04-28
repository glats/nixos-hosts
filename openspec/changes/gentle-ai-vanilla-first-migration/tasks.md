# Tasks: Gentle-AI Vanilla-First Migration

## Phase 0: Backup (BLOCKS ALL PHASES)

- [ ] 0.1 Create timestamped backup dir `.atl/backups/pre-vanilla-migration-YYYYMMDD-HHMMSS/`
- [ ] 0.2 Copy all 14 categories: `hosts/`, `modules/`, `pkgs/`, `secrets/`, `.sops.yaml`, `flake.nix`, `flake.lock`, `lib/`, `bin/`, `AGENTS.md`, `gentle-ai-investigation/`, `openspec/`, `.atl/`, `.opencode/`
- [ ] 0.3 Generate `MANIFEST.md` with `sha256sum` for every backed-up file
- [ ] 0.4 Create `restore.sh` (chmod +x, verify checksums before restore, restore all categories to original paths)
- [ ] 0.5 Create git tag `vanilla-migration-pre-YYYYMMDD-HHMMSS` on HEAD
- [ ] 0.6 Run `restore.sh --dry-run` to verify backup integrity (all files present, checksums match)

## Phase 1: Vanilla Runtime (Depends on Phase 0)

- [ ] 1.1 Create `pkgs/gentle-ai-assets/vanilla.nix` — copy-only derivation from `gentle-ai-src` (no localPersonaRules, no extraSkills, no skill copy from custom dirs)
- [ ] 1.2 Add `gentle-ai-assets-vanilla` to `flake.nix` packages output (callPackage vanilla.nix with gentle-ai-src)
- [ ] 1.3 Expose `gentle-ai-assets-vanilla` in `modules/base/overlays.nix` overlay
- [ ] 1.4 Add `vanilla` runtime entry to `runtimeConfigs` in `modules/home/opencode.nix` (dir: "opencode-vanilla", label: "vanilla")
- [ ] 1.5 Add `assetsSource` option to `modules/home/opencode.nix` (enum: "custom"/"vanilla", default "custom") — when "vanilla", use `gentle-ai-assets-vanilla` for PERSONA.md, AGENTS.md, skills, commands
- [ ] 1.6 Add `"vanilla"` to `runtime` enum and wire `mkRuntimeConfig` to generate `~/.config/opencode-vanilla/` when `runtime = "vanilla"`
- [ ] 1.7 Build vanilla derivation: `nix build .#gentle-ai-assets-vanilla` and verify no custom persona rules or extra skills in output
- [ ] 1.8 Rebuild with `runtime = "both"` and verify `~/.config/opencode-vanilla/` exists with upstream assets only

## Phase 2: Testing (Depends on Phase 1)

- [ ] 2.1 Launch vanilla runtime: `OPENCODE_CONFIG_DIR=~/.config/opencode-vanilla opencode` — verify basic chat and file editing works
- [ ] 2.2 Test SDD workflow in vanilla: run `/sdd-init` then `/sdd-explore test-feature` — confirm artifacts generated
- [ ] 2.3 Verify built-in skills load correctly (`ls ~/.config/opencode-vanilla/skills/` has upstream skills, no caveman/nix-verify/go-testing)
- [ ] 2.4 Document gaps: list any broken functionality with severity (P0=critical, P1=important, P2=nice, P3=optional)
- [ ] 2.5 Run `nix flake check` to validate all derivations still pass

## Phase 3: Cutover (Depends on Phase 2)

- [ ] 3.1 Switch production to vanilla: set `home.opencode.assetsSource = "vanilla"` and `home.opencode.runtime = "stable"` in host config
- [ ] 3.2 Run `nixos-build dry` for both `rog` and `thinkcentre` — verify no build errors
- [ ] 3.3 Run `nixos-build switch` on primary host, launch opencode, verify production works
- [ ] 3.4 Document rollback procedure: `nixos-rebuild switch --rollback` or revert `assetsSource` to `"custom"`

## Phase 4: P0 Restoration (Depends on Phase 3)

- [ ] 4.1 Restore engram MCP toggle (`home.opencode.mcpToggles.engram = true`) + verify `mem_save`/`mem_search` work
- [ ] 4.2 Restore sops-nix secrets integration — verify `.sops.yaml` and `modules/base/sops.nix` still load, secrets decrypt
- [ ] 4.3 Restore permission rules — enable `home.opencode.permissions` with bash allow/ask rules and read deny for secrets
- [ ] 4.4 Restore model assignments — enable `home.opencode.agentOverrides` with per-phase models from `agents.nix`
- [ ] 4.5 Restore remaining MCP servers (github, nixos, context7, exa) — verify each responds to tool invocation
- [ ] 4.6 Test each P0 restoration individually: restore one, test it, commit — do NOT batch all at once

## Phase 5: Evaluation (Depends on Phase 4)

- [ ] 5.1 Evaluate P1 items: caveman-* skills, nix-verify skill, persona rules — document restore/defer/discard decision per item
- [ ] 5.2 Test any restored P1 items: verify caveman mode compresses output, nix-verify queries NixOS options
- [ ] 5.3 Evaluate P2/P3 items: extraSkills, orchestratorPrompt, plugins — document each decision with rationale
- [ ] 5.4 Create decision log `openspec/changes/gentle-ai-vanilla-first-migration/decisions.md` listing all items with status (restored/deferred/discarded) and criteria for future re-evaluation
