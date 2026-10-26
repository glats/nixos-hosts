---
name: tool-adoption
description: "Trigger: new tool, new CLI, new MCP, does it fit, worth it, replace, consolidate. Compare against the current harness before adopting."
license: MIT
metadata:
  author: "glats"
  version: "1.3"
---

## Activation Contract

Load when the user brings an external tool, repository, CLI, MCP, skill, app,
viewer, or service and asks whether it fits, whether it is worth it against the
current harness, or whether it should replace, consolidate, or sit alongside
what exists. Explore before proposing or installing.

## Hard Rules

- Name the baseline first: the assets the candidate would replace, consolidate,
  or sit beside, what each costs today, and where it wins. No named baseline, no
  verdict.
- Count retired assets as savings: maintenance surface removed outweighs
  features added.
- A hybrid needs the highest bar: two tools on one slice create a seam paid for
  indefinitely.
- `keep` and `reject` are successful outcomes, never failed research.
- Research before reading repository code: Context7, GitHub, Exa, and
  `nix_versions` from the `nixos` MCP for package availability. Record missing
  sources as unknown; never infer APIs, security, or platform support.
- Do not run upstream `init`, installer, `curl | sh`, or `npx @latest` commands
  here during evaluation, and do not copy generated agent instructions without
  reviewing their behavior and ownership model.
- Check license, pinning, update and telemetry behavior, listeners, local state,
  filesystem reach, secret exposure, open security issues, and Linux plus
  arm64-darwin support.
- Keep skills, MCPs, user packages, services, and operational helpers as distinct
  integration classes; helpers remain Go only.

## Decision Gates

| Finding | Decision |
| --- | --- |
| Beats the baseline on its slice, cost is paid, reversible | `replace`, narrowly and pinned. |
| Retires two or more assets without losing capability | `consolidate`; report maintenance removed. |
| Wins one slice, loses another | `hybrid` only with a named seam owner and recurring cost; else `keep`. |
| Baseline wins, or the gain is sporadic while its cost is recurring | `keep`; record why and the re-entry condition. |
| Does not compose but the flow may still win | Run an isolated `trial`, then re-run the comparison. |
| Unresolved security, portability, or ownership blockers | `defer` with concrete re-entry conditions. |
| Duplicates capability with no measurable gain | `keep`; do not adopt. |
| Needs another lifecycle or an independent risk profile | Split into a separate change. |

## Execution Steps

1. Identify the canonical upstream repository, release, license, and install
   surface; separate marketing claims from source behavior.
2. Measure the baseline as it exists today: steps per task, time, failure modes,
   and the maintenance the named assets already cost.
3. Map the candidate: skills (`.atl/skill-registry.md`, `shared/assets/skills/`),
   MCPs (`shared/opencode/mcps*.nix`), Home Manager packages, Go helpers
   (`pkgs/nixos-scripts/`), and host deployment to rog, thinkcentre, t14, and
   macm5.
4. Inspect runtime boundaries: processes, ports, GUI needs, network calls,
   telemetry, update checks, emitted artifacts, and read/write scope.
5. Compare capability, workflow, maintenance, adoption cost, portability across
   the four hosts, and exit cost. State where the baseline wins.
6. Measure the candidate with `references/isolated-trial.md` when documentation
   cannot answer; the trial produces evidence, never adoption.
7. Delegate one read-only explorer when mapping exceeds a bounded batch;
   otherwise explore inline. Compare package-only, managed integration, and no
   change; include the host evaluation command and rollback.
8. Propose from read-only evidence; require explicit approval before
   implementation. Implementation approval does not authorize activation.
9. Keep skill sources in `shared/assets/skills/`; never hand-edit installed
   copies, because `ai-assets-reconcile` refuses modified collisions. Activation
   stays separately authorized through each target's existing workflow; Linux
   `nixos-build test` does not apply to every host.

## Output Contract

Return the canonical source and one verdict: `replace`, `consolidate`,
`hybrid`, `keep`, `defer`, or `reject`. State the baseline assets and their
measured cost, the dimension where the baseline wins, the integration class,
affected paths, evidence-backed risks, platform coverage, and whether it belongs
in a separate change. A `trial` is an instrument, not a verdict.

## References

Paths are relative to the repository root unless noted.

- `AGENTS.md` — repository architecture, Go-only policy, and Nix verification.
- `docs/rtk-pilot.md` — runtime-output and local-state risk analysis.
- `docs/browser-mcp-setup.md` — MCP and browser boundary example.
- `shared/opencode/mcps.nix` — current MCP inventory source.
- `references/isolated-trial.md` — trial boundary, probes, teardown, and a
  worked example; relative to this skill directory.
