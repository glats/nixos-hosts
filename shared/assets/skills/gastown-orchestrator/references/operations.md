# Operations

Swarm state lives in `~/.local/state/gastown/swarm/<project>/`: `campaign.json` (memory), `notifications.jsonl`, `watch.json`, `ledger.jsonl` (tokens), `staging.git` (accepted branches), `gate-logs/`.

## Commands

| Goal | Command |
|---|---|
| Plan and run an intent (resumes if saved) | `gastown-run campaign start <p> "<intent>"` |
| Pick items | `gastown-run campaign reply <p> "a c"` or `all` |
| Answer a Mayor question | `gastown-run campaign answer --question <id> <p> "<text>"` |
| Steer running work | `gastown-run campaign reply <p> "<instruction>"` |
| Status, tokens | `gastown-run campaign status <p>`, `gastown-run swarm usage <p>` |
| Approve an item you reviewed | `gastown-run campaign approve <p> <item> gastown/<bead>...` (refused unless the gate accepted every branch) |
| Add items for a new direction | `gastown-run campaign extend <p> "<direction>"` |
| Let it pick items that need no decision | `gastown-run campaign autopilot <p> on` (at most 3 active; `off` to stop) |
| Finish a blocked item whose branches the gate accepted | `gastown-run campaign retry <p> <item>` (mechanical; says so in the record) |
| Add accepted branches to the base by hand | `gastown-run campaign advance <p> gastown/<bead>...` |
| Stop (state kept) | `gastown-run campaign stop <p>` |
| One-off goal without a campaign | `gastown-run swarm run --goal "<text>" <p>` |
| Models alive before spending | `gastown-run swarm check <p>` |

Replies are queued as files and read by the supervisor on its next round (20 s plus the round itself); confirm in `campaign.json` instead of assuming.

## Notifications

| Title | Meaning |
|---|---|
| Campaign plan ready | Process, questions and items proposed; waits for the user. |
| Item started / verified | Goal sent / a gate-accepted branch exists. |
| Ready for review | A branch passed the checks; fetch it from `staging.git`. |
| Rejected `<bead>` | The gate refused the branch; logs in `gate-logs/<bead>`. |
| Item blocked | No verified result and no activity for 30 minutes, or a decision is missing. |
| Mayor (unverified) | A model claim, not a fact. |
| Accepted branches conflict | Parallel branches touch the same lines; merge by hand from staging. |
| Answer kept as a note | The answer matched no single question; resend with `--question`. |

## Known traps

- `campaign start` and `swarm run` block until the unit ends (`--wait`); run them in the background and watch `notifications.jsonl`. Killing the client leaves the unit running.
- If every branch is rejected, suspect the gate environment before the workers: compare `gate-logs/<bead>/check-N.stdout` with the same check run in the gate's bwrap.
- To change checks, stop the swarm, edit `swarm.json`, reset blocked or running items to `selected` in `campaign.json`, remove stale failed entries from `watch.json`, and keep a backup.

- Boot dog and refinery escalations are Gas Town infrastructure noise.
- `swarm check` does not probe codex or claude agents (subscription quota).
- An older `gastown-run` rewrites `campaign.json` without fields it does not know (for example `autopilot`); run the supervisor with the newest binary and check the flag after a handoff.
- `swarm init` cannot be repeated on an existing project; changing the Mayor means removing its state directory, only when nothing ran.
- A power loss mid-item leaves it `running` until it is marked blocked; resume with `campaign start`, then reply to re-send it.
