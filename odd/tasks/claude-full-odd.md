# claude-full-odd

Objective: give Claude Code the complete Gentle AI v4.1.1 ODD integration that upstream installs for Claude, as OpenCode already has it.
Branch: `master` (user: "todo en la rama master. sin pr"). Delivery strategy: `single-pr` waived — direct work-unit commits on master, push after verification. Test runners: `go` exporter build (`nix build .#gentle-ai-assets`), `go -C pkgs/nixos-scripts test ./...`, `nix flake check --no-build`, host `nix eval`, `shared/opencode/asset-ownership.test.py`.

## Specs

S1. "ahora quiero full odd para claude tambien darle soporte gntle ai odd" — Claude Code receives upstream's Claude ODD install surface: rendered orchestrator CLAUDE.md (already present), the 8 review/JD subagents rendered the way upstream `reviewassets.renderNativeAgent` renders them (no `{{CLAUDE_MODEL}}`, `{{CLAUDE_EFFORT_FRONTMATTER}}`, `{{ENGRAM_TOOL_PREFIX}}` or other placeholders; JD judge ledger contract, engram tool prefix, codegraph grant, agent-language-contract, remote authorization injections), the Engram protocol section in CLAUDE.md, the review lifecycle hooks (`gentle-ai review stop-hook --agent claude-code` on `Stop` and `SessionStart` `startup|resume|clear|compact`), the skill-registry `UserPromptSubmit` refresh hook, managed output styles, and an `outputStyle` setting.
S2. Models, user answer verbatim: "bueno orquestador opus y lo demas el mejor fit". Decision: main session `opus` (wrapper `--model opus`); `review-refuter` opus; `jd-judge-a`, `jd-judge-b`, `jd-fix-agent`, `review-risk`, `review-readability`, `review-reliability`, `review-resilience` sonnet. Remove `CLAUDE_CODE_SUBAGENT_MODEL=haiku` (installed Claude Code 2.1.241 lets that variable override agent frontmatter).
S3. Telemetry hook, user answer verbatim: "me da igual . loe mejor, cinluso si skip it" — skipped (it can send data over HTTP).
S4. Output style, user answer: "Neutral" — settings `outputStyle` selects the managed neutral style.
S5. Keep the MCP-first exploration rule for Claude as well (`shared/rules/explore-mcp.md` in CLAUDE.md), worded for ODD exploration (Claude has no `gentle-ai-explore` agent; upstream generates none).
S6. No SDD remnants in the Claude path; drop the Claude legacy-bootstrap tree now that every host has a Claude ownership manifest (thinkcentre gained one 2026-10-15), removing the prior-flake fetch.

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1, S2 | delegated writer (parallel unit: Go exporter in pkgs/gentle-ai-assets) | pending | |
| T2 | S1-S6 | parent inline (Nix wiring in shared/claude-code.nix, wrapper, rules, ai-assets-tree) | pending | |
| T3 | S1-S6 | parent seam check + switch rog | pending | |

## Log

L1 (2026-10-15, user, verbatim): "ahora quiero full odd para claude tambien darle soporte gntle ai odd"
L2 (2026-10-15, evidence): explorer map (upstream /nix/store/br3n98v4…-source): `internal/components/reviewassets/install.go:26-28,226-278,320-337`; hooks `internal/components/agenthooks/claude.go:46-56`, `skill_registry.go:20-26`; presets `internal/model/claude_model.go:130-182`. Live `~/.claude/agents/*.md` carry literal `model: {{CLAUDE_MODEL}}`; settings.json has only the rtk PreToolUse hook, no `outputStyle`; Claude Code 2.1.241. Upstream generates no Claude explore/worker/verify agents.
L3 (2026-10-15, user answers): models "bueno orquestador opus y lo demas el mejor fit"; telemetry "me da igual . loe mejor, cinluso si skip it"; style "Neutral".
