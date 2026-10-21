# gentle-ai factory parity

Objective: restore gentle-ai factory behavior where the user chose it, keep user additions, and separate global rules from NixOS repo facts. Branch: `feate/gentle-ai`. Delivery: ask-on-risk. Test runner: `nix eval`, `python3 shared/opencode/*.test.py`, `nix flake check --no-build`.

## Specs

- S1 (D4, done 2026-10-21): RDD back to factory default: "tiene que ser por lo de fabrica". `gentle-ai review mode enable --scope global` ran; status `global: on`.
- S2 (D1): OpenCode permissions: "quiero mantener pero sacar lo destructivo ojala lecutra desde / del fhs en adelante". Reads stay allowed from `/`; add the factory destructive bash ask/deny rules (gentle-ai `internal/components/permissions/opencode_overlay.go`); also deny read/edit of factory secret paths (user chose "Sí, bloquear secretos (Recomendado)").
- S3 (D2c): Claude Code permissions: "la idea es similiar a como quedair opencode". Same policy as S2 for Claude Code.
- S4 (D2a): Claude Code telemetry hooks back to factory ("Volver a fábrica"): async `gentle-ai telemetry runtime claude --json` in Stop and SubagentStop, timeout 5.
- S5 (D3): skill-registry plugin: "volver a de fabcrica y quizas si es necesario borrarlo de mi nix? no se". Use upstream `plugins-v2/skill-registry.ts` (binary path substitution allowed) and delete the local copy.
- S6 (D4 relay): "Volver a fábrica": drop `GENTLE_AI_OPENCODE_RELAY_CONTRACT` from the gentle-ai wrapper; verify the review relay still starts.
- S7 (D6): "d6 para lo que es global no deberia tener anda de nix, para esto esta anget.md en cwd" / "mantener aguas separdas. o sea que los agnets o claude globales para cualquier proeyto nbo tiene nada que ver con el angets del repo nix". Global `~/.config/opencode/AGENTS.md` and `~/.claude/CLAUDE.md` contain no NixOS repo content; the repo `AGENTS.md` loads only inside the repo (OpenCode via cwd instructions keeping `OPENCODE_DISABLE_PROJECT_CONFIG`; Claude Code via repo `CLAUDE.md` importing `@AGENTS.md`).
- S8: "el out format deberian estar para ambos claude code y opecnode". `shared/rules/output-format.md` loads in both harnesses.
- S9 (D5): "la idea es que mis reglas iempre manden para cualquier harness: claude code codex, oepncode, etc." / "codex agremos las reglas". Codex receives the shared rules.
- Kept as is (user decisions): D2b outputStyle Neutral, D5 rule injection + `neutral` + `managed-writing-task` (used by `code-work`), D7 models, D8 opencode.json extras, D9 extra MCPs, D11 own themes.

## Tasks

- T1 S1 inline done (runtime command, no commit).
- T2 S2,S3 inline done (commit A) — `shared/ai-safety.nix` factory data; OpenCode bash/read/edit rules (361 shell rules, byte-order last-match-wins), Claude ask/deny + `additionalDirectories = ["/"]`. Risk item 2.
- T3 S4 inline done (commit B) — SubagentStop + Stop async telemetry hooks.
- T4 S5 inline done (commit B) — upstream plugin installed; local `v2-plugins/skill-registry.ts` and dead `skill-registry-worktree-root.ts` deleted; asset-ownership test pins upstream bytes.
- T5 S6 inline done (commit B) — wrapper env removed; plugin `shell.create.before` already sets it (observed in session shell). Test asserts absence. Risk item 3.
- T6 S7,S8 partial (commit B) — global prompts = factory neutral persona + `ruleSources` (output-format now in Claude); repo `CLAUDE.md` = `@AGENTS.md`. OPEN: OpenCode cannot load cwd AGENTS.md while `OPENCODE_DISABLE_PROJECT_CONFIG=1` (docs: "skip project AGENTS.md discovery"; relative `instructions` resolve against global dir). Needs user decision.
- T7 S9 inline done (commit B) — `shared/codex.nix` writes `~/.codex/AGENTS.md` from `ruleSources`; registered in Linux shared modules.
- Checks: asset-ownership, v2-agents, home-launcher PASS; `nix flake check --no-build` PASS; t14 HM eval OK; macm5 eval fails at baseline too (darwin IFD of gentle-ai-rendered-prompts on Linux). RED-first not observed for T3-T6 (tests added after code) — exception recorded.

Route: inline (no parallel units launched together, no context backstop). High-risk tasks (T2, T5) get an independent verifier at feature end.

## Log

- L1 (2026-10-21) original request: "quiero saber si mi nix esta bien integrado gentlai a mi harness opecnode y claude code. tambien los skilss y mcp si estan bien confiurado. odd"
- L2: "no eso esta mal pues. tiene que ser por lo de fabrica. de heco deja todo de fabrica preocuapte de eso. todo lo que no este de fabrica . igual veamos uno a uno porsi caso"
- L3: per-item answers recorded in Specs. Deviation inventory from explorer against upstream 898d397.
- L4: evidence: this OpenCode session loaded only `~/.config/opencode/AGENTS.md`, not the repo AGENTS.md (wrapper sets `OPENCODE_DISABLE_PROJECT_CONFIG=1`, `shared/opencode.nix:67`).
