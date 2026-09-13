## Exploration: replace-local-secret-guard

### Current State
`secret-guard.ts` is a locally maintained managed plugin, enabled for every shared OpenCode profile. It is broken because it exports an object typed from `@opencode-ai/sdk`, whereas the current OpenCode plugin contract requires a default async plugin function returning hooks. Its effective scope is limited to `bash` output redaction and removal of `SOPS_AGE_KEY` / `SOPS_AGE_KEY_FILE` from the shell environment; Nix permissions already deny `sops*`, `.env*`, and `/run/secrets/**`.

NPM plugins are serialized into `opencode.json` from `home.opencode.plugins.npmPlugins`. The activation copies packages already fetched and hash-verified by `pkgs/opencode-npm-packages` into the runtime `node_modules`; an undeclared package in that derivation would instead be resolved dynamically by OpenCode. Official documentation supports pinned npm specs and uses `--ignore-scripts`, but dynamic installation is still outside the Nix store.

### Affected Areas
- `shared/opencode-profile.nix` — disables the local guard and enables the chosen community plugin for all shared OpenCode hosts.
- `shared/opencode/plugins.nix` — removes the obsolete `secretGuard` option/active-plugin entry and declares the version-pinned npm plugin.
- `shared/opencode/runtime-config.nix` — removes the managed local-plugin source entry; its existing `plugin = cfg.plugins.npmPlugins` serialization is the npm declaration path.
- `pkgs/secret-guard-assets/default.nix` — deleted with the local plugin asset.
- `pkgs/secret-guard-assets/share/secret-guard/opencode/plugins/secret-guard.ts` — deleted; it is the broken implementation.
- `lib/packages.nix`, `overlays/linux.nix`, `overlays/darwin.nix` — remove the retired cross-platform derivation and overlay exports.
- `pkgs/opencode-npm-packages/versions.json` and `pkgs/opencode-npm-packages/node-modules.json` — add the chosen package and its fixed tarball hash so activation remains Nix-reproducible.

### Approaches
1. **Adopt `opencode-warden@1.2.0` with Nix-pinned package assets** — use the maintained security-focused plugin and retain the existing permission deny rules as the primary SOPS/filesystem boundary.
   - Pros: Default-export `Plugin` implementation uses the current hook model; 74 regex patterns, tool input/output redaction, sensitive-path blocking, audit logs, and `shell.env` sanitization cover the former SOPS variables through `*_KEY` patterns. It has recent July 2026 fixes/releases, 871 reported tests, an MIT license, and a peer dependency on `@opencode-ai/plugin ^1.2.0`. The documented v0.1.0+ requirement and hook usage support OpenCode 1.18.22 compatibility, although no explicit 1.18.22 test matrix is published. It has the strongest verified maintenance signal of the candidates.
   - Cons: Broader policy can cause false positives and blocks; its default SOPS protection redacts matching environment values rather than deleting only the two former variables. Prompt blocking is opt-in because upstream displays a generic session error. LLM safety features must remain disabled unless separately configured, because they add latency, external-model trust, and fail-closed availability behavior.
   - Effort: Medium

2. **Adopt `opencode-secret-redactor@0.5.1` with Nix-pinned package assets** — use a focused reversible-redaction plugin.
   - Pros: Correct default async `Plugin` export, recent packaged release, tests/build tooling, and placeholder restoration for `bash`, `write`, and `edit` avoids corrupting legitimate secret-bearing operations. It redacts chat messages, provider-bound message history, and selected tool output.
   - Cons: Does not provide SOPS environment sanitization or sensitive-file blocking, so it is not a complete replacement for the local guard. Its in-memory vault and experimental message-transform hook introduce restoration/session-restart and upstream-API risks. Maintenance evidence is weaker than Warden (last repository update April 2026).
   - Effort: Medium

3. **Adopt `opencode-secrets-protect@0.1.0` (formerly documented as `opencode-secret-protect`)** — replace output with a warning on detection.
   - Pros: Small, focused output guard for `read`, `bash`, and `grep`; entropy detection can catch unknown formats.
   - Cons: The project calls itself alpha, package naming changed, the latest source only overwrites output after execution, and it has no SOPS environment protection, reversible restoration, file blocking, or current compatibility evidence beyond its old `@opencode-ai/plugin ^1.1.0` development dependency. Entropy detection raises false-positive risk by design.
   - Effort: Low

### Recommendation
Adopt `opencode-warden@1.2.0` and pin its exact npm tarball in `pkgs/opencode-npm-packages`; do not rely on OpenCode's runtime npm fetch. It is the best verified community-maintained option: it uses the official default-function plugin API, is actively maintained with a substantial test suite, replaces both current defenses (output redaction and SOPS-key shell protection), and adds deterministic path protection that complements—not replaces—the repository's existing Nix permissions. Start in its default regex-only mode with `scanUserPrompts` and all LLM features disabled. Preserve `sops*`, `.env*`, and `/run/secrets/**` denies because plugin policy is defense in depth, not the authorization boundary.

### Risks
- Warden's broad default environment stripping may redact provider credentials passed to shell commands; test expected OpenCode/MCP workflows and configure only documented exclusions if necessary.
- Warden's broad path and input rules can block valid secret-template or fixture work; use narrowly scoped documented allowlists/exemptions rather than disabling global redaction.
- Reversible redactors keep secret mappings in memory; they improve tool continuity but cannot protect secrets missed by detection and may lose mappings across restarts.
- OpenCode's package specification supports an exact npm version, but reproducibility requires adding the tarball/version hash to the repository derivation; a config-only npm declaration leaves runtime network resolution.
- No candidate publishes an explicit OpenCode 1.18.22 compatibility matrix; the proposal must include a smoke test on the pinned runtime before rollout.

### Ready for Proposal
Yes — propose a cross-platform Home Manager migration to `opencode-warden@1.2.0`, Nix-pin its package assets, remove every local secret-guard derivation/reference, keep existing Nix permission denies, and verify the OpenCode 1.18.22 startup plus redaction, SOPS shell-environment, and blocked-path behavior on Linux and Darwin.
