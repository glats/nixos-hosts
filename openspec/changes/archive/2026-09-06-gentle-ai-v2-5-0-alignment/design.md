# Design: Gentle AI v2.5.0 Alignment

## Technical Approach

Pin one upstream tag, keep Home Manager authoritative, wire the four v2.5.0 plugins, and translate every formerly true/false agent tool grant into OpenCode `permission` values before provider-tier models are added.

```text
v2.5.0 overlay ── smartMerge(local permission class/name) ── model overlay ── agentOverrides ── opencode.json
v2.5.0 assets  ── managedPlugins enable filter ── activation copy/removal ── runtime plugins/
```

## Architecture Decisions

| Decision | Choice and rationale |
|---|---|
| Source/build | Change `gentle-ai-src.url` to `github:Gentleman-Programming/gentle-ai/v2.5.0` and update only its lock node. Set `vendorHash = lib.fakeHash`, run `nix build .#gentle-ai`, copy Nix's `got: sha256-…`, replace the fake hash, then build `.#gentle-ai` and `.#gentle-ai-assets`. The asset derivation already copies `opencode`; no edit is needed. |
| Plugin interface | In `plugins.nix`, delete `backgroundAgents`; add `modelVariants`, `opencodeReviewTransport`, `sddTaskResultArtifacts`, and `skillRegistry` using `mkEnableOption` (verified default `false`). Add corresponding active names. `opencode-profile.nix` enables only the latter two and removes the stale warning block. |
| Plugin cleanup | `runtime-config.nix` replaces the ghost entry with the four exact upstream files. Inside `setupOpencodePluginRuntime`, immediately after creating the real `plugins/` directory, run store-qualified `rm -f "$runtime_dir/plugins/background-agents.ts"`; then run generated `disabledManagedPluginNames` removals, then copy enabled files. This handles removed-option history independently of current option state. |
| Permission merge | Remove `localTools` and always strip upstream `tools`. Build `localPermission` by recursively merging the generic class overlay with the named overlay, then `smartMerge localPermission (upstream.permission or {})`; local values remain right-hand winners and nested upstream `__replace__` markers are stripped. `lib.recursiveUpdate` was verified as recursive RHS precedence. |

## Interfaces / Contracts

`home.opencode.plugins.{modelVariants,opencodeReviewTransport,sddTaskResultArtifacts,skillRegistry}.enable` are booleans defaulting false. Managed filenames are `model-variants.ts`, `opencode-review-transport.ts`, `sdd-task-result-artifacts.ts`, and `skill-registry.ts`.

`local-agent-overlays.json` deletes `toolOverlays` and the neutral `tools`. Permissions use strings or command maps, never booleans: `"read": "allow"`, `"edit": "allow"`, `"bash": {"pattern": "allow", "*": "deny"}`. Exact classes are:

- orchestrator: read/write/edit/bash/question, Engram, and delegation tools allow; task remains `{"*":"deny","sdd-*":"allow"}`;
- mutable (`general`, all `sdd-*` except research, `jd-fix-agent`): prior read/write/edit/bash grants plus Engram allow; `general.task` denies;
- read-only: both judges and four review lenses get read/bash/Engram allow; `explore` gets read/codegraph/Engram allow and write/edit/bash/task deny; refuter gets read/Engram allow and write/edit/bash/task deny; validator gets read/Engram allow, write/edit/task deny, and bash `{"gentle-ai review inspect-candidate --purpose targeted-validation *":"allow","*":"deny"}`;
- `sdd-research`: read/write/edit and Engram allow; bash/webfetch/websearch/task deny;
- neutral: all former bash/read/edit/write/delegate/task/delegation/Engram true values become `"allow"`.

Provider-tier model selection remains unchanged and is applied after permissions; runtime `agentOverrides` remains the final merge.

## File Changes

| File | Action | Exact change |
|---|---|---|
| `flake.nix` / `flake.lock` | Modify | Tag URL and resolved lock node. |
| `pkgs/gentle-ai/default.nix` | Modify | Accepted v2.5.0 vendor hash. |
| `shared/opencode/plugins.nix` | Modify | Delete ghost option/active entry; declare four options/active names. |
| `shared/opencode/runtime-config.nix` | Modify | Four managed assets and ordered legacy cleanup. |
| `shared/opencode-profile.nix` | Modify | Enable two SDD plugins; remove warning. |
| `shared/opencode/agents.nix` | Modify | Permission-only class/name merge. |
| `shared/opencode/local-agent-overlays.json` | Modify | Permission-shaped grants. |
| `docs/gentle-ai-update.md` | Rewrite | Tagged-v2.x workflow and rollback. |
| `pkgs/gentle-ai-assets/default.nix`, `shared/claude-code.nix` | Unchanged | Existing copy/orphan cleanup suffices. |

## Testing Strategy

| Spec scenario | Proof |
|---|---|
| Pin/derivations | Inspect lock; build `.#gentle-ai` and `.#gentle-ai-assets`; assert four plugin assets exist. |
| Enabled plugin | Build t14 activation and inspect enabled plugin copy statements. |
| Disabled/legacy removal | Inspect activation for disabled removals and unconditional legacy `rm`; canary with seeded file. |
| Permission migration | `out=$(nix build .#homeConfigurations.t14.activationPackage --no-link --print-out-paths)` then `jq -e` over `$out/home-files/.config/opencode/opencode.json`; assert every explore/general/sdd-/review-/jd-/neutral/orchestrator class grant above and `all(.agent[]; has("tools")|not)`. |
| Claude retirement | Seed 11 old files, activate t14, assert none remain and `gentle-sdd-*` plus OpenCode `sdd-*` exist. |
| Runbook | Assert ordered commands and absence of `v1.22.0`, `/main`, `.last-sync`. |
| Shared gate | `format-nix && nix flake check --no-build`. |

## Threat Matrix

| Boundary | Applicability | Response / RED test |
|---|---|---|
| Documentation-like paths | N/A—no executable classification. | None. |
| Git repository selection | N/A—no VCS automation. | None. |
| Commit state | N/A—no commit automation. | None. |
| Push state | N/A—no push automation. | None. |
| PR commands | N/A—no PR automation. | None. |

## Migration / Rollout and Rollback

Canary t14 after evaluation, permission inspection, and seeded cleanup; then roll out other hosts. Rollback restores the previous `main` input/definitions and vendor hash, runs `nix flake lock --update-input gentle-ai-src`, and rebuilds. Existing config refresh and orphan cleanup restore plugin, agent, and command state; nothing else requires cleanup.

## Review Workload Guard

Forecast: 250–350 authored changed lines, medium 400-line risk, normally one PR. `delivery_strategy = ask-on-risk` (orchestrator-cached); tasks must stop for a delivery decision if their forecast reaches 400 lines.

## Open Questions

None.
