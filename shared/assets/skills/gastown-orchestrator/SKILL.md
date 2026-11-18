---
name: gastown-orchestrator
description: "Trigger: gastown, gastown-run, swarm, campaign, Mayor, polecat, orchestrate the swarm. Operate a running campaign for the user: run the commands, read notifications, answer what is already decided, ask only what is theirs."
license: Apache-2.0
metadata:
  author: "glats"
  version: "1.1"
---

## Activation Contract

Load when the user asks to start, steer, monitor, stop or resume a `gastown-run` swarm or campaign, or asks what one of its notifications means. For a new project use `gastown-kickoff` first.

## Hard Rules

- Models are never authorities. An item is done only with a branch the trusted gate accepted after its goal was sent. Mayor mail is labelled unverified; never report it as a result.
- Flags go before the project: `campaign answer --question ID <project> TEXT`. After the project they become part of the text and the answer is silently kept as a note.
- Never print, copy or commit credentials; pass them by environment only.
- One swarm at a time per machine (about 5 GB peak). Never `pkill -f` a pattern that appears in your own command line.
- Never push, deploy, sign, spend or pick hardware: those decisions belong to the user.
- "Running" is not "progressing". Never say the autopilot or the swarm is taking items without evidence of progress: new `ledger.jsonl` entries, a changed item count, a new accepted branch. A live service with identical digests is idle.

## Provider Health (check on every observation)

Compare the last two `Campaign digest` token totals and the `at` field of the last `ledger.jsonl` entry; the file modification time proves nothing because the file is rewritten without new usage. A worker marked `working` with no new commit is not progress: read its pane with `gt peek <rig>/<polecat> --lines 40`, where a quota shows as `Error: The usage limit has been reached`. If nothing moved while items are `running` or `selected`, or a notification says workers "die right after launch", run `gastown-run swarm check <p>` before anything else. A line `UNAVAILABLE ... usage limit` is a provider quota, not a scheduler fault: tell the user at once, in the first sentence, with the exact agent and message. A `Provider limit on <agent>`, `Agent unavailable` or `All providers are limited` notification is the same alert. Do not wait for the user to notice, and do not accept a Mayor's explanation that blames the scheduler until `swarm check` is clean.

When a provider is out, offer the choices and let the user pick the models: wait for the renewal (`campaign stop`), or switch workers to a provider with quota. The model catalog is whatever `tools.opencode.models` lists; confirm a candidate answers (`swarm check`, or a one-word `opencode run -m <provider/model>`) before proposing it. `opencode:openai/<model>[:<effort>]` needs the swarm's own login (see `references/operations.md`). Switching to Claude is documented in `references/operations.md` ("Switching workers to Claude"); the token usually already exists in the OpenCode store.

## Decision Gates

| Situation | Action |
|---|---|
| `Campaign plan ready` | Read `campaign.json`: explain process, questions, items; the user chooses. |
| Question the user already answered | Send it with `campaign answer --question`, quoting their words. |
| Question about custody, cost, hardware, publishing, release policy | Ask the user, one question at a time. |
| `Needs you:` escalation | Separate infrastructure noise from a real decision; only real ones reach the user. |
| Item `blocked` | Reply with the missing decision using `campaign reply`; do not reselect. |
| Items that depend on earlier code | Warn: every item starts from the rig's main; accepted branches are not chained. |
| Repeated `Rejected <bead>` | Read the gate logs. The same mistake twice becomes a proposed rule (`odd-project` `references/correction-to-rule.md`), not a steering reply; a stronger Mayor only for planning failures. |
| Branch edits a check, rule or tool configuration | Reject it and report it; never accept relaxed rules. Add the path to the protected list on the next project. |

## Execution Steps

1. Observe: `gastown-run campaign status <p>`, `gastown-run swarm usage <p>`, tail `notifications.jsonl`.
2. Act with the commands in `references/operations.md`.
3. Report phase, items by status, new notifications in plain words, tokens by role, and the one thing the user must decide.

## Output Contract

Lead with the state and the next action. Name every unverified claim as unverified. List only decisions that are the user's.

## References

- `references/operations.md` — commands, state files, notification glossary and known traps.
