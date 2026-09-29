# Tasks: Warden Opt-In (Default-Off)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~15 (≈10 additions + ≈5 deletions across two Nix modules) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single direct-to-master change |
| Delivery strategy | ask-on-risk (default; low risk → no decision gate) |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | `warden.enable` option + derived `npmPlugins` + gated config file, with eval proofs | Single direct-to-master change | `nix flake check --no-build` | `nix eval` plugin-array and `home.file` assertions (Phase 3) | Revert single commit; no migration or store state |

## Phase 1: Nix Module Change

- [x] 1.1 In `shared/opencode/plugins.nix`, add `warden.enable = mkEnableOption "the opencode-warden npm plugin";` under `options.home.opencode.plugins` (before the `npmPlugins` option).
- [x] 1.2 In the same file, reduce the `npmPlugins` declared default to the two base entries and add `config.home.opencode.plugins.npmPlugins = mkDefault ([ "opencode-claude-auth@latest" "opencode-multimodal@latest" ] ++ optional config.home.opencode.plugins.warden.enable "opencode-warden@1.2.0");` so membership derives from the flag while explicit consumer overrides keep higher precedence.

## Phase 2: Conditional Config Lifecycle

- [x] 2.1 In `shared/opencode.nix`, wrap the `home.file.".config/opencode/opencode-warden.json"` entry (lines 211–213) in `mkIf config.home.opencode.plugins.warden.enable` so the managed file exists only when enabled; Home Manager removes it on the next disabled activation (spec scenario "Disabled generation removes stale config").

## Phase 3: Formatting/Evaluation Verification

- [x] 3.1 Format touched files: `nix fmt -- shared/opencode/plugins.nix shared/opencode.nix`.
- [ ] 3.2 Default-off V1 JSON on rog, thinkcentre, t14, macm5: `nix eval --raw '.#homeConfigurations.<host>.config.home.file.".config/opencode/opencode.json".text' | jq -e '.plugin == ["opencode-claude-auth@latest","opencode-multimodal@latest"]'` — exit 0 for all four hosts.
- [ ] 3.3 Disabled hosts carry no Warden config entry: `nix eval --json '.#homeConfigurations.<host>.config.home.file' | jq -e 'has(".config/opencode/opencode-warden.json") | not'` for the same four hosts.
- [x] 3.4 Opt-in eval on rog and t14 via `nix eval --impure --raw --expr` with `builtins.getFlake` + `extendModules { modules = [{ home.opencode.plugins.warden.enable = true; }]; }`: the V1 `plugin` array contains `opencode-warden@1.2.0` exactly once with both base plugins present, and `home.file` gains `".config/opencode/opencode-warden.json"` whose `audit.filePath` ends with `/.local/state/opencode/warden/audit.log`.
- [x] 3.5 Regression evals on rog: `.#homeConfigurations.rog.config.home.file.".config/opencode-v2/opencode.json".text` byte-identical pre/post change, `.#homeConfigurations.rog.config.home.opencode.activePlugins` unchanged, and `git diff --exit-code -- pkgs/opencode-npm-packages/versions.json pkgs/opencode-npm-packages/node-modules.json` (read-only pins).
- [x] 3.6 Full gate: `nix flake check --no-build` passes.
- [ ] 3.7 Host-scoped targets evaluate: `nix eval .#homeConfigurations.<host>.activationPackage.drvPath` for rog, thinkcentre, t14, macm5 — plus `nix eval .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath`.

## Notes

- Threat matrix is `N/A` per design (declarative option, list, and JSON-file generation only) — no RED-test tasks.
- Live file removal on hosts happens at each host's next Home Manager activation (HM sweep of the dropped managed entry); no deployment task in this register.
- Posture: default-off removes Warden redaction from all hosts; Nix `permissions` remains the authorization boundary.
