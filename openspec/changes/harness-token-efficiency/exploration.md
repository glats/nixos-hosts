## Exploration: harness-token-efficiency

### Current State
The stack is already deliberately token-aware: Gentle AI provides SDD agents and phase-to-model routing; Caveman compresses agent prose; Cavecrew reduces delegated-result size; Ponytail constrains implementation scope; Engram retains state. OpenCode also enables automatic compaction and pruning, keeps a 10,000-token reserve, and removes rarely used GitHub MCP schemas. Claude Code and OpenCode share declarative Home Manager deployment for skills, MCPs, and mutable runtime configuration.

Hermes is identified as `NousResearch/hermes-agent`, a separate self-improving agent runtime rather than an OpenCode/Claude Code plugin. Its native `delegate_task` creates isolated child sessions and returns final summaries to conserve parent context. The installed Hermes delegation skill is a workflow contract patterned on that API; it does not mean Hermes is installed or wired into this Nix configuration.

RTK is identified as `rtk-ai/rtk` (Rust Token Killer), a CLI proxy that rewrites supported shell commands and compresses their output. The pinned `nixos-26.05` branch packages RTK 0.41.0. RTK supplies a fail-open OpenCode `tool.execute.before` plugin, a Claude Code PreToolUse hook, and a Hermes Python plugin. Its advertised 60–90% reduction applies to command output only, not total model cost.

### Affected Areas
- `shared/opencode.nix` and `shared/opencode/runtime-config.nix` — canonical Home Manager package and managed-plugin/config deployment surfaces for OpenCode.
- `shared/claude-code.nix` — generates Claude settings and MCP configuration; the RTK PreToolUse hook must be declarative and merged without clobbering existing settings.
- `shared/ai-assets.nix` and `shared/opencode/mcps-base.nix` — shared skill/MCP composition; Hermes should not be added as an MCP without a verified bridge and a concrete cross-agent use case.
- `lib/packages.nix` — exposes common packages to Linux and Darwin; RTK can be sourced directly from pinned nixpkgs.
- `flake.nix` — has Gentle AI, Caveman, Ponytail, Claude Code, and Engram inputs but no Hermes or RTK input; RTK does not require a new input.
- `linux/home/shared-modules.nix` and `darwin/home/shared-modules.nix` — shared OpenCode and Claude Code modules already apply to all four hosts.

### Approaches
1. **RTK-first declarative integration** — install `pkgs.rtk` through shared Home Manager configuration; vendor RTK's small OpenCode plugin through the existing managed-plugin path and declaratively merge its Claude Code hook.
   - Pros: Targets the remaining high-volume source of context (shell output), applies across the current OpenCode/Claude Code stack, uses a package already in the pinned channel, and needs no new flake input or operational script.
   - Cons: Only shell calls benefit; built-in Read/Grep/Glob bypass Claude's hook. Filters can remove useful detail, so failures must retain RTK's recall path and exclusions need validation.
   - Effort: Medium.

2. **Add Hermes as a separately managed, opt-in runtime** — package/pin Hermes and declare its own config, credentials, MCP access, and delegation policy, optionally enabling RTK's Hermes adapter.
   - Pros: Native isolated delegation, configurable inexpensive worker model, and a mature parallel-workflow runtime beyond the current skill-level convention.
   - Cons: Duplicates OpenCode/Gentle AI orchestration, memory, skills, provider setup, and MCP policy; Hermes is not available from nixpkgs according to the package search; its installer and runtime introduce Python/Node lifecycle and separate state. It is not a drop-in OpenCode or Claude Code extension.
   - Effort: High.

3. **Skill-only trial** — add instructions to call RTK manually and treat the existing Hermes delegation skill as documentation, without installing hooks, plugins, or a new runtime.
   - Pros: Low-risk comparison and no configuration coupling.
   - Cons: Manual adoption is inconsistent, provides no reliable measurement, and cannot establish whether automatic rewrites preserve the current workflows.
   - Effort: Low.

### Recommendation
Propose an RTK-first change limited to declarative package installation and native integrations for the existing two runtimes. Start with OpenCode's official fail-open TypeScript plugin and Claude Code's supported PreToolUse hook, preserve every existing setting during merges, disable telemetry explicitly, and measure `rtk gain` before and after a short trial. Keep the current Caveman/Cavecrew/Ponytail/compaction/tool-pruning layers; they address different token sources and are complementary.

Do not add Hermes to this change. Its `delegate_task` capability overlaps with the existing Gentle AI SDD orchestration and Hermes-specific skill, but adopting the actual Nous runtime is a separate platform decision. Revisit it only with a named unmet workflow (for example, long-lived remote automation or multi-agent execution that OpenCode cannot provide) and a decided ownership boundary for skills, memory, providers, MCP credentials, and cost controls.

### Risks
- RTK's claimed percentage concerns shell-output bytes/tokens, not total spend; benchmark representative OpenCode and Claude Code sessions before treating it as a cost reduction.
- RTK changes commands before execution; test Git, Nix evaluation, Go tests, and failure/recall behavior, and retain exclusions for commands where complete output matters.
- RTK's upstream OpenCode integration targets the current plugin hook API; the pinned OpenCode is 1.18.18, so verify the copied plugin against that version rather than relying on the upstream installer.
- Hermes would create a second harness with independent persistent state and credentials; adding it without a bounded role increases maintenance and token spend rather than reducing it.

### Ready for Proposal
Yes — tell the user that RTK is a verified, nixpkgs-packaged candidate for a measured declarative pilot across OpenCode and Claude Code, while Hermes is a separate agent platform that should be deferred until they choose a concrete workflow it uniquely solves.
