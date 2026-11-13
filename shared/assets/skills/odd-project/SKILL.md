---
name: odd-project
description: "Trigger: project-wide ODD, guiar proyecto, desarrollar con Gas Town. Understand the project and guide the user from discovery to verified deliveries."
license: MIT
metadata:
  author: "glats"
  version: "1.2"
---

## Activation Contract

Use when guiding a user through developing a whole project with ODD and Gas
Town. Understand how the project works before planning implementation. Treat
the product as the scope, not its first delivery. Skip isolated small changes.

## Hard Rules

- Inspect existing vision, roadmap, logbooks, repository policy and Git state
  first. Reuse authoritative documents; never create competing task ledgers.
- Preserve original intent and history. Quote user requirements verbatim; label
  assumptions. Never silently convert OpenSpec or mark inherited work complete.
- Keep one parent roadmap for direction, capabilities, dependencies and delivery
  boundaries. Give each selected feature one owner document for tasks and proof.
  Epics describe coverage, not parallel work queues.
- Expand only the next selected delivery or feature. Name future capabilities
  without empty task files, speculative implementation or a giant backlog.
- Use ODD for direction and continuity, Gas Town for implementation, and the
  agent for discovery, guidance and orchestration. The user owns product
  decisions. Never duplicate swarm implementation or hardcode model choices.
- Link campaign/item IDs to feature tasks; retain one acceptance ledger.
  Follow installed `gastown-kickoff` and `gastown-orchestrator` skills for
  operations. Verify current capabilities; do not copy stale CLI recipes.
- Plans, checkpoints, memory and passing tests grant no permissions. Preserve
  repository rules and separate user acceptance from technical verification.

## Decision Gates

| Situation | Action |
| --- | --- |
| Existing plan covers the product | Extend it; retain stable IDs and links. |
| Only a first slice is documented | Add a parent map linking that slice without rewriting its history. |
| Scope or acceptance needs a product choice | Ask one focused question and wait. |
| Finished work leaves decisions for the user | Read them, brief, and close them one by one with the native question tool: `references/decision-review.md`. |
| Evidence is missing or contradictory | Mark affected work pending; preserve both accounts. |
| Gas Town is unavailable or its checks fail | Report the blocker; do not silently replace it or weaken checks. |
| Memory is unavailable | Keep local continuity and mark the mirror pending. |

## Execution Steps

1. Discover users, goals, terminology, real workflows, inputs, outputs,
   exceptions and constraints from existing documents, code and user examples.
   Trace a representative case end to end. Distinguish evidence from assumptions;
   research named gaps and ask one consequential question at a time. Explain
   your understanding in plain language; resolve material uncertainty before build.
2. Map product → delivery → feature → next task/decision. Use `odd/roadmap.md`
   and `odd/tasks/<feature>.md` only when no authoritative equivalent exists.
   Define delivery acceptance as an observable user outcome.
3. Record selected requirements, dependencies, checks and task IDs using the
   active ODD feature format. Guide the user toward the smallest useful delivery,
   explaining tradeoffs and acceptance. Keep future work named but unexpanded.
4. Load `gastown-kickoff` for a new campaign and `gastown-orchestrator` for an
   existing one. Check existing state before initialization. Prepare the intent
   from agreed workflows, non-goals, protected paths, dependencies and acceptance;
   verify checks in the actual gate environment. Preserve model/cost choices
   and obtain missing execution consent before starting.
5. Operate authorized work continuously: inspect campaign state and gate
   evidence, answer technical questions from established decisions, and bring
   only unresolved product or consent decisions to the user. Present a usable
   delivery with a concrete review walkthrough; gate acceptance is not user
   acceptance. Close the open decisions interactively, one question at a time
   (`references/decision-review.md`). Record feedback and carry it into the next selected work.
6. Maintain a named current checkpoint: completed work and evidence, active
   selection, pending decisions, exact next safe step, retained scope,
   authorization limits, Git branch/commit, campaign/item IDs and recovery locations.
7. Log scope corrections verbatim; change only affected requirements and reopen
   their tasks. Resolve incidents without losing the original objective.
8. Mirror canonical documents when project memory is available. Discover its
   project identity, store full content and locator, then read back both copies
   before claiming synchronization. Never overwrite a conflicting mirror.
9. Resume by reconciling checkpoint, documents, memory, Git and campaign state.
   Reuse valid evidence; do not redo finished work or infer acceptance from tests.

## Output Contract

Explain what the project does, the selected delivery, what Gas Town has actually
verified, what the user can try, and the next step or real decision. Include the
checkpoint locator; label unverified claims, pending checks and mirrors honestly.
