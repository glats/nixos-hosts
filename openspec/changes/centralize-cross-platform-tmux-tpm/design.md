# Design: Centralize Cross-Platform tmux TPM

## Technical Approach

`shared/tmux.nix` becomes the sole TPM owner for `rog`, `thinkcentre`, `t14`, and `macm5`. It will contain the ordered seven `set -g @plugin` declarations, `TMUX_PLUGIN_MANAGER_PATH`, and the final `run -b` loader in one `programs.tmux.extraConfig` value. It will also own one idempotent activation node, ordered after `linkGeneration`, which clones TPM only when absent and runs its installer. Linux and Darwin leaf modules retain only platform integration.

## Architecture Decisions

| Option | Trade-off | Decision and rationale |
|---|---|---|
| Keep TPM in leaf modules | Duplicates declarations and activation behavior | Reject. Shared ownership gives one ordered runtime contract. |
| Use `programs.tmux.plugins` | Expects derivation-backed plugin values, not repository strings | Reject. TPM repositories stay in `extraConfig`; no competing plugin manager is configured. |
| Replace TPM with `pkgs.tmuxPlugins` | Removes network activation but changes requested mutable TPM model | Reject as out of scope. |
| Activation after `writeBoundary` | Config links may not exist yet | Reject. Use `entryAfter [ "linkGeneration" ]` so generated tmux config exists before TPM installation. |

The loader MUST be the final shared tmux fragment. Leaf modules MUST NOT append TPM declarations, loaders, or `programs.tmux.extraConfig`; this preserves TPM's required ordering.

## Data Flow

```text
shared/tmux.nix
  ├─ tmux.conf: seven declarations → TPM loader (last)
  └─ home.activation.installTpm after linkGeneration
       → fixed $HOME/.config/tmux/plugins/tpm
       → git clone if absent → TPM install_plugins
```

The node creates the parent directory through Home Manager's `run` helper, uses Nix-store `git` and `tmux` paths, quotes all runtime paths, and is idempotent. A non-Git TPM path or clone/install failure MUST fail activation without deleting existing plugin state or masking the error. A later successful activation reuses the clone and refreshes declared plugins.

## File Changes

| File | Action | Description |
|---|---|---|
| `shared/tmux.nix` | Modify | Add canonical TPM config and valid DAG bootstrap; update module arguments for `lib`/`pkgs`. |
| `linux/home/tmux.nix` | Modify | Remove invalid activation, `plugins`, and forced `extraConfig`; retain `escapeTime = 0`. |
| `darwin/home/tmux.nix` | Modify | Remove duplicate TPM config/bootstrap; retain `escapeTime = 10`, shim, and Darwin packages. |
| `hosts/t14/home/omarchy.nix` | Conditional modify | Update the stale broad-force comment; add only a proven narrow merge override if evaluation requires it. |

## Interfaces / Contracts

No custom option is introduced. The module consumes existing Home Manager interfaces:

```nix
programs.tmux.extraConfig = "...";
home.activation.installTpm = lib.hm.dag.entryAfter [ "linkGeneration" ] '' ... '';
```

`home.activation` is a DAG option, not the invalid `activation.install-tpm` attribute. The activation contract has one fixed user-home target and uses no caller-provided repository/path input. Host scope is Linux `rog`, `thinkcentre`, `t14`, plus Darwin `macm5`, through their existing module lists.

## Testing Strategy

| Layer | What to test | Approach |
|---|---|---|
| RED/static | One source has seven repositories and one final loader; leaves have none | Add a focused repository assertion/search test before module edits. |
| RED/eval | DAG node is under `home.activation`, depends on `linkGeneration`, and leaves do not populate typed `plugins` | Add evaluation assertions before implementation, then evaluate t14 and macm5. |
| Integration | Host composition and generated configuration | Run `nix fmt` on changed Nix files; evaluate `nixosConfigurations.t14` and `darwinConfigurations.macm5` toplevel drvPaths. |

## Threat Matrix

| Boundary | Applicability | Design response | Planned RED tests |
|---|---|---|---|
| Documentation-like paths | N/A — no file classification/execution | None | None |
| Git repository selection | Applicable — activation initializes a fixed absolute TPM repository | Never accept relative or caller-selected paths; fail if target is non-Git, never remove it | Mock/home-fixture checks for relative, arbitrary absolute, and existing non-Git targets; only the fixed target may be cloned |
| Commit state | N/A — no commit operation | None | None |
| Push state | N/A — no push operation | None | None |
| PR commands | N/A — no PR automation | None | None |
| Process/network activation | Applicable — `git clone` and TPM installer contact GitHub | Use store paths and `run`; propagate network/installer failure and retain existing state | Simulate clone and installer failure; assert nonzero activation and no deletion/masked success |

## Migration / Rollout

Move the exact Darwin repository order to shared first, then the DAG node, then delete both leaf copies and Linux's forced plugin/config replacement. Evaluate t14 before accepting any Omarchy override, then macm5. Roll back by reverting these declarations and restoring the prior Darwin block; never delete `$HOME/.config/tmux/plugins`.

## Open Questions

- [ ] Does the current Omarchy tmux definition merge cleanly once Linux's broad force is removed? Resolve by t14 evaluation, not speculation.
