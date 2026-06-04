---
description: Write detailed specifications from a proposal
agent: sdd-orchestrator
---

Write specifications for the change named "$ARGUMENTS".

WORKFLOW:
1. Launch sdd-spec sub-agent to create specs.md based on the proposal
2. Present the specification summary to the user
3. Ask if they want to proceed to design phase

CONTEXT:
- Working directory: !`echo -n "$(pwd)"`
- Current project: !`echo -n "$(basename $(pwd))"`
- Change name: $ARGUMENTS
- Artifact store mode: engram

ENGRAM NOTE:
The spec artifact is saved automatically by the sub-agent with topic_key "sdd/$ARGUMENTS/spec".

Read the orchestrator instructions to coordinate this workflow. Do NOT write specs inline — delegate to sdd-spec sub-agent.
