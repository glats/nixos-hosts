# Proposal: qwen3-opencode-type-validation

## Intent

The `opencode-go` and `opencode-go2` provider tiers are broken. All three Qwen 3.7 family models (`qwen3.7-plus`, `qwen3.7-max`, `qwen3.8-ultra`) emit content-block shapes the AI SDK rejects via the OpenCode Go endpoint (upstream `opencode#23960`, `#32418`, `#29754`). Replace these two tiers with **three** new working tiers built from models on the safe OpenAI-compatible transport, and expand the model catalogue to include all 8 working models plus the 3 zombie Qwen entries.

## Scope

### In Scope
- Expand `opencodeProvider` model catalogue: 3 entries → 11 (8 working + 3 zombie Qwen)
- Replace `opencode-go` tier → `opencode-go-full` (4 models: glm-5.2, deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- Replace `opencode-go2` tier → `opencode-go-medium` (3 models: deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- Add new `opencode-go-light` tier (3 models: deepseek-v4-pro, kimi-k2.6, deepseek-v4-flash)
- Update default `activeProviderName` from `"opencode-go"` → `"opencode-go-full"` in 4 locations
- Add upstream tracking comment block above zombie Qwen entries

### Out of Scope
- Fixing the upstream OpenCode SDK bug
- Bumping `pkgs/opencode` version
- Changing `home-linux/openfang.nix` model (separate work item)
- Host-specific overrides (t14 `omarchy.nix` — updated separately)

## Capabilities

### New Capabilities
- `opencode-provider-tiers`: Provider model catalogue and SDD phase-to-model tier routing for the `opencode-go` subscription. Covers model declarations, tier definitions, and default provider selection.

### Modified Capabilities
None — no existing spec covers this area.

## Approach

Single-file primary change in `shared/opencode/providers-base.nix`:
1. Add 8 model entries to `opencodeProvider.opencode.models` (glm-5.2, glm-5.1, kimi-k2.6, kimi-k2.7-code, deepseek-v4-pro, deepseek-v4-flash, mimo-v2.5, mimo-v2.5-pro)
2. Keep Qwen entries with a comment block citing upstream issues
3. Replace tier `opencode-go` → `opencode-go-full`
4. Replace tier `opencode-go2` → `opencode-go-medium`
5. Add new tier `opencode-go-light`
6. Update default parameter `activeProviderName ? "opencode-go-full"`

Secondary defaults updated in `shared/opencode.nix`, `shared/opencode-profile.nix`, `shared/opencode/providers.nix`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/providers-base.nix` | Modified | Model catalogue expansion + 3 tier definitions + default param |
| `shared/opencode.nix` | Modified | `activeProviderName` default → `"opencode-go-full"` |
| `shared/opencode-profile.nix` | Modified | `activeProviderName` mkDefault → `"opencode-go-full"` |
| `shared/opencode/providers.nix` | Modified | Default parameter → `"opencode-go-full"` |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Model quality regression vs Qwen 3.7 on reasoning phases | Medium | Qwen entries kept as zombies; one-line revert per phase when upstream fixes |
| t14 host still points to old `opencode-go` tier name | Low | t14 override in `omarchy.nix` needs update; caught by flake check |
| `nix flake check` fails on model name mismatch | Low | All model keys match phase value suffixes; verified against catalogue |

## Rollback Plan

Revert the single commit. The old `opencode-go` / `opencode-go2` tier names and Qwen model entries remain in git history. No secrets, hardware configs, or package versions are touched.

## Dependencies

- Upstream tracking: `opencode#23960`, `#32418`, `#29754`, `#33055`, `#33721` — when fixed, revert zombie Qwen assignments

## Success Criteria

- [ ] `nix flake check --no-build` passes for all 3 NixOS hosts (rog, thinkcentre, t14)
- [ ] `opencode-go-full` tier resolves all 12 phase model assignments without error
- [ ] `opencode-go-medium` tier resolves all 12 phase model assignments without error
- [ ] `opencode-go-light` tier resolves all 12 phase model assignments without error
- [ ] No `qwen3.7-*` model is assigned to any phase in any of the 3 new tiers
- [ ] Upstream tracking comment block is present above zombie Qwen entries
- [ ] `format-nix` produces no diff on changed files
