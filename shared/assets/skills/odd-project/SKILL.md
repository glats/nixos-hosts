---
name: odd-project
description: "Trigger: project-wide ODD, whole-project roadmap, epics, entregas, checkpoints, organizar proyecto. Preserve direction and continuity across deliveries."
license: MIT
metadata:
  author: "glats"
  version: "1.0"
---

## Activation Contract

Use when organizing a whole project with ODD or resuming its roadmap across
sessions. Treat the product as the scope; its first delivery is not the product.
Do not create project-wide machinery for an isolated small change.

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
- Keep planning separate from execution. ODD may coordinate direct work or a
  swarm; require neither a particular tool nor a model. Link execution IDs to
  feature tasks instead of copying their status into another queue.
- Plans, checkpoints, memory and passing tests grant no permissions. Preserve
  repository rules and separate user acceptance from technical verification.

## Decision Gates

| Situation | Action |
| --- | --- |
| Existing plan covers the product | Extend it; retain stable IDs and links. |
| Only a first slice is documented | Add a parent map linking that slice without rewriting its history. |
| Scope or acceptance needs a product choice | Ask one focused question and wait. |
| Evidence is missing or contradictory | Mark affected work pending; preserve both accounts. |
| Memory is unavailable | Keep local continuity and mark the mirror pending. |

## Execution Steps

1. Establish the product outcome, non-goals, current evidence and authorized
   scope. Identify the existing plan of record before choosing new paths.
2. Map product → delivery → feature → next task/decision. Use `odd/roadmap.md`
   and `odd/tasks/<feature>.md` only when no authoritative equivalent exists.
   Define delivery acceptance as an observable user outcome.
3. Record selected requirements, dependencies, checks and task IDs using the
   active ODD feature format. Keep future work named but unexpanded.
4. Maintain a named current checkpoint: completed work and evidence, active
   selection, pending decisions, exact next safe step, retained scope,
   authorization limits, Git branch/commit and recovery document locations.
5. Log scope corrections verbatim; change only affected requirements and reopen
   their tasks. Resolve incidents without losing the original objective.
6. Mirror canonical documents when project memory is available. Discover its
   project identity, store full content and locator, then read back both copies
   before claiming synchronization. Never overwrite a conflicting mirror.
7. Resume by reconciling the checkpoint, documents, memory and Git state.
   Reuse valid evidence; do not redo finished work or infer acceptance from tests.

## Output Contract

Give a short status: product direction, selected delivery, verified outcome,
real blocker or next step, and checkpoint locator. Ask only for decisions that
change scope or require consent. State pending checks and mirrors honestly.
