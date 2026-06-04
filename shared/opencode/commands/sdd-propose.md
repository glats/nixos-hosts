---
description: Create a change proposal from exploration findings
agent: sdd-orchestrator
---

Create a proposal for the change named "$ARGUMENTS".

WORKFLOW:
1. Launch sdd-propose sub-agent to create a proposal.md based on previous exploration
2. Present the proposal summary to the user
3. Ask if they want to proceed to spec and design phases

CONTEXT:
- Working directory: !`echo -n "$(pwd)"`
- Current project: !`echo -n "$(basename $(pwd))"`
- Change name: $ARGUMENTS
- Artifact store mode: engram

ENGRAM NOTE:
The proposal artifact is saved automatically by the sub-agent with topic_key "sdd/$ARGUMENTS/propose".

Read the orchestrator instructions to coordinate this workflow. Do NOT create the proposal inline — delegate to sdd-propose sub-agent.
