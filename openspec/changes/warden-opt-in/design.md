# Design: Warden Opt-In (Default-Off)

## Technical Approach

Add a default-false `home.opencode.plugins.warden.enable` option in the existing Home Manager plugin module. Keep the V1 runtime serializer unchanged: it already serializes `cfg.plugins.npmPlugins`. Instead, compute that list in `plugins.nix` from the flag, and conditionally manage Warden's V1 JSON file in `shared/opencode.nix`. This implements the proposal without changing V2 or the offline npm package closure.

## Architecture Decisions

| Decision | Options and tradeoff | Choice and rationale |
|---|---|---|
| Warden control point | Append in `runtime-config.nix` splits membership from plugin declarations; derive in `plugins.nix` moves the default but centralizes membership. | Derive `npmPlugins` in `plugins.nix` with `mkDefault (basePlugins ++ lib.optional cfg.plugins.warden.enable "opencode-warden@1.2.0")`. The existing V1 serializer remains the sole emitter and option overrides retain normal precedence. |
| Plugin representation | Add Warden to `activePlugins`, or keep it as an npm plugin. | Keep it out of `activePlugins`; that attrset represents managed `.ts` plugins, while Warden is an npm plugin. |
| Offline availability | Remove Warden's pin, or retain it unused by default. | Retain `opencode-warden` version and hash pins. The package stays resolvable offline when the option is enabled. |
| V2 scope | Share the new flag with V2, or preserve its drop set. | Preserve V2 unchanged. Its JSON does not contain the V1 plugin array and its activation explicitly removes a stale V1 Warden plugin copy. |

## Data Flow

```
home.opencode.plugins.warden.enable (false by default)
  ├─ false → base npmPlugins → V1 opencode.json has no Warden → no Warden JSON file
  └─ true  → base + opencode-warden@1.2.0 → V1 opencode.json → Warden JSON file

pkgs/opencode-npm-packages (unchanged pin) ──→ offline package availability
V2 runtime ──→ unchanged JSON and activation drop set
```

Home Manager owns the conditional file entry. On a later disabled generation it removes the formerly managed `~/.config/opencode/opencode-warden.json`; activation verification must prove that transition rather than only inspecting the declaration.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode/plugins.nix` | Modify | Declare `warden.enable` with `mkEnableOption`; replace the literal Warden list member with a `mkDefault` derived from the flag and the two existing base npm plugins. |
| `shared/opencode.nix` | Modify | Include the V1 `opencode-warden.json` managed file only when the same flag is enabled. |
| `shared/opencode/runtime-config.nix` | Unchanged | Continue serializing `cfg.plugins.npmPlugins` for V1; leave V2 serialization and drop set intact. |
| `pkgs/opencode-npm-packages/{versions,node-modules}.json` | Unchanged | Retain the `opencode-warden` 1.2.0 offline pin and fixed-output hash. |

## Interfaces / Contracts

```nix
home.opencode.plugins.warden.enable = lib.mkEnableOption "the opencode-warden npm plugin";
```

The option defaults to `false`. When false, the effective default `npmPlugins` list contains only `opencode-claude-auth@latest` and `opencode-multimodal@latest`; when true, it additionally contains exactly `opencode-warden@1.2.0`. Explicit consumer overrides of `npmPlugins` retain higher priority than this default. The conditional JSON contains the existing `audit.filePath` only in the enabled case.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Evaluation | Default behavior on `rog`, `thinkcentre`, `t14`, and `macm5` | Evaluate each Home Manager activation package and inspect evaluated V1 JSON: Warden is absent from `plugin` and its managed JSON file is absent. |
| Evaluation | Opt-in behavior | Extend one existing Home Manager configuration in a one-off Nix evaluation with `warden.enable = true`; assert the V1 JSON contains Warden once and the managed Warden JSON entry has the existing audit path. |
| Regression | V2 and offline package contract | Compare the evaluated V2 JSON before/after (no Warden change), confirm its V1 drop-set remains, and assert both Warden pin entries remain unchanged. |
| Integration | Declarative generation | Run `nix flake check --no-build`; evaluate all four host-scoped activation targets. Apply an enabled generation then a disabled generation in a disposable Home Manager test environment and assert the Warden JSON file is removed. |

No persistent test harness is added: this two-module option change is covered by evaluation and generation checks, preserving the smallest implementation.

## Threat Matrix

N/A — this is declarative Home Manager option, list, and JSON-file generation only. It adds no routing, shell command, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No data migration is required. Existing hosts move to default-off at their next Home Manager activation. Hosts that require Warden set `home.opencode.plugins.warden.enable = true`; rollback is a commit revert or restoring that prior default. Archive reconciliation must supersede the active `opencode-secret-protection` requirement that still describes Warden as default-on.

## Open Questions

- [ ] Should a later change add an explicit host-level opt-in after the default-off rollout? This change intentionally adds none.
