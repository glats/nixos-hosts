# Swarm campaigns: goal-driven, multi-provider, phone-visible agent work
Objective: turn `gastown-run swarm` into a campaign system that takes an intent ("quiero shipear distros"), proposes what is needed, executes what the user selects, asks when blocked, persists everything it learns, and reports to the user's phone, balancing work across the user's subscriptions.
Branch: `feat/bot` | Delivery: work-unit commits on the branch; push only when the user asks | Runner: `go -C pkgs/nixos-scripts test -count=1 -json ./internal/gastown/` | Predecessor: `odd/tasks/persistent-swarm-and-desktop-assistant.md` (L69-L79).

## Specs

1. **S1 — Campaign loop with acquired, persisted knowledge.** User: "todo eso tiene que ir siendo adquerido por la agente e ir guarando. yo digo "quiero shipear distos". ai, necesitas de a,b,c. oka vamos con a y c primero y asi." The system answers an intent with the capabilities it needs (a, b, c), the user selects which to pursue, selected items are executed, and every decision, finding and result is persisted so the campaign resumes across sessions. Acceptance: see T6.
2. **S2 — One command, long-running, asks and keeps going, user reviews along the way.** User: "hazme la distro y que vaya preguntando, y que vaya haciendo mientras pueda y que pueda ur yo dando reviews de como deberia quedando." Work continues on everything not blocked by a question; user reviews steer later work. Invocation is a command, not ODD: ODD is how each worker works inside its station (L2 D1).
3. **S3 — See progress and answer from the phone.** User: "ojala ver esto con openfan o con el telefono. con telelfono tengo wireguard, dinwods app. erpo es mas o menos uan molestia, ,e gustria una app. porque quiero ir saibendo como va." and "vamos a usar herdr o rex que es nuevo." Acceptance: notifications and replies work from a phone app without WireGuard/RDP. Channel choice is the user's (T7 blocked on decision).
4. **S4 — All agents working, best fit, paid only by subscriptions.** User: "quiero ahcer build con tod s mis agentes trabajod y mejor fit. pagando lo jusot con mis subscripciones openai claude y oallam cloud." Agents: Codex (ChatGPT login), Claude Code (Claude subscription login, never an API key), OpenCode with Ollama Cloud, plus NVIDIA NIM (free) already working. No pay-per-token API billing is introduced.
5. **S5 — Token usage and the best model for the upper layer.** User: "tambien tener pendiente el uso de token y que modelos hacen el mejor fit para la capa superior." Acceptance: a per-run token ledger by role, agent and model (T3), and a measured comparison that picks the Mayor and worker defaults (T5).
6. **S6 — Fit the gentle-ai/ODD harness into each station.** User: "si te fijas como tengo coenectado mi ahrness uso algo que se llama gentle ai con odd. entonces la idea es aprovechar eso con opecnode, codex, pi hermess, claudre no se. veamos como se ahce el fit alli." Acceptance: T4. Pi and Hermes are deferred: Pi has gentle-ai support but is not installed; Hermes is not present on this machine.
7. **S7 — Distro builds need a trusted build step.** Statement accepted by the user: "Construir RPMs, el chroot y la ISO necesita root, red y un disco dedicado, y el sandbox no da nada de eso a propósito. La salida razonable es que los agentes editen specs, scripts y docs verificados por gates offline, y que el build lo ejecute un paso de confianza en una VM o en un chroot dedicado. Es una decisión de seguridad tuya, pero la dejamos para después." Decision deferred by the user (T8).
8. **S8 — Opus designs, Sonnet executes.** User: "quiero usar oposu para lograr esta menta par aluego pasar a sonnet. asi que deja todo listo en un odd supongo y engram t sabes. y cuando "sietnas" que esta bien. voy con sonnet oj? para que sea mas mecanioc." This document and its Engram mirror are the handoff; tasks are written to be executed without design decisions. A task that needs a product or security decision stops and asks the user.

9. **S9 — The campaign defines its own delivery process and asks what exists.** User (2026-11-10): "eso tiene que definirlo el proceso del gastown. tiene que ser parte del proceso. el agente tiene que saber eso de antemano. yo voy a decir quierouna distro: como se prueba, como se shipea etc. todo eso lo propoone el agente y yo voy deiciendo las copoines con los recuros que tenemos hy igual mauqilinnux.org. etc. y preguntar tambien que hay disponible. eso lo voy a ir diciendo yo." Acceptance: the plan carries process test/build/ship and questions with options; the user's answers are persisted and reach every goal; the Mayor is told the station limits. This replaces my earlier recommendation of a libvirt VM for T8: the build mechanism is chosen by the user from the options the campaign proposes (T8).

## Tasks

- [x] T1 | S4 | Claude Code agent preset `claude:<model>` (subscription token only), confined | Route: inline | Status: done, live gate check passed (L9) | Commit: see L4, L9
- [x] T2 | S4 | Ollama Cloud worker through OpenCode `opencode:ollama-cloud/<model>`, verified auth | Route: inline | Status: done | Commit: see L5
- [x] T3 | S5 | Token ledger per run, role, agent and model; `swarm usage`; totals in the final notification | Route: inline | Status: done | Commit: see L6
- [x] T4 | S6 | Polecat ODD worker contract installed read-only in every agent home | Route: inline | Status: done (with/without comparison belongs to T5) | Commit: see L7
- [ ] T5 | S5 | Model-fit benchmark for Mayor and workers; set measured defaults | Route: inline runs, user reviews the table | Status: pending (after T1-T4) | Commit: -
- [x] T6 | S1, S2 | Campaign layer: intent -> needs -> selection -> execution -> persisted ledger, resumable | Route: inline | Status: done | Commit: see L8
- [ ] T7 | S3 | Phone channel (notifications out, replies in) | Route: inline | Status: STANDBY by user decision (2026-11-10: "dejemos standby") | Commit: -
- [ ] T8 | S7, S9 | Trusted build step for maquilinux (RPM, chroot, ISO) | Route: design + inline | Status: process definition done (S9, L9); the build mechanism waits for the user to choose among the options a campaign proposes | Commit: see L9
- [ ] T9 | S1, S2 | First real campaign on maquilinux: "quiero shipear distros" | Route: inline | Status: pending (after T5, T6; builds need T8) | Commit: -
- [x] T10 | S8 | Write this handoff document and its Engram mirror | Route: inline (Opus) | Evidence: L1-L3 | Commit: see L3

### Task acceptance (mechanical; each item is a test or an observed check)

**T1 Claude preset.**
- `AgentPreset` accepts `claude:<model>` (`opus`, `sonnet`, `haiku` or a full model id) and builds: `gastown-run confine ... --home-bind .claude/.credentials.json -- <GASTOWN_CLAUDE> --dangerously-skip-permissions --model <model>`; `process_names` include `claude`; `prompt_mode: "arg"`; `ready_prompt_prefix: "❯ "`; Gas Town's own claude hooks keep working (its preset `supports_hooks: true` writes `.claude/settings.json` in the worktree, which stays inside the town).
- The preset never passes or forwards `ANTHROPIC_API_KEY`; a unit test asserts it is absent from args and from the swarm environment even when set in the caller.
- `pkgs/gastown-run/default.nix` gains `claude-code ? null` and sets `GASTOWN_CLAUDE` like `GASTOWN_OPENCODE`; `cli.go` `ConfigFromEnv` reads it.
- Bind only the single file `~/.claude/.credentials.json` (verified present, 326 bytes, mode 0600). Never bind `~/.claude` (it holds projects, history and settings).
- Observed check: one toy goal with `--polecat-agent claude:sonnet` passes the gate. `swarm check` does not probe claude (subscription quota), like codex.

**T2 Ollama Cloud.**
- First verify, with a confined one-shot `opencode run --standalone --auto` inside `gastown-run confine`, how OpenCode authenticates `ollama-cloud`: the user's `opencode.json` declares `providers.ollama-cloud` with only `models: {deepseek-v4-pro}`, so base URL and credential come from OpenCode's built-in catalog and either an env var or `~/.local/share/opencode/auth.json`. Record the exact env var or auth mechanism in the Log before coding.
- If auth is an env var: add `"ollama-cloud"` to `openCodeProviders` with the verified env name and base URL; if it needs `auth.json`, add a per-provider `HomeBinds` of that single file only. Never bind the whole OpenCode data directory (it holds a 295 MB database).
- Acceptance: unit tests like `TestOpenCodePresetIsConfinedStandaloneAndNeverEmbedsTheKey` for ollama-cloud; `swarm check` reports `ok` for at least one Ollama Cloud model; one toy goal with an Ollama Cloud worker passes the gate.

**T3 Token ledger.**
- Sources (verify each format on a real polecat before parsing; record a sample line in the Log):
  - Codex: rollout JSONL under `<town>/.agent-home/.codex/sessions/**`. The user's interactive session file had no `token_count` event, so confirm where the TUI records usage; `codex exec --json` emits `turn.completed.usage` with `input_tokens`, `cached_input_tokens`, `output_tokens`, `reasoning_output_tokens` (seen in the pilot).
  - Claude: `<agent-home>/.claude/projects/**/*.jsonl`, `message.usage` (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`) and `message.model`; skip `model == "<synthetic>"`.
  - OpenCode: standalone storage under `<agent-home>/.local/share/opencode`; confirm whether `opencode stats` or the session store exposes per-session tokens.
- The supervisor writes `~/.local/state/gastown/swarm/<project>/ledger.jsonl`, one record per agent session: `{run, goal_at, role, agent, model, input, cached, output, reasoning, source}`; deduplicated by session id.
- `gastown-run swarm usage <project> [--since <goal|all>]` prints totals by role and model. The final "Swarm finished" notification includes the totals. No money estimate for subscriptions; NVIDIA free tier shown as tokens only.
- Tests: parser per source with fixture lines; dedupe; totals.

**T4 Polecat ODD worker contract.**
- One Nix-built file `share/gastown/polecat-odd.md` (in `pkgs/gastown-run`) containing the contract below; `gastown-run confine` (or `AgentPreset`) installs it read-only into the agent home as `~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md` and `~/.config/opencode/AGENTS.md` (bind the store file; do not copy the user's gentle-ai files).
- Contract content (adapted from gentle-ai `gentle-ai-worker.md` principles; do not copy that prompt, it assumes a parent orchestrator): the task source is the hooked bead (`gt hook`, `gt prime`); work inline, never launch subagents or orchestrate; explore only what the bead needs; when a deterministic test applies, observe RED, then GREEN, then refactor; change only files the bead requires; never edit protected paths, Gas Town files (`.beads/`, `.runtime/`, `.logs/`, `CLAUDE.md` overlays), build outputs or binaries; never move or restructure existing files unless the bead says so; ask through `gt escalate -s HIGH` instead of guessing a product decision; finish with `gt done` whose message lists the files changed and the checks run with their observed results; claims without command output are worthless because a trusted gate re-runs every check.
- Tests: confine argv contains the three read-only binds; file content contains the key rules (string assertions).
- Observed check: part of T5 (with versus without the contract on the same goal).

**T5 Model-fit benchmark.**
- Fixed suite on a disposable Go module (recipe in L2 O4): G1 single-bead feature; G2 ambiguous goal that must escalate a question before work (answered with `swarm reply`); G3 two parallel beads with `--protect main.go --protect cmd/`.
- Mayor candidates: `claude:sonnet`, `claude:opus`, `codex:gpt-5.6-luna:medium`, `codex:gpt-5.6-luna:high`, `opencode:ollama-cloud/<best available>`. Workers fixed for the Mayor comparison: `opencode:nvidia/nvidia/nemotron-3-ultra-550b-a55b`, then `codex:gpt-5.6-luna:low`.
- Worker comparison (Mayor fixed to the winner): each worker agent alone, with and without the T4 contract, on G1 and G3.
- Metrics per run, from notifications, watch.json and the T3 ledger: goal verified (yes/no), asked when required (G2), unverified claims rejected count, gate rejects and reasons, unrequested files dropped, wall time, tokens by role and model, quota-limit events.
- Budget: at most 40 minutes per run; stop the matrix and report if any subscription shows a limit. Present the table to the user; the user confirms the defaults; then set them in `swarm init` defaults and `docs/gastown.md`.

**T6 Campaign layer.**
- Commands: `gastown-run campaign start <project> "<intent>"`, `campaign reply <project> "<text>"`, `campaign status <project>`, `campaign stop <project>`; `start` on an existing campaign resumes it.
- State: `~/.local/state/gastown/swarm/<project>/campaign.json` with `intent`, `items[] {id, title, why, depends_on[], needs_decision, status: proposed|selected|running|done|blocked|dropped, goal_at, branches[], summary}`, `decisions[] {at, question, answer}`, `learnings[] {at, item, text}`. Written only by the supervisor (atomic rename).
- Plan step: the Mayor receives the intent plus `campaign.json` and must reply by mail with a fenced ```json block `{"items":[...]}`; the supervisor validates it (unique ids, known dependencies, no cycles); on invalid JSON it asks the Mayor once more, then escalates to the user. Valid plans are notified to the user as a numbered list with `campaign reply` instructions.
- Selection: the user's free-text reply is forwarded to the Mayor, which must answer with ```json `{"select":["a","c"]}`; the supervisor applies only ids that exist and are unblocked.
- Execution: each selected item becomes a swarm goal (existing `Swarm.Goal`) in dependency order, using the gate and integration as today. Completion of an item requires a verified branch (existing `VerifiedSinceGoal`).
- Persistence of knowledge: when an item finishes or a decision is answered, the supervisor appends to `campaign.json` and publishes `CAMPAIGN.md` (rendered from it) on branch `gastown/campaign` in the staging repository, so it can be pulled into the project's own `odd/`.
- Notifications: plan ready, item started, item verified, needs you, item blocked; a digest every 4 hours while running.
- Tests: plan parsing and validation; selection mapping; dependency order; resume from a saved file; CAMPAIGN.md rendering; publishing to staging.

**T7 Phone channel (BLOCKED: D-PHONE).** Ask the user before any code: use Telegram? openfang already holds a bot token in sops (`openfang/telegram_bot_token`) and consumes that bot's updates; Telegram Bot API allows a single `getUpdates` consumer, so reusing the same bot for replies conflicts with openfang. Options to present: (a) a second Telegram bot dedicated to gastown (recommended: no conflict, outbound only, messages pass through Telegram's servers); (b) route through openfang as an agent tool; (c) ntfy self-hosted behind WireGuard (no app for replies without exposure); (d) evaluate Rex (Superlogical; durable sessions, working/done/blocked states, joins a Tailscale tailnet; the user runs WireGuard, mobile client unverified). After the decision: token read at runtime from a sops secret (never in the Nix store); outbound via `--notify-cmd` helper `gastown-run notify-telegram`; inbound poller accepts only the configured chat id and maps messages to `campaign reply` / `swarm reply`.

**T8 Trusted build step (BLOCKED: D-BUILD).** Present options to the user: (a) gate runs `mql build` in the existing overlay chroot with sudo (fast; high risk: agent-authored specs execute as root on rog); (b) a dedicated libvirt VM on rog reset from a snapshot per build, receiving only the gate-accepted branch, returning RPMs, logs and ISO (recommended); (c) the existing GitHub Actions runner workflows. Implement only the chosen option.

## Log

### L1 — 2026-11-10: User requests, verbatim

- "ya. ahora quiero ver la orquestadcion. si te fijas como tengo coenectado mi ahrness uso algo que se llama gentle ai con odd. entonces la idea es aprovechar eso con opecnode, codex, pi hermess, claudre no se. veamos como se ahce el fit alli. porqu entiendo que el swarm son ahreness y claro cada uno tiene su puesto de trabajo. pero no se si esto quedaria en que nivel entiendes?"
- "tambien tener pendiente el uso de token y que modelos hacen el mejor fit para la capa superior. entiendes? como hacemos entonces? odd o es un comando. por ejemplo para la distor de linux le quiero decir: hazme la distro y que vaya preguntando, y que vaya haciendo mientras pueda y que pueda ur yo dando reviews de como deberia quedando. y ojala ver esto con openfan o con el telefono. con telelfono tengo wireguard, dinwods app. erpo es mas o menos uan molestia, ,e gustria una app. porque quiero ir saibendo como va. quizas gastwon es ya me lo heres. vamos a usar herdr o rex que es nuevo. tneindes a donde quiereo llegar con esto. porque quiero ahcer build con tod s mis agentes trabajod y mejor fit. pagando lo jusot con mis subscripciones openai claude y oallam cloud."
- "Hay un obstáculo real con la distro. [...] todo eso tiene que ir siendo adquerido por la agente e ir guarando. yo digo "quiero shipear distos". ai, necesitas de a,b,c. oka vamos con a y c primero y asi. dale quiero usar oposu para lograr esta menta par aluego pasar a sonnet. asi que deja todo listo en un odd supongo y engram t sabes. y cuando "sietnas" que esta bien. voy con sonnet oj? para que sea mas mecanioc."
- Open question asked and not yet answered: whether to use the Telegram bot already configured for openfang as the phone channel (D-PHONE).

### L2 — 2026-11-10: Design decisions and operational facts (Opus)

Decisions:
- D1 Two layers. Upper: Gas Town coordination plus the trusted supervisor (`gastown-run swarm`, later `campaign`), invoked as a command. Lower: each polecat works with an ODD worker discipline. The gentle-ai orchestrator must not run inside a polecat (two bosses, multiplied tokens); RDD native review stays outside polecats and may later run on `gastown/integrated`.
- D2 Authority. Models are never trusted for completion: a goal or item is done only with a branch that passed the gate after it was sent (implemented: `VerifiedSinceGoal`, rejected unverified completion, Mayor mail labelled unverified).
- D3 Coordinator strength. A low-effort Mayor confabulated a commit and skipped a mandatory question; a medium-effort Mayor asked correctly. Default Mayor is `codex:<model>:medium` until T5 measures better.
- D4 Subscriptions only. Codex binds only `~/.codex/auth.json`; Claude binds only `~/.claude/.credentials.json`; OpenCode never mounts the user's config or database and gets keys by env. No API-key billing paths.
- D5 Knowledge persistence for campaigns lives in supervisor-owned `campaign.json` and is published as `CAMPAIGN.md` to staging; agents cannot write it directly.

Current implementation (commit d3ddc3b7 and earlier on `feat/bot`):
- `pkgs/nixos-scripts/internal/gastown/`: `confine.go` (bwrap confinement, `TrustProject`, `GitRoot`), `gate.go` (gate, `IsInfrastructure`, `IsProtected`, binaries, `.gitignore` cleaning, `Integrate`), `swarm.go` (init/up/down/goal/reply/presets/`ProbeCommand`/`Check`), `swarm_watch.go` (tick: escalations, mail, gate, providers, idle, finish, integration), `swarm_support.go` (`LimitHit`, `PickAgent`, `Notifier`), `swarm_cli.go` (commands), plus the older `gastown-run run` executor (`runner.go`, `cli.go`, `doctor.go`, `abandon.go`, `gitignore.go`). 106 tests in the package; 821 in nixos-scripts.
- Nix: `pkgs/gastown` (gt 1.2.1), `pkgs/beads` (bd 1.0.5), `pkgs/dolt` (2.6.0), `pkgs/gastown-run` (wrapper; `opencode ? null`, `toolPackages`), `linux/system/features/gastown.nix` (`gastown.enable`, `gastown.toolPackages`), enabled on rog with go, python3, bats, shellcheck. Docs: `docs/gastown.md`.

Operational facts (avoid these traps):
- O1 Go test output is summarized by the RTK wrapper; always parse `go test -json` for pass/fail counts. `grep` and `ls` are also rewritten; use python3 for exact parsing.
- O2 zsh does not word-split `$VAR` holding a command; write a small script (e.g. `g.sh`) instead of `$E cmd`.
- O3 Never `pkill -f` a pattern that appears in your own shell command line; it kills the shell. Stop swarms with `gastown-run swarm stop <p>` then `systemctl --user stop gts-<p>-*`.
- O4 E2E recipe: disposable Go module with one commit and a tracked `.gitignore`; build the wrapper with `nix build --no-link --print-out-paths --impure --expr 'let f = builtins.getFlake (toString ./.); p = f.nixosConfigurations.rog.pkgs; in p.gastown-run.override { toolPackages = [ p.go p.python3 ]; }'`; `GASTOWN_STATE=<scratch>/state`; `swarm init ... --dolt-port 45911 calc <repo>`; `swarm run --timeout 40m --goal ...` in the background; watch `<state>/swarm/calc/notifications.jsonl`. Delegate long waits to a read-only subagent to save parent tokens.
- O5 New Go files must be `git add -N` before `nix build` sees them.
- O6 The sandbox cannot exec `/run/current-system/sw` aliases; use canonical `/nix/store` paths (the wrapper already does).
- O7 NVIDIA model ids include the organization: `nvidia/nvidia/nemotron-3-ultra-550b-a55b`, `nvidia/google/gemma-4-31b-it`. Only these two answered on 2026-11-05; the rest in `providers-base.nix` are end of life or unavailable.
- O8 OpenCode agents must run with `--standalone` (the user's OpenCode service listens on 127.0.0.1:49374 and shares the network namespace).
- O9 A swarm run uses about 5 GB peak memory and half a core; one run at a time on rog.
- O10 Real credentials are involved in E2E runs; never print, copy or commit them.

### L3 — 2026-11-10: Handoff readiness

- Unknowns resolved before handoff: Ollama Cloud is declared in the user's OpenCode config with model `deepseek-v4-pro` only (auth mechanism still to verify in T2); Claude Code 2.1.322 with `~/.claude/.credentials.json`; Claude session JSONL carries `message.usage`; the Codex interactive rollout file inspected had no `token_count` event (T3 must locate usage); gentle-ai 4.4.0 ships `opencode/agents/gentle-ai-worker.md` but it assumes a parent orchestrator, hence a dedicated polecat contract (T4).
- Recommended order for Sonnet: T1, T2, T3, T4 (mechanical), then T6 (mechanical against its spec), then T5 runs (bounded; present the table), then ask D-PHONE and D-BUILD, then T9.
- Risk: item 2 (agents with real subscription credentials under confinement) for T1, T2, T7; item 5 (delivery/environment) for T8.

### L4 — 2026-11-10: T1 executed (Sonnet-phase run)

- Deviation from T1 text, with evidence: the plan bound `~/.claude/.credentials.json`. Observed instead: the user's file holds empty `accessToken` and `refreshToken` and `expiresAt: 0`, and the user's own `claude -p` answers "OAuth session expired and could not be refreshed". A single-file bind also cannot take Claude's atomic rename on refresh, and a refresh inside the sandbox could rotate the user's refresh token away. Decision: claude agents authenticate only with `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`, subscription based, no API billing), no home bind. `ANTHROPIC_API_KEY` is never forwarded (tests).
- First-run dialogs observed in a live pane (login method, theme picker). New `confine --prepare-claude` pre-answers onboarding, theme, workspace trust and the bypass-permissions notice (`PrepareClaude`, idempotent, preserves existing keys). Observed: with a fake token the confined pane reaches the prompt with no dialog (401 expected).
- Codex Mayor hit its subscription limit during the live attempt ("try again at Nov 11th, 2026 12:46 PM"); live runs that need the Codex Mayor wait for that, or use an OpenCode Mayor.
- Pending live check: one toy goal with `--polecat-agent claude:sonnet` once the user exports `CLAUDE_CODE_OAUTH_TOKEN`.
- Tests: 112 in internal/gastown, all pass. Risk: item 2 (credentials under confinement; narrowed to a single env token).

### L5 — 2026-11-10: T2 executed

- Auth mechanism verified (models.dev catalog plus live runs): env `OLLAMA_API_KEY`, base URL `https://ollama.com/v1`, OpenAI-compatible; the user's OpenCode `auth.json` does not exist, so no file bind is needed. `ollama-cloud` was added to `openCodeProviders`; the key reaches agents only by `--env`, never in argv or inline config (test).
- `swarm check` reported `ok` for `glm-5.3-flash`, `minimax-m3.1-flash`, `deepseek-v4-pro` and `kimi-k3`.
- Observed toy goal (G1) with Mayor `opencode:ollama-cloud/glm-5.3` and workers `glm-5.3-flash` then `minimax-m3.1-flash`: the Mayor dispatched bead ocl-t6o, the worker produced `Sub` plus a two-case test, the gate published `gastown/ocl-t6o`, goal verified, swarm finished, no leftovers. An OpenCode Mayor therefore works, which matters because the Codex Mayor is out of quota until Nov 11 12:46.
- Tests: 113 in internal/gastown. Risk: item 2 (real subscription key under confinement, env only).

### L6 — 2026-11-10: T3 executed

- Formats verified on real files. Codex: rollout `event_msg` `token_count` with `info.total_token_usage` {input_tokens (includes cached), cached_input_tokens, output_tokens, reasoning_output_tokens}, cumulative, so the last one is the session total; `info` is null when the session hit its limit; role comes from `session_meta.payload.cwd`, model from `turn_context.payload.model`. Claude: `message.usage` per assistant line, repeated once per content block, so counted once per `message.id`; skip `<synthetic>`. OpenCode: sqlite `opencode.db` table `session_v2` has `tokens_input/output/reasoning/cache_read/cache_write`, `model` as JSON `{id, providerID}`, `directory`, `time_created` (ms); read through the `sqlite3` CLI (`GASTOWN_SQLITE`, `-readonly -json`), since the Go module has no sqlite driver.
- `ledger.jsonl` (swarm dir): one line per agent, session and model; running sessions are updated in place, vanished sessions are kept; `cache_write` added to the spec's fields; `input` excludes cached tokens. Written every supervisor tick and before "Swarm finished", whose body now carries the totals. `swarm usage [--since goal|all]` prints totals by role and model.
- Observed on the real Ollama Cloud run (L5), `swarm usage --since all`: mayor glm-5.3 in 67k cached 1.7M out 17k; polecat glm-5.3-flash in 45k cached 863k out 10k; refinery minimax-m3.1-flash in 46k cached 1.1M out 16k; witness minimax-m3.1-flash in 84k cached 4.2M out 40k. Finding for T5: the witness role consumed the most tokens of all, more than the Mayor and the worker; role agents deserve the cheapest model.
- Tests: 120 in internal/gastown. Risk: none (read-only parsing of agent session files; a new swarm-owned ledger file).

### L7 — 2026-11-10: T4 executed

- The contract text is `pkgs/nixos-scripts/internal/gastown/polecat-odd.md` (kept inside the Go module so the package test can read it in the Nix sandbox); `pkgs/gastown-run/default.nix` installs it to `$out/share/gastown/polecat-odd.md` and sets `GASTOWN_POLECAT_CONTRACT`. The agent home is shared by every role, so the text is conditional: it applies only when `gt prime` says the role is polecat; other roles ignore it.
- New `confine --ro-file /nix/store/...=<relative path in home>` (validated: store path, relative non-escaping destination). Each agent preset mounts the contract at `.codex/AGENTS.md`, `.claude/CLAUDE.md` or `.config/opencode/AGENTS.md`.
- Observed: in a real bwrap confinement all three paths show the contract and any write fails with Permission denied (read-only).
- Tests: 124 in internal/gastown (argv mounts, bad destinations refused, per-agent destination, contract rules asserted as strings). Risk: item 2 (sandbox mounts; read-only store files only).

### L8 — 2026-11-10: T6 executed

- Built per the T6 spec: `campaign start|reply|status|stop` (+ internal `exec`), `campaign.json` (supervisor-owned, atomic rename), `ParsePlan` validation (unique ids, known deps, no cycles), Mayor mail interception through a `mailHook` in `tickMail`, selection by literal ids (`a c`, `all`, no model round trip) or by the Mayor's fenced `{"select":[...]}`, sequential execution in dependency order via `Swarm.Goal`, completion only with a gate-verified branch (`VerifiedSinceGoal`), blocked after 30 minutes without progress, replies queued as files and consumed by the supervisor, 4-hour digest, `CAMPAIGN.md` on `gastown/campaign` (history kept, no commit when unchanged). One deviation: the plan retry budget is one re-ask then an escalation to the user, as specified; a user reply after that re-asks the Mayor with the guidance.
- Observed live with Mayor `opencode:ollama-cloud/glm-5.3` and workers glm-5.3-flash/minimax-m3.1-flash on the toy repo: intent "quiero una libreria calc minima: necesito operaciones Sub y Mul, cada una con sus tests" produced a valid 2-item plan, `campaign reply all` selected both, item 1 started, was verified by the gate, the learning was recorded and `CAMPAIGN.md` appeared on `gastown/campaign`.
- Defects the live run exposed, and what was done: (1) the Mayor, knowing the plan from the planning mail, dispatched item 2 inside item 1's goal, so both beads ran in parallel on the same file, the two branches conflicted ("Accepted branches conflict") and item 1 claimed both branches. Fix: every item goal now says to dispatch beads for that item only and not to create beads for the other items (asserted by test). Not re-run live; watch for it in T5 and T9. (2) Items do not build on each other's code: polecat branches start from the rig's main, so a dependent item cannot see its predecessor's result until the user merges it; the dependency only orders the goals, and learnings reach later items through the goal text. Documented in docs/gastown.md; a base-advancing step is a possible follow-up. (3) Noise: Gas Town's boot dog raised a HIGH "worktree integrity violation in town/deacon/dogs/boot" escalation (the town root is not a git repository); the Mayor resolved it itself. Not addressed here.
- Tests: 142 in internal/gastown (plan validation, selection, dependency order, resume, rendering, publishing, flow, blocked and unblock, digest, replies queue, commands). Risk: item 3 is not touched; the only shared-code change is the `mailHook` in `tickMail` (nil by default, so swarm behaviour is unchanged). Risk: none.

### L9 — 2026-11-10: user decisions, live Claude check, delivery process in campaigns

- User answers (verbatim): "1. porque no puedes usar la acutal? eso ya lo hice una vez deberia estar por alli. 2 . bueno codex termina mñana el limite creo. abra que esperar. 3. dejemos standby. 4 . eso tiene que definirlo el proceso del gastown. [...] 5. solo push yo hago el build . siempre que tenga lo de master. ñara que mi rog no se estropee quedadno sean feautre que peudas estar usando. o acutalizando."
- (1) The setup-token was in OpenCode's credential store (table `credential`, label Anthropic, `sk-ant-oat` shape, 108 characters); it was read in memory and passed by environment only to one run, never printed or stored. Observed live: Mayor `opencode:ollama-cloud/glm-5.3` plus worker `claude:sonnet` (`claude-sonnet-5-5`) produced Sub with a test, passed the gate and finished; `swarm usage` shows the Claude row (1.1M cached, 5.9k output). T1's pending live check is closed. The token is not read automatically by code; the user exports `CLAUDE_CODE_OAUTH_TOKEN` where the swarm starts.
- Bug found by that run and fixed: Claude transcripts whose first line has no `cwd` made the role `other`; the first non-empty `cwd` is now used (test).
- (2) Codex limit resets Nov 11; T5 waits. (3) T7 on standby. (5) The user pushes and builds; `feat/bot` already contains `master` (0 commits behind at 2026-11-10); nothing here deploys.
- (4) S9 implemented in the campaign layer: the plan must carry `process.test/build/ship` (validation refuses an incomplete process), optional `questions` with options, and items; the plan request tells the Mayor the station limits and the offline checks and says to ask the user what resources exist; `campaign answer [--question ID]` stores answers (no id answers the only open question, otherwise it is kept as a note and the user is told); answers unblock items that needed a decision; process and answers are in `CAMPAIGN.md` and in every item goal. Tests: 145 in internal/gastown.
- Noise seen again, not addressed: Gas Town infrastructure escalations to the user (boot dog worktree integrity in L8; refinery "origin remote does not exist" before the first publish). Candidate follow-up: classify and auto-resolve known infrastructure escalations in `tickEscalations`.
- Risk: none for the S9 code (contained in the campaign layer); item 2 for the one live run that used a real subscription token under confinement.
