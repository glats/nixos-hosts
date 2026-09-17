# Proposal: Centralize Cross-Platform tmux TPM

## Intent

Separate safe TPM checkout bootstrapping from TPM's interactive plugin lifecycle. Confirmed physical macm5 evidence shows Home Manager activation has no usable terminal or configured tmux server; it MUST clone TPM only and never run `install_plugins`.

## Scope

### In Scope
- Modify the shared activation node to validate or shallow-clone TPM, then stop.
- Preserve the canonical seven-plugin declaration, final TPM loader, and guarded tmux runtime `PATH`.
- Define first installation and later updates as user-initiated TPM `prefix + I` actions in a real configured tmux session.
- Host scope: `rog`, `thinkcentre`, `t14`, and Darwin `macm5`.

### Out of Scope
- Headless tmux servers, forced `TERM`, config-time automatic installation, plugin pinning, or migration to `pkgs.tmuxPlugins`.
- Changes to plugin repositories, host imports, platform-specific tmux settings, or production implementation in this phase.

## Capabilities

### New Capabilities
- `cross-platform-tmux-tpm`: Shared TPM ownership with clone-only Home Manager activation and interactive plugin lifecycle for all scoped hosts.

### Modified Capabilities
None; no archived OpenSpec capability defines tmux or TPM behavior.

## Approach

In `shared/tmux.nix`, retain the activation DAG ordering after `linkGeneration`, fixed checkout path, invalid-path refusal, and idempotent clone guard. Remove every activation-time call to TPM's installer. Keep platform leaves unchanged. A user starts or reloads a managed tmux session and presses `prefix + I` to install or update plugins.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `shared/tmux.nix` | Modified | Clone-only activation; preserve runtime declarations and loader. |
| `openspec/changes/centralize-cross-platform-tmux-tpm/*` | Modified later | Reconcile spec, design, and tasks with the revised lifecycle. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Fresh plugins need one user action | High | Document `prefix + I` as first-use and update workflow. |
| Existing server predates managed config | Medium | Reload it safely before using the binding; never kill active sessions. |
| TPM/network failure at runtime | Medium | Keep it outside activation; retry interactively without blocking generation activation. |

## Rollback Plan

Revert the clone-only activation edit to restore the prior behavior only if explicitly required. Preserve `$HOME/.config/tmux/plugins`; it is mutable runtime state and permits recovery with an earlier generation.

## Dependencies

- Home Manager activation DAG and `git` for TPM checkout bootstrapping.
- A real configured tmux session and TPM's documented `prefix + I` binding for plugin installation or updates.

## Success Criteria

- [ ] Activation on physical macm5 completes without `TERM` or TPM installer failures.
- [ ] Activation validates/clones TPM but never invokes `install_plugins`.
- [ ] In a configured tmux session, `prefix + I` installs the seven declared plugins.
- [ ] Repeated activation preserves a valid TPM checkout; Linux and Darwin platform settings remain unchanged.
