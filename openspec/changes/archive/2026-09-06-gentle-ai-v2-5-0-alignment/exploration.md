# Exploration: gentle-ai-v2-5-0-alignment

## Current State

The repo consumes gentle-ai upstream through two derivations built from the `gentle-ai-src` flake input: `gentle-ai` (buildGoModule, `subPackages cmd/gentle-ai`) and `gentle-ai-assets` (stdenvNoCC copy of `internal/assets/{opencode,skills,claude,cursor,windsurf,gemini,codex,kimi,qwen,kiro}` + root `skills/` + `AGENTS.md`). The input is pinned to `main@26d7ceed225e16d45378a78333a5e4068d8287e7` (flake.lock), a commit between v2.4.0 and v2.5.0; the binary builds with `version = gentle-ai-src.rev` and no ldflags, so `gentle-ai version` reports "dev".

Assets deploy at Home Manager activation time, never via `gentle-ai install/sync`:

- `shared/claude-code.nix` copies `claude/{agents,commands}` + skills + output-styles to `~/.claude/` with per-file cmp guards and union orphan removal.
- `shared/opencode/runtime-config.nix` copies commands/skills/plugins to `~/.config/opencode/` and writes `opencode.json`; `managedPlugins` currently lists `background-agents.ts` (ghost — the asset no longer exists upstream), `engram.ts`, `secret-guard.ts`.
- `shared/opencode/agents.nix` builds the OpenCode agent graph by reading `sdd-overlay-single.json` from the asset derivation and merging per-phase model assignments + a local `neutral` agent + overlays from `shared/opencode/local-agent-overlays.json`.

Today: 11 unprefixed `sdd-*.md` Claude commands deploy; only 2 of the 4 upstream-managed OpenCode plugins are wired; the theme component is absent; `docs/gentle-ai-update.md` documents a v1.22.0/main workflow that no longer matches reality.

## Affected Areas

- `flake.nix` (lines 45-49) — `gentle-ai-src` url `main` → `v2.5.0` tag; re-lock.
- `pkgs/gentle-ai/default.nix` — `vendorHash` will change with the source bump (buildGoModule); must be recomputed at apply time.
- `shared/opencode/plugins.nix` — remove the ghost `backgroundAgents` option; add 4 new enable options.
- `shared/opencode/runtime-config.nix` — `managedPlugins`: add 4 entries, drop `background-agents.ts`; add an explicit `rm -f background-agents.ts` cleanup in the plugin activation.
- `shared/opencode-profile.nix` — remove the stale `backgroundAgents`/`gentle-ai#58`/`agent-teams-lite#58` references; decide which of the 4 plugins are on by default.
- `shared/opencode/agents.nix` + `shared/opencode/local-agent-overlays.json` — v2.5.0 moved the subagent schema from `tools` to `permission`; the repo still injects the deprecated `tools` field.
- `shared/claude-code.nix` — no code change needed; its union orphan cleanup auto-retires the unprefixed `sdd-*.md` after the bump.
- `docs/gentle-ai-update.md` — full rewrite to a v2.x tag-pinning workflow.
- (unchanged) `pkgs/gentle-ai-assets/default.nix` — the copy list already includes `opencode`; the 4 plugins and all v2.5.0 assets live inside `internal/assets/opencode`, so no derivation edit is needed.

## Approaches

1. **Pin bump: tag v2.5.0** — change url to `github:Gentleman-Programming/gentle-ai/v2.5.0`, re-lock, recompute `vendorHash`.
   - Pros: reproducible and signed (checksums.txt.minisig, deterministic release provenance); matches "stable releases preferred for hosts"; auto-retires the 11 unprefixed Claude commands via the existing orphan cleanup.
   - Cons: `vendorHash` recompute (build-time); one-time lock churn.
   - Effort: Low.
   - Alternative: keep tracking `main`. Pros: always-latest. Cons: moving target breaks the deterministic-host principle, and the audit already shows the pin drifted 212 commits behind. Not recommended.

2. **Wire the 4 managed plugins** — add `model-variants`, `opencode-review-transport`, `sdd-task-result-artifacts`, `skill-registry` options (default off, matching the `secretGuard` precedent) + `managedPlugins` entries sourcing from `gentle-ai-assets`; delete the `backgroundAgents` option/entry and add an explicit `rm -f` for the ghost file.
   - Pros: closes gaps #3/#4; mirrors upstream `installOpenCodePlugins` always-writes behavior while keeping the repo's opt-in discipline.
   - Cons: 2 of the 4 plugin files (`sdd-task-result-artifacts.ts`, `skill-registry.ts`) changed content between the pin and v2.5.0, so wiring must land together with the bump.
   - Effort: Low-Medium.

3. **Reconcile the `tools` → `permission` schema (new finding)** — the v2.5.0 overlay dropped per-subagent `tools` blocks in favor of `permission`; OpenCode deprecated agent `tools` in v1.1.1 (still auto-migrated, so not a hard break). Migrate `local-agent-overlays.json` `toolOverlays` → `permissionOverlays` and adjust `agents.nix` to inject permission-shaped grants so subagents keep read/write/edit/bash plus the Engram mem tools.
   - Pros: aligns the declarative output with the v2.5.0 schema; removes deprecated `tools` and its auto-migration warnings; preserves subagent tool grants deterministically.
   - Cons: largest/riskiest part; requires empirically verifying the generated `opencode.json` (build/eval) to confirm no subagent loses write/edit.
   - Effort: Medium.

4. **Theme component** — omit entirely, or add an optional off-by-default `home.gentle-theme.enable` that writes the opencode.json `theme` key and `~/.claude/themes/{gentleman,gentleman-cute}.json`.
   - Pros (omit): decorative only; repo prefers minimal/opt-in (only conky/rog ships decorative assets); keeps the budget low.
   - Cons: leaves gap #5 open (cosmetic only).
   - Effort: Low if omitted; Low-Medium if wired.

5. **Docs rewrite** — rewrite `docs/gentle-ai-update.md` to the v2.x tag workflow.
   - Pros: small; removes stale v1.22.0/main/`.last-sync` references.
   - Effort: Low.

## Recommendation

Do approaches 1 + 2 + 5 together, with approach 3 included but scoped tightly and gated on an empirical `opencode.json` check. Pin to the `v2.5.0` tag (reproducible + signed) rather than continuing to track `main`. Wire all 4 plugins with off-by-default options, and enable the two SDD-critical ones (`sdd-task-result-artifacts`, `skill-registry`) by default since SDD is core to this repo; leave `model-variants` and `opencode-review-transport` off-by-default until a host opts into variant/review workflows. Remove `backgroundAgents` entirely and add explicit ghost-file cleanup. Omit the theme (decorative; defer to a follow-up opt-in). The `tools`→`permission` migration is the one piece that changes generated runtime behavior, so it belongs in this change but must be verified against the built `opencode.json` before declaring done.

## Risks

- **vendorHash mismatch**: buildGoModule fails after the source bump until `vendorHash` is recomputed — expected, a standard Nix step, but must not be forgotten.
- **tools → permission schema**: subagents could silently lose write/edit grants (or emit deprecated-`tools` warnings) if `agents.nix`/`local-agent-overlays.json` are not reconciled — the highest-impact risk in the bump.
- **plugin content drift**: `sdd-task-result-artifacts.ts` and `skill-registry.ts` changed between the pin and v2.5.0; wiring before/after the bump must stay consistent.
- **sdd-research model gap** (pre-existing, out of scope): `agents.nix` `sddPhases` omits `sdd-research`, so that agent gets no per-phase model. Not a v2.5.0 regression, but worth a follow-up.
- **never run `gentle-ai sync/install`** on hosts — it would mutate NixOS-managed files; activation is the sole deploy path.
- **orphan cleanup correctness**: retiring the unprefixed Claude `sdd-*.md` relies on `claude-code.nix` union orphan cleanup — already correct, but must be exercised once on a real host.

## Ready for Proposal

Yes. The orchestrator should tell the user: (a) we recommend pinning the `v2.5.0` tag over tracking `main`; (b) the four plugins will be wired with off-by-default options (two SDD plugins on by default), and the ghost `background-agents.ts` removed; (c) a newly-discovered `tools`→`permission` schema migration must be folded in and verified against the generated `opencode.json`; (d) the theme is deferred (decorative); (e) the authored diff stays under the 400-line budget (~200-300 lines), so a single PR is viable, but the user should confirm whether to include the tools→permission migration now or split it into a second PR.
