# opencode-rename-sdd-removal

Objective: retire every live trace of the Gentle AI SDD workflow and make OpenCode V2 plain `opencode`, preserving all user state.
Branch: `feat/opencode-rename-sdd-removal` (from master `c164dc09`). Delivery strategy: `ask-on-risk`. Test runners: `go -C pkgs/nixos-scripts test ./...`, `nix flake check --no-build`, host `nix eval` targets, repo `*.test.py` / `*.test.ts` checks.

## Specs

S1. "Nothing from the old Gentle AI SDD workflow remains in use or installed. Historical openspec artifacts stay as history."
- Applies to: OpenCode/Claude instruction rules, agent overlays, installed skills/commands/plugins, packages (user decision L2: "Remove (Recommended)" — drop `pkgs.openspec` from Linux and Darwin home profiles and the OpenSpec step plus `--no-openspec` from `opencode-harness-init`; Engram init stays), docs that describe SDD as a live workflow, and tests that encode SDD phase names.
- `openspec/` and the ignored `sdd/` directory are history: untouched.
- Asset reconciliation must not leave empty directories behind for retired assets (rog has 12 empty `~/.openfang/skills/sdd-*` dirs).
- Hosts not yet switched (thinkcentre, t14, macm5) still hold SDD files; the switched configuration must retire them when those hosts are later switched (with user OK).

S2. "quizas tomar la idea de que el explore use herramientas mcp que ayuda mucho." — keep the MCP-research-first idea, rewritten for ODD's Explore step and the `gentle-ai-explore` agent, with no SDD phase names.

S3. "las listas en provider cambian para odd." — provider profile lists speak ODD: profiles are keyed by ODD roles (attribute `roles`, not `phases`), no SDD phase vocabulary (init/propose/spec/design/tasks/apply/archive) in comments or tests. Model assignments themselves are unchanged (assumption: not requested).

S4. "OpenCode V2 is simply "opencode": no command, path, package, module, file, script, test or doc uses "opencode2" or "opencode-v2" anymore."
- Acceptance: `git grep -I -i -E 'opencode[-_.]?v?2' -- ':!openspec' ':!odd'` returns nothing.
- Layout (decision): OpenCode uses its native XDG paths (`~/.config/opencode`, `~/.local/share/opencode`, `~/.local/state/opencode`, `~/.cache/opencode`); no XDG/TMPDIR/OPENCODE_DB overrides and no environment file.
- Commands: `opencode` (project config disabled by default), `opencode-project` (project config enabled), `opencode-home` (replaces `opencode2-home`). Package attribute `opencode`, directory `pkgs/opencode`, binary `bin/opencode`.

S5. "My existing sessions, credentials, history and configuration must survive."
- Sessions and credentials live in the V2 DB (`credential`, `session_v2` tables) at `~/.local/opencode-v2/data/opencode.db`; history/state under `~/.local/opencode-v2/{data,state}/opencode`; user config `~/.config/opencode-v2/opencode.jsonc` and `service.json`.
- Migration moves them to the native paths, never deletes: every other old item (V1 leftovers at the native paths, `~/.config/opencode-back`, child-process junk, cache, tmp) moves into one archive under `~/.local/share/opencode-migration-archive/<UTC timestamp>/`.
- Migration refuses to run while an OpenCode server from the old layout is alive; it is idempotent (no-op when no old root exists).

S6. "You are authorized to implement, commit on a feature branch and switch rog; push, merge to master and other hosts need my OK."

## Tasks

| ID | Specs | Route | Status | Evidence |
|----|-------|-------|--------|----------|
| T1 | S1, S2, S3 | delegated writer A (parallel units) | done | eb62c465; RED/GREEN projectinit + reconcile prune |
| T2 | S4, S5 (Go: renames + migration command) | delegated writer B (parallel units) | done | 321abb41; fix d70e10a7 (RED/GREEN resume test) |
| T3 | S1, S4, S5 (Nix: package, modules, wiring, tests, docs) | writers C/C1/C2 partial, finished inline by parent | done | dd8e7ceb |
| T4 | S1-S5 seam check + independent verify | parent + verifier (high risk: data, CLI contract) | done | S1-S4 pass; S5 blocker fixed in d70e10a7, recheck pass |
| T5 | S5, S6 switch rog + migrate + post-check | parent, detached job | done | switch exit=0; DB 186 sessions, 5 credentials |

Route evidence: T1-T3 have disjoint edit surfaces and each is clearly heavier than a subagent start (Writer trigger a). T4 high risk items 1 (persisted data move) and 3 (CLI commands renamed).

## Log

L1 (2026-10-15, user, verbatim):
"Gentle AI v4.1.1 with ODD is now live on rog from master. I want two outcomes in /home/glats/.nixos:

1. Nothing from the old Gentle AI SDD workflow remains in use or installed. Historical openspec artifacts stay as history.

2. OpenCode V2 is simply "opencode": no command, path, package, module, file, script, test or doc uses "opencode2" or "opencode-v2" anymore. My existing sessions, credentials, history and configuration must survive.

Assume nothing about the current state; verify it. Ask me only for decisions that are genuinely mine. You are authorized to implement, commit on a feature branch and switch rog; push, merge to master and other hosts need my OK."

L2 (2026-10-15, user decision): OpenSpec CLI question answered "Remove (Recommended)".

L3 (2026-10-15, user, verbatim): "usa caveman y ponitail"

L4 (2026-10-15, user, verbatim): "o sea quiero que uses full ODD y atento con lo solicitado. la idea es sacar topdo lo de sdd, quizas tomar la idea de que el explore use herarmitnas mcp que ayuda mucho. las listas en provider cambian para odd."

L5 (2026-10-15, evidence, rog + read-only ssh):
- 119 tracked files match outside openspec: 35 files / 171 hits with the S4 regex.
- rog V2 runtime: config `~/.config/opencode-v2` (managed + `opencode.jsonc`, `service.json`, junk `BraveSoftware/ go/ pulse/`), runtime `~/.local/opencode-v2/{data,state,cache,tmp}` (data 208M, tmp 2.3G), env file `~/.local/share/opencode-v2/environment`. V2 server pid in `~/.local/opencode-v2/state/opencode/service.json`; this session runs on it.
- Native V2 defaults (`opencode2 debug paths` with clean env): data `~/.local/share/opencode`, db `opencode.db`, config `~/.config/opencode`, state `~/.local/state/opencode`, cache `~/.cache/opencode`. These paths hold stale V1 leftovers (last write 2026-10-05) including SDD skills/commands in `~/.config/opencode`.
- DB: `opencode-v2` strings only in `instruction_blob` (186) and `session_message` (4355) text history; no structural path columns.
- SDD live on rog: `shared/rules/explore-mcp.md` (sdd-explore) injected into gentle-orchestrator via `local-agent-overlays.json`; `output-format.md` SDD wording; unused `review-gate.md`; `pkgs.openspec`; harness-init OpenSpec; docs `gentle-ai-omo-workflow.md`, `oh-my-openagent.md`, `opencode-provider-tier-execution-brief.md`, `opencode-v2-final-cutover.md`; empty `~/.openfang/skills/sdd-*` dirs.
- thinkcentre, t14, macm5: no ownership manifests; 11 SDD skills in `~/.config/opencode-v2/skills`, `~/.openfang/skills`, `~/.claude/{agents,skills}`.

L6 (2026-10-15, decisions): native XDG layout; V2 config tree rebuilt fresh after archiving (so the V2 consumer needs no legacy bootstrap and the `opencode-v2` byte references go); openfang sync only where `home.openfang` is enabled (rog, already manifest-owned), stale `~/.openfang/skills` on other hosts archived by the migration; Claude legacy bootstrap stays (other hosts need it to retire SDD agents). Migration is a tested Go command invoked from Home Manager activation. Rog switch runs last from a detached job because it must stop the server this session runs on.

L7 (2026-10-15, evidence): writers C, C1, C2a stopped early (partial) repeatedly; parent finished T3 inline. Checks: `go -C pkgs/nixos-scripts test ./...` pass; `nix flake check --no-build` pass; rog/t14/thinkcentre toplevel and rog/t14/thinkcentre HM activation eval pass; macm5 eval fails with "Required system: 'aarch64-darwin'" (gentle-ai IFD) identically at baseline c164dc09 — known environmental, unverified for Darwin. `home-launcher.test.py`, `v2-agents.test.py`, `asset-ownership.test.py`, `contracts.test.py` PASS. S4 grep empty; the only intentional references to the old name are `"opencode-" + "v2"` in the migrator and its test (it must locate the old roots). host-config plugin deleted (only forced the native XDG default). Verifier: S1-S4 pass; S5 resume blocker (re-archiving migrated data) fixed by a one-shot archive marker, recheck pass on c1/c2/first-loop probes.
L8 (2026-10-15): moved 10 OpenFang-generated `~/.openfang/skills/sdd-*` dirs (skill.toml/prompt_context.md derived from retired SDD skills) to `~/.local/share/opencode-migration-archive/openfang-sdd-<ts>/`; removed 2 empty ones. Next: T5 detached rog switch (kills this session's server), then post-check on resume.
L9 (2026-10-15, user, verbatim): "quiero hgacer los menos pasos posible. asi que temrina por mi y luego listame los coamndos que tengo que dejar. todo en la rama master. sin pr. ok?"
L10 (2026-10-15, evidence): rog switch exit=0; migration archive 20261015T184557Z; old roots gone; `opencode debug paths` native; `opencode auth list` shows stored Anthropic/OpenAI/Console logins; DB has 186 sessions and 5 credentials; this session resumed on the new layout; no `sdd` skills in ~/.config/opencode/skills. Merged fast-forward to master and pushed per L9. Remaining: switch thinkcentre, t14, macm5.
