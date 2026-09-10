## Exploration: cheap-orchestrator-omo-pilot

### Current State

`rog` alone selects `opencode-go-openai` in `hosts/rog/home/default.nix:16-17`. That profile maps only `gentle-orchestrator` to OpenCode Go, currently `opencode-go/glm-5.3-flash`, while every SDD phase stays on OpenAI (`shared/opencode/providers-base.nix:382-420`). `shared/opencode/agents.nix:10-15,37-66,128` resolves the active profile into the generated agent model, so changing that one profile assignment is host-scoped and does not change thinkcentre (`openai-medium`), t14 (`opencode-free`), or mact2 (`anthropic-opencode-free`) (`hosts/*/home/default.nix:12,26`; `hosts/mact2/default.nix:59-68`).

OpenCode Go documentation lists GLM-5.3-Flash at $0.15/$0.50 input/output per million tokens with $60 monthly headroom; MiMo-V2.5 at $0.14/$0.28 with $60; and GPT-5.6 Luna at $0.20/$1.20 with $15. The $0.10/$0.20 Muse models are cheaper but train on prompts/completions, so are unsuitable for this configuration. GLM-5.1 is explicitly marked as giving up too quickly in `providers-base.nix:19-22`; it is not a safe orchestrator candidate. The current source supplies no comparable orchestration-quality evidence for MiMo, so the replacement must be a reversible live pilot with gate-focused acceptance tests, not a claim of proven equivalence.

The installed binary is a custom, pinned release derivation rather than nixpkgs: `pkgs/opencode/default.nix:18-41` pins 1.18.18 and four platform artifacts; `lib/packages.nix:49-51` and both overlays expose it. The Nix MCP returned no `opencode` package result for either requested channel, so it does not establish a nixpkgs upgrade path. In contrast, the Nix-built npm surface already pins `@opencode-ai/plugin` and `@opencode-ai/sdk` to 1.18.22 (`pkgs/opencode-npm-packages/versions.json:2-3`), matching the live generated `~/.config/opencode/package.json`. Upstream confirms v1.18.22 is a release commit, and current upstream is newer, so an exact 1.18.22 binary bump is sufficient compatibility alignment.

`shared/opencode/runtime-config.nix:98-130` generates `opencode.json` from agents, MCPs, permissions, and `cfg.plugins.npmPlugins`; it installs the Nix-built `package.json` at lines 135-163 and copies the dependency closure plus the five live managed plugin files at lines 281-335. The enabled managed files are engram, rtk, secret-guard, skill-registry, and sdd-task-result-artifacts (`shared/opencode-profile.nix:31-39`). The generated OpenCode MCP set already contains Context7, Exa, and both GitHub servers (`shared/opencode/mcps-base.nix:12-72`), while skills are copied from the four existing sources (`shared/ai-assets.nix:21-40`; `runtime-config.nix:228-255`).

OmO Ultimate is an OpenCode npm plugin. Upstream's current dev docs require the plugin entry `"oh-my-openagent"` (the legacy `oh-my-opencode` entry only loads with a warning), and its published npm package remains named `oh-my-opencode` at 5.0.0-beta.53 with exact OpenCode plugin/SDK 1.18.22 dependencies. Its unified user configuration is `~/.omo/omo.jsonc`; OpenCode-only settings belong in `[opencode]`. The declarative pilot must never invoke its installer because that installer writes `opencode.json` and `omo.jsonc`.

The exact pilot configuration surface is: `[opencode].disabled_mcps = ["websearch", "context7", "grep_app"]` (leaving `lsp` enabled); `[opencode].disabled_hooks` including `directory-agents-injector` and `rules-injector`; `[opencode].telemetry = false`; `[opencode].team_mode.enabled = false`; and `[opencode].categories` model aliases. Set `OMO_DISABLE_POSTHOG=1` in Home Manager as a second, global telemetry kill switch. OmO documents `disabled_skills` for its built-in skills; its user-level skills outrank plugin skills, so this repository's same-named skills win. Disable the unwanted documented OmO skills explicitly; verify whether its ast-grep skill has a disable key during implementation because its docs confirm it ships but do not document a separate switch. OmO creates runtime state under `~/.omo`, so the pilot must treat it as runtime state, not a generated artifact.

Mandatory research used OpenCode's current Go documentation, the OmO dev branch via GitHub, and the Nix MCP. Context7 and Exa MCP tools were not exposed in this executor environment; their configured existence in this repo was verified, but webfetch/GitHub evidence was used instead.

### Affected Areas

- `shared/opencode/providers-base.nix` — change only the `opencode-go-openai.gentle-orchestrator` model; it is the host-selected profile.
- `pkgs/opencode/default.nix` — update the custom OpenCode release version and all four immutable artifact hashes.
- `pkgs/opencode-npm-packages/versions.json` and `pkgs/opencode-npm-packages/node-modules.json` — add the pinned `oh-my-opencode` npm package and its fixed tarball hash to the existing declarative dependency closure.
- `shared/opencode.nix` and `shared/opencode/plugins.nix` — add an opt-in `home.opencode.omo.enable` interface and use it to add the plugin entry and telemetry environment only when enabled.
- `shared/opencode/runtime-config.nix` — generate/deploy `~/.omo/omo.jsonc` only for the opt-in host while preserving its mutable-copy and managed-plugin behavior.
- `hosts/rog/home/default.nix` — enable the OmO pilot alongside the existing rog-only provider selection.
- `shared/claude-code.nix` — read-only scope boundary: OmO must not be connected to its separate Claude Code configuration or activation path.

### Approaches

| Item | Option | Pros | Cons | Complexity |
|---|---|---|---|---|
| Orchestrator | Keep GLM-5.3-Flash | Cheapest known reliable baseline by repository evidence; highest documented Go headroom. | Does not satisfy the requested cheaper re-fit. | Low |
| Orchestrator | Pilot `opencode-go/mimo-v2.5` | Lower documented token prices than Flash and equal $60 headroom; remains OpenCode Go. | No upstream quality proof for gate-driving orchestration; model capability must be live-tested. | Low |
| Orchestrator | Use Muse Spark 1.3/1.2 | Lowest documented price. | Provider trains on prompts/completions; unacceptable privacy trade-off. | Low, rejected |
| OpenCode bump | Exact v1.18.22 custom derivation | Meets OmO's exact plugin/SDK compatibility point with the smallest release delta. | Requires four source hashes and cross-platform evaluation. | Low |
| OpenCode bump | Latest custom derivation | Gets later fixes. | Larger unreviewed compatibility surface during a plugin pilot. | Medium |
| OmO | Declarative full plugin pilot | Retains OmO's actual orchestration, plan review, and category routing; Nix owns every config input. | Adds a large third-party hook surface and runtime state. | Medium |
| OmO | Extract a small subset locally | Smaller hook surface. | Reimplements and forks upstream behavior, losing the requested OmO pilot. | High |
| OmO | Use a slim fork | Potentially fewer features. | Different project and maintenance burden; does not evaluate the requested upstream OmO. | Medium |

### Recommendation

Make this a three-stage, reversible rog-only pilot. First bump the custom binary exactly to 1.18.22 and verify all five managed plugins load before introducing OmO. Second, change only `opencode-go-openai.gentle-orchestrator` to `opencode-go/mimo-v2.5`, with GLM-5.3-Flash retained as the one-line rollback. Accept MiMo only if it independently completes representative delegation, gate, retry, and no-early-exit checks; otherwise revert to Flash. Luna and GLM-5.2 are not cheaper than Flash on the published price table, and Muse is rejected for privacy.

Third, add an explicit `home.opencode.omo.enable = false` default and set it to true only in rog. When true, append `oh-my-openagent` to generated `opencode.json`, provide `oh-my-opencode` through the existing pinned npm closure, deploy `~/.omo/omo.jsonc`, and set `OMO_DISABLE_POSTHOG=1`. Keep LSP, disable OmO's duplicate websearch/context7/grep_app MCPs and duplicate AGENTS/rules injection hooks, default Team Mode off, and map `quick` to the configured light tier and `deep`/`ultrabrain` to the configured reasoning tier. The dependency closure will be built globally under the current package architecture, but the plugin registration, config, environment, and runtime behavior must exist only on rog.

### Risks

- MiMo may be cheaper but fail orchestration gates or terminate early. Mitigate with an explicit baseline comparison and immediate GLM-5.3-Flash rollback criterion.
- OmO's 50+ hooks can duplicate or conflict with Gentle AI behavior. Disable duplicate MCPs and AGENTS/rules hooks, disable unwanted skills, leave Team Mode off, and run `doctor --verbose` plus live gate scenarios.
- An OpenCode binary/plugin API mismatch can prevent the existing five plugins from loading. Bump only to 1.18.22 first and test each plugin before enabling OmO.
- `opencode-npm-packages` currently copies its full closure to every OpenCode runtime. Although only rog activates OmO, document and test that other hosts have no OmO plugin entry, `.omo` managed file, or OmO environment variable.
- OmO migrations can move legacy files and writes runtime state. Do not run its installer or migration command; deploy a fresh declarative `~/.omo/omo.jsonc` and preserve runtime data outside Home Manager ownership.

### Ready for Proposal

Yes. Tell the user that the OpenCode Go constraint is feasible and the recommended cheaper candidate is a guarded MiMo-V2.5 pilot, not an assumed quality upgrade; OpenCode should first align exactly to 1.18.22; and OmO can be ported declaratively to rog with duplicate integrations disabled, telemetry hard-off, and an immediate rollback path.
