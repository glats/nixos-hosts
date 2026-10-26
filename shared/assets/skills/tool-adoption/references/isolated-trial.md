# Isolated Trial

Use this instrument for user-requested learning, new capabilities, intentional
coexistence, uncertain composition, or costs that documentation cannot answer.
A documented tool that overlaps the baseline can still merit exploration.
The trial produces evidence; it never adopts.

## Intent and approval

Name the question the trial should answer, its scope, a time or resource budget,
and an exit condition. Use the user's stated goal rather than requiring a
replacement benefit. Learning can be the entire result.

Propose the boundary before execution and obtain explicit approval. Interest in
a tool is not permission to install it, access credentials, activate a profile,
or leave a service running. If the goal is clear, propose the smallest useful
experiment rather than asking the user to design the infrastructure.

## Boundary

- Root: a scratch directory outside the repository (`~/trials/<tool>` or
  `/tmp/opencode/trial-<tool>`), never a working tree, never `shared/`.
- State: redirect `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and
  `XDG_STATE_HOME` into the root. Redirection organizes state; it is not a
  security sandbox. Use a container or VM when the execution risk requires it,
  with only approved trial mounts and bounded resources.
- Denied: sops material, writes under `shared/` or `hosts/`, profile activation
  on any host, permanent user services, and listeners bound beyond loopback.
  Do not share the user's home, credentials, browser profile, or runtime state.
- Processes: a temporary foreground or background process may run within the
  approved boundary and budget, with an explicit stop procedure; it must not
  become an installed or automatically restarting service.
- Probe input: a small set of user-relevant tasks. Reuse the current logbook for
  replacement comparisons; use bounded new tasks for exploration. A new
  capability need not already exist in the current workflow.

## Probes

For replacement, reproduce actual workflow steps, such as spec authoring, one
bounded delegation, and focused verification, rather than following only the
tool's tutorial. For learning or coexistence, test the requested capability and
whether the existing stack remains unaffected. Keep synthetic inputs confined
to safe demonstrations of that capability; do not present them as production
proof.

For each probe, record the question, observed result, `native`, `manual glue`,
or `impossible`, and the measured steps or resources. Mark absent baselines
`not applicable` and unmeasured costs `unknown`; do not invent comparisons.

## Kill condition and teardown

Stop if the candidate exceeds its approved boundary or budget, needs permanent
service installation, writes outside trial-owned state, requests repository-wide
configuration, or requires secrets. Record the blocker and propose a narrower
probe or a separately authorized change; do not silently expand permissions.

Stop trial-owned processes, remove only confirmed trial-owned artifacts under
the approved cleanup scope, and verify no leftover trial units or listeners and
an unchanged repository status. Preserve pre-existing user work and services.
A trial that became permanent through inertia is a failed trial.

## Findings and recommendation

Return one table: goal or workflow step/probe, baseline cost where applicable,
candidate cost, glue required, and per-probe verdict. Include observed benefit
or learning and remaining uncertainty. Report cleanup and whether the baseline
remained unchanged.

Use the skill's verdicts: `replace`, `consolidate`, `hybrid`, `keep`, `defer`, or
`reject`. Learning without adoption is a successful `keep` outcome. Intentional
coexistence may support a `hybrid` proposal without retiring any asset; name
each tool's role, state and permission boundaries, recurring maintenance owner,
and rollback. An unmeasured benefit is not proven value or proof of no value.

## Worked examples

An external harness with its own permissions, project configuration, and daemon
has a separate lifecycle, not automatic incompatibility. Compare it in a
throwaway repository with real workflow probes, redirected state, an approved
temporary loopback process, and appropriate isolation. Do not install it over
the active workspace. Record portable behavior and harness-specific glue.

A user may instead want a companion alongside existing coding agents to explore
scheduled research. Keep those agents unchanged; probe scheduling and result
retrieval using public data in the approved isolated environment. Retiring zero
tools is acceptable. The result may justify a separate integration proposal or
simply answer the learning question. Neither result authorizes deployment.
