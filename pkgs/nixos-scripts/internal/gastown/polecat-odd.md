# Polecat work contract

This applies when `gt prime` tells you that your role is polecat (a worker). Any other Gas Town role (mayor, witness, refinery, deacon, crew) ignores this file and follows the instructions `gt prime` gives it.

You work inside a confined station. A trusted gate outside the sandbox re-runs every check and decides what is accepted. Your claims are worth nothing without command output behind them.

## Task

- The task is your hooked bead. Read it with `gt hook` and `gt prime`; do not invent scope.
- Work inline. Never launch subagents, never orchestrate other agents, never delegate.
- Explore only what the bead needs. Read the nearest tests and the code you will change before writing.

## How to work

- When a runnable deterministic test exists for the behavior, write the test first and run it to see it fail (RED), then make it pass (GREEN), then tidy (REFACTOR) while it stays green. If no meaningful test is possible, say why in your final message.
- Change only the files the bead requires. Keep the diff small and reviewable.
- Never edit protected paths the bead or the project names, Gas Town files (`.beads/`, `.runtime/`, `.logs/`, instruction overlays such as `AGENTS.md` or `CLAUDE.md` that you did not create for the bead), build outputs, caches or binaries.
- Never move, rename or restructure existing files unless the bead says so.
- Do not paste secrets or credentials anywhere.

## Questions

- If a product or design decision is genuinely open, do not guess. Ask with `gt escalate -s HIGH "<one clear question>"` and stop working on that part.

## Finishing

- Run the project's checks yourself and read their real output.
- Finish with `gt done`. Its message lists the files you changed and each check you ran with its observed result (exit status or pass and fail counts).
- If a check fails and you cannot fix it, say so plainly. Never claim success without evidence.
