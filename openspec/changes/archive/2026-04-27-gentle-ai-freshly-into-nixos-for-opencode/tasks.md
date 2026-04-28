# Tasks: Gentle AI Freshly Into NixOS for OpenCode

## Phase 1: Foundation — Vanilla Derivation & Overlay

- [x] 1.1 Create `pkgs/gentle-ai-assets/vanilla.nix`: `stdenvNoCC.mkDerivation` with `gentle-ai-src` as `src`. `installPhase` copies AGENTS.md, opencode/ (including ALL plugins/), skills/, agent dirs from `internal/assets/` to `$out/share/gentle-ai/` with zero local modifications. Expose `version` from `gentle-ai-src.rev`. Must copy `internal/assets/opencode/plugins/` if present — no exclusions.
- [x] 1.2 Add `gentle-ai-assets-vanilla` to the overlay `inherit` in `modules/base/overlays.nix` line 9.
- [x] 1.3 Wire `gentle-ai-assets-vanilla` in `flake.nix`: add `callPackage` at line ~59 and register in `packages.${system}` at line ~66.
- [x] 1.4 Verify foundation: `nix build .#gentle-ai-assets-vanilla` succeeds; output contains no `persona-gentleman.md` with local rules, no local `caveman/` or other extra skills, but DOES contain upstream `opencode/plugins/background-agents.ts`.

## Phase 2: Core — Layered Derivation & Version Pin

- [x] 2.1 Refactor `default.nix`: switch from `stdenvNoCC.mkDerivation` to `runCommand` accepting `vanilla` parameter. Copy vanilla tree via `cp -r`, then prepend `localPersonaRules` (via `writeText`) to `persona-gentleman.md`, overlay `extraSkills/*` on top of `skills/`. DO NOT touch `opencode/plugins/` — it remains identical to vanilla.
- [x] 2.2 Update `flake.nix` line ~59: pass `vanilla = gentle-ai-assets-vanilla` instead of `gentle-ai-src`. Keep `writeText` and `extraSkills` as before. Remove `extraPlugins` parameter.
- [x] 2.3 Pin `gentle-ai-src` in `flake.nix` line ~21 to `url = "github:Gentleman-Programming/gentle-ai/v1.21.0"`. Add comment: "Must match version in pkgs/gentle-ai/default.nix".
- [x] 2.4 Fix `.last-sync` at `modules/home/opencode/.last-sync` to `v1.21.0` (was v1.23.0 — resolving drift).
- [x] 2.5 Run `nix flake lock --update-input gentle-ai-src` to resolve pinned tag in `flake.lock`.

## Phase 3: Plugin Handling — Upstream Only + engram.ts Special Case

- [x] 3.1 Fix `modules/home/opencode.nix` activation script: replace hardcoded `${./opencode/plugins/background-agents.ts}` with nix store path `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/background-agents.ts`.
- [x] 3.2 Keep `engram.ts` copy from local path `${./opencode/plugins/engram.ts}` (special case — does not exist upstream).
- [x] 3.3 Delete `modules/home/opencode/plugins/background-agents.ts` — use upstream version instead of local override.
- [x] 3.4 Verify activation script: upstream plugins reference `${pkgs.gentle-ai-assets}/...` nix store path; engram.ts references local path; no other `${./opencode/plugins/` references remain.

## Phase 4: TDD Strict Default Configuration

- [x] 4.1 Update `openspec/config.yaml`: change `strict_tdd: false` to `strict_tdd: true` at both root level (line 23) and testing section (line 52).
- [x] 4.2 Update testing note in `openspec/config.yaml` to reflect TDD strict is now enabled (remove "disabled" note).
- [x] 4.3 Verify config: `sdd-init` would detect `strict_tdd: true` and load strict TDD modules for `sdd-apply` and `sdd-verify`.

## Phase 5: Documentation

- [x] 5.1 Create `docs/gentle-ai-update.md`: 5-step workflow (check release, update binary, update tag, re-lock+sync-marker, build+verify) with example commands and verification checklist.

## Phase 6: Verification & Polish

- [x] 6.1 Build: `nix build .#gentle-ai-assets` — confirm output has 21 local skills under `share/gentle-ai/skills/`.
- [x] 6.2 Content: verify `persona-gentleman.md` has local rules prepended above upstream; local skills override upstream same-name skills (e.g., `caveman/SKILL.md` is local version).
- [x] 6.3 Plugins: verify `opencode/plugins/` in layered output is IDENTICAL to vanilla output (no local additions or overrides).
- [x] 6.4 Activation: verify `opencode.nix` activation script references `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/` for upstream plugins and `${./opencode/plugins/engram.ts}` for engram.
- [x] 6.5 TDD strict: verify `openspec/config.yaml` has `strict_tdd: true` at both locations.
- [x] 6.6 Flake check: `nix flake check` exits 0 with no warnings.
- [x] 6.7 Format: `format-nix` on all modified `.nix` files; confirm `nixfmt` passes.
- [x] 6.8 Backward compat: confirm downstream consumer (`modules/home/opencode/`) finds assets at expected `$out/share/gentle-ai/` path.
