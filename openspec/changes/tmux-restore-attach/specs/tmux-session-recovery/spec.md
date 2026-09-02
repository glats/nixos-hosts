# tmux-session-recovery Specification

## Purpose

Define a single, cross-platform human command (`tmux-resume`) that reliably attaches to the tmux workspace restored by Continuum/Resurrect after a cold start (Linux hosts and `mact2`), without exposing a transient false `no sessions` failure, without creating a bootstrap session, and without triggering a second restore.

## Requirements

### Requirement: Common Recovery Command

The system MUST expose a single platform-neutral command, `tmux-resume`, available on all configured Linux hosts and on `mact2`, that attaches the user to the tmux session set restored by Continuum.

#### Scenario: Command exists on every host

- GIVEN a Linux host (rog, thinkcentre, t14) or `mact2` with the shared tmux/shell configuration active
- WHEN the user invokes `tmux-resume`
- THEN the command is found and executable without host-specific syntax differences

### Requirement: Native Attach When Sessions Exist

The system MUST attach using native `tmux attach` semantics whenever at least one tmux session already exists (server already running, no cold-start race in progress).

#### Scenario: Server already running with sessions

- GIVEN a tmux server is running with one or more existing sessions on a Linux host or `mact2`
- WHEN the user invokes `tmux-resume`
- THEN the command attaches to the most recently used session immediately, equivalent to `tmux attach`
- AND no additional session, window, or pane is created

### Requirement: Bounded Wait During Cold-Start Restore

The system MUST tolerate the asynchronous Continuum restore race during a cold start by retrying attach for a bounded interval, and MUST NOT wait indefinitely.

#### Scenario: Cold start with restore in progress

- GIVEN the tmux server has just started and Continuum's background restore has not finished attaching sessions yet, on a Linux host or `mact2`
- WHEN the user invokes `tmux-resume` immediately after login
- THEN the command retries attach within a fixed short timeout
- AND once Continuum's restored session(s) become available, the command attaches to them without the user re-running the command

#### Scenario: No false "no sessions" during cold start

- GIVEN the same cold-start condition as above
- WHEN the user invokes `tmux-resume`
- THEN the command MUST NOT report a "no sessions" failure while the bounded retry window has not elapsed

### Requirement: No Bootstrap Session

The system MUST NOT create a new session (e.g., via `tmux new-session -A`) as part of `tmux-resume`, on cold start or otherwise.

#### Scenario: Snapshot restores multiple sessions

- GIVEN a valid Resurrect snapshot describing 3 sessions
- WHEN `tmux-resume` completes successfully
- THEN exactly the 3 restored sessions exist, with no additional bootstrap session created by the recovery command

### Requirement: Continuum Remains Sole Restore Authority

The system MUST NOT invoke Resurrect's restore mechanism directly or in parallel with Continuum's automatic restore. `tmux-resume` MUST only observe/wait for and attach to Continuum's restoration; it MUST NOT trigger a second restore.

#### Scenario: No duplicate restoration

- GIVEN Continuum's `@continuum-restore on` auto-restore has started on server boot
- WHEN `tmux-resume` is invoked during that restore
- THEN no second Resurrect restore is executed by `tmux-resume`
- AND panes, windows, and processes are not duplicated as a result of running `tmux-resume`

### Requirement: Preserved Process and Layout Restoration

The system MUST preserve the current Resurrect/Continuum process-restoration policy and full layout fidelity (sessions, windows, panes, layouts, working directories) unchanged; `tmux-resume` MUST NOT alter which processes are eligible for relaunch.

#### Scenario: Existing eligible processes still restored

- GIVEN a snapshot that includes processes currently eligible for restoration under the existing policy
- WHEN `tmux-resume` attaches after cold start
- THEN those processes are restored exactly as they would be without `tmux-resume`, using the same eligibility policy already configured

#### Scenario: Process policy not implicitly broadened

- GIVEN the current process-restoration policy (not `:all:`)
- WHEN `tmux-resume` is used repeatedly across cold starts
- THEN the policy remains unchanged unless explicitly reconfigured outside this command

### Requirement: Clear Terminal Outcomes for Failure Cases

The system MUST terminate `tmux-resume` with a clear, actionable outcome — not indefinite waiting — for: missing/corrupt snapshot, exhausted retry timeout, and genuine tmux errors unrelated to the restore race.

#### Scenario: Missing or corrupt snapshot

- GIVEN no Resurrect snapshot file exists (or it is unreadable) and no session appears within the bounded interval
- WHEN `tmux-resume` exhausts its retry window
- THEN the command exits with a clear message distinguishing "no snapshot to restore" from a generic failure, rather than hanging

#### Scenario: Retry timeout exceeded

- GIVEN Continuum's restore does not complete within the bounded retry interval for any reason
- WHEN the timeout elapses
- THEN `tmux-resume` exits with an actionable timeout message instead of waiting further

#### Scenario: Genuine tmux failure

- GIVEN tmux itself is unavailable or misconfigured (e.g., binary missing, socket permission error) independent of the restore race
- WHEN the user invokes `tmux-resume`
- THEN the command surfaces the underlying tmux error directly rather than masking it as a restore-related timeout

### Requirement: `tmux a` Remains Native and Unaffected

The system MUST leave native `tmux attach`/`tmux a` behavior unchanged for advanced use; `tmux-resume` is an additive contract, not a replacement of native tmux commands.

#### Scenario: Direct native attach still works

- GIVEN a running tmux server with existing sessions
- WHEN the user runs `tmux a` directly (not `tmux-resume`)
- THEN it behaves exactly as stock tmux, without any bounded-retry wrapping or new side effects
