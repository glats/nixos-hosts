# Exploration: warden-opt-in

## Exploration: warden-opt-in

### Current State

OpenCode's runtime configuration is generated declaratively by Home Manager. `shared/opencode/plugins.nix` declares `home.opencode.plugins.npmPlugins` as a `types.listOf types.str` option whose hardcoded default is:

```nix
[ "opencode-claude-auth@latest" "opencode-multimodal@latest" "opencode-warden@1.2.0" ]
```

`shared/opencode/runtime-config.nix` serializes that list verbatim into the V1 `opencode.json` `plugin` array (`plugin = cfg.plugins.npmPlugins;`, line 152), so `opencode-warden@1.2.0` is globally loaded on every host that enables OpenCode. Separately, `shared/opencode.nix` (lines 211–213) writes `~/.config/opencode/opencode-warden.json` unconditionally under `home.opencode.enable`, setting only `audit.filePath`. Warden's npm tarball and dependency closure remain pinned in `pkgs/opencode-npm-packages/{versions,node-modules}.json`.

Per-plugin managed plugins (model-variants, opencode-review-transport, sdd-task-result-artifacts, skill-registry, engram, rtk) are toggled via `mkEnableOption` flags under `home.opencode.plugins.*` and materialized in the computed `activePlugins` attrset. `npmPlugins` is a separate mechanism — a raw string list that does not flow through `activePlugins`.

V2 is already unaffected: `opencode-warden` was dropped as V1-only during the V2 migration (`runtime-config.nix` line 276 removes `opencode-warden.ts` in the V2 drop set, and it is never emitted in the V2 `opencode.json`). No host (`rog`, `thinkcentre`, `t14`, `macm5`) overrides `npmPlugins` or references a warden toggle today.

### Affected Areas

- `shared/opencode/plugins.nix` — remove `opencode-warden@1.2.0` from the `npmPlugins` default; add a `warden.enable` opt-in flag and make the flag control `npmPlugins` membership.
- `shared/opencode.nix` — gate the unconditional `opencode-warden.json` file write (lines 211–213) on the new toggle so a disabled Warden leaves no stale config.
- `pkgs/opencode-npm-packages/{versions,node-modules}.json` — NO change. Keep Warden pinned so the opt-in path resolves offline from the Nix store.
- `shared/opencode/runtime-config.nix` — no change under the recommended approach (V1 `plugin = cfg.plugins.npmPlugins` stays truthful). V2 is untouched.

### Approaches

1. **Compute `npmPlugins` in `plugins.nix` (recommended)** — Add `warden.enable = mkEnableOption "..."` under `options.home.opencode.plugins`. Remove the static `opencode-warden@1.2.0` from the `npmPlugins` default and move the default into a `config.home.opencode.plugins.npmPlugins = mkDefault (base ++ lib.optional cfg.plugins.warden.enable "opencode-warden@1.2.0")` merge. Gate the `opencode-warden.json` write in `shared/opencode.nix` on `warden.enable`.
   - Pros: single source of truth for plugin membership stays in the plugin manifest; `runtime-config.nix` (the most complex file) is untouched; `mkDefault` preserves user-override precedence; mirrors the existing computed-`activePlugins` pattern.
   - Cons: default moves from option declaration into a config block (slightly more indirection).
   - Effort: Low

2. **Conditional append at the serialization site** — Keep `npmPlugins` default as `[ claude-auth, multimodal ]`, add `warden.enable`, and change `runtime-config.nix` line 152 to `plugin = cfg.plugins.npmPlugins ++ lib.optional cfg.plugins.warden.enable "opencode-warden@1.2.0";`; gate the json write.
   - Pros: explicit at the emit point; option default stays a simple literal list.
   - Cons: warden membership logic is split across `plugins.nix` and `runtime-config.nix`; touches the critical runtime file.
   - Effort: Low

### Recommendation

Approach 1. Add a `warden.enable` boolean option (default `false`) to `home.opencode.plugins` and derive the `npmPlugins` list from it with `lib.mkDefault`, so the plugin manifest remains the single place that decides which npm plugins load. Keep `opencode-warden@1.2.0` pinned in `pkgs/opencode-npm-packages` (it stays in `node_modules` for offline opt-in resolution but no longer appears in the generated `plugin` array by default). Gate the `opencode-warden.json` write on the same flag. Do not add warden to `activePlugins` — that attrset is reserved for managed `.ts` plugins; warden is an npm plugin. V2 requires no change.

### Risks

- Default-off silently removes Warden's defense-in-depth redaction and deterministic path protection from all hosts; Nix `permissions` remains the primary authorization boundary (per the `replace-local-secret-guard` decision), so this is a deliberate posture change that must be confirmed as intended.
- If `opencode-warden.json` is not gated, a disabled Warden leaves a stale/meaningless config file (and Warden treats that path as sensitive).
- The V1 npm closure still ships Warden's package files to `node_modules`; harmless, but if the goal is also to stop shipping it, removing the pin from `versions/node-modules.json` would break the opt-in path — the two goals conflict, so the pin stays.
- `mkDefault` must not be shadowed by a future host override of `npmPlugins`; no host overrides it today (verified).

### Ready for Proposal

Yes — propose a cross-platform Home Manager change that adds `home.opencode.plugins.warden.enable` (default `false`), derives `npmPlugins` from it, gates the `opencode-warden.json` write, and leaves the Nix-pinned Warden package available for opt-in. Verification: evaluate activation packages for all four hosts, run `nix flake check --no-build`, and assert the generated `opencode.json` omits `opencode-warden@1.2.0` by default and includes it when the flag is set, with no V2 diff.
