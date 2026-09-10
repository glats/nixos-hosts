# Proposal: Prune Declared Built-in Providers

## Intent

Remove redundant OpenCode built-in provider overrides and unreachable configuration. OpenCode merges configured providers over its models.dev catalog; A/B evaluation proves all 22 routing profiles remain structurally identical and all 29 referenced built-in model IDs resolve. This is configuration hygiene, not a routing change.

## Scope

### In Scope
- Reduce `opencodeProvider` to its live one-hour `timeout` and `chunkTimeout` options; remove its dead model pins and unsupported `thinking` fields.
- Remove the redundant Anthropic and GitHub Copilot blocks, then set `allProviders = nvidiaProvider // opencodeProvider`.
- Delete dead `providers-extra.nix` and remove `extraProviders` threading.
- Preserve all 22 profiles byte-identically; keep NVIDIA and secrets/env exports unchanged.

### Out of Scope
- Profile deletion, rename, phase remapping, or per-host `activeProviderName` changes.
- Host files, SOPS configuration/secrets, and stale `AGENTS.md` wording.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None; observable routing and timeout behavior remain unchanged.

## Approach

Use exploration Approach B: retain only custom NVIDIA configuration and OpenCode's live timeout override. Built-in model discovery remains catalog-driven. Do not change the existing declarative-runtime spec: its `providers-base.nix` reference does not describe the deleted blocks.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/providers-base.nix` | Modified | About 905→633 lines: replace the 154-line OpenCode block with 8 option-only lines and remove 124 provider-block lines plus surrounding whitespace. |
| `shared/opencode/providers-extra.nix` | Removed | Delete all 438 unreachable lines. |
| `shared/opencode/providers.nix` | Modified | About 19→12 lines: remove the 7-line optional extras branch and return the base import directly. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Free Zen requests regress to five-minute timeouts | Low | Preserve both 3,600,000 ms options and inspect generated provider config. |
| Copilot plan/API hides an assigned model | Existing | Catalog proves startup validity; account-level `/models` pruning is independent of static declarations. |
| Future catalog drift breaks a profile | Low | Re-run the 29-model catalog check; NVIDIA remains explicitly declared. |
| Hidden `extraProviders` consumer exists | Low | Grep the repository before deletion and after implementation. |

## Rollback Plan

Revert the three-file change to restore the static overrides and extras export; no data or secret migration is involved.

## Dependencies

- OpenCode's models.dev catalog and native authentication flows.

## Success Criteria

- [ ] The A/B Nix eval reports 22 byte-identical profile structures and unchanged phase mappings.
- [ ] Catalog cross-check reports 29/29 built-in model IDs present and zero missing; NVIDIA remains exempt and declared.
- [ ] No removed key or `extraProviders` consumer remains.
- [ ] `format-nix && nix flake check --no-build` passes.
- [ ] `nix build .#nixosConfigurations.t14.config.system.build.toplevel` succeeds without switching.
