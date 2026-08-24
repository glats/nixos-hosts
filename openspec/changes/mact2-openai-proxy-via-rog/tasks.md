# Tasks: mact2 OpenAI Proxy via rog

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 240-360 |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | rog gateway, nginx exposure, and secret boundaries | PR 1 | `nix eval --raw .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` | `curl -sS https://oai.glats.org/v1/models` after deploy | `linux/system/services/web/opencode-proxy.nix`, `linux/system/services/web/nginx.nix`, `hosts/rog/secrets.nix` |
| 2 | bootstrap seed publication and mact2 installer flow | PR 1 | `bash -n bin/install-opencode-auth-seed` | `bin/install-opencode-auth-seed --dry-run` | `bin/install-opencode-auth-seed`, rog-side uploads publisher, seed path wiring |
| 3 | mact2 custom provider tier and runtime config switch | PR 1 | `nix eval --raw .#darwinConfigurations.mact2.config.system.build.toplevel.drvPath` | inspect generated `~/.config/opencode/opencode.json` for `openai-proxy` | `shared/opencode/providers-base.nix`, `hosts/mact2/default.nix`, `shared/opencode.nix` |

## Phase 1: rog gateway foundation

- [x] 1.1 Create `linux/system/services/web/opencode-proxy.nix` for a loopback-only gateway with upstream key input, client key input, and a health endpoint.
- [x] 1.2 Add `opencode/openai_proxy_*` host secrets in `hosts/rog/secrets.nix` and shared sops declarations in `shared/sops.nix` for the client key boundary.
- [x] 1.3 Import the new module from `hosts/rog/default.nix` and extend `linux/system/services/web/nginx.nix` with `oai.glats.org` proxying only `/v1` while denying admin/UI paths.

## Phase 2: bootstrap seed flow

- [x] 2.1 Add a rog-side publisher flow that writes an encrypted `mact2` bootstrap seed under the existing `uploads/` tree and fails closed on plaintext auth material.
- [x] 2.2 Create `bin/install-opencode-auth-seed` to fetch the seed, verify/decrypt it, back up `~/.local/share/opencode/auth.json`, and merge only the seed payload.
- [x] 2.3 Wire any mact2-local secret/env inputs needed for the installer and keep the bootstrap artifact scoped to `mact2`.

## Phase 3: mact2 runtime provider switch

- [x] 3.1 Add `openai-proxy` to `shared/opencode/providers-base.nix` using `@ai-sdk/openai-compatible` and `https://oai.glats.org/v1` as a separate provider family.
- [x] 3.2 Add `openai-full-proxy`, `openai-medium-proxy`, and `openai-light-proxy` tiers in `shared/opencode/providers-base.nix` (separate family from `openai-full/medium/light`).
- [x] 3.3 Switch `hosts/mact2/default.nix` `home.opencode.activeProviderName` to one of the new `openai-*-proxy` tiers and update `shared/opencode.nix` for the new `OPENAI_PROXY_API_KEY` export.

## Phase 4: verification

- [x] 4.1 Run `format-nix` and review the resulting diff for only intended Nix edits.
- [x] 4.2 Run `nix flake check --no-build`.
- [x] 4.3 Run focused host builds for `rog` and `mact2`.
- [ ] 4.4 Smoke-test the generated OpenCode config and `oai.glats.org/v1` routing before apply.
