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
  - `disabled_hooks: ["directory-agents-injector", "rules-injector", "auto-update-checker"]`
    (AGENTS.md is loaded natively by opencode — no double injection; the
    update-check ping is noise because Nix owns the version)
  - `team_mode.enabled: false`
  - `categories`: `quick -> openai/gpt-5.6-luna`, `deep`/`ultrabrain ->
    openai/gpt-5.6-sol` (resolved from the active provider tier)
- Never run `bunx oh-my-openagent install` — it fights the Nix-generated config.

## Waking it up: the complete user-facing surface

Verified against `docs/reference/features.md` (dev @ cf3758f). IntentGate is a
regex detector over the message text, edge-triggered per message (known issue
#5806: repeat the keyword in every follow-up you want kept in mode).

### Mode keywords (IntentGate `keyword-detector` hook)

| Keyword | What activates | Pilot status |
|---|---|---|
| `ulw <task>` (or the full word `ultrawork`) | Ultrawork execution mode: decompose into todo checkboxes, classify LIGHT/HEAVY, fan out category workers, independent done-claim review | available |
| `mass ulw <task>` | Ultrawork with multi-model spread (own protocol: `mass-ulw-protocol.md`) | available |
| `hyperplan` / `/hyperplan` | Five hostile critics attack the plan | BLOCKED — requires `team_mode.enabled: true` (ours: off) |
| `team`, `team mode`, `team-mode`, `team_mode`, `teammode` | Team Mode lead + members | BLOCKED — same gate |
| `hyperplan-ultrawork` | Combo of both | BLOCKED — same gate |

### Reasoning-boost keywords (separate `think-mode` hook)

| Keyword | What happens | Pilot status |
|---|---|---|
| `think` / `ultrathink` | Sets the message reasoning variant to `high` | available |

Usage rules: the literal English words only (the detector is regex — Spanish
"piensa" does not match), edge-triggered per message like every other
keyword, and it costs reasoning tokens — use it on hard questions, not
mechanical work. It stacks with any other prompt content (it is a boost of
the current message, not a mode).

### Named agent mentions (plain language, read-only)

Invocable by you — the three: `@explore` (fast repo greps), `@librarian`
(docs/OSS/GitHub research with sources), and `@architect` / asking for
`task(category: "architect")` (design trade-offs, proposes without
implementing). The scouting mechanism (see below).

Not name-invocable: `plan-consultant` and `plan-reviewer` run only inside
`/ulw-plan` (plan-gated; the reviewer is additionally one-shot); Kibitzer is
the automatic memory nudge; category workers and the ultra workers/deep
agents spawn only inside an `ulw` run.

### Skill text-triggers (auto-activate when the trigger appears)

| Trigger text | Skill | Notes |
|---|---|---|
| `ulw-research` | saturation research swarm with citations | see collision warning below |
| "review work" / "review my work" / "QA my work" | post-implementation gate review | |
| "remove AI slop" / "de-AI" / "humanize" | removes AI-slop from code | also `/remove-ai-slops` |
| commit / rebase / squash / "who wrote X" | `git-master` expert | |
| browser / testing / screenshots | `playwright` (or agent-browser/dev-browser) | |
| UI/UX / styling | `frontend` designer persona | |

### Slash commands

| Command | What it does | Pilot status |
|---|---|---|
| `/ulw-plan` | Planning interview → `plan-consultant` + `plan-reviewer` (max 5 rounds) → decision-complete work plan | available |
| `/ulw-execute [plan] [--worktree <path>] [--make-pr] [--ship]` | Executes the approved plan in-session, resumable (`.omo/boulder.json`) | available |
| `/refactor <target> [--scope] [--strategy]` | Refactor with LSP + ast-grep + TDD verification | available |
| `/btw <question>` (alias `/side`) | Side conversation while main works; `Esc Esc` returns, `Ctrl+/` picker | available |
| `/handoff` | Context summary to continue in a fresh session | available |
| `/stop-continuation` | Emergency brake: stops todo-continuation, Goal, and boulder for the session | available |
| `/remove-ai-slops` | Removes AI-slop from branch changes | available |
| `/goal <objective>` | Persistent objective with idle continuations | BLOCKED — `goal.enabled: false` |

### The `ulw`-substring collision (learned the hard way)

IntentGate regex-matches ANY occurrence of `ulw` in your message. The literal
chain `ulw-research` therefore wakes ULTRAWORK (execution mode) instead of the
research skill — with the mandatory "ULTRAWORK MODE ENABLED!" opener. Rules:

- Never write a chain containing `ulw` unless you want execution mode.
- For research: plain language + explicit delegation rule (below), or
  `@librarian`/`@explore`, or ask the orchestrator to load the saturation
  research skill internally ("load the saturation research skill") — invoking
  it via the skill tool never touches your text, so the detector stays quiet.

Anything without the keywords above is 100% your normal gentle-ai flow. OmO is
asleep.

## Scouting / feasibility — plain language, read-only

Factibility checks use the read-only agents (`librarian`, `explore`, the
`architect` consult lane), spawned by the orchestrator from a normal prompt.
Never use `ulw` for scouting: `ulw` is the execution mode and will start
implementing instead of scoping.

Pilot-verified lesson: delegation in free-form chat is a MODEL JUDGMENT, not a
guarantee. First scouting attempt ran 6 file reads inline (session ses_f723);
the same prompt plus one explicit rule delegated to three parallel read-only
agents (session ses_f722). The reliable recipe:

```
<question> Investigación read-only, NO implementes nada.

REGLA DE EJECUCIÓN — no hagas las lecturas inline: delega la investigación
(librarian/explore de OmO, en paralelo) y devuélveme solo el resumen final.
```

If the scouting will feed a formal change anyway, the contractual instrument
is the SDD cycle itself (`sdd-explore`): the orchestrator MUST delegate there,
MCP research is mandatory, and the result is a durable `exploration.md`.
Sequence: scout → decide → `sdd-explore` onward if it merits a change.

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

- Features reference (keyword surface, hooks, commands, tools): `docs/reference/features.md` (dev @ cf3758f)
- Known issues (incl. #5806 edge-triggered keyword detection): `docs/reference/known-issues.md`
- Overview/philosophy/IntentGate: `docs/guide/overview.md` (dev @ 7918f24)
- Delegation deep-dive: `docs/guide/orchestration.md`
- Categories/agents/model chains: `docs/guide/agent-model-matching.md`
- Side conversations: `docs/guide/btw.md`
- SDD change + implementation: `openspec/changes/cheap-orchestrator-omo-pilot/`
