# Gentle-ai SDD + OmO — Working Both Together

Real-workflow guide grounded in the installed skills (`sdd-explore` through
`sdd-archive`, `sdd-verify`, `judgment-day`) and OmO upstream docs
(`overview.md`, `orchestration.md`, `btw.md`). Worked example is a real
archived change: `openspec/changes/archive/2026-09-10-oneplus5-wifi-watchdog/`.

## The relationship in one line

Gentle-ai owns **how changes are designed and proven** (SDD gates, specs,
independent verification). OmO owns **how a bounded batch of work gets
executed** (parallel workers, per-task done-claim checks). They compose:
SDD produces the artifacts; OmO can execute some of them; neither replaces
the other.

## Phase map

| SDD phase | Who runs it | OmO role | What you type |
|---|---|---|---|
| explore | `sdd-explore` subagent (MCP research first) | Optional: `librarian`/`explore` agents absorb broad reads and OSS/API research so the phase's context stays lean | Nothing manual — orchestrator picks `task(subagent_type: ...)` |
| propose / spec / design | dedicated subagents on your tier's judgment models | None — these are judgment phases; `/ulw-plan` is an alternative planning gate for AD-HOC work, not a substitute for SDD design | — |
| tasks | `sdd-tasks` subagent | None directly — but its `tasks.md` checkboxes are exactly what `ulw` executes | — |
| apply (mechanical) | orchestrator + `sdd-apply` | `ulw <phase>` fans the mechanical tasks out with independent per-task verification | `ulw execute tasks.md Phase 1 (1.1-1.3)` |
| apply (runtime harness) | orchestrator, sequential | None — real-device/SSH/systemd steps with escape hatches must NOT be fanned out | — |
| verify | `sdd-verify` subagent (independent gate) | None — verify explicitly forbids parallel refuters or extra validators | — |
| after-verify review | judgment-day (your stack) | Alternative: `hyperplan` critics — pick ONE, don't stack both | `judgment day` or `hyperplan` |
| long apply/verify runs | main agent keeps working | `/btw <question>` side conversations while it runs | `/btw why did the rebind fail?` |

## Worked example: oneplus5-wifi-watchdog

That change produced versioned phone artifacts, deployed them over SSH to a
real device, ran one controlled rebind test, and mapped evidence to R1-R10.

**Explore** — the `explore` curated agent greps the repo (NM ordering, systemd
timers precedent); `librarian` looks up ath10k unbind/bind behavior in kernel
docs. Both are read-only and keep the main context lean. You type nothing:
the orchestrator spawns them.

**Apply Phase 1 (three artifact tasks: script, units, runbook)** — pure file
creation with hard constraints (≤150 lines, `set -u`, exact permissions).

```
ulw execute tasks.md Phase 1 (1.1-1.3): create the versioned watchdog
artifacts with the documented constraints, run sh -n and the line-count
check per task, and mark checkboxes only after the reviewer confirms
```

Perfect `ulw` material: three independent file-creation tasks, mechanical
checks, no external state. The done-claim reviewer adds a safety net that a
plain apply batch doesn't have.

**Apply Phases 2-3 (SSH preflight, deploy, rebind test)** — do NOT hand these
to `ulw`. Sequential dependencies, a physical device, a required escape hatch
(manual reboot if rung 1 fails), and evidence that must be recorded in
`tasks.md` verbatim. This is orchestrator-driven, one careful step at a time.
The real failure in this change (first rebind attempt hung ath10k, phone
unreachable, reboot escape hatch) is exactly why fan-out is wrong here.

**Apply Phase 4 (stub scenarios, threshold arithmetic, gates)** — good `ulw`
candidates: machine-checkable stubs, guard arithmetic at boundary values,
`format-nix && nix flake check --no-build`, R1-R10 evidence mapping.

**Verify** — `sdd-verify` runs the independent requirements-vs-runtime proof.
OmO plays no part. A contradiction returns FAIL for the orchestrator to fix,
not for workers to remix.

**After verify (optional)** — judgment-day dual adversarial review. Use
`hyperplan` instead only if you want OmO's five-critic pass; never both on
the same diff.

## Prompt recipes

- Burst a mechanical apply phase:
  `ulw execute tasks.md Phase 1 (1.1-1.3) from openspec/changes/<name>/`
- Ad-hoc follow-up inside the same change without breaking SDD discipline:
  `ulw clean up the comments in the new watchdog script only`
- Side question during a long apply:
  `/btw does rung 1 need NM to be up first?`
- Full ad-hoc task with a plan (NOT a designed change):
  `/ulw-plan migrate the thinkcentre conky configs into a shared module`

## Do-not list

- Never fan out `ulw` over phases whose runtime harness is a physical device,
  an SSH session with state, or anything with an escape-hatch protocol.
- Never route secrets (sops) work through OmO workers; secret-guard still
  guards the session, but stay inline anyway.
- Never let `ulw` touch `openspec/specs/` — only `sdd-archive` promotes specs.
- Verify phase is off-limits to OmO by design; that gate must stay independent.

## Quick decision line

Designed change? → SDD phases, use OmO only for mechanical apply bursts and
side questions. Random pile of chores? → `ulw` directly. Both finish in the
same session, on the same orchestrator, with your stack intact.
