---
name: tool-adoption
description: "Trigger: new tool, CLI, MCP, worth it, tool exploration, try tools, coexist, replace, consolidate. Evaluate fit and learning without a replacement bias."
license: MIT
metadata:
  author: "glats"
  version: "1.4"
---

## Activation Contract

Use for external tools, repositories, CLIs, MCPs, skills, apps, viewers, or
services: evaluating adoption, exploring capabilities, or coexisting with
current tools. Explore before proposing or installing.

## Hard Rules

- Follow the user's goal: replace, consolidate, add capability, learn, or
  coexist. Ask only when an unresolved choice changes the next safe step.
- Name the baseline and what stays unchanged. Mark unmeasured costs unknown;
  judge new capabilities against the goal, not only today's workflow.
- Value learning and user-accepted parallel maintenance. Retiring assets is a
  benefit, not a prerequisite; novelty alone is not proof. `keep` and `reject`
  remain successful outcomes.
- Distinguish isolated or complementary stacks from overlapping tools sharing
  state or authority. Name ownership, recurring costs, permissions, and exit;
  do not veto coexistence solely because it adds maintenance.
- Research before repository code: Context7, GitHub, Exa, and `nix_versions`
  from the nixos MCP. Missing evidence is unknown, not inferred support or safety.
- Keep initial evaluation read-only: no upstream `init`, installers,
  `curl | sh`, or `npx @latest`. Review generated instructions before copying.
  Require explicit trial or implementation approval; activation stays separate.

## Decision Gates

| Finding | Decision |
| --- | --- |
| Replacement goal; evidence beats baseline and cost is accepted | `replace`, narrowly, reversibly, and pinned. |
| Consolidation goal; retires multiple assets without losing required capability | `consolidate`; report savings. |
| New capability or intentional coexistence serves the goal | Propose `hybrid`; name each role, isolation or shared boundary, owner, cost, and exit. |
| User wants exploration, or value/composition is unmeasured | Propose an isolated trial, even with documentation or overlapping features; do not demand proven superiority first. |
| Evidence meets only the learning goal, or added cost has no value toward the goal | `keep` with findings, or `reject` with reasons; no adoption required. |
| Security, target-platform, or ownership blocker | `defer` the affected scope; offer a narrower trial only if it avoids the blocker. |
| Independent lifecycle or risk profile | Separate change, not automatic rejection. |

## Execution Steps

1. Establish intent and canonical upstream, release, license, and install
   surface. Separate marketing, source evidence, and runtime observations.
2. Inspect pinning, updates, telemetry, processes, listeners, GUI needs, network,
   local state, filesystem access, secrets, and open security issues.
3. Map distinct integration classes: skills, MCPs, Home Manager packages,
   services, and Go-only helpers under `pkgs/nixos-scripts/`. Check target hosts
   first; report Linux and arm64-darwin coverage without requiring every host
   for a deliberately host-scoped pilot.
4. Compare workflow, capability, learning, maintenance, and exit costs. State
   where the baseline wins. Use `references/isolated-trial.md` for approved
   experiments; findings never authorize adoption.
5. Delegate a read-only explorer only beyond the bounded mapping budget.
   Compare package-only, isolated pilot, managed integration, and no change
   proportionately; include target evaluation and rollback when proposing changes.
6. Edit skill sources only in `shared/assets/skills/`, never installed copies:
   `ai-assets-reconcile` refuses modified collisions. Use each target's separately
   authorized activation workflow; Linux `nixos-build test` is not universal.

## Output Contract

Return the user's goal, canonical source, baseline, evidence and unknowns,
and one provisional or supported verdict: `replace`, `consolidate`, `hybrid`,
`keep`, `defer`, or `reject`. Include benefits, costs, boundaries, integration
class, affected paths/hosts, and the smallest next step with required approval.
Give re-entry conditions for baseline-winning `keep` or blocked `defer` decisions.
A trial is an instrument, not adoption; name its learning question and exit.

## References

Paths are relative to the repository root unless noted.

- `AGENTS.md` — repository architecture, Go-only policy, and Nix verification.
- `docs/rtk-pilot.md` — runtime-output and local-state risk analysis.
- `docs/browser-mcp-setup.md` — MCP and browser boundary example.
- `shared/ai-mcps.nix` — shared MCP inventory source.
- `references/isolated-trial.md` — trial boundaries, probes, and examples;
  relative to this skill directory.
