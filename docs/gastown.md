# Gas Town on rog

`gastown-run` runs project tasks through the pinned Gas Town toolchain with a
sandboxed native Codex executor. Nothing runs in the background: every command
starts what it needs and stops it again.

Enable it per host with `gastown.enable = true;` (see `hosts/rog/default.nix`).
`gastown.toolPackages` adds the toolchain your projects need (for example
`pkgs.go`) to the executor and to the trusted checks. bash, coreutils, git,
grep, sed, awk, find, diff and make are always present.

Pinned versions: `gt` 1.2.1 (gastown commit `466aa41`), `bd` 1.0.5, `dolt`
2.6.0 (`pkgs/gastown`, `pkgs/beads`, `pkgs/dolt`). Codex uses your existing
ChatGPT login with `gpt-5.6-luna` at low reasoning; override with
`GASTOWN_MODEL` and `GASTOWN_EFFORT`. State lives in `~/.local/state/gastown`
(`GASTOWN_STATE` to move it).

## Use

Project and worker names use lowercase letters and hyphens only: Gas Town derives task ids from the project name and rejects ids whose prefix contains a digit.

```sh
gastown-run setup                      # once: create the Gas Town workspace
gastown-run add myproj ~/code/myproj   # register a local git repository
gastown-run doctor myproj              # prove the sandbox boundary (no model)
gastown-run run --task "Add a --json flag" \
  --check "go vet ./..." --check "go test ./..." myproj
gastown-run run --tasks tasks.json myproj   # several tasks, one at a time
gastown-run status myproj
```

The executor and your checks run with a clean environment: only `PATH`, `HOME`,
`TMPDIR` and the Go variables are set. A command that needs anything else must set
it inline, for example `--check 'USER=gastown ./mql lint spec'`.

`tasks.json` is a list of `{"title", "prompt", "checks": ["cmd", ...]}`. A task
without checks is rejected, because only checks can close a task.

The executor and the checks run offline (`GOPROXY=off`, `GOSUMDB=off`) with a
worker-local module cache, so a Go project with external dependencies fails
unless they are vendored. Run `go mod vendor` in your repository and commit
`vendor/` before `add`. The same applies to any ecosystem that needs the
network at build or test time: its dependencies must already be in the
repository.

## What a run guarantees

1. The task is created and assigned to the worker before the executor starts,
   and the exact task id must appear in the executor's context.
2. The executor edits only the worker clone. It cannot write `.git` or task
   metadata, use the network, or read your home directory and other user data
   (`/home`, `/root`, `/tmp`, `/var`, `/run`, `/mnt`, `/media`, `/proc`); system
   paths such as `/nix/store` and `/etc` stay readable. `run` first executes
   `doctor` and refuses to start if the boundary does not hold.
3. Your checks run in isolation after the executor stops. The task is closed
   and committed in the worker clone only if every check passes.
4. Your own repository is never touched. Merge a result with
   `git pull ~/.local/state/gastown/town/myproj/crew/worker <branch>`, where
   `<branch>` is your repository's own default branch (`add` prints the exact
   command).
5. Each run executes in a `systemd --user` unit with memory, CPU and task
   limits. `systemctl --user stop gastown-<project>-<id>` cancels it; the task
   stays hooked and `report.json` records the checkpoint.

A failed or cancelled task stays hooked and the next `run` refuses to start.
Release it with `gastown-run abandon myproj`: partial work is saved in a
`git stash` of the worker clone and the task returns to `open`. Abandoning
never closes a task.

Reports, streams and per-step output are under
`~/.local/state/gastown/runs/<project>/<timestamp>-NN/`.

## Limits

- Prompt rules are not enforcement: a model may still try forbidden commands.
  The sandbox and the post-run checks are the boundary, not the prompt.
- Cancelling stops processes in the unit; it does not cancel a model request
  already in flight on the provider side.
- Token usage is recorded per run; subscription quota cost is not measured.
- Tasks run one at a time. There is no parallel swarm and no mobile client yet.
- Dependencies must be vendored or otherwise committed; the executor and the
  checks cannot download them.
- `doctor` proves the boundary on the worker clone at the time it runs.
