## SDD Review Gate (MANDATORY)

After every `sdd-apply` phase fully completes, the orchestrator **MUST** present the Review Gate with **exactly 3 options**:

1. **done** — proceed to verify, then archive  
2. **retry** — re-apply via a fresh delegated `sdd-apply` sub-agent (launch a new clean sub-agent with the same spec, design, and tasks). Do NOT do inline edits, reads, or fixes with the feedback provided by the user.  
3. **reiterate** — re-explore via a delegated `sdd-explore` sub-agent, then run a full SDD cycle. Do NOT do inline exploration or planning with the feedback provided by the user.
