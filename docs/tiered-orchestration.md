# Tiered orchestration

A big-tier model builds the base of the work and acts as its inspector. A
mid-tier model executes it. You bring the inspector back whenever the work may
be going off track. The feature document is the bridge between the two tiers,
and the context is kept small so every switch is cheap.

| Tier | Models | Job |
| --- | --- | --- |
| Big | `claude-opus-5-5` (`gpt-6-astra` when Claude is out) | Orchestrator only: write the feature document, then inspect that the work stays on track |
| Mid | `claude-sonnet-5-5` or `gpt-6.1-sol` | Orchestrator while executing the tasks |

The big tier only ever runs as the orchestrator. Every subagent (explore,
worker, verify, review and judgment roles) runs on the mid tier or below, even
while the big tier is orchestrating.

Your part is three actions: **compact, switch model, decide when to call the inspector**.
The agent proposes the hand-off, keeps the log current and follows the document.

## New work

1. Open a session in the herdr worktree. It starts on the big tier.
2. The big tier delegates mapping to the explore subagent (mid tier or below),
   decides, and writes `odd/tasks/<feature>.md`: specs quoted
   verbatim, tasks, and the log.
3. The agent says the base is ready and proposes the hand-off.
4. Compact, then switch to the mid tier in the model picker.
5. The mid tier runs the tasks one by one until the feature is done.

## Work already in progress

1. Resume the session, or open a new one if the old one is very large.
2. Compact first.
3. Pick the tier from the state of the base:

| Base state | Tier |
| --- | --- |
| Solid; only tasks remain | Mid tier resumes at the next unfinished task |
| Outdated, or the work drifted | Big tier reads the document and log, fixes the base, hands back |
| No feature document exists | Big tier writes it from what exists before anything else |

## Calling the inspector

The big tier comes back to inspect, not to take over the execution. It compares
the work done against the specs and the log, corrects the base, and hands back.

Call it when the mid tier:

- repeats a mistake you already corrected;
- fails the same verification twice;
- proposes work the specs do not ask for;
- loses track of the task it is on.

Then:

1. Tell the agent what is wrong. It writes your correction verbatim into the
   document `## Log` first, because anything left only in the chat is lost.
2. Compact.
3. Switch to the big tier. It reads the document, checks the finished tasks
   against the specs, fixes the base and proposes the hand-off back down.

You can also call it without a symptom, for example after a few finished tasks,
as a routine check that nothing drifted.

## Rules of thumb

| Rule | Why |
| --- | --- |
| Always compact before switching | The new model rereads only the summary, not the whole history |
| Keep the context near 200k | Very large contexts (400k-800k) cost quota on every turn and dilute focus |
| Corrections go into the log | The document is what survives compaction and switches |
| The big tier plans and inspects, it does not execute | Running tasks on the scarce tier wastes it; its value is keeping the work on track |

## Role models

One profile per environment, all built with the same rule: big-tier
orchestrator, mid-tier-or-below subagents, verify from another family than the
worker.

| Profile | Orchestrator | Explore | Worker | Verify, review, judges |
| --- | --- | --- | --- | --- |
| `personal` | `claude-opus-5-5` | `deepseek-v4-pro` | `minimax-m3.1-flash` | `gpt-6.1-sol` |
| `personal-claude` | `claude-opus-5-5` | `claude-sonnet-5-5` | `claude-haiku-5-5` | `claude-sonnet-5-5` (same family: no other provider) |
| `work` | `claude-opus-5-5` (Anthropic) | Copilot `claude-sonnet-5.5` | Copilot `claude-haiku-5.5` | Copilot `gpt-6.1-sol` |

`gpt-6-luna` is not used for worker or explore.

## Gas Town

Campaigns follow the same split: the Mayor runs on the big tier, polecats on the
mid tier or the worker model. Their chains come from the active OpenCode
profile instead of being picked by hand per campaign.

## Status

Active on `rog` after `nixos-build switch`:

| Part | Where |
| --- | --- |
| Orchestrator rule: hand-off announcements, log before switching | `shared/rules/tiered-orchestration.md` |
| New sessions start on the profile orchestrator | root `model` in `shared/opencode/runtime-config.nix` |
| Compaction near 200k on 1M-window models | `home.opencode.compactionBuffer = "80%"` in `hosts/rog/home/default.nix` |
| Haiku worker and fix agent | `personal-claude` in `shared/opencode/providers-base.nix` |
| Gas Town chains from the profile | `linux/home/gastown-campaigns.nix` |

Profiles are per environment: `personal` (Anthropic, OpenAI, Ollama) on t14,
samsung and thinkcentre; `personal-claude` (Anthropic only) on rog while the
other quotas are exhausted; `work` (Anthropic orchestrator, Copilot subagents)
on macm5. Every host gets the rule and the root `model`; only rog sets the
compaction buffer.
