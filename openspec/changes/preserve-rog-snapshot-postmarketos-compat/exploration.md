## Exploration: preserve-rog-snapshot-postmarketos-compat

### Current State

`sync-opencode-remote` copies Rog's generated `~/.config/opencode` with an explicit rsync allowlist, then runs remote post-copy mutations. Today those mutations disable the NixOS MCP and rename the generated `opencode` provider to `opencode-go`; they do not make copied agent models or local plugins compatible. Rog selects the `openai-medium` routing profile, and the generated agent graph therefore contains explicit `openai/gpt-5.6-terra` assignments. The OnePlus postmarketOS runtime has only `nvidia` and `opencode-go` provider catalogs, so OpenCode rejects those assignments rather than inheriting a viable model. `rtk` is absent (its plugin disables itself with a warning), and Gentle AI intentionally rejects postmarketOS, making the copied skill-registry integration unsupported there.

OpenCode configuration is merged from global configuration and config-directory assets; agents can pin a `provider/model`, while agents without a model inherit the active session model. Model identifiers must exist in the active provider catalog. This makes compatibility a transfer-time concern, not a safe remote profile concern. Sources: [OpenCode Config](https://opencode.ai/docs/config/), [OpenCode Models](https://opencode.ai/docs/models/), [OpenCode Agents](https://github.com/anomalyco/opencode/blob/dev/packages/web/src/content/docs/agents.mdx), and [OpenCode's model-not-found guidance](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/cli/error.ts).

### Affected Areas
- `pkgs/nixos-scripts/cmd/sync-opencode-remote/main.go` — owns the post-rsync remote compatibility mutations and user-visible sync contract.
- `pkgs/nixos-scripts/cmd/sync-opencode-remote/main_test.go` — should prove deterministic config and file adaptation without contacting the OnePlus.
- `hosts/rog/home/default.nix` — explains why the snapshot contains the `openai-medium` graph; it should remain unchanged.
- `shared/opencode/agents.nix` and `shared/opencode/providers-base.nix` — generate explicit Rog model assignments and are source evidence, not the correct place for a phone-specific profile.
- `shared/opencode/runtime-config.nix`, `shared/opencode/rtk.ts`, and `shared/opencode-profile.nix` — explain copied managed plugins and the missing-RTK/unsupported-Gentle-AI behavior.

### Approaches
1. **Explicit post-sync compatibility transform** — copy the complete Rog snapshot, then have the Go command apply a small, documented OnePlus compatibility transform on the remote.
   - Pros: preserves Rog as the sole configuration source; makes every exception reviewable and repeatable; retains the existing backup, rsync, and post-copy architecture.
   - Cons: the transform must be maintained when the snapshot gains new portable-runtime dependencies; it requires focused JSON and file-set tests.
   - Effort: Medium.

2. **Maintain a OnePlus OpenCode profile** — generate an independent remote provider/agent configuration instead of adapting the copied snapshot.
   - Pros: gives the phone a wholly native configuration.
   - Cons: violates the required snapshot semantics; duplicates routing and plugin ownership; will drift from Rog.
   - Effort: Medium.

3. **Exclude incompatible assets during rsync** — narrow the snapshot allowlist until the failing models and plugins are never copied.
   - Pros: minimal post-copy code.
   - Cons: silently turns the transfer into a hand-curated remote configuration and makes omissions difficult to audit; cannot repair invalid model references already embedded in `opencode.json`.
   - Effort: Low initially, High ongoing.

### Recommendation

Adopt approach 1. Keep the existing rsync allowlist as the snapshot boundary and add one explicit post-copy compatibility stage for postmarketOS. It should parse the copied `opencode.json`, retain only agent model references supported by the remote catalog (`nvidia` and `opencode-go`), and replace unsupported references with one documented, confirmed OpenCode Go fallback such as `opencode-go/glm-5.3-flash` rather than creating a remote routing profile. It should also remove or disable only the known non-portable local integrations: `rtk.ts` because RTK is absent, and the Gentle-AI-dependent skill-registry integration because that tool intentionally rejects postmarketOS. The stage should report each adaptation, run after rsync on every non-dry sync, and leave the raw Rog source and all remote credentials untouched.

The implementation should make the compatibility contract data-driven but deliberately narrow: an allowlist of supported provider IDs, one fallback model, and an explicit local-plugin exclusion set. Unit tests should cover unchanged supported references, rewritten unsupported references (including `openai/gpt-5.6-terra`), malformed/missing optional fields, idempotency, and the exact excluded files. A dry run should show the planned compatibility treatment without performing remote mutations.

### Risks
- The remote catalog can change, so the fallback must be selected from a currently verified OnePlus catalog and exposed as a small, obvious constant or environment override rather than inferred from fragile CLI output.
- OpenCode merges configuration sources and loads local plugins from its config directory; leaving a known incompatible plugin file behind can preserve a failure even after JSON model repair.
- Plugin failures are not reliably isolated upstream: a plugin config-hook failure can prevent later hooks from running, and a model mismatch can disrupt delegated tasks. Sources: [upstream issue #18310](https://github.com/anomalyco/opencode/issues/18310) and [upstream issue #11066](https://github.com/anomalyco/opencode/issues/11066).
- The compatibility stage must never copy API keys, mutate Rog's generated source, or treat postmarketOS as a supported Gentle AI platform.

### Research Sources

- Context7, OpenCode documentation and source: [Config](https://opencode.ai/docs/config/), [Providers](https://opencode.ai/docs/providers/), [Models](https://opencode.ai/docs/models/), and [agent model resolution](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/tool/task.ts).
- GitHub MCP, `anomalyco/opencode`: [CLI handling for unavailable provider/model pairs](https://github.com/anomalyco/opencode/blob/dev/packages/opencode/src/cli/error.ts) and [issue #11066 on task-time ProviderModelNotFoundError](https://github.com/anomalyco/opencode/issues/11066).
- Exa research: [issue #18310 on plugin config-hook isolation and invalid agent/model failures](https://github.com/anomalyco/opencode/issues/18310), plus the official OpenCode documentation above.

### Ready for Proposal

Yes — propose a bounded Go-only change to add and test the post-sync postmarketOS compatibility transform. The proposal must state that the OnePlus receives a Rog-generated snapshot plus explicit adaptations, never an independently maintained remote profile.
