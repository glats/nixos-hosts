# RTK Pilot

RTK is a command-rewriting and output-filtering helper for shell commands used
by OpenCode and Claude Code. The pilot measures reduced shell output delivered
to the model; it does not compress the model's prompt, built-in tool results,
source files, or arbitrary interactive command output.

## Installation and privacy

RTK 0.41.0 is installed declaratively on rog, thinkcentre, t14, and mact2.
The managed OpenCode plugin lives in `~/.config/opencode/plugins/`, and Claude
Code receives a Bash-only `PreToolUse` hook. Verify the installation with:

```sh
rtk --version
rtk telemetry status
```

`RTK_TELEMETRY_DISABLED=1` is exported by the shared Home Manager
configuration. This prevents outbound telemetry while local gain tracking
continues. RTK stores command statistics in local SQLite data at
`~/.local/share/rtk/tracking.db` on Linux and
`~/Library/Application Support/rtk/tracking.db` on macOS. Records are cleaned
up after approximately 90 days. Do not treat local estimates as billing data.

## Measured workloads

Run representative sessions for Git commands, `go -C pkgs/nixos-scripts test
./...`, `nix flake check --no-build`, and `nixos-build`. Record the reports from
the same project directory:

```sh
rtk gain --project
rtk gain --project --history
```

Capture the workload, command, whether it was rewritten or passed through,
estimated input/output tokens, savings percentage, outcome, and exit code.
Compare intentional failures as well as successful commands. The 60–90%
figure is a shell-output-only claim for commands that RTK actually filters; it
is not a claim about total context reduction or total spend.

## Limits and hidden detail

OpenCode's built-in `Read`, `Grep`, and `Glob` tools do not invoke this Bash
hook. Commands RTK does not recognize, interactive or streaming commands, and
commands excluded by RTK also pass through. Inspect the raw command and the
gain/history reports to find these gaps; a low or missing saving is not proof
that no output was produced. Use the raw bypass for a direct comparison:

```sh
RTK_DISABLED=1 git status
git status
```

The bypass executes the original command without rewriting. Compare output
meaning and `$?`, not only token estimates.

For intentional failures, inspect RTK's recovery report as well:

```sh
rtk gain --failures
```

Use RTK exclusions or the raw bypass when a filter hides detail needed for
diagnosis.

## Disable and rollback

To disable interception temporarily, export `RTK_DISABLED=1` for the command
or session. To disable it declaratively, set
`home.opencode.plugins.rtk.enable = false` in the host Home Manager override
and remove or disable the Claude hook if it was explicitly configured. A
single revert of this pilot change removes the package, environment, managed
plugin, Claude hook, and runbook. RTK is fail-open: a missing binary, load
failure, unsupported command, or rewrite failure leaves the original command
unchanged. Local tracking data may remain after rollback and can be deleted
explicitly if desired.
