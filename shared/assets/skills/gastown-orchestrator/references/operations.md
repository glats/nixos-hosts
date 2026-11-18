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
| Provider limit on `<agent>` | The agent (or its one-word probe, every 30 min) hit a usage limit; it cools for 30 minutes. High severity: tell the user. |
| Agent unavailable: `<agent>` | The probe failed for another reason (end of life, 404, no login). |
| All providers are limited | Every worker agent is out; dispatch is paused. Critical: tell the user now. |
| Provider recovered on `<agent>` | The probe answers again; dispatch resumes when any agent is healthy. |

## Known traps

- `campaign start` and `swarm run` block until the unit ends (`--wait`); run them in the background and watch `notifications.jsonl`. Killing the client leaves the unit running.
- If every branch is rejected, suspect the gate environment before the workers: compare `gate-logs/<bead>/check-N.stdout` with the same check run in the gate's bwrap.
- To change checks, stop the swarm, edit `swarm.json`, reset blocked or running items to `selected` in `campaign.json`, remove stale failed entries from `watch.json`, and keep a backup.

- Boot dog and refinery escalations are Gas Town infrastructure noise.
- `swarm check` does not probe codex or claude agents (subscription quota).
- A monthly provider limit makes workers die right after launch with nothing in the pane, so the pane check never sees it. Only the probe does; the Mayor will blame the scheduler.
- `opencode:openai/<model>[:<effort>]` reads its login from the swarm's own agent home, never from the user's. Sign in once with `HOME=<state>/swarm/<p>/town/.agent-home opencode auth login openai` (a browser step that belongs to the user), then `swarm check <p>`. Copying the user's credential would let two clients rotate one refresh token.
- A campaign declared in Nix (`home.gastown.campaigns.<p>`) with `chainsFromProfile` (the default) takes its chains from the active OpenCode profile at every start, so a manual `chains` edit is overwritten: change the profile or turn the option off for that campaign. `docs/gastown.md` lists the mapping.
- Changing agent chains means editing `chains` in `swarm.json` with the supervisor stopped, then restarting it with a binary that knows the provider. Older supervisors never rewrote `town/settings/agents.json` (only written at init): every dispatch then fell back to `claude` (exit 127) and the item hit the scheduler circuit breaker. Newer ones sync it each round and notify `Agent registry updated`. With an older binary, add the presets by hand, then ask the Mayor to reset the breaker and re-sling. "Running" is proven by `swarm status` listing a working polecat, not by a live service.
- An older `gastown-run` rewrites `campaign.json` without fields it does not know (for example `autopilot`); run the supervisor with the newest binary and check the flag after a handoff.
- `swarm init` cannot be repeated on an existing project; changing the Mayor means removing its state directory, only when nothing ran.
- A power loss mid-item leaves it `running` until it is marked blocked; resume with `campaign start`, then reply to re-send it.
