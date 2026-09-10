# Oh My OpenAgent (OmO) — Pilot Tutorial

Grounded in upstream docs (`code-yeongyu/oh-my-openagent`, dev branch — `docs/guide/overview.md`,
`docs/guide/orchestration.md`, `docs/guide/agent-model-matching.md`, `docs/guide/btw.md`).
Declarative pilot port lives in `openspec/changes/cheap-orchestrator-omo-pilot/`.

## What OmO is (and is not)

OmO is a multi-model agent orchestration plugin. It registers worker agents, a
keyword-based mode injector (IntentGate), and a few commands inside your existing
OpenCode session. It does NOT replace your main agent, your skills, or your
memory: **your session agent stays the gentle-ai orchestrator** (currently
`opencode-go/kimi-k3` on rog). OmO only wakes up when a prompt contains one of
its keywords.

## How it is deployed here

- Plugin `oh-my-openagent` 4.19.4 pinned in `pkgs/opencode-npm-packages/` and
  registered in the generated `opencode.json` via the HM option
  `home.opencode.omo.enable` (default `false`, enabled on rog only).
- Runtime config at `~/.omo/omo.jsonc` (deployed by Nix):
  - `telemetry: false` + `OMO_DISABLE_POSTHOG=1`
  - `disabled_mcps: ["websearch", "context7", "grep_app"]` (lsp kept — the user
    already runs exa/context7/github MCPs)
  - `disabled_hooks: ["directory-agents-injector", "rules-injector"]`
    (AGENTS.md is loaded natively by opencode; no double injection)
  - `team_mode.enabled: false`
  - `categories`: `quick -> openai/gpt-5.6-luna`, `deep`/`ultrabrain ->
    openai/gpt-5.6-sol` (resolved from the active provider tier)
- Never run `bunx oh-my-openagent install` — it fights the Nix-generated config.

## Waking it up: keywords and commands

IntentGate is a regex keyword injector (upstream: "It does not semantically
classify requests"; prompts without the keywords continue untouched).

| You type | What happens |
|---|---|
| `ulw <task>` (or the full word `ultrawork`) | Ultrawork mode on that task: decompose into todo checkboxes, classify LIGHT/HEAVY, fan out category workers in parallel, independent reviewer verifies each done-claim. |
| `mass ulw <task>` | Ultrawork with multi-model spread across workers. |
| `hyperplan <task>` | Five hostile critics attack the plan before execution. |
| `/ulw-plan` | Planning interview: the agent questions you, runs `plan-consultant` (gap analysis) and `plan-reviewer` (review rounds, max 5), writes a decision-complete work plan. No code touched yet. |
| `/ulw-execute [plan] [--worktree <path>] [--make-pr] [--ship]` | Executes an approved ulw-plan in the same session, todo per task, verified independently, resumable across sessions (`.omo/boulder.json`). |
| `/btw <question>` (alias `/side`) | Side conversation while the main agent keeps working: ask "what is the risky part of this?" without polluting the main transcript. `Esc Esc` returns; `Ctrl+/` opens the picker. |

Placement tip: put the keyword at the start of the prompt — it is regex text
detection, and leading placement avoids ambiguity.

Anything without those keywords is 100% your normal gentle-ai flow. OmO is
asleep.

## The workers OmO spawns (mapped to our stack)

The main agent never picks a model name — it picks a **category**:

| Category | Use | Model in this pilot |
|---|---|---|
| `quick` | trivial single-file tasks | `openai/gpt-5.6-luna` (our omo.jsonc) |
| `deep` / `ultrabrain` | hard, cohesive, goal-only work | `openai/gpt-5.6-sol` (our omo.jsonc) |
| `unspecified-low/high`, `architect`, `visual-engineering`, `artistry`, `writing` | other work types | builtin fallback chains (several have `opencode-go/...` rungs) |

Curated read-only agents: `explore` (fast codebase grep), `librarian`
(docs/OSS search), `plan-consultant` + `plan-reviewer` (plan-gated only).
Kibitzer is a read-only memory nudge. All live inside the same session.

## Use cases — the frontier with gentle-ai

| Situation | Use |
|---|---|
| Designed change (multi-file, spec-worthy, SDD-worthy) | Your normal flow: SDD cycle + review-gate. NOT ulw. |
| Trivial one-file fix you already understand | Plain prompt, no keyword. |
| Ad-hoc pile ("clean up warnings, fix flaky tests, update docs") | `ulw ...` |
| Chunky ad-hoc where a plan saves rework | `/ulw-plan` then `/ulw-execute` |
| Question while a long task is running | `/btw <question>` |
| Adversarial review of a final diff | judgment-day (your stack). Hyperplan only if you explicitly want its critics. |

## Known constraints (upstream-documented)

- Recommended main-agent tier is Claude Opus/Fable or GPT-5.6 Sol. Kimi K3 has
  a tuned preset ("instruction-following mirrors Claude; budget thinking
  tokens") but is lighter-validated — exactly what our one-week observation
  window is for. If delegation/gates regress: revert the three
  `gentle-orchestrator` lines to `opencode-go/glm-5.3-flash`.
- `deep`/`ultrabrain` are built for GPT-style autonomous work; our mapping to
  Sol matches that. Do not point them at Claude/Kimi-family models.
- `quick` workers are small fast models: give them explicit numbered must-do
  steps, forbidden deviations, and concrete success criteria.
- `hashline_edit` (`LINE#ID` edits) exists upstream but is opt-in and we left
  it off in the pilot.

## Health and rollback

- Check: `oh-my-opencode doctor --verbose` (expect clean on rog; exit 1 on
  hosts without the pilot is expected).
- Rollback OmO: set `home.opencode.omo.enable = false` (or remove it) on rog,
  rebuild — no OmO artifacts remain in the generated config.
- Rollback orchestrator: one-line revert per tier to
  `opencode-go/glm-5.3-flash`.

## Sources

- Overview/philosophy/IntentGate: `docs/guide/overview.md` (dev @ 7918f24)
- Delegation deep-dive: `docs/guide/orchestration.md`
- Categories/agents/model chains: `docs/guide/agent-model-matching.md`
- Side conversations: `docs/guide/btw.md`
- SDD change + implementation: `openspec/changes/cheap-orchestrator-omo-pilot/`
