# Design: Parallel Isolated OpenCode V2 Runtime

## Technical Approach

Keep `opencode` and its V1 tree unchanged at 1.18.32. First package/delivery deletes stale Docker `opencode2` before native V2 delivery: the shared command makes removal a prerequisite, not a later isolation task. Native V2 uses `$HOME/.config/opencode-v2` and `$HOME/.local/opencode-v2/{data,cache,state,tmp}`. One Nix function derives launcher/restart exports. V2 uses its native shared server, never `--standalone` or a managed daemon.

## Architecture Decisions

| Decision | Choice | Rejected / rationale |
|---|---|---|
| Distribution and delivery | First remove `pkgs/nixos-scripts/cmd/opencode2/` and its `default.nix` entry, then deliver `pkgs/opencode-v2/default.nix`: fixed-hash `@opencode/cli-<os>-<arch>@2.0.14`, Linux `autoPatchelfHook`, and `makeBinaryWrapper`; installs native `opencode2` only. | Deferral leaves two `opencode2` providers and blocks autonomous delivery. The npm meta-package runs postinstall; GitHub/standalone artifacts are not V2 distribution. Mirror V1 without changing it. |
| Runtime | Extend `shared/opencode.nix` and `shared/opencode/runtime-config.nix` with `v1`/`v2` runtime records. Preserve V1 byte-for-byte; V2 writes only native global configuration (`update = "disable"`) and no V1 plugins, npm tree, `tui.json`, commands, or skills. | Translating V1 config/plugins is deferred; sharing them would execute V1 SDK code in V2. |
| Isolation and lifecycle | `mkV2Environment` derives `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`, `OPENCODE_CONFIG_DIR`, `OPENCODE_DB`, and `TMPDIR` below `$HOME/.local/opencode-v2`, except config at `$HOME/.config/opencode-v2`. `opencode2` exports these plus `OPENCODE_DISABLE_PROJECT_CONFIG=1` and execs `${pkgs.opencode-v2}/bin/opencode2`. | Inherited XDG values and `--standalone` risk V1 state or multiple SQLite owners. A V2 activation stamp/cmp guard runs `opencode2 service restart` with the same exports only when V2 `opencode.json` content changes. |
| Project and auth gates | `opencode2-project` is the sole opt-in wrapper: it removes the disable flag and refuses `$PWD/.opencode/package.json` with `@opencode-ai/plugin`. Default V2 never reads project config or `AGENTS.md`. `install-opencode-auth-seed --v2` copies V1 `auth.json` read-only to a 0600 V2 migration input; V2 owns SQLite credentials. | No automatic migration or global V2 `AGENTS.md`; V1 auth never changes. |

## Data Flow

```
HM runtime record -> V2 config/stamp -> activation cmp -> env opencode2 service restart
                         ^                         |
zsh opencode2 -> same mkV2Environment -> V2 shared server/state/db
opencode (V1) -> existing PATH/config/data, untouched
```

The hook runs after V2 mutable-config activation, stamps only compared/copied content, and reports restart failure without V1 fallback or V1 writes. The launcher preserves cwd and arguments. Same-folder V1/V2 have separate global state; project edits and Git contention remain normal user concurrency, documented but not locked.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/opencode-v2/default.nix` | Create | Pinned V2 platform derivation. |
| `lib/packages.nix`, `overlays/{linux,darwin}.nix` | Modify | Expose `opencode-v2` on Linux and Darwin. |
| `linux/system/base/profiles/dev.nix`, `darwin/home/packages.nix` | Modify | Deliver V2 alongside V1 to all four hosts. |
| `shared/opencode.nix`, `shared/opencode/runtime-config.nix`, `shared/shell-aliases.nix` | Modify | Dual generator, environment function, wrappers, and cmp-guarded HM hook. |
| `pkgs/nixos-scripts/cmd/opencode2/` | Delete | First package/delivery prerequisite: remove the stale Docker launcher. |
| `pkgs/nixos-scripts/default.nix`, `pkgs/nixos-scripts/cmd/install-opencode-auth-seed/{main.go,main_test.go}` | Modify | First remove the launcher subpackage; later add V2's 0600 one-way seed target/tests. |

## Interfaces / Contracts

`home.opencode.v2` has `enable`, `runtimeRoot`, and `projectConfigCommand`, defaulting from `config.home.homeDirectory`. `mkV2Environment` solely produces launch/hook exports. `opencode2-project` returns nonzero before exec for a V1 SDK marker. `--v2` changes only the seed destination.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Nix evaluation | Pins, exports, host delivery, V1 bytes | `nix flake check --no-build`; evaluate four HM/NixOS/Darwin targets and compare V1 generated baseline. |
| Go | V2 seed destination/mode and V1 immutability | Add table tests before seed changes; run `go -C pkgs/nixos-scripts test ./...`. |
| Smoke | V1/V2 same-folder isolation | Per-host fresh-root test: versions, DB/server/config separation, no V1 writes, project gate/refusal, changed-only restart. |

## Threat Matrix

| Boundary | Applicability | Safe / failure behavior | RED test |
|---|---|---|---|
| Documentation-like paths | N/A: no executable classifier. | — | — |
| Git repository selection | N/A: wrappers do not select repositories or invoke Git. | Preserve caller cwd; Git remains user/tool behavior. | — |
| Commit state | N/A: no commit command. | Git `index.lock` remains clean failure during concurrent use. | — |
| Push state | N/A: no push command. | — | — |
| PR commands | N/A: no PR command. | — | — |
| Shell/process integration | Applicable: zsh wrapper, activation subprocess, shared server. | Correct env/args target only V2; restart failure is visible and cannot mutate/fallback to V1. | Assert all exports/argument forwarding, no `--standalone`, changed-only restart, and nonzero V1-SDK refusal. |

## Migration / Rollout

Ship to rog, thinkcentre, t14, and macm5 with V1 default. Users opt into clean `opencode2`; optionally seed once for proxy OAuth. Roll back by a prior generation or removing V2 paths/package; delete only the V2 DB to reset V2 credentials. No systemd/launchd unit, daily standalone mode, or V1 mutation is introduced.

## Open Questions

None.
