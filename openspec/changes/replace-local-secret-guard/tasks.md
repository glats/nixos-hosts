# Tasks: Replace Local Secret Guard

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 180–300 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Pin Warden, migrate shared profiles, remove local guard, and validate both platforms | Single PR | `format-nix && nix flake check --no-build` | Offline OpenCode 1.18.22 smoke session on Linux and mact2 | Revert this migration commit; permission denies remain unchanged |

## Phase 1: Package Pinning

- [x] 1.1 Inspect the pinned `opencode-warden@1.2.0` tarball `package.json`; run `nix-prefetch-url` and `nix hash to-sri --type sha256` for its registry tarball and every absent non-peer production dependency.
- [x] 1.2 Add exact Warden/dependency versions to `pkgs/opencode-npm-packages/versions.json` and matching SRI hashes to `pkgs/opencode-npm-packages/node-modules.json`; verify the existing derivation produces the complete offline closure.

## Phase 2: Configuration and Retirement

- [x] 2.1 In `shared/opencode-profile.nix` and `shared/opencode/plugins.nix`, remove `secretGuard`, add exact `opencode-warden@1.2.0` to `npmPlugins`, and ensure the generated plugin array has no local guard.
- [x] 2.2 In `shared/opencode/runtime-config.nix`, remove the `secret-guard.ts` managed source and add unconditional removal of the legacy runtime file before managed-plugin copies.
- [x] 2.3 Remove `secret-guard-assets` from `lib/packages.nix`, `overlays/linux.nix`, and `overlays/darwin.nix`; delete `pkgs/secret-guard-assets/default.nix` and its `share/secret-guard/opencode/plugins/secret-guard.ts` asset.
- [x] 2.4 Preserve `permissions.nix` denies for `sops*`, `.env*`, and `/run/secrets/**`; do not add a Warden config file, prompt blocking, LLM safety, or broad allowlists.

## Phase 3: Regression and Runtime Validation

- [x] 3.1 Build/inspect one Linux activation package and generated `opencode.json` plus `lib/node_modules`; assert exact Warden registration, package presence/integrity, no `secret-guard` active references, and all four host profiles include Warden.
- [x] 3.2 Run an offline OpenCode 1.18.22 Linux smoke session with synthetic key-shaped tool output and `SOPS_AGE_KEY`; assert startup has no plugin error, output is redacted, and the shell-tool environment omits the synthetic secret.
- [ ] 3.3 Run the corresponding offline smoke session on mact2; assert package identity, startup, redaction, sanitized environment, and denial of `sops*`, `.env*`, and `/run/secrets/**` paths. Never use real secrets.

## Phase 4: Nix Verification

- [x] 4.1 Run `format-nix && nix flake check --no-build` after all Nix edits.
- [ ] 4.2 Evaluate the package and supported configurations, then run `nixos-build build` for Linux and `nix build .#darwinConfigurations.mact2.config.system.build.toplevel` for Darwin; record failures and stop acceptance on any failed validation.
