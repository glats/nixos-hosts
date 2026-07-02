# Archive Report: ai-command-assist

**Archived**: 2026-07-01
**Change**: AI-powered command assistant using shell-gpt and nvidia NIM
**Commit**: `0471ed7` (feat(shell-gpt): add nvidia NIM-powered AI command assistant)
**Status**: IMPLEMENTED and VERIFIED (PASS WITH WARNINGS)

## Summary

Added a Home Manager module (`home-linux/shell-gpt.nix`, 46 lines) that installs
`pkgs.shell-gpt` from nixpkgs and configures it for the nvidia NIM OpenAI-compatible
endpoint. The module provides declarative options (`enable`, `model`, `baseUrl`,
`provider`) and sets environment variables that shell-gpt reads natively — no
fork, no custom script, no config file needed.

The module is imported per-host (rog, thinkcentre, t14) following the
host-conditional pattern (NOT in `shared-modules.nix`). Only rog has
`home.shell-gpt.enable = true`; thinkcentre and t14 have commented stubs.

## What Was Done

| Action | Details |
|--------|---------|
| New module | `home-linux/shell-gpt.nix` — HM module with `home.shell-gpt.*` options |
| rog import | `hosts/rog/home/modules.nix` — enabled, uses default nemotron-3-ultra |
| thinkcentre import | `hosts/thinkcentre/home/modules.nix` — commented, disabled |
| t14 import | `hosts/t14/home/omarchy.nix` — commented, disabled |
| flake.nix | NOT modified (pkgs.shell-gpt from existing nixpkgs input) |
| shared-modules.nix | NOT modified (host-conditional pattern) |

## Key Decisions

1. **Use shell-gpt from nixpkgs as-is** — no fork, no custom derivation. Zero
   maintenance burden. Upstream provides `shlex.quote()`-protected execution.
2. **Configure via `home.sessionVariables`** — shell-gpt reads env vars before
   falling back to `~/.sgptrc`. Declarative, per-host, no `home.file` needed.
3. **OPENAI_API_KEY via sops-nix secret path** — reads
   `config.sops.secrets."opencode/nvidia_api_key".path` at session-variable
   source time. More robust than relying on `$NVIDIA_API_KEY` shell variable.
4. **Host-conditional imports** — module has zero `hostName` conditionals.
   Hosts pick model and enable/disable at the import site.

## Verification Results

| Check | Result |
|-------|--------|
| `nix flake check --no-build` | PASSED (all hosts) |
| `nixos-build dry` on rog | PASSED |
| Runtime: env vars correct | PASSED (all 5 vars present) |
| Runtime: NIM connectivity | PASSED (`sgpt --shell` works) |
| Runtime: confirmation gate | PASSED ([E/M/D/A] prompt appears) |
| Spec compliance | 20/22 scenarios compliant (2 untested=upstream-only) |
| Issues | 1 WARNING: AD3 design deviation (secret injection method) — functionally harmless |

## Artifacts

Located in `openspec/changes/archive/2026-07-01-ai-command-assist/`:

- `exploration.md` — Deep-dive comparison of shell-gpt vs llm-cmd vs build-from-scratch
- `proposal.md` — Scope, approach, risk analysis, rollback plan
- `spec.md` — Delta spec with 4 new requirements, 22 Given/When/Then scenarios
- `design.md` — 8 architecture decisions (AD1-AD8), data flow, interfaces, testing strategy
- `tasks.md` — 9 tasks across 4 phases, review workload forecast
- `verify-report.md` — Spec compliance matrix, coherence check, PASS WITH WARNINGS verdict

## Delta Specs Synced

Delta specs for **home-manager** domain have been merged into
`openspec/specs/home-manager/spec.md`:
- Added Requirement: Shell-GPT Home Manager Module (9 scenarios)
- Added Requirement: shell-gpt CLI works with NVIDIA NIM (6 scenarios)
- Added Requirement: Per-host configuration (4 scenarios)
- Added Requirement: Zero maintenance overhead (4 scenarios)
