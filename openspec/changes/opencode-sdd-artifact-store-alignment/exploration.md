## Exploration: opencode-sdd-artifact-store-alignment

### Current State
- Observed: the active runtime uses `gentle-ai 1.40.2`, `engram 1.16.3`, and an enabled local Engram OpenCode plugin in `~/.config/opencode/plugins/engram.ts`.
- Observed: the native `gentle-ai sdd-status` / `sdd-continue` path is OpenSpec-scoped. On this machine it enumerates `openspec/changes/*`, emits `artifactStore: "openspec"`, and returns `Active OpenSpec change not found` for change names that only exist in Engram.
- Observed: the installed runtime orchestrator and status contract still instruct the orchestrator to use the native dispatcher whenever `gentle-ai` is available, without first scoping that choice by artifact store.
- Observed: the runtime assets inspected in `~/.config/opencode/` match the packaged `gentle-ai-assets` / `gentle-ai-assets-vanilla` content for the orchestrator and status contract files; this is not a repo-local fork of those specific files.
- Observed: the workspace already contains `openspec/changes/restore-omarchy-hyprland-ownership/` and `openspec/changes/unify-color-system/`, so the native dispatcher sees active OpenSpec changes even when a session previously chose Engram-only persistence.
- Confirmed evidence: upstream `gentle-ai` v1.40.2 already contains a newer orchestrator/status-contract model that says the dispatcher must NOT be invoked for `engram` store because it is blind to Engram-backed changes. The local packaged/runtime assets have not incorporated that upstream behavior.
- Secondary observation: current prompts use both `both` and `hybrid` for the same artifact-store concept. The preflight mapping says `B3 -> both`, while phase skills and persistence contracts use `hybrid`.

### Affected Areas
- `~/.config/opencode/sdd-orchestrator.md` — active runtime orchestration rule currently forces native dispatcher use whenever `gentle-ai` exists.
- `~/.config/opencode/commands/sdd-status.md` — active runtime status command treats native `gentle-ai sdd-status` as authoritative without artifact-store scoping.
- `~/.config/opencode/commands/sdd-continue.md` — active runtime continue command also prefers native dispatcher unconditionally when the binary exists.
- `~/.config/opencode/skills/_shared/sdd-status-contract.md` — active runtime fallback contract still describes native status as universally authoritative.
- `~/.config/opencode/plugins/engram.ts` — active runtime Engram integration is enabled and working, so the missing continuity is not explained by Engram being absent.
- `shared/opencode.nix` — declarative wiring that deploys runtime assets from packaged `gentle-ai-assets` / `gentle-ai-assets-vanilla` into `~/.config/opencode/`.
- `lib/packages.nix` — package composition showing commands/orchestrator come from upstream assets while local overlays mainly replace skills, not these command files.
- `flake.nix` — pins `gentle-ai-src` to `v1.40.2`, `engram-src` to `v1.16.3`, and `opencode-src` to `v1.17.7`.
- `openspec/changes/` — existing repo-local OpenSpec change roots that the native dispatcher currently treats as the active planning home.

### Approaches
1. **Artifact-store-aware orchestration alignment** — make the active orchestrator/command assets choose status/continue behavior by selected artifact store before invoking native dispatcher.
   - Pros: matches confirmed runtime behavior; fixes Engram-only continuity without changing Engram itself; preserves native dispatcher for OpenSpec/hybrid where it is valid.
   - Cons: requires updating packaged/runtime assets and verifying terminology/contract consistency.
   - Effort: Medium

2. **Version/pin sync to upstream fixset** — update the local packaged Gentle AI assets/runtime so the installed orchestrator and shared status contract include the upstream artifact-store-aware dispatcher rules already present in upstream `v1.40.2` assets.
   - Pros: smallest conceptual delta if the local runtime is simply stale relative to pinned upstream content; likely low-risk if limited to asset sync.
   - Cons: must first verify why local runtime assets from `gentle-ai-assets(-vanilla)` still expose the older rules despite the repo pin and binary being `1.40.2`; may uncover packaging/deployment drift rather than just missing upgrade.
   - Effort: Medium

3. **Native dispatcher expansion** — teach the binary status engine itself to understand Engram-backed changes and hybrid selection directly.
   - Pros: reduces prompt-layer special cases and makes CLI status authoritative across stores.
   - Cons: larger upstream/binary change; not needed to explain the current incident; current evidence shows the binary is intentionally OpenSpec-only in this version.
   - Effort: High

### Recommendation
Recommend proposal work around **artifact-store-aware orchestration alignment**, with a first implementation workstream focused on confirming why the installed runtime assets are older in behavior than the pinned upstream assets, not on changing Engram storage semantics.

Confirmed root cause direction:
- The observed `nextRecommended: sdd-new` and `Active OpenSpec change not found` are expected outputs when an OpenSpec-only dispatcher is asked about an Engram-only change.
- The misalignment is primarily in the active orchestration/status assets choosing the native dispatcher without respecting the selected artifact store.

Responsibility split inferred from evidence:
- `gentle-ai` binary: authoritative for OpenSpec status only in the inspected version.
- Runtime prompts/commands/assets in `~/.config/opencode`: responsible for deciding when the binary should or should not be used.
- Repo declarative wiring: responsible for which packaged assets become active at runtime.
- Engram plugin/runtime: provides persistence and was active, but is not the component that produced the OpenSpec-only status error.

Correct operating model per store:
- `openspec`: native dispatcher/status is valid and should remain authoritative.
- `engram`: orchestration should resolve status from Engram artifacts and must ignore OpenSpec-only native blocked output for Engram-backed changes.
- `hybrid` / `both`: native dispatcher may validate the OpenSpec side, but continuity logic must still account for Engram copies and use one canonical store token consistently.

### Risks
- There may be two distinct issues: the confirmed Engram-vs-native-dispatcher mismatch, plus a separate `both` vs `hybrid` token inconsistency that could affect hybrid sessions.
- Existing `openspec/changes/` content in the repo can mask Engram-only sessions by making native status appear valid while still pointing at the wrong planning home.
- If the runtime asset mismatch comes from packaging/deployment rather than prompt text alone, a prompt-only fix would be incomplete.

### Ready for Proposal
Yes — the proposal should frame this as a runtime alignment problem between artifact-store selection and dispatcher selection, with workstreams for (1) reproducing/locking expected behavior by store, (2) tracing why installed assets lag the upstream dispatcher guidance, and (3) normalizing store semantics for `openspec`, `engram`, and `hybrid`/`both`.
