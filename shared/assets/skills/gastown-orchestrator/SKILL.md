---
name: gastown-orchestrator
description: "Trigger: gastown, gastown-run, swarm, campaign, Mayor, polecat, orchestrate the swarm. Operate a running campaign for the user: run the commands, read notifications, answer what is already decided, ask only what is theirs."
license: Apache-2.0
metadata:
  author: "glats"
  version: "1.0"
---

## Activation Contract

Load when the user asks to start, steer, monitor, stop or resume a `gastown-run` swarm or campaign, or asks what one of its notifications means. For a new project use `gastown-kickoff` first.

## Hard Rules

- Models are never authorities. An item is done only with a branch the trusted gate accepted after its goal was sent. Mayor mail is labelled unverified; never report it as a result.
- Flags go before the project: `campaign answer --question ID <project> TEXT`. After the project they become part of the text and the answer is silently kept as a note.
- Never print, copy or commit credentials; pass them by environment only.
- One swarm at a time per machine (about 5 GB peak). Never `pkill -f` a pattern that appears in your own command line.
- Never push, deploy, sign, spend or pick hardware: those decisions belong to the user.

## Decision Gates

| Situation | Action |
|---|---|
| `Campaign plan ready` | Read `campaign.json`: explain process, questions, items; the user chooses. |
| Question the user already answered | Send it with `campaign answer --question`, quoting their words. |
| Question about custody, cost, hardware, publishing, release policy | Ask the user, one question at a time. |
| `Needs you:` escalation | Separate infrastructure noise from a real decision; only real ones reach the user. |
| Item `blocked` | Reply with the missing decision using `campaign reply`; do not reselect. |
| Items that depend on earlier code | Warn: every item starts from the rig's main; accepted branches are not chained. |
| Repeated `Rejected <bead>` | Read the gate logs; suggest a steering reply or a stronger Mayor. |

## Execution Steps

1. Observe: `gastown-run campaign status <p>`, `gastown-run swarm usage <p>`, tail `notifications.jsonl`.
2. Act with the commands in `references/operations.md`.
3. Report phase, items by status, new notifications in plain words, tokens by role, and the one thing the user must decide.

## Output Contract

Lead with the state and the next action. Name every unverified claim as unverified. List only decisions that are the user's.

## References

- `references/operations.md` — commands, state files, notification glossary and known traps.
