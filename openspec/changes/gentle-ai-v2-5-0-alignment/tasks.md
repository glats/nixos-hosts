# Tasks: Gentle AI v2.5.0 Alignment

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 250–350 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR (ordered phases) |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

Resolved: single PR, no chain (Medium, under 400); apply gated on user confirming single-PR scope.

### Suggested Work Units (all → PR 1)

| Unit | Goal | Focused test command | Runtime harness | Rollback boundary |
|------|------|----------------------|-----------------|-------------------|
| 1 | Tag pin + vendorHash (Req 1) | `nix build .#gentle-ai-assets`; ls plugins | `nix build` | Revert flake trio |
| 2 | Plugin lifecycle (Req 2) | t14 activationPackage; grep copies + legacy `rm` | activation inspect | Revert 3 plugin files |
| 3 | Permission migration (Req 3, HARD GATE) | t14 activationPackage; `jq -e` grants + no `tools` | t14 eval | Revert agents.nix + overlays |
| 4 | Docs + full gate (Req 5/6/4) | `format-nix && nix flake check --no-build`; seeded t14 canary | t14 activation | Revert docs |

## Phase 1: Foundation

- [x] 1.1 `flake.nix` line 47: `gentle-ai-src.url` → `github:Gentleman-Programming/gentle-ai/v2.5.0`; `nix flake lock --update-input gentle-ai-src`; confirm lock resolves tag.
- [x] 1.2 `pkgs/gentle-ai/default.nix`: `vendorHash = lib.fakeHash` → `nix build .#gentle-ai` → copy error `got: sha256-…` into `vendorHash` → rebuild; `nix build .#gentle-ai-assets`; assert 4 plugin `.ts` files exist, `background-agents.ts` absent, in `$out/share/gentle-ai/opencode/plugins/`.

## Phase 2: Plugin Lifecycle

- [x] 2.1 `shared/opencode/plugins.nix`: delete `backgroundAgents` option (lines 11–24) + `background-agents` active entry (107); add `modelVariants`, `opencodeReviewTransport`, `sddTaskResultArtifacts`, `skillRegistry` via `mkEnableOption` (default false) + active names `model-variants`, `opencode-review-transport`, `sdd-task-result-artifacts`, `skill-registry`.
- [x] 2.2 `shared/opencode/runtime-config.nix` `managedPlugins`: drop `background-agents.ts`; add 4 entries sourcing `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/plugins/{model-variants,opencode-review-transport,sdd-task-result-artifacts,skill-registry}.ts`.
- [x] 2.3 Same file `setupOpencodePluginRuntime`: after `mkdir -p "$runtime_dir/plugins"` insert `${pkgs.coreutils}/bin/rm -f "$runtime_dir/plugins/background-agents.ts"` BEFORE `disabledManagedPluginNames` loop; enabled copies last.
- [x] 2.4 `shared/opencode-profile.nix`: drop stale `backgroundAgents`/`#58` block (lines 31–34); enable `plugins.sddTaskResultArtifacts.enable = true;` + `plugins.skillRegistry.enable = true;`; others off.

## Phase 3: Permission Migration (HARD GATE)

- [x] 3.1 `shared/opencode/local-agent-overlays.json`: delete `toolOverlays` + neutral `tools`; write permission-shaped overlays (strings/command maps, never booleans): orchestrator read/write/edit/bash/question + Engram + delegation allow, task `{"*":"deny","sdd-*":"allow"}`; mutable (general, sdd-* minus research, jd-fix-agent) read/write/edit/bash + Engram allow, `general.task` deny; judges + 4 review lenses read/bash/Engram allow; explore read/codegraph/Engram allow, write/edit/bash/task deny; refuter read/Engram allow, write/edit/bash/task deny; validator read/Engram allow, write/edit/task deny, bash single-command allow-map per design; sdd-research read/write/edit + Engram allow, bash/webfetch/websearch/task deny; neutral all-allow.
- [x] 3.2 `shared/opencode/agents.nix`: remove `localTools` (lines 91–97); always strip upstream `tools` via `removeAttrs upstream ["tools"]`; `localPermission = lib.recursiveUpdate classOverlay namedOverlay`; emit `permission = smartMerge localPermission (upstream.permission or {})`; keep `stripReplace`.
- [x] 3.3 GATE: `out=$(nix build .#homeConfigurations.t14.activationPackage --no-link --print-out-paths)`; `jq -e '([.agent[]|has("permission")]|all) and ([.agent[]|has("tools")]|any|not) and (.agent["sdd-apply"].permission.edit=="allow") and (.agent["explore"].permission.write=="deny") and (.agent["gentle-orchestrator"].permission.task=={"*":"deny","sdd-*":"allow"})' "$out/home-files/.config/opencode/opencode.json"`; every agent (explore, general, gentle-orchestrator, neutral, sdd-*, review-*, jd-*, review-validator) must carry `permission`, no agent may carry `tools`; any miss fails the change.

## Phase 4: Documentation

- [x] 4.1 Rewrite `docs/gentle-ai-update.md` to v2.x tagged workflow: bump tag → `nix flake lock --update-input gentle-ai-src` → recompute `vendorHash` → `nix build .#gentle-ai-assets` → `format-nix && nix flake check --no-build` → canary t14 → other hosts; rollback; no `v1.22.0`/`/main`/`.last-sync`.

## Phase 5: Verification

- [x] 5.1 `format-nix && nix flake check --no-build`; rog/thinkcentre/t14/mact2 shared config evaluates (Req 6); fix only touched-config regressions.
- [ ] 5.2 Activation check (Req 4): seed 11 unprefixed `~/.claude/commands/sdd-*.md`, activate t14, assert none remain and `gentle-sdd-*` + OpenCode `sdd-*` exist.

## Phase 6: Commit and Rollout (user-gated)

- [ ] 6.1 Stage 9 touched files, show diff; commit only on explicit user request (repo convention).
- [ ] 6.2 User deploys `nixos-build` t14 (canary) first, then rog/thinkcentre/mact2; rollback restores prior `main` pin/hash, re-locks, rebuilds.