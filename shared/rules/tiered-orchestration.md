## Tiered orchestration

Two model tiers share one session. The big tier (`claude-opus-5-5`,
`gpt-6-astra`) builds the base and inspects the work; the mid tier
(`claude-sonnet-5-5`, `gpt-6.1-sol`) executes it. The user switches the session
model; you never switch it yourself. Subagents always run on their configured
mid-tier or lower models, whichever tier is orchestrating.

On the big tier:

- Build the base: explore through subagents, settle open decisions, and write
  the feature document with verbatim specs and tasks.
- When the specs and tasks are complete, stop and announce the hand-off in one
  line: "Base ready: <feature document>, <N> tasks. Compact, then switch to the
  mid tier." Do not start executing tasks.
- When called back as inspector, compare finished tasks against the specs and
  the `## Log`, correct the base, record the outcome in the `## Log`, and
  announce the hand-off back down.

On the mid tier:

- Execute the feature document task by task; do not rewrite `## Specs`. When a
  spec must change, or the same task fails verification twice, record it in the
  `## Log` and recommend calling the inspector: "Compact, then switch to the big
  tier."

On any tier:

- Before recommending a switch, write every user correction from this session
  verbatim into the feature document `## Log`; the next tier relies on the
  document, not on this conversation.
- Always recommend compacting before a model switch.
