# Proposal: Warden Opt-In (Default-Off)

## Intent

Warden's redaction and deterministic path protection currently load by default on every OpenCode host because `shared/opencode/plugins.nix` hardcodes `opencode-warden@1.2.0` into `npmPlugins`. Keep Warden packaged for offline opt-in, but disable it by default behind a Home Manager option; Nix `permissions` remains the primary authorization boundary.

## Scope

### In Scope
- Add `home.opencode.plugins.warden.enable` (default `false`) in `shared/opencode/plugins.nix`.
- Derive `npmPlugins` from the flag so `opencode-warden@1.2.0` enters the V1 `plugin` array only when enabled.
- Gate the `opencode-warden.json` write in `shared/opencode.nix` on the flag (no stale config when disabled).
- Keep Warden pinned in `pkgs/opencode-npm-packages` for offline opt-in resolution.

### Out of Scope
- V2 changes (already Warden-free).
- Removing Warden's package from the Nix store / npm closure.
- Touching other plugins or the managed `activePlugins` attrset.
- Host overrides of `npmPlugins` (none exist).

## Capabilities

### New Capabilities
- `opencode-warden-opt-in`: Warden is packaged for offline opt-in but disabled by default via `home.opencode.plugins.warden.enable`; enabling it adds it to the V1 plugin array and writes its config; all other OpenCode plugins stay unaffected; V2 remains Warden-free.

### Modified Capabilities
- None

## Approach

Approach 1 (exploration recommendation). Add `warden.enable = mkEnableOption` under `options.home.opencode.plugins`; remove the static `opencode-warden@1.2.0` from the `npmPlugins` default and compute it as `mkDefault (base ++ lib.optional cfg.plugins.warden.enable "opencode-warden@1.2.0")`. Gate the `opencode-warden.json` write on `warden.enable`. `runtime-config.nix` stays untouched (V1 `plugin = cfg.plugins.npmPlugins` remains truthful). Do not add Warden to `activePlugins` (reserved for managed `.ts` plugins).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/opencode/plugins.nix` | Modified | Remove Warden from default; add `warden.enable`; derive list |
| `shared/opencode.nix` | Modified | Gate `opencode-warden.json` write on flag |
| `shared/opencode/runtime-config.nix` | None | V1/V2 serialization unchanged |
| `pkgs/opencode-npm-packages/{versions,node-modules}.json` | None | Pin stays for offline resolution |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Silent removal of default redaction on all hosts | High | Deliberate posture change; Nix `permissions` remains the boundary |
| Stale `opencode-warden.json` when disabled | Med | Gate write on `warden.enable` |
| `mkDefault` shadowed by a future host override | Low | Verified no host overrides `npmPlugins` today |
| Divergence with unarchived `opencode-secret-protection` spec | Med | Flag for archive reconciliation |

## Rollback Plan

Revert the commit: the prior default (Warden in `npmPlugins`, unconditional config write) is restored. No schema or data migration to unwind.

## Dependencies

- `replace-local-secret-guard` (still active/unarchived): its `opencode-secret-protection` spec mandates default-on Warden; this change supersedes those requirements and archive must reconcile them.

## Success Criteria

- [ ] `nix flake check --no-build` passes; all four hosts' activation packages evaluate.
- [ ] Generated V1 `opencode.json` omits `opencode-warden@1.2.0` by default and includes it when `warden.enable = true`.
- [ ] Generated V2 `opencode.json` is unchanged.
- [ ] `opencode-warden.json` is written only when enabled.