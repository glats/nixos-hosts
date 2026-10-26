# Isolated Trial

Use this instrument when the candidate does not compose with the current harness
but could still change the workflow, or when documentation cannot answer what
the candidate side actually costs. The trial measures; it never adopts.

## Boundary

- Root: a scratch directory outside the repository (`~/trials/<tool>` or
  `/tmp/opencode/trial-<tool>`), never a working tree, never `shared/`.
- State: redirect `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and
  `XDG_STATE_HOME` into the root, or run inside a container that mounts only
  that directory.
- Denied: sops material, writes under `shared/` or `hosts/`, profile activation
  on any host, permanent user services, and listeners bound beyond loopback.
- Probe input: three real tasks taken from the current logbook, not synthetic
  demos.

## Probes

Reproduce steps of the existing workflow, not the tool's own tutorial: spec
authoring, one bounded delegation, and focused verification. For each, record
`native`, `manual glue`, or `impossible`, plus the steps it took against the
measured baseline.

## Kill condition and teardown

Stop immediately if the candidate needs a permanent daemon, writes outside the
trial root, requests repository-wide configuration, or requires secrets.
Teardown is `rm -rf` of the root, then verify no user units, no listening
ports, and a clean `git status` in the repository. A trial that became permanent
through inertia is a failed trial.

## Workflow diff

Return one table: workflow step, baseline cost, candidate cost, glue required,
and verdict for that step. The diff is the deliverable; the comparison it feeds
decides `replace`, `consolidate`, `hybrid`, or `keep`.

## Worked example

An external agent harness that ships its own permission model, project-scoped
configuration directory, and background daemon composes with nothing here: it is
not a skill, not an MCP entry in `shared/opencode/mcps*.nix`, not a Home Manager
package, and not a Go helper. Installing it inside `~/.nixos` would put two
harnesses over one workspace.

The trial instead uses a throwaway repository under `~/trials/<tool>` with three
tasks from the logbook, redirected XDG roots, a loopback-only listener allowed,
and sops plus `shared/` unreachable. The probes show which parts of the current
flow are harness-specific and which are portable, and that split feeds the
comparison. A passing trial still requires a separate adoption proposal.
