# Tasks: Refactor AI assets separation — independent skill sources

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~380 (200 added + 180 deleted) |
| 800-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: New Derivation Packages

- [x] 1.1 Create `pkgs/caveman-assets/default.nix` — copies caveman-src skills/ and commands/ to `$out/share/caveman/`. Reference design file derivation.
- [x] 1.2 Create `pkgs/ponytail-assets/default.nix` — copies ponytail-src skills/ and `.opencode/command/` to `$out/share/ponytail/`. Reference design file derivation.
- [x] 1.3 Rewrite `pkgs/gentle-ai-assets/default.nix` — pure gentle-ai-src, no vanilla chain. Copies AGENTS.md, internal/assets dirs, and root-level skills/ to `$out/share/gentle-ai/`. Reference design file derivation.

## Phase 2: Options, Packages & Overlays

- [x] 2.1 Rename `shared/gentle-ai-common.nix` → `shared/ai-assets.nix`. Rewrite options: namespace `home.ai-assets`, new `skillSources` (list of paths), `commandSources` (list of strings), `agentsMdSources` (list of paths). Keep `mcps`, `extraMcps`, `engramConfig` under the new namespace. Reference design HM options section.
- [x] 2.2 Update `lib/packages.nix` — remove `gentle-ai-assets-vanilla` and `sharedOpencodePaths` let-binding; modify `gentle-ai-assets` to call its default.nix with `{ gentle-ai-src = inputs.gentle-ai-src; }`; add `caveman-assets` and `ponytail-assets`. Both linuxPackages and darwinPackages. Reference design packages section.
- [x] 2.3 Update `overlays/linux.nix` — remove `gentle-ai-assets-vanilla` from inherit list; add `caveman-assets`, `ponytail-assets`.
- [x] 2.4 Update `overlays/darwin.nix` — same changes as linux overlay.

## Phase 3: Activation Scripts & Integration

- [x] 3.1 Update `shared/opencode.nix` — change imports from `./gentle-ai-common.nix` to `./ai-assets.nix`. Replace `config.home.gentle-ai` with `config.home.ai-assets` throughout. Rewrite activation script: generalize commands loop to N-way using `config.home.ai-assets.commandSources`; generalize skills loop to N-way using `skillSources` with cmp-guard + orphan cleanup across ALL sources; add AGENTS.md concat from `agentsMdSources`; change review-gate.md source to `./shared/opencode/assets/opencode/review-gate.md`; remove old 2-pass skills pattern. Reference design activation scripts.
- [x] 3.2 Update `shared/claude-code.nix` — same namespace rename (`home.gentle-ai` → `home.ai-assets`). Rewrite activation script: N-way skills from `skillSources`, N-way commands from `commandSources`, CLAUDE.md concat from `agentsMdSources`, review-gate.md from `./shared/opencode/assets/opencode/review-gate.md`. Reference design claude-code section.
- [x] 3.3 Update `shared/opencode-profile.nix` — change import to `./ai-assets.nix` and enable via `home.ai-assets.enable`.
- [x] 3.4 Update `shared/claude-code-profile.nix` — same import and enable changes.
- [x] 3.5 Update `shared/opencode/agents.nix` — change `${pkgs.gentle-ai-assets-vanilla}` to `${pkgs.gentle-ai-assets}` for sdd-overlay JSON read.
- [x] 3.6 Update `shared/opencode/mcps-base.nix` — rename `options.home.gentle-ai.mcps` → `options.home.ai-assets.mcps`.
- [x] 3.7 Update `shared/opencode/mcps.nix` — rename `home.gentle-ai.extraMcps` → `home.ai-assets.extraMcps`.
- [x] 3.8 Update `home-darwin/opencode/mcps-extra.nix` — rename `home.gentle-ai.extraMcps` → `home.ai-assets.extraMcps`.

## Phase 4: Cleanup & Docs

- [x] 4.1 Delete `pkgs/gentle-ai-assets/vanilla.nix`.
- [x] 4.2 Delete `shared/assets/review-gate.md` (18-line redundant version; 443-line orchestrator version stays at `shared/opencode/assets/opencode/review-gate.md`).
- [x] 4.3 Delete `shared/opencode/assets/skills/.gitkeep` and the empty parent dir.
- [x] 4.4 Update `docs/gentle-ai-update.md` — replace `gentle-ai-assets-vanilla` references with `gentle-ai-assets`, `caveman-assets`, `ponytail-assets`.

## Phase 5: Verification

- [x] 5.1 Run `format-nix` and fix any formatting issues.
- [x] 5.2 Run `nix flake check --no-build` — must exit 0.
- [x] 5.3 Build each new derivation: `nix build .#caveman-assets`, `nix build .#ponytail-assets`, `nix build .#gentle-ai-assets`.
- [x] 5.4 Build one NixOS host config: `nix build .#nixosConfigurations.rog.config.system.build.toplevel`.
- [x] 5.5 Verify `grep -r 'gentle-ai-assets-vanilla\|home\.gentle-ai' --include='*.nix'` returns empty.
