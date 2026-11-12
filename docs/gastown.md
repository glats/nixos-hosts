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

## Swarm: state a goal, get notified, answer when asked

`gastown-run swarm` runs a whole goal instead of pre-split tasks. A Mayor agent
plans and dispatches, workers code in parallel, and a trusted gate (plain code,
not a model) verifies every result before you see it. You are told what is
happening and asked when a decision is needed.

```sh
# once per project: a private town, a staging repository, your trusted checks
gastown-run swarm init \
  --check 'test -z "$(gofmt -l .)"' --check 'go vet ./...' --check 'go test ./...' \
  --polecat-agent opencode:nvidia/nvidia/nemotron-3-ultra-550b-a55b \
  --polecat-agent opencode:nvidia/google/gemma-4-31b-it \
  --polecat-agent codex:gpt-5.6-luna:low \
  --protect main.go --protect cmd/ \
  --notify-cmd 'notify-send "$GASTOWN_NOTIFY_TITLE" "$GASTOWN_NOTIFY_BODY"' \
  myproj ~/code/myproj
gastown-run swarm check myproj      # probes each opencode model: alive, key valid
gastown-run swarm run --goal "Add a --json flag to the export command" myproj
gastown-run swarm reply myproj "Use the second option"   # when it asked you something
gastown-run swarm status myproj
gastown-run swarm stop myproj       # or: systemctl --user stop gts-myproj-*
```

`run` starts Dolt, the daemon, tmux, the Mayor and the workers inside one
`systemd --user` unit with memory, CPU and task limits, works until the goal is
verified, and shuts everything down. Expect several GB of memory and about half
a core while it runs. Nothing stays running afterwards.

What you receive, in `~/.local/state/gastown/swarm/<project>/notifications.jsonl`
and through `--notify-cmd` (it gets `GASTOWN_NOTIFY_SEVERITY`, `_TITLE` and
`_BODY`): questions the Mayor escalated ("Needs you"), the Mayor's mail, the
gate's verdict for every branch ("Ready for review: git fetch <staging> gastown/<bead>"),
provider limits and agent switches, and the final result. Point `--notify-cmd` at
`notify-send`, `ntfy`, a Telegram bot script or anything else that takes a message.

Campaigns: `gastown-run campaign start <project> "<intent>"` asks the Mayor which
capabilities the intent needs. The plan always includes the delivery process (how the
result is tested, built and shipped) and the questions the Mayor needs answered, such as
which build machines, accounts or sites exist; it is told what workers cannot do (root,
VMs, devices, downloads, publishing) so it asks instead of assuming. You get the process,
the questions and the numbered items in one notification. Answer with
`campaign answer <project> --question <id> "..."` (no id answers the only open
question); answers are saved and travel with every later goal. Pick with
`campaign reply <project> "a c"` (ids, `all`, or free text the Mayor interprets);
items marked as needing your decision wait for a `campaign reply`. Selected items run
one at a time in dependency order through the same gate; an item is done only with a
verified branch, and an item that shows no progress for 30 minutes becomes blocked until
you reply. Everything is kept in `campaign.json` (decisions, learnings, results) and
published as `CAMPAIGN.md` on branch `gastown/campaign` of the staging repository;
`campaign start` on an existing campaign resumes it: interrupted items are sent again to a fresh Mayor. The supervisor runs detached in a systemd user unit and writes to the journal, so closing the terminal does not stop it. Flags such as `--question` work before or after the project name. `campaign status` and
`campaign stop` do what they say, and a digest notification arrives every four hours.
Items build on each other: when an item is verified, its accepted branches are merged
into the swarm's own base, the trusted checks run on the combined result, and only then
does the base move (staging `main` and the rig's `main`), so the next item starts from the
work already accepted. If branches conflict or the combined checks fail, the item is
blocked instead of done. Your own repository is never touched. `campaign advance <project>
gastown/<bead>...` adds accepted branches to the base by hand.

Reviewing and growing the plan: `campaign approve <project> <item> gastown/<bead>...` records
that you reviewed an item's branches and marks it done, but only when the trusted gate accepted
every branch (the supervisor re-checks it and adds the branches to the base). `campaign extend
<project> "<direction>"` records a new direction and has the Mayor propose additional items
(new ids, dependencies on existing ones); they wait as proposed until you select them.

Starting at boot: with `home.gastown.campaigns.<project> = { }` (enabled for `maquilinux` on
`rog`) a systemd user service `gastown-campaign-<project>` starts the supervisor when the
machine boots (`users.users.glats.linger` makes user services start without a login),
resumes interrupted items and stops the swarm cleanly at shutdown. It does nothing until the
swarm exists (`swarm init`), does not start after `campaign stop` (the STOP file) and
refuses to start while a manually launched supervisor runs. Only one supervisor can hold a
project: a lock the kernel releases on any exit, including power loss. Provider keys come
from your sops secrets; the Claude token comes from `claudeTokenFile` when set, otherwise
from the OpenCode credential store, and a campaign with a claude agent and no token refuses
to start (exit 78, not retried). Check it without starting anything:
`GASTOWN_CAMPAIGN_DRYRUN=1 gastown-campaign-start <project> 720h`.

Worker contract: every agent starts with a short read-only worker contract mounted
into its home (`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`,
`~/.config/opencode/AGENTS.md`). It is the ODD discipline for a polecat: work the
hooked bead inline, never orchestrate, test first when a runnable test exists, change
only what the bead needs, ask with `gt escalate` instead of guessing, and finish with
`gt done` listing the checks run and their real results. Other roles ignore it. Your
own gentle-ai files are never copied in, so no second orchestrator runs inside a
worker. The text lives in `pkgs/nixos-scripts/internal/gastown/polecat-odd.md`.

Token usage: the supervisor records every agent session's tokens (Codex rollouts,
Claude transcripts, OpenCode's session store) in `ledger.jsonl` inside the swarm
directory. `gastown-run swarm usage [--since goal|all] <project>` prints totals by
role and model (input excludes cached tokens), and the "Swarm finished" notification
carries the same totals. Subscriptions are shown as tokens only, never as money.

Agents and providers:

- `codex:<model>:<effort>` uses your ChatGPT login (only `auth.json` is exposed to
  the agent) with the model and reasoning effort you name.
- `claude:<model>` (`sonnet`, `opus`, `haiku` or a full id) runs Claude Code on your
  Claude subscription. Run `claude setup-token` once and export the printed token as
  `CLAUDE_CODE_OAUTH_TOKEN` where you start the swarm; it is the only credential the
  agent receives. `ANTHROPIC_API_KEY` is never forwarded, and `~/.claude` is never
  mounted, so nothing inside the sandbox can rotate your own login away.
- `opencode:ollama-cloud/<model>` uses your Ollama Cloud subscription through OpenCode
  with the `OLLAMA_API_KEY` from your environment (base URL `https://ollama.com/v1`;
  e.g. `opencode:ollama-cloud/glm-5.3-flash`). It works as worker and as Mayor
  (`--mayor-agent opencode:ollama-cloud/glm-5.3`).
- `opencode:nvidia/<model id>` uses NVIDIA NIM through OpenCode with a minimal
  inline configuration and the `NVIDIA_API_KEY` from your environment. Your own
  OpenCode configuration, sessions and database are never mounted. The model id
  is NVIDIA's full id, which usually repeats the organization
  (`nvidia/nvidia/nemotron-3-ultra-550b-a55b`, `nvidia/google/gemma-4-31b-it`).
  Several models in `providers-base.nix` have reached end of life; use
  `swarm check` to find out which still answer.
- Workers use the first agent in the order given. When a worker pane shows a usage
  or rate limit, that agent cools down for 30 minutes and new workers use the next
  one; if every agent is limited, dispatch pauses until one recovers.
- The Mayor defaults to the Codex model at medium effort. Cheap workers confabulate
  less when the coordinator is stronger.

Safety model:

- Agents run inside `bwrap`: they can write only the swarm's own town directory,
  cannot see your home, SSH or GPG keys, and receive only the environment variables
  the chosen agents need. Network stays on because the model APIs need it.
- Agents never get the tmux socket and cannot start other agents; a deferred
  scheduler inside the trusted side starts workers, so a compromised agent cannot
  ask tmux to run something outside the sandbox.
- The gate rebuilds each branch on the base, removes Gas Town's own files, the
  ignore entries workers add to hide them and any new binary file, rejects a branch
  that changes a `--protect` path (a file, or a `dir/`), flags edits to files that
  already existed, runs your checks in isolation, and only then publishes
  `gastown/<bead>` in the swarm's staging repository.
- When the goal is verified, the accepted branches are merged into
  `gastown/integrated` and your checks run on the combination. A conflict between
  branches, or checks that fail only together, is reported instead of hidden. Your repository
  is not touched. A model saying "done" counts for nothing: a goal is complete only
  if at least one branch passed the gate after the goal was sent.
- Mayor mail is shown as unverified claims. A "goal complete" with nothing verified
  is rejected with a high alert.

## Limits

- Prompt rules are not enforcement: a model may still try forbidden commands.
  The sandbox and the post-run checks are the boundary, not the prompt.
- Cancelling stops processes in the unit; it does not cancel a model request
  already in flight on the provider side.
- Token usage is recorded per run; subscription quota cost is not measured.
- `run` executes tasks one at a time; `swarm` runs workers in parallel. There is no mobile client yet.
- Dependencies must be vendored or otherwise committed; the executor and the
  checks cannot download them.
- `doctor` proves the boundary on the worker clone at the time it runs.
- Swarm: workers and the Mayor are language models and can ask for the wrong thing,
  stall or invent a result; the gate and your checks are the only authority, so write
  checks that actually express "done". The Mayor's answer to your reply is not
  instant. Replies are not delivered to a phone yet; answer with `swarm reply`.
- Swarm: `codex:` agents are not probed by `swarm check` because they spend quota.
- Swarm: tasks stay in the swarm's town until you delete `~/.local/state/gastown/swarm/<project>`.
