# Apply: Prune Declared Builtin Providers

## What
Implemented T1-T7 (all complete) as pure deletion/reduction. Files (git, unstaged — tree left dirty for review, nothing committed):

1. `shared/opencode/providers-base.nix` — modified: 982→708 lines (+1/−276). Deleted `anthropicProvider` (4 models) and `githubCopilotProvider` (28 models) blocks incl. header comments; reduced `opencodeProvider` to `{ opencode = { options = { timeout = 3600000; chunkTimeout = 3600000; }; }; }` (all 33 model pins + all `thinking = false` + stale free-tier/risk comments removed); `allProviders = nvidiaProvider // opencodeProvider;`. NVIDIA block (lines 1-72) and every routing profile (canonical + legacy) byte-identical, proven by diff hunks touching only the deleted region.
2. `shared/opencode/providers.nix` — modified: 19→12 lines (+5/−13). Header comment updated; body is now `import ./providers-base.nix { inherit lib activeProviderName; }`; no `extras` let, no `extraProviders` key, no `builtins.pathExists` branch.
3. `shared/opencode/providers-extra.nix` — deleted (438 lines, 11 providers, zero consumers).

Not touched (hard constraints held): `shared/opencode.nix` sops env exports, hosts/, flake.nix, darwin/, `agents.nix`, `runtime-config.nix`.

## Verification Evidence

| Check | Result |
|---|---|
| T1: pruned allProviders keys | `["nvidia", "opencode"]` (expected) |
| T2: adapter attrNames | `[activeProvider, activeProviderName, allProviders, getModelForPhase, nvidiaProvider, providers]` — no `extraProviders` |
| T3: repo grep `providers-extra|extraProviders` in *.nix | zero hits (only openspec archive/history docs outside -g breakage) |
| T4: A/B profile identity (harness `/tmp/opencode/apply/harness.nix`, pinned lib a9e6d84, `git show HEAD` base vs pruned) | profiles full-JSON equality **True**; all 12 phase keys resolve in both variants |
| T5: models.dev catalog cross-check | 30 built-in IDs, **0 missing** (anthropic 4, github-copilot 10, openai 7, opencode 4, opencode-go 5); nvidia exempt (4 refs, declared in-file) |
| T6: `format-nix` | pass; "0 / 1 have been reformatted" (already canonical) |
| T6: `nix flake check --no-build` | "all checks passed!" |
| T6: t14 toplevel eval (`--no-link --dry-run`) | exit 0; full drv list incl. `opencode.json.drv` |
| T7: | `openspec/specs/gentle-ai-declarative-runtime/spec.md` line 77 mention = anchor only; conditional T7.2 no-op |

## Concurrency discovery
HEAD moved during this apply: the user committed `ae5b172 feat(opencode): luna apply, new opencode-go-openai profile` (new canonical profile + `openai-opencode-balanced` remaps) while apply was in flight. The unstaged diff is the pure prune against that new HEAD; final A/B (HEAD base vs final disk) verifies full JSON equality over all **25** profiles — including the user's new ones. tasks.md and the spec freeze the count at 22 ("22 entries MUST remain byte-identical"); the real contract is preservation, so apply verified byte-identity dynamically. Stale "22" wording should be corrected in verify/archive. The sops env exports in `shared/opencode.nix` are untouched (clean diff).

## Workload
~726 changed lines (726 deletions + 6 additions), delivered as one batch per explicit orchestrator instruction (no chained-PR split; no commit; user reviews tree). Size:exception applies — this is a pure-deletion hygiene change where a split adds risk without protecting anything.

## Workload/Batch
~727 changed lines (pure deletion hygiene), delivered as one batch per orchestrator instruction; size:exception acceptable — a split protects nothing here and risks conflict with the user's in-flight commit.

## Rollback
Revert the three files (`git checkout -- shared/opencode/providers-base.nix shared/opencode/providers.nix && git checkout HEAD -- shared/opencode/providers-extra.nix`) and redo a Home Manager switch; `makeOpencodeConfigMutable` refreshes `opencode.json`.
