---
name: tool-adoption
description: "Trigger: new tool, add tool, evaluate tool, new CLI, new MCP, new skill, does it fit, integrar herramienta. Research and classify external tools before adopting them."
license: Apache-2.0
metadata:
  author: "glats"
  version: "1.0"
---

## Activation Contract

Load when the user brings an external tool, repository, CLI, MCP, skill, app,
viewer, or service and asks whether it fits this harness. Explore before
proposing or installing anything.

## Hard Rules

- Research before reading repository code: use Context7, GitHub, Exa, and
  `nixos_nix` where package or option availability matters. Record unavailable
  sources as unknown; never infer APIs, security, or platform support.
- Do not run upstream `init`, installer, `curl | sh`, or `npx @latest` commands
  in this repository during evaluation. Do not copy generated agent instructions
  without reviewing their behavior and ownership model. Use the current pattern in the nix code.
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
2. Map it to the current harness: shared skills, MCP inventory, Home Manager
   packages, Go scripts, existing tools, and multi-host deployment.
3. Inspect runtime boundaries: processes, ports, browser or GUI needs, network
   calls, telemetry, update checks, emitted artifacts, and read/write scope.
4. Run or delegate `explore` for a named change. Compare package-only,
   managed integration, and defer options; include validation and rollback.
5. Require explicit user approval before proposal or implementation.

## Output Contract

Return the tool's canonical source and a concise verdict: **adopt**, **defer**,
or **reject**. State the integration class, affected paths, evidence-backed
risks, platform coverage, and whether it belongs in a separate change.

## References

- `AGENTS.md` — repository architecture, Go-only policy, and Nix verification.
- `docs/rtk-pilot.md` — example of runtime-output and local-state risk analysis.
- `docs/browser-mcp-setup.md` — example of an MCP/browser boundary.
