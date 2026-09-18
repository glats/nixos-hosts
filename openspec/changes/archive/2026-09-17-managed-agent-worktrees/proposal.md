# Proposal: Managed Agent Worktrees

## Intent

Enable parallel writing without source collisions or unreviewed host mutation. Each dispatched writing task receives a branch-attached worktree; only a human main-checkout gate can integrate or activate.

## Scope

### In Scope
- Extend `code-work` as the cross-platform authority for task worktrees, lifecycle, locks, and recovery.
- Dispatch OpenCode writing tasks into `.worktrees/managed/<task-id>` with an explicit Level 0/1 capability profile.
- Add a serialized main-checkout gate for integration and NixOS, nix-darwin, or Home Manager generation creation/activation.

### Out of Scope
- Treating OpenCode native worktrees as policy enforcement; they remain optional support.
- OS containment, port isolation, credential isolation, network restrictions, or increased Nix daemon concurrency.
- Automatic merge, push, cleanup, or activation by dispatched agents.

## Capabilities

### New Capabilities
- `managed-agent-worktrees`: Task worktrees, agent capability levels, lifecycle control, and serialized integration.

### Modified Capabilities
- `gentle-ai-declarative-runtime`: Generated OpenCode permissions gain a role-specific managed-writing-task profile while preserving declarative Home Manager ownership.

## Approach

Build on `code-work`, not OpenCode-native worktrees, to create or reuse a uniquely identified worktree from an approved base. Agents may edit, test, run scoped `nix fmt`, evaluate, and build with conservative Nix limits; the dispatcher and OpenCode permissions deny activation, generation/profile mutation, input updates, cleanup, `sudo`, and service control. A portable lifecycle lock protects transitions. The human main-checkout gate validates state, serially integrates an approved branch, validates/builds, and solely activates.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `pkgs/nixos-scripts/cmd/code-work/main.go` | Modified | Managed dispatch and lifecycle commands |
| `pkgs/nixos-scripts/internal/gitutil/` | Modified | Task identity, metadata, and worktree helpers |
| `shared/opencode/{agents,permissions}.nix` | Modified | Role-specific grants and denials |
| `shared/opencode/local-agent-overlays.json` | Modified | Managed-task prompt/permission overlay |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Permissions are not OS containment | High | Defer containment; mutation stays in human gate |
| Shared daemon queues builds | Medium | Preserve daemon settings; cap agent Nix commands |
| Interrupted lifecycle leaves stale state | Medium | Locked transitions plus inspect/recover commands |

## Rollback Plan

Revert dispatcher, lifecycle, and OpenCode overlay changes. Existing `code-work` and main-checkout workflows remain; retain task branches/worktrees until abandonment.

## Dependencies

- Existing `code-work`, Git linked-worktree support, and declarative OpenCode configuration.
- Human operator for serialized integration and any activation.

## Success Criteria

- [ ] Each dispatched parallel writing task receives a unique branch-attached worktree under `.worktrees/managed/`.
- [ ] Agents can edit, test, evaluate, and build locally but cannot activate or create shared NixOS, nix-darwin, or Home Manager generations.
- [ ] The main-checkout integration gate serializes approved integration and is the only activation path on `rog`, `thinkcentre`, `t14`, and `macm5`.
