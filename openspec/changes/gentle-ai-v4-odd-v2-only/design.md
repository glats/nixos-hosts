# Design: One Gentle AI v4 / ODD Stack

## Technical Approach

Replace binary, assets and executable workflow together after disposable candidate proof; retain CLI/SDK 2.0.14. Implement four capability specs (12 requirements, 14 scenarios). Reconcile main specs against delivered, unarchived `retire-opencode-v1` deltas: supersede only Gentle-2.5/no-v4 continuity; preserve auth/proxy/tunnel and V2-only invariants. Planning stops after tasks; no implementation authorization.

## Architecture Decisions

| Option | Tradeoff | Decision/rationale |
|---|---|---|
| One tagged source / parallel stack | Coupled replacement / permanent divergence | v4.0.0 `ff77164d4f56f1665b22fb6fac51c2ccbb769400`; recompute vendorHash, Go ≥1.25.10, `/v4` module; no second production stack. |
| Source rendering / copied templates | Build-only export / placeholder drift | Vendored-source Go exporter calls `opencodeagents.Entry/Refuter/Validator`, `agentguidance.RenderOrchestratorWithSource`, `RenderRouting`, `reviewassets.ReviewExecutionContractFor`; export OpenCode/Claude prompts, not repository AGENTS.md. No shipped exporter CLI. |
| Tagged V2 relay / old local adapter | Narrow path adaptation / missing role binding | Source `internal/assets/opencode/plugins-v2/opencode-review-transport.ts`; preserve native hooks/ownership/cleanup, adapt invocation paths only. Old adapter omits required `agent`; matching schema alone is insufficient. |
| Ownership reconciliation / directory replacement | Before-image inventory / user-data destruction | Manifest relative path, source revision, installed digest and before-image; bootstrap from actual 2.5 assets including local remaps. Preserve modified/unowned files; refuse collisions. |

## Data Flow

`tag → vendored exporter → assets → HM graph/plugins → native subagent → Go admission → receipts`

`authorized substantial work → odd/tasks/<feature>.md ↔ Engram odd/<feature>/tasks`

Read back both full documents and locator; reconcile stable identity/code/evidence before writes. Outage retains local progress and pending mirror; conflicting versions survive. Small/read-only work creates no ODD artifact. Canonical source-default applicable RED/GREEN/refactor supersedes obsolete strict flags; disclose exceptions. Explicit repository/user restrictions override upstream commit defaults.

## File Changes

| Paths | Planned change |
|---|---|
| `flake.nix`, `flake.lock`, `pkgs/gentle-ai/default.nix` | Single pin, hash/toolchain/provenance, V2 registry-root patch. |
| `pkgs/gentle-ai-assets/default.nix`, new `pkgs/gentle-ai-assets/render_test.go`, `pkgs/gentle-ai-assets/v2-plugins/` | Build-only exports; replace relay/registry adapters; retire SDD-result adapter after proof. |
| `shared/opencode.nix`, `shared/opencode/runtime-config.nix` | HM native binary-wrapper/environment; manifest-based reconciliation, including OpenFang. |
| `shared/opencode/agents.nix`, `shared/opencode/v2-agents.nix`, `shared/opencode/local-agent-overlays.json`, `shared/opencode/providers-base.nix` | Replace absent SDD overlay with tagged ODD explore/verify/worker, JD/review graph; bounded grants, executor contracts, explicit existing-model mappings. |
| `shared/ai-assets.nix`, `shared/claude-code.nix`, `shared/assets/skills/`, `shared/shell-aliases.nix` | Validate shared consumers; retire executable SDD assumptions/gsdd/gnext, no invented alias. |
| `docs/gentle-ai-update.md`, existing adapter/agent/launcher tests | Gates, rollback, regression fixtures. |

## Interfaces / Contracts

No new public options: preserve `home.opencode.{enable,activeProviderName,agentOverrides,agents,disabledTools,v2.*}` and `home.ai-assets.{skillSources,agentsMdSources,engramConfig}`; overrides remain last-wins.

HM-scoped compiled `gentle-ai` wrapper restores complete `mkV2Environment` for its children despite host-config shell scrubbing; prefixes private discovery directory containing `opencode` pointing to actual `.opencode2-unwrapped`, plus Git. Relay/registry use its absolute path. No shell-function reliance, global bare alias, fabricated version, credential access, new service or Go CLI subsystem. Preserve launcher arguments, standalone/server/proxy behavior and isolated roots.

Declare `GENTLE_AI_OPENCODE_RELAY_CONTRACT=gentle-ai.opencode-relay/v2-staged`; Go still probes runtime. Wire remains `gentle-ai.provider-transport/v1`: start(prompt, dispatched agent), prompt(nonce), complete(nonce, raw terminal output OR error), result/refused. Go alone owns binding/admission/budgets/authority; adapters never parse reviewer JSON. Registry replaces archived V1 global root with canonical V2 root, retaining project-first precedence.

## Threat Matrix

Every row includes RED safe/refusal fixtures; propagate unchanged into tasks.

| Boundary | Applicability; safe/failure and RED cases |
|---|---|
| Documentation-like paths | Applicable: native classification; requirements.txt/CMakeLists.txt/executable Markdown/MDX/README.sh never passive-by-extension. |
| Git repository selection | Applicable: bound cwd; git -C/relative/absolute sibling or wrong-root fixtures refuse mismatches. |
| Commit state | Applicable: staged/commit -a/empty-index requests cannot override no-commit scope; index unchanged. |
| Push state | Applicable: tracking/first-push/explicit-refspec all denied without consent; refs unchanged. |
| PR commands | Applicable: --head/environment-prefix/composed commands cannot confer consent; no publication. |
| Process/PATH/standalone | Applicable: missing/wrong runtime/declaration, spaces/quotes/metacharacters, Linux/Darwin server/standalone preserve isolation or refuse. |
| Review roles/lifetime | Applicable: wrong-role/replay/stale/background/session-reuse/empty/truncated/duplicate/disposed relays refuse without authority mutation. |
| Ownership/archive | Applicable: foreign/modified/symlink escapes conflict safely; only proven-owned executable assets retire; archives/auth/sessions unchanged. |

## Testing Strategy

Before production edits: tagged Go runtime/admission/classification tests; Bun native-plugin fixtures extending `opencode-review-transport.test.ts`; Python `v2-agents.test.py`/`home-launcher.test.py`; ownership/recovery fixtures. Assert actual failure, unchanged authority and provider-policy/MCP/Engram/RTK parity; sandbox dependencies explicit (including jq).

Later gates: native Linux/Darwin binary/assets builds; formatting/flake-check; three Linux systems plus integrated HM, Darwin/integrated HM, four standalone HM evaluations; full-JSON routing equivalence except approved ODD mappings, catalog resolution/NVIDIA declaration. Separately authorized live SDD→ODD delegation terminal proof and real lens/refuter/validator receipts, negatives, reachable four-host runtime/MCP proof. Unavailable evidence remains UNVERIFIED.

## Migration / Rollout

Retain active SDD until candidate validated; explicit selected-unfinished-work handshake/history links precede retirement, never bulk conversion. Temporary configs only. Separately authorize rog-first then others. Rollback pins/adapters/environment/generations/owned before-images; retain OpenSpec/ODD/session/receipt data. Preserve dirty SSH branch/index; no staging/checkout.

## Open Questions

None blocking tasks. Proven 2.0.14 incompatibility blocks deployment pending explicit runtime-upgrade decision; released installer SDK 2.0.4 equality/main tolerance neither proves incompatibility nor authorizes downgrade. Models, builds, activation and commits remain separate gates.
