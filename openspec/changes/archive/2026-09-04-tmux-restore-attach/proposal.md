# Proposal: Reliable tmux Session Recovery

## Intent

Provide one reliable recovery command after a cold start so users on every configured Linux host and `mact2` can attach to a Continuum-restored tmux workspace without a transient, misleading `no sessions` failure. Preserve the existing full Resurrect recovery behavior, including sessions, windows, panes, layouts, directories, and eligible processes.

## Scope

### In Scope
- Define `tmux-resume` as the common, documented human-facing recovery interface for Linux hosts and `mact2`.
- Wait for the existing asynchronous Continuum restore only for a bounded cold-start interval, then attach to the restored session set.
- Preserve Continuum as the sole restore authority and retain the current process-restoration policy.
- Define consistent outcomes for successful recovery, absent/corrupt snapshots, timeouts, and genuine tmux failures.

### Out of Scope
- Replacing Continuum/Resurrect with a custom restore sequence or manually invoking Resurrect alongside Continuum.
- Creating a bootstrap session with `tmux new-session -A`.
- Changing the process policy to `false` or `:all:` without a separately approved decision.
- Guaranteeing progressive window appearance as a status/progress interface.

## Capabilities

### New Capabilities
- `tmux-session-recovery`: A cross-platform, bounded recovery-and-attach contract that coordinates with Continuum without taking over restoration.

### Modified Capabilities
None. No existing OpenSpec capability defines tmux behavior.

## Approach

Expose a single platform-neutral `tmux-resume` interface through the shared Home Manager composition. Its implementation location and mechanism remain design decisions, but it SHALL retain native `tmux attach` semantics once sessions exist and use only bounded retry/observation during Continuum's cold-start restoration. `tmux a` remains available as the native advanced attach command.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `shared/tmux.nix` | Modified | Preserve shared Continuum/Resurrect policy and expose recovery contract if appropriate. |
| `shared/shell-aliases.nix` | Modified | Possible shared command exposure. |
| `linux/home/tmux.nix` | Modified | Validate Linux plugin path supports the common contract. |
| `darwin/home/tmux.nix` | Modified | Validate mact2 TPM path supports the same contract. |
| `pkgs/` | New/Modified | Possible implementation location, pending design. |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Infinite wait conceals a restore failure | Medium | Require a short bounded timeout and actionable error. |
| Second restore duplicates panes or processes | Medium | Continuum remains the only restore authority. |
| Linux/Darwin plugin differences diverge | Low | Verify cold-start recovery on both paths. |
| Process relaunch has side effects | Medium | Preserve current policy; do not broaden it implicitly. |

## Rollback Plan

Remove the `tmux-resume` exposure and its supporting configuration, leaving the existing Continuum/Resurrect settings and native `tmux a` behavior unchanged. No snapshot migration or persistent-state conversion is introduced.

## Dependencies

- Existing tmux-resurrect and tmux-continuum configuration on Linux hosts and `mact2`.

## Success Criteria

- [ ] `tmux-resume` behaves consistently on Linux hosts and `mact2` after a cold start with a valid multi-session snapshot.
- [ ] Recovery attaches without a false transient `no sessions` failure and creates no bootstrap session.
- [ ] Sessions, panes, layouts, directories, and the current eligible-process behavior remain preserved.
- [ ] Missing/corrupt snapshots, restore timeout, and genuine tmux errors terminate clearly without indefinite waiting or double restoration.
