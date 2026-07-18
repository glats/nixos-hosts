## SDD Review Gate (MANDATORY)

After every `sdd-apply` phase completes, the orchestrator MUST present the review decision with EXACTLY 3 options:

1. **done** — proceed to verify, then archive
2. **retry** — re-apply via delegated `sdd-apply` sub-agent. Do NOT do inline edits, reads, or fixes. Launch a fresh sub-agent with the same spec, design, and tasks.
3. **reiterate** — re-explore via delegated `sdd-explore` sub-agent, then full SDD cycle. Do NOT do inline exploration or planning. All phases run via sub-agents.
