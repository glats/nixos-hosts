#### Review Gate (MANDATORY)

After every `sdd-apply` slice returns and before launching any subsequent
`sdd-apply` or `sdd-verify`, the orchestrator MUST present the review decision.
This gate MUST NOT be skipped regardless of apply outcome.

Do NOT attempt to locate a pre-existing review artifact. Instead, ALWAYS
present this question directly via an interactive prompt, with EXACTLY three
options:

1. **done** — verify -> archive. The change is correct.
2. **retry** — re-apply only, no re-explore. Same spec, same design. Small fix.
3. **reiterate** — full SDD cycle from explore. Large rework, needs rethinking.

Record the chosen verdict as the review artifact.

Do NOT offer a fourth option. Do NOT auto-advance. Do NOT launch `sdd-verify`
unless the verdict is `done`.
