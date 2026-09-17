# Design: Centralize Cross-Platform tmux TPM

## Technical Approach

`shared/tmux.nix` is the TPM owner for `rog`, `thinkcentre`, `t14`, and `macm5`: seven ordered declarations, `TMUX_PLUGIN_MANAGER_PATH`, guarded tmux-server runtime `PATH`, and final loader. Its activation after `linkGeneration` only validates or clones TPM. Plugin installation is interactive: start or reload tmux, then press `prefix + I`.

## Architecture Decisions

| Option | Trade-off | Decision and rationale |
|---|---|---|
| Keep TPM in leaf modules | Duplicates declarations | Reject; shared ownership preserves one ordered runtime contract. |
| Use `programs.tmux.plugins` | Requires derivation-backed values | Reject; repositories remain in `extraConfig`. |
| Replace TPM with `pkgs.tmuxPlugins` | Avoids network work but changes the mutable TPM model | Reject as out of scope. |
| Run `install_plugins` in activation | Automates first use but needs a terminal and configured server | Reject; macm5 activation has `TERM=unknown`, and activation-shell variables do not configure a tmux server. |
| Force `TERM` or create a temporary server | Bypasses one error but risks collisions, races, and configuration failure | Reject; clone-only activation has neither dependency. |

The loader MUST remain final; leaf modules MUST NOT append TPM configuration.

## Data Flow

```text
shared/tmux.nix
  ├─ tmux.conf: declarations → runtime PATH prefix → loader (last)
  └─ activation after linkGeneration → fixed TPM path → clone if absent

interactive tmux server → managed config loads TPM → prefix + I → plugins install
```

The activation node uses `run`, Nix-store `git`, quoted fixed paths, and is idempotent. A non-Git target or clone failure fails without deletion or masked success. A valid clone is reused. The existing server `PATH` prefix remains for TPM's loader and bindings; plugin-install network failures occur in tmux, never Home Manager activation.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/tmux.nix` | Modify | Retain canonical config and clone guard; remove activation-time installer and its activation-only tmux environment. |
| `pkgs/nixos-scripts/internal/tmuxtapm/tmuxtapm_test.go` | Modify | Replace installer-success/failure activation assertions with clone-only, no-installer, and preserved-target checks. |
| `darwin/home/tmux.nix`, `linux/home/tmux.nix`, `hosts/t14/home/omarchy.nix` | No change | Preserve Darwin/Linux settings and the existing t14 merge decision. |

## Interfaces / Contracts

No custom option is introduced:

```nix
programs.tmux.extraConfig = "...";
home.activation.installTpm = lib.hm.dag.entryAfter [ "linkGeneration" ] '' ... '';
```

`home.activation` is a DAG option. Its fixed target accepts no caller path and promises only clone reuse or bootstrap. It MUST NOT invoke TPM's installer, create a server, or set `TERM`. The runtime contract exposes `prefix + I` once managed configuration loads.

## Testing Strategy

| Layer | What to test | Commands / approach |
|---|---|---|
| RED/static | Seven repositories, final loader, and no activation installer | Update `TestCanonicalTPMDeclarations` before the Nix edit. |
| RED/runtime | First clone, repeat reuse, non-Git/clone failure preservation, installer uncalled | Update `TestRealTPMRuntime` with a fake installer that fails if called. |
| Eval/physical | Composition and terminal-free macm5 activation followed by interactive install | `nix fmt -- shared/tmux.nix`; `go -C pkgs/nixos-scripts test ./internal/tmuxtapm`; evaluate t14, macm5 Home Manager, and macm5 Darwin drvPaths; on macm5 run `home-manager switch --flake .#macm5`, start/reload tmux, then press `prefix + I`. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no file classification/execution | None | None |
| Git repository selection | Applicable — fixed TPM target | Reject caller-selected paths; fail for non-Git target without removal | Fixed target, non-Git target, no path input |
| Commit state | N/A — no commit operation | None | None |
| Push state | N/A — no push operation | None | None |
| PR commands | N/A — no PR automation | None | None |
| Process/network activation | Applicable — activation clones TPM; runtime installs plugins | Store `git`; propagate clone failure; never launch tmux or installer in activation | Clone failure preserves state; fake installer remains uncalled |

## Migration / Rollout

Deploy the narrow shared edit with its RED test update. Existing valid clones remain untouched; newly cloned TPM awaits one `prefix + I`. On macm5, reload an existing server with `tmux source-file "$HOME/.config/tmux/tmux.conf"` before attaching, or start a new session, then press `prefix + I`. Roll back by reverting only this clone-only change and test update; never delete `$HOME/.config/tmux/plugins`, kill sessions, force `TERM`, or restore activation-time installation.

## Open Questions

None. Physical macm5 activation established that plugin installation belongs to a live configured tmux runtime.
