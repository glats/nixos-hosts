# Design: OpenCode V2 Scoped Home Launcher Parity

## Technical Approach

Extend the packaged Go launcher, not the network stack. Implement the delta's conditional client environment, executable identity, isolation, argument, and MCP contracts. Keep V1 default behavior and ordinary V2 unchanged. Provider parity uses an explicitly requested private V2 server; client environment alone cannot reconfigure an existing shared server.

## Architecture Decisions

| Option | Tradeoff | Decision and rationale |
|---|---|---|
| Reuse `opencode-home` with a scoped executable override | One internal environment input | Choose `OPENCODE_HOME_BINARY`; default remains PATH-resolved `opencode`. Avoid parsing user flags or adding another operational binary. |
| Go TCP probe versus external `nc` | Removes PATH/platform dependency | Choose `net.DialTimeout("tcp", "127.0.0.1:2080", time.Second)`; close successful connections. Failure/timeout prints stderr and adds no proxies. |
| Guarded Home Manager shell function versus Go shell-environment parser | Existing environment file is shell syntax | Choose macm5's `opencode2-home()` subshell: guarded source, scoped override, exec absolute packaged launcher. No shell operational executable or duplicated isolation values. |
| Caller-selected standalone versus automatic flags/service changes | Small command-aware shell dispatch | Choose private V2 server by default for interactive TUI/mini (`--standalone` before top-level args) and `run` (`run --standalone ...`). Preserve user argument order, leave unrelated commands and explicit server selection alone, and never restart/reconfigure the shared service. |
| Preserve MCP generation versus new scrub logic | Existing shared transformation already applies to V1/V2 | Preserve `runtime-config.nix` and `v2-mcps.nix`; add regression proof only. |

## Data Flow

```text
macm5 zsh subshell -> guarded V2 environment source
 -> command-aware standalone default (TUI/mini or run position)
 -> packaged Go launcher -> bounded loopback probe
 -> packaged opencode2, forwarded user argv, conditional proxy env
 -> private V2 server by default -> providers
                                        -> local MCP scrub
```

The home alias starts a private server for TUI, `mini`, and `run` unless the caller supplies `--server` or `--standalone`. Other subcommands are passed through without injected flags. Ordinary V2 commands outside the alias are unchanged.

## File Changes

| File | Action | Description |
|---|---|---|
| `pkgs/nixos-scripts/cmd/opencode-home/main.go` | Modify | Thin entry point calling launcher logic. |
| `pkgs/nixos-scripts/internal/opencodehome/launcher.go` | Create | Target selection, probe, child environment, syscall exec. |
| `pkgs/nixos-scripts/internal/opencodehome/launcher_test.go` | Create | Focused unit/subprocess regressions. |
| `shared/shell-aliases.nix` | Modify | Add Darwin/V2-gated `opencode2-home`; preserve existing functions. |
| `shared/opencode/home-launcher.test.py` | Create | Generated shell/MCP regression using repository Python-test pattern. |
| `docs/home-link.md` | Modify | V1/V2 commands, standalone ownership, fallback and proof limits. |

`pkgs/nixos-scripts/default.nix` already builds/tests the launcher; no registration or dependency change.

## Interfaces / Contracts

`OPENCODE_HOME_BINARY`, when present, must be nonempty and absolute; invalid targets fail visibly, never fall back. Strip this private control variable before exec. Default V1 keeps `argv[0]=opencode`; explicit target uses its basename. User arguments remain byte-for-byte ordered, including empty strings.

Source failure returns nonzero before launch. Exec failures retain diagnostic/127 behavior. Build child environment without changing parent state. On successful V2 probing, append loopback exclusions `localhost,127.0.0.1,::1` to existing `NO_PROXY`; do not override caller exclusions or alter V1. Failure adds neither HTTP nor HTTPS proxy; inherited proxies are not sanitized (the fallback scenario assumes a proxy-clean parent).

Nix interface: reuse `programs.zsh.initContent`, `home.opencode.v2.enable`, `home.homeDirectory`, and existing package attributes. No new options, services, activation changes, or breaking option migration.

## Testing Strategy

| Layer | Proof |
|---|---|
| Go RED/unit | Listener success/refusal/injected timeout, one-second dial bound, notice, conditional env, NO_PROXY, invalid target, unchanged V1. |
| Offline integration | Recorder executable captures argv/env; competing PATH names cannot win; guarded source/missing binary fail; parent and all isolation fields match ordinary V2. |
| Generated configuration | Both versions enforce local proxy scrub over conflicting values, preserve unrelated values, and leave remote definitions unchanged. |
| Evaluation | Go suite; touched Nix formatting; shared no-build flake check; macm5 Darwin/Home Manager and Linux Home Manager evaluations. |

## Threat Matrix

| Boundary | Applicability / reason |
|---|---|
| Documentation-like paths | N/A: no file classification or content execution. |
| Git repository selection | N/A: no Git invocation or repository selection. |
| Commit state | N/A: no index/commit operations. |
| Push state | N/A: no push operations. |
| PR commands | N/A: no PR composition. |

Applicable process risks—target substitution, shell argument splitting, missing isolation, proxy leakage, shared-server ownership—are covered by the contracts and RED checks above.

## Migration / Rollout

No migration required. Verification only: no activation, deployment, service mutation, provider calls, or commits. Revert only these changes; preserve unrelated dirty edits and runtime data.

## Open Questions

Later macm5 inspection must verify actual standalone provider egress and MCP child environments; offline tests cannot establish tunnel health. Official [network](https://opencode.ai/v2/docs/network/) and [command](https://opencode.ai/v2/docs/cli/commands/) documentation establish server ownership; installed 2.0.14 help confirms `--standalone`. No task-blocking question remains.
