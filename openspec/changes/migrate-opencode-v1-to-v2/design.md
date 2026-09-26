# Design: Parallel Isolated OpenCode V2 Runtime

## Technical Approach

Keep V1 (`opencode`, 1.18.32) unchanged and deliver native V2 as `opencode2` with its own config and state roots. V2's shared server becomes an OS-supervised user process: a Home Manager systemd user service on rog, thinkcentre, and t14, and a Home Manager launchd agent on macm5. `mkV2Environment` remains the single source of all V2 isolation exports for the interactive wrappers and both supervisors. Activation restarts the applicable supervisor only after the generated V2 `opencode.json` changed.

## Architecture Decisions

| Decision | Choice | Rejected / rationale |
|---|---|---|
| Distribution and runtime generation | Retain the pinned native `opencode-v2` package and dual V1/V2 records in `shared/opencode.nix` and `shared/opencode/runtime-config.nix`; V2 emits only its native global config. | Reusing V1 plugins, commands, skills, or npm tree would run V1 SDK code in V2; changing V1 violates the fallback contract. |
| Environment contract | Represent `mkV2Environment` so it can render shell exports for `opencode2`/`opencode2-project` and environment attributes for service declarations. It includes all XDG roots, `OPENCODE_CONFIG_DIR`, `OPENCODE_DB`, `TMPDIR`, and default `OPENCODE_DISABLE_PROJECT_CONFIG=1`. | Duplicated wrapper, systemd, launchd, and activation environments can drift into V1 paths. |
| Linux supervision | Declare `systemd.user.services.opencode2` in the shared HM module for Linux. It starts the V2 server in foreground mode with the rendered `mkV2Environment`, restarts on failure, and is enabled for the user session. | Invoking the native background-service command from activation leaves the process outside systemd supervision. |
| macOS supervision | Declare a `launchd.agents.opencode2` job on macm5 with the same V2 executable, environment attributes, run-at-load, and keep-alive recovery. | A nix-darwin system daemon would use the wrong user home/session; an unsupervised background server cannot recover after failure. |
| Activation lifecycle | Keep the V2 config stamp and `cmp` guard after `makeOpencodeConfigMutable-v2`. On a difference, restart the platform supervisor; on identical content, do nothing. Stamp only after a successful restart. | Unconditional activation restart disrupts active sessions; activation must not serve as a recovery loop. Supervisor restart policy handles crashes. |
| Project and auth gates | Keep default project-config disablement, V1-SDK refusal in `opencode2-project`, and one-way `--v2` auth seeding. | Automatic V1 credential/config migration or a global V2 `AGENTS.md` crosses the isolation boundary. |

## Data Flow

```
mkV2Environment ──> zsh wrappers ────────────────> V2 client/server
       │                                                │
       ├──> systemd.user opencode2 (Linux) ─────────────┤
       └──> launchd agent opencode2 (macm5) ────────────┘
HM V2 config ──> cmp/stamp ──changed only──> platform supervisor restart
opencode (V1) ──> existing V1 paths and process, untouched
```

The supervisor owns crash recovery. The activation hook only performs the config-change restart and must expose a failed restart without falling back to V1 or copying a success stamp.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/opencode.nix` | Modify | Render `mkV2Environment` for shell, systemd, and launchd; declare Linux and macOS V2 user supervisors; restart the correct supervisor behind the existing config comparison. |
| `shared/shell-aliases.nix` | Modify | Keep both wrappers consuming the shell rendering of `mkV2Environment`. |
| `shared/opencode/runtime-config.nix` | Verify / modify if needed | Preserve isolated V2 config emission and the activation DAG dependency. |
| Existing V2 package, overlays, and host package lists | No change | Package delivery is already cross-platform and does not need a second launcher. |

## Interfaces / Contracts

`home.opencode.v2` retains `enable`, `runtimeRoot`, and `projectConfigCommand`. `mkV2Environment` is the authoritative V2 environment interface; every launcher and supervisor must derive from it. The Linux job is named `opencode2`; the macOS agent is named `opencode2`, so discovery is `systemctl --user status opencode2` or `launchctl list`. V1 receives none of the V2 variables.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| Nix evaluation | Linux systemd and Darwin launchd declarations, rendered environment, V1 bytes | `nix flake check --no-build`; evaluate all host targets, including macm5 natively. |
| Declarative RED checks | One environment source, foreground V2 server, Linux restart policy, launchd keep-alive, changed-only platform restart | Assert generated service/agent definitions and activation text before production changes. |
| Smoke | Service discovery, recovery, isolation, and no-op activation | On Linux inspect `systemctl --user`; on macm5 inspect `launchctl`; crash/stop then verify supervisor recovery; compare unchanged versus changed config activation. |

## Threat Matrix

| Boundary | Applicability | Safe / failure behavior | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A: no executable classifier. | — | — |
| Git repository selection | N/A: wrappers preserve caller cwd and do not invoke Git. | — | — |
| Commit state | N/A: no commit command. | — | — |
| Push state | N/A: no push command. | — | — |
| PR commands | N/A: no PR command. | — | — |
| Shell/process integration | Applicable: wrappers, activation subprocesses, systemd, and launchd execute V2. | Every process receives only `mkV2Environment`; supervisor failures remain visible and never fall back to V1. | Assert V2 exports and argument forwarding; no `--standalone`; Linux/launchd foreground declarations and recovery; changed-only restart; V1-SDK refusal. |

## Migration / Rollout

Switch V2 on all four hosts while V1 remains the default. The first activation may restart the enabled V2 supervisor because the config stamp is absent; later identical activations do nothing. Roll back through a prior generation or remove V2 paths/package; delete only the V2 database to reset V2 credentials. No V1 mutation is required.

## Open Questions

None.
