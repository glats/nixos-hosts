# Design: Harness Token Efficiency

## Technical Approach

Add nixpkgs RTK 0.41.0 to the existing cross-platform package surface, install it through the shared OpenCode Home Manager module, and deploy upstream RTK integrations through the repository's managed configuration paths. All four hosts import the shared OpenCode and Claude profiles. Rewrites remain runtime-only; local SQLite data supplies pilot evidence.

## Architecture Decisions

| Decision | Choice and rationale | Rejected alternative |
|---|---|---|
| Package exposure | Add `rtk = pkgs.rtk` to `commonPackages` in `lib/packages.nix`, exposing `packages.{x86_64-linux,x86_64-darwin}.rtk`; install `pkgs.rtk` in `shared/opencode.nix`. Both resolve from pinned nixos-26.05. Do not re-export RTK through overlays: it is already a native nixpkgs attribute, and round-tripping it through `self.packages` risks recursion. | New flake input or custom derivation. |
| Privacy environment | Set `home.sessionVariables.RTK_TELEMETRY_DISABLED = "1"` in the shared enabled OpenCode configuration so login-launched OpenCode, its plugin subprocess, Claude Code, and its hook inherit one cross-platform value. RTK 0.41.0 `src/core/telemetry.rs` checks exactly value `1` before any ping; `src/core/tracking.rs` writes local gain independently. | systemd-only environment, which excludes Darwin, or disabling tracking. |
| OpenCode plugin | Vendor byte-reviewed [`hooks/opencode/rtk.ts`](https://github.com/rtk-ai/rtk/blob/v0.41.0/hooks/opencode/rtk.ts) as `shared/opencode/rtk.ts`; add `plugins.rtk.enable`, `rtk.ts` to `managedPlugins`, and enable it in `shared/opencode-profile.nix` (the profile is at the shared root, not under `shared/opencode/`). Activation copies it into `~/.config/opencode/plugins/`. OpenCode 1.18.18 auto-loads that global directory; no config-array entry is needed. | Fetching mutable content during activation or registering the local file as an npm plugin. |
| Fail-open lifecycle | Missing RTK returns `{}`; rewrite errors leave `args.command` unchanged. OpenCode 1.18.18 also catches external-plugin load/initialization errors and continues startup. Unsupported commands and `RTK_DISABLED=1` produce no rewrite. | Blocking startup or command execution on interception errors. |
| Claude hook merge | Add `home.claude-code.hooks.preToolUse` (list, default `[]`) and serialize existing declarative entries followed by one canonical RTK entry, de-duplicated by matcher plus command. The generated file remains authoritative, matching current behavior; ad-hoc edits to `~/.claude/settings.json` lose to Home Manager, while Nix-defined hooks survive. | Runtime mutation of an otherwise declarative managed file. |

## Data Flow

    Bash tool input -> RTK hook/plugin -> rtk rewrite -> rewritten or original command
                                             |
                                             -> local tracking.db -> rtk gain

Claude JSON shape:

```json
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"rtk hook claude","timeout":5}]}]}}
```

Built-in Read, Grep, and Glob never match `Bash`.

## File Changes

| File | Action | Description |
|---|---|---|
| `lib/packages.nix` | Modify | Expose RTK for Linux and Darwin. |
| `shared/opencode.nix` | Modify | Install RTK and export telemetry opt-out. |
| `shared/opencode/plugins.nix` | Modify | Declare managed RTK plugin option. |
| `shared/opencode/runtime-config.nix` | Modify | Copy/remove `rtk.ts` with existing lifecycle. |
| `shared/opencode-profile.nix` | Modify | Enable RTK plugin globally. |
| `shared/opencode/rtk.ts` | Create | Vendor upstream v0.41.0 plugin. |
| `shared/claude-code.nix` | Modify | Merge Bash-only hook. |
| `docs/rtk-pilot.md` | Create | Pilot runbook. |

## Testing Strategy

Verify exposure with `nix eval --raw .#nixosConfigurations.rog.pkgs.rtk.version`, equivalent evaluations for thinkcentre/t14, and `nix eval --raw .#darwinConfigurations.mact2.pkgs.rtk.version`; each must print `0.41.0`. After activation run `rtk --version`, `rtk telemetry status`, `rtk gain --project`, and `rtk gain --project --history`.

Run representative Git, `go -C pkgs/nixos-scripts test ./...`, `nix flake check --no-build`, and `nixos-build` sessions from the repository. Compare raw (`RTK_DISABLED=1`) and intercepted success and intentional-failure commands, capturing `$?`; outcomes and exit codes must match. Repository gates are `format-nix --check`, `nix flake check --no-build`, optional Go regression tests, and scoped diff inspection.

The runbook sections are: installation/privacy checks; baseline and intercepted workloads; exit-code comparison; project gain/history recording table; shell-output-only interpretation; Read/Grep/Glob and passthrough gaps; failure recall and cached data; `RTK_DISABLED=1` raw bypass; disable and revert.

## Threat Matrix

| Boundary | Applicability | Safe/failure behavior and planned RED test |
|---|---|---|
| Documentation-like paths | N/A | No executable-file classification is added; upstream RTK owns command classification. |
| Git repository selection | Applicable | Preserve `git -C` relative/absolute target and exit status; test all three selector forms before integration. |
| Commit state | Applicable | Status/diff must reflect staged, `commit -a`-eligible, and empty-index states; compare raw/intercepted output meaning and exits. |
| Push state | N/A | No push automation or destination resolution is introduced. |
| PR commands | N/A | No PR automation or argument composition is introduced. |

## Migration / Rollout

Deploy as one reversible change. Reverting removes package exposure, plugin, hook, environment, and runbook; no rewritten command persists. Gain history may remain at `~/.local/share/rtk/tracking.db` on Linux and `~/Library/Application Support/rtk/tracking.db` on macOS (90-day retention); it is inert after rollback and may be deleted explicitly.

## Open Questions

None.
