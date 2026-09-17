# Proposal: Centralize Cross-Platform tmux TPM

## Intent

Eliminate split, invalid TPM ownership while preserving the seven-repository TPM runtime model. One declaration and bootstrap must serve Linux and Darwin without changing platform-specific tmux integration.

## Scope

### In Scope
- Centralize TPM declarations, loader ordering, and idempotent Home Manager activation bootstrap in `shared/tmux.nix`.
- Remove Linux's package-typed repository strings and `mkForce` replacement; retain Linux `escapeTime = 0` and Linux-only integration.
- Remove Darwin's duplicate TPM block; retain `escapeTime = 10`, `.tmux.conf` shim, and Darwin-only helpers.
- Update t14's Omarchy tmux override/comment only if needed after narrow merge resolution.
- Hosts: `rog`, `thinkcentre`, `t14`, and Darwin `macm5`.

### Out of Scope
- Migrating to `pkgs.tmuxPlugins`, pinning plugin revisions, or changing TPM's mutable Git-managed runtime model.
- Changing plugin repositories, tmux behavior, host imports, or unrelated Home Manager configuration.
- Production implementation in this phase.

## Capabilities

### New Capabilities
- `cross-platform-tmux-tpm`: A shared TPM declaration and activation contract for all scoped Home Manager hosts.

### Modified Capabilities
None; no existing OpenSpec capability defines tmux or TPM behavior.

## Approach

Keep all seven repositories, `TMUX_PLUGIN_MANAGER_PATH`, and the final TPM `run -b` together in shared `programs.tmux.extraConfig`. Add one idempotent `home.activation` DAG node after `linkGeneration` to clone TPM when absent and install declared plugins. Platform modules retain only their platform concerns; TPM repositories will not use `programs.tmux.plugins`.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/tmux.nix` | Modified | Canonical TPM declarations, loader, and activation node. |
| `linux/home/tmux.nix` | Modified | Remove invalid TPM ownership; retain Linux settings. |
| `darwin/home/tmux.nix` | Modified | Remove duplicate TPM ownership; retain Darwin integration. |
| `hosts/t14/home/omarchy.nix` | Modified | Narrow/update tmux merge assumption if required. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Activation lacks GitHub access | Medium | Keep bootstrap idempotent; preserve existing runtime clones. |
| Loader ordering breaks TPM | Low | Keep loader final after every plugin declaration. |
| t14 merge conflict emerges | Medium | Replace broad force only with a proven narrow override. |

## Rollback Plan

Revert the shared move and restore the prior Darwin declaration block if needed. Do not delete `$HOME/.config/tmux/plugins`; it is mutable user runtime state and enables recovery with an earlier generation.

## Dependencies

- Home Manager activation DAG, `git`, `tmux`, and GitHub availability during TPM bootstrap.

## Success Criteria

- [ ] Exactly one source declares all seven TPM repositories and the final TPM loader.
- [ ] Scoped host evaluations succeed for Linux (including t14) and `macm5`.
- [ ] Linux and Darwin retain their stated platform-specific tmux integration.
- [ ] Repeated activation reuses TPM state without unnecessary destructive changes.
