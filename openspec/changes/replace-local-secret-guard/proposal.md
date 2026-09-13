# Proposal: Replace Local Secret Guard

## Intent

Replace the broken local `secret-guard` plugin with the maintained community `opencode-warden@1.2.0` while retaining Nix permissions as the primary secret-access boundary.

## Scope

### In Scope
- Enable the exact Warden npm plugin for all shared OpenCode Home Manager profiles on rog, thinkcentre, t14, and mact2.
- Pin Warden's npm tarball in `pkgs/opencode-npm-packages` and deploy it from the Nix store.
- Remove the local guard option, runtime source, derivation, overlay exports, and plugin asset.
- Preserve `sops*`, `.env*`, and `/run/secrets/**` permission denies; configure Warden's default regex-only mode with prompt scanning and LLM features disabled.

### Out of Scope
- Changing OpenCode agent permissions or sops secret declarations.
- Enabling Warden prompt blocking, LLM safety features, or broad allowlists.
- Replacing unrelated managed or npm plugins.

## Capabilities

### New Capabilities
- `opencode-secret-protection`: Cross-platform, Nix-reproducible runtime secret redaction, shell-environment sanitization, and sensitive-path protection.

### Modified Capabilities
None.

## Approach

Declare `opencode-warden@1.2.0` in the shared npm plugin list and add its version and fixed tarball hash to the existing Nix package derivation. Remove the local managed plugin lifecycle completely. Keep permissions unchanged as authorization enforcement; Warden supplies defense-in-depth redaction and deterministic path checks. Verify startup and expected redaction, SOPS environment, and blocked-path behavior against OpenCode 1.18.22 on Linux and Darwin.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode-profile.nix` | Modified | Enable Warden for shared hosts. |
| `shared/opencode/plugins.nix` | Modified | Retire `secretGuard`; declare pinned npm plugin. |
| `shared/opencode/runtime-config.nix` | Modified | Remove local plugin deployment. |
| `pkgs/opencode-npm-packages/{versions,node-modules}.json` | Modified | Add exact version and tarball hash. |
| `pkgs/secret-guard-assets/`, `lib/packages.nix`, `overlays/{linux,darwin}.nix` | Removed/Modified | Retire local asset and exports. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Broad rules block valid workflows or redact shell credentials | Medium | Smoke-test workflows; add only documented narrow exclusions. |
| Unpublished 1.18.22 compatibility gap | Low | Test pinned runtime before rollout. |

## Rollback Plan

Revert the migration commit, restoring the local derivation and declarations; retain existing permission denies throughout.

## Dependencies

- `opencode-warden@1.2.0` npm tarball and its fixed Nix hash.

## Success Criteria

- [ ] All four shared hosts serialize and load the Nix-pinned Warden plugin without runtime npm resolution.
- [ ] The local `secret-guard` assets and references are absent.
- [ ] Existing permission denies remain intact and startup, redaction, SOPS environment, and blocked-path smoke tests pass.
