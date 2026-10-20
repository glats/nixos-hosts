---
name: tool-adoption
description: "Trigger: new tool, add tool, evaluate tool, new CLI, new MCP, new skill, does it fit, integrar herramienta. Research and classify external tools before adopting them."
license: MIT
metadata:
  author: "glats"
  version: "1.2"
---

## Activation Contract

Load when the user brings an external tool, repository, CLI, MCP, skill, app,
viewer, or service and asks whether it fits this harness. Explore before
proposing or installing anything.

## Hard Rules

- Research before reading repository code: use Context7, GitHub, Exa, and the
  `nixos` MCP (`nix_versions` on NixHub.io) where package availability matters.
  Record unavailable sources as unknown; never infer APIs, security, or
  platform support.
- Do not run upstream `init`, installer, `curl | sh`, or `npx @latest` commands
  in this repository during evaluation. Do not copy generated agent instructions
  without reviewing their behavior and ownership model.
- Check license, pinning, update/telemetry behavior, network listeners, local
  state, filesystem reach, secret exposure, open security issues, and support
  for Linux plus arm64-darwin.
- Keep agent skills, MCPs, user packages, background services, and operational
  helpers as distinct integration classes. Operational helpers remain Go only.

## Decision Gates

| Finding | Decision |
| --- | --- |
| Fits an existing asset, MCP, or package path with acceptable risks | Propose a narrow, pinned integration. |
| Needs a different lifecycle or has an independent risk profile | Split into separate changes. |
| Has unresolved security, portability, or ownership blockers | Defer with concrete re-entry conditions. |
| Duplicates existing harness capability without a clear human benefit | Do not adopt. |

## Execution Steps

1. Identify the canonical upstream repository, release, license, and install
   surface; distinguish marketing claims from source behavior.
2. Map it to the current harness: registered skills (`.atl/skill-registry.md`,
   sources under `shared/assets/skills/`), MCP config in
   `shared/opencode/mcps*.nix`, Home Manager packages, Go helpers under
   `pkgs/nixos-scripts/`, and multi-host deployment to rog, thinkcentre,
   t14, and macm5.
3. Inspect runtime boundaries: processes, ports, browser or GUI needs, network
   calls, telemetry, update checks, emitted artifacts, and read/write scope.
4. Delegate one read-only explorer when mapping exceeds a bounded read batch;
   otherwise explore inline. Compare package-only, managed integration, and
   defer options; include the host evaluation command and rollback.
5. Propose from read-only evidence; require explicit user approval before
   implementation. Implementation approval does not authorize activation.
6. Keep skill sources in `shared/assets/skills/`; never hand-edit installed
   copies, because `ai-assets-reconcile` refuses modified collisions.
   Deployment requires separately authorized activation through the target's
   existing NixOS, standalone Home Manager, or nix-darwin workflow. Do not
   assume the Linux `nixos-build test` command applies to every host.

## Output Contract

Return the tool's canonical source and a concise verdict: **adopt**, **defer**,
or **reject**. State the integration class, affected paths, evidence-backed
risks, platform coverage, and whether it belongs in a separate change.

## References

Paths are relative to the repository root.

- `AGENTS.md` — repository architecture, Go-only policy, and Nix verification.
- `docs/rtk-pilot.md` — example of runtime-output and local-state risk analysis.
- `docs/browser-mcp-setup.md` — example of an MCP/browser boundary.
- `shared/opencode/mcps.nix` — current MCP inventory source.
