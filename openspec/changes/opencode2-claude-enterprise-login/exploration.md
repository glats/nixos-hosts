## Exploration: opencode2-claude-enterprise-login

### Current State

Exploration only, independently researched on 2026-10-06 through Context7 official V2 documentation, authenticated GitHub searches (`get_me` first), Exa, upstream source, npm metadata, and NixOS MCP. No installation, login, credential read, inference/billing request, restart, activation, or Nix edit occurred. Existing dirty work was preserved. `openspec/config.yaml:1-7` declares hybrid persistence; Engram project discovery returned `nixos-hosts`. The named folder did not previously exist.

OpenCode V2 is pinned to 2.0.14 (`pkgs/opencode-v2/default.nix:11-34`), with matching SDK packages (`pkgs/opencode-npm-packages-v2/versions.json:3-8`). The environment isolates config/data/cache/state/database/tmp and disables project configuration (`shared/opencode.nix:50-59`). The ordinary launcher uses that environment but does not force standalone mode (`shared/shell-aliases.nix:170-188`). Official V2 documentation says normal clients discover/start the user's shared background server; changing environment variables alone is therefore not sufficient proof of trial isolation.

The managed global JSON owns agents, permissions, MCPs, provider policies and disabled updates (`shared/opencode/runtime-config.nix:61-112`). Activation restores that JSON and copies six harness plugins plus pinned SDK assets (`:137-225`). Anthropic is already allowed (`shared/opencode/providers-base.nix:76-79`), but that is not an authenticated account. Current Linux host selections are `openai-medium`; macm5 selects `github-copilot-medium` (`hosts/rog/home/default.nix:18`, `hosts/thinkcentre/home/default.nix:12`, `hosts/t14/home/default.nix:26`, `hosts/macm5/default.nix:76`). An older main spec describes macm5 as OpenAI-native; current source, not that historical profile claim, must determine preservation assertions.

The strongest technical candidate is MIT-licensed `opencode-claude-subscription@0.1.4`, source commit `5290dc718c0648fb79a4aa07f7b41756cf145aba`. Its README requires OpenCode >=2.0.16 and reports testing OpenCode 2.0.16 with plugin SDK 2.0.18, only Haiku 4.5 and Claude Code reuse. Its Node engine is >=24, with no declared runtime dependencies. npm publishes 0.1.4 with integrity `sha512-ZzUonzhCrZxu6dpkw9Q7YaZUqs6nPg2WJmMUa4r99jSPocfYBiYzosolj9YjkF6SXCI5xrfX0kbUBmXFu6PWhw==`; this is registry metadata, not an independently verified Nix content hash or published-tarball/source equivalence proof.

`src/claude-code.ts` registers `claude-subscription-claude-code`, reads the Linux credentials file respecting `CLAUDE_CONFIG_DIR`, or invokes macOS `security find-generic-password` for service `Claude Code-credentials`, falling back to the file. It returns the access token, expiry, and optional subscription metadata with an empty refresh token. It does not filter subscription type or write/rotate native credentials. Refresh re-reads the native source, retaining the stale credential on failure. OpenCode still stores an imported access-token copy: read-only does not mean no-copy. Enterprise access, seat eligibility, organization authorization and actual macm5 Keychain compatibility remain unverified.

Crucially, this is direct HTTP token reuse, not official CLI inference delegation. `src/index.ts`, `src/constants.ts`, and `src/request.ts` add Claude Code identity/headers, rename tools and replace an environment phrase explicitly identified by upstream as a third-party classifier. That replacement is unconditional in the default options. The plugin zeroes displayed model costs while OAuth is active; this cannot establish Enterprise billing. `SECURITY.md` confirms a custom Anthropic base URL receives the bearer token. Optional debug logging records prompt bodies. Browser/paste-code login methods also exist, with callback port 53692 for browser login; the native import method itself needs no callback listener or extra daemon. No separate telemetry/update mechanism was found in the reviewed candidate files, but this was not a complete dependency or tarball audit.

Evidence, fetched anew:

- Official V2 configuration/plugins/providers and private-server semantics: https://opencode.ai/v2/docs/config, https://opencode.ai/v2/docs/build/plugins/migrate-v1, https://opencode.ai/v2/docs/providers, https://opencode.ai/v2/docs/cli, https://opencode.ai/v2/docs/network.
- Candidate source and tests: https://github.com/eysenfalk/opencode-claude-subscription/tree/5290dc718c0648fb79a4aa07f7b41756cf145aba; registry: https://registry.npmjs.org/opencode-claude-subscription/0.1.4. GitHub issue search returned zero public issues in that repository, not evidence of Enterprise support or absence of private vulnerabilities.
- Prior failure reports: https://github.com/anomalyco/opencode/issues/7410 and https://github.com/anomalyco/opencode/issues/18267 document consumer OAuth failures, not current Enterprise compatibility. https://github.com/anomalyco/opencode/issues/53393 reports a 2.0.23 config-directory watcher storm; do not upgrade blindly to latest or put mutable logs under config.
- Official authorization boundary: https://code.claude.com/docs/en/legal-and-compliance limits OAuth to ordinary Claude Code/native application use and directs developer integrations toward approved API/cloud authentication; Enterprise uses commercial terms. https://support.claude.com/en/articles/15036540-use-the-claude-agent-sdk-with-your-claude-plan explicitly pauses the June 15 SDK/`claude -p` billing changes. Its third-party-app discussion is about SDK-based usage, not permission for copied-token HTTP plugins. These pages do not establish permission for this Enterprise use case; obtain organization/Anthropic confirmation rather than treating the consumer-specific prohibition or its Enterprise omission as permission.

### Affected Areas

- `shared/opencode/runtime-config.nix:77-112,202-225` — reuse generated harness assets for a separate trial; never append the candidate to the active global runtime during initial adoption.
- `shared/opencode.nix:50-59,127-175,220-279` — separate trial state/environment; preserve no-restart and singleton BrowserMCP assertions.
- `shared/shell-aliases.nix:170-215` — eventual explicit opt-in launcher must guarantee a private server, not merely override XDG variables. Any substantive operational helper belongs under `pkgs/nixos-scripts/`, not a new shell script.
- `pkgs/opencode-v2/default.nix`, `pkgs/opencode-npm-packages-v2/{versions.json,node-modules.json}` — candidate-specific fixed binary/SDK closure if compatibility requires it. Existing global pins should remain unchanged for the initial isolated trial.
- `flake.nix:279-296` — existing check verifies agent JSON shape only, not plugin API loading, HTTP hooks, credential safety or billing. Linux and Darwin evaluation/build gates are separate.
- `shared/opencode/v2-mcps.nix:21-25` — trial may use the existing loopback remote BrowserMCP broker, never start a second listener. Preserve other MCP/agent/provider settings without importing production credential databases.

### Approaches

1. **Defer direct OAuth adoption; prepare an offline isolated compatibility trial** — separate runtime with a pinned candidate and separate compatible OpenCode/SDK closure, no native credential access until separately approved and authorized.
   - Pros: preserves the live harness, permits reproducible compatibility/security checks, contains state and rollback.
   - Cons: cannot promise Enterprise login success; copied-token request disguise and misleading cost reporting remain adoption blockers, even when optional billing/prompt-relocation features are disabled.
   - Effort: Medium. Test 2.0.16/SDK 2.0.18 as upstream's actual documented combination or evaluate an aligned 2.0.18 closure; neither is locally proven. npm metadata confirms 2.0.18 Linux x64 and Darwin arm64 binaries exist. All four platform pins and SDK dependency closure/hash compatibility still require verification. NixOS MCP's stable catalog returned OpenCode 1.1.14 and no exact candidate package, so it does not prove repository 26.05 availability; use the existing custom packaging pattern.

2. **Official Claude Code/Agent SDK subprocess route** — leave OAuth ownership and inference in the official client, with Enterprise/admin approval.
   - Pros: avoids raw credential extraction and native-token rotation races; follows the official SDK/CLI usage surface discussed by Anthropic.
   - Cons: no verified ready-made V2 bridge preserving OpenCode's exact tool/permission loop was established; nested Claude harness semantics may differ. A project called `opencode-anthropic-login-via-cli` actually reads credentials and patches HTTP, so its name is not evidence of delegation.
   - Effort: Medium/High; investigate separately before expanding this change into a custom provider/proxy. Existing official Claude Code is the no-code fallback, but does not satisfy replacing it with OpenCode.

3. **Install a token-refreshing plugin globally** — `heymaaz/opencode-claude-auth-v2@0.4.0-beta.5`.
   - Pros: advertises reuse of native credentials and built-in Anthropic tools.
   - Cons: README targets old beta `0.0.0-next-17444`; package depends on `@opencode/plugin: latest`. Source `src/credentials.ts` writes shared auth state and supports rotated native-credential writeback. Its hard-coded `~/.local/share/opencode/auth.json` path bypasses the desired XDG trial boundary. Reject for this scope.
   - Effort: High risk, not recommended. Sources: https://github.com/heymaaz/opencode-claude-auth-v2 and https://github.com/cemalturkcan/opencode-anthropic-login-via-cli.

### Recommendation

Verdict: **defer authenticated/direct-OAuth adoption**, while allowing a narrowly scoped proposal for an **offline, disabled-by-default compatibility trial**. Integration class is a provider-auth plugin plus a private runtime, not an MCP or background service. Keep the existing binary, SDK, provider profiles and global harness untouched initially. Do not fork the plugin or add a proxy just to bypass restrictions. Before any Enterprise credential import or live request, require distinct explicit user consent, organization approval/Anthropic clarification, a reviewed destination allowlist and trustworthy billing expectations. If those cannot be obtained, stop and use the official client/approved integration route.

Acceptance should be staged: first verify exact package hashes/provenance, matching API surfaces and dependency closure, and offline plugin setup/disposal plus request/SSE tool-name restoration. Synthetic fixtures must cover Enterprise metadata, expired/missing/malformed native credentials, native-source immutability, empty refresh/no rotation, real API-key passthrough, no default credential reads or network calls, redacted logs, and rejection of non-approved origins. Upstream tests were inspected, not executed; their native fixture is Max and macOS coverage mostly checks the source label, not real Keychain import.

Then prove separate config/data/cache/state/db/tmp and private process ownership, no attachment to or restart of production, preserved agent/permission/provider/MCP snapshots, no duplicate plugins and exactly one BrowserMCP broker. Leave warming and automatic requests disabled. Any SDK/binary changes require `nix flake check --no-build`, explicit Linux integrated/standalone Home Manager and macm5 Darwin/Home Manager evaluations, candidate builds and offline load tests on actual Linux and macm5. Only after the distinct authorization gate may a bounded harmless reply/tool roundtrip and native Claude Code continuity check establish real functionality; local zero-cost UI is never billing proof.

Rollback is exit-only at first: stop only the private trial process, remove its launcher/plugin reference and trial-owned mutable config/data/cache/state/db/tmp plus imported credential copy after identifying ownership, then remove optional trial package pins. Never delete native Claude credentials, the production database, shared BrowserMCP resources or production plugin assets; never restart/revoke global sessions as cleanup. Verify the production harness still matches the baseline. No rollback command was executed here.

### Risks

- Enterprise authorization, model entitlement, account/seat type, SSO and organization policy are unknown; login reuse is only technically plausible.
- Candidate defaults deliberately imitate official-client identity/classification and hide per-token costs; an opt-in UI does not resolve these compliance/billing concerns.
- Read-only native access expands credential exposure into a second store; expired-token fallback can keep sending stale credentials. macOS service-name/profile selection and Keychain prompts need real, separately approved validation.
- Provider-scoped hooks are not a hostname allowlist; custom/proxy destinations can receive tokens. No approved-origin safety test was found in the inspected source.
- Global SDK upgrades may affect six managed plugins and concurrent sessions; config-only isolation may accidentally attach to the production shared service.
- This exploration proves documentation/source/registry availability only, not successful builds, plugin loading, Enterprise authentication, request authorization, billing or live cross-platform behavior. The advertised OpenCode skill was not present at the managed path; official Context7 V2 docs were used directly instead.

### Ready for Proposal

Yes, for a gated offline trial proposal only; no, for a claim of working or approved Enterprise login. Tell the user that a concrete V2 npm candidate exists and preserves native refresh ownership, but stronger source evidence reveals default request disguise, copied-access-token exposure and zeroed cost reporting. Planning approval is not credential-import, billing-request, installation or deployment approval. Confirm the first trial host (Linux host and/or macm5), authorization owner, acceptable billing limit and whether the official-client route is preferable before enabling authenticated testing.
