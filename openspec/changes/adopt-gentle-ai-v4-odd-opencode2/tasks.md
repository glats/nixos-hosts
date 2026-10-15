# Tasks: Adopt Gentle AI 4.1.1 ODD in opencode2 (rog)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | Staged apply diff ~18 lines; full branch vs master ~3,300 lines (feature/gentle-ai-4 carried in) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | Unit 1 (pin/packaging/reconcile) → Unit 2 (routing/tests/openspec) |
| Delivery strategy | Single branch/worktree now; commit/PR split deferred until commits are authorized |
| Chain strategy | Single branch; no commit, push, or PR authorized |

Decision needed before apply: No — user selected one branch for this apply; commit/PR split deferred
Chained PRs recommended: Yes — delivery decision is to defer splitting until commits are authorized
Chain strategy: single branch/worktree; no publication
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Pin v4.1.1, packages, reconcile SHA args | PR 1 | `nix build .#gentle-ai .#gentle-ai-assets`; `python3 shared/opencode/asset-ownership.test.py` | N/A: build-level; live proof in 3.3 | Revert flake.nix/lock, pkgs/gentle-ai*, runtime-config.nix, claude-code.nix |
| 2 | Rog routing, v2-agents test, openspec supersede note | PR 2 (base = PR 1) | `python3 shared/opencode/v2-agents.test.py` | N/A: offline eval; live proof in 3.3 | Revert hosts/rog/home/default.nix, providers-base.nix, v2-agents test |

## Phase 0: Completed (evidence in Engram #4245, staged in worktree)

- [x] 0.1 Pin `gentle-ai-src` to v4.1.1 `898d3976…` in `flake.nix`/`flake.lock` — `nix build .#gentle-ai` OK
- [x] 0.2 Version 4.1.1 in `pkgs/gentle-ai/default.nix`, `pkgs/gentle-ai-assets/{default,render}.nix` — `nix build .#gentle-ai-assets` OK
- [x] 0.3 Reconcile SHA args in `shared/opencode/runtime-config.nix`, `shared/claude-code.nix`, `asset-ownership.test.py`, `home-launcher.test.py` — asset-ownership, home-launcher, contracts tests and `go test ./internal/aiassets` PASS
- [x] 0.4 `hosts/rog/home/default.nix` activeProviderName = `anthropic-openai-opencode` — decision #4242

## Phase 1: Routing Verification

- [x] 1.1 Fix `shared/opencode/v2-agents.test.py` line 88: baseline 35 → after 33 (retire 3, add approved `anthropic-openai-opencode`). Update expected set and assert the new profile's shape separately; keep per-profile equality for existing profiles. `python3 shared/opencode/v2-agents.test.py` — PASS (exit 0; both PASS lines). New profile source block matches master's dirty `shared/opencode/providers-base.nix` exactly; test validates its transformed v4 phase/profile shape.
- [x] 1.2 Verify provider diff vs decisions #4242: 3 retired profiles absent; `nvidia` alias and `nvidiaProvider` retained; all `sdd-*` phases mapped to `gentle-ai-explore/worker/verify`. Evidence: focused provider assertions in the passing test; exact profile block comparison against the master checkout passed.

## Phase 2: Gates

- [x] 2.1 rog toplevel + HM: `nix eval --offline --raw .#nixosConfigurations.rog.config.system.build.toplevel.drvPath` — PASS (exit 0; `/nix/store/wrgw5k5lq03412hzyvgpfkxiyil30bfb-nixos-system-rog-26.05.20260822.a9e6d84.drv`); `nix build --no-link --print-out-paths "path:$PWD#nixosConfigurations.rog.config.system.build.toplevel"` — PASS (exit 0; `/nix/store/i2bqdag9k420mvkq2jsz1nwqz5yxxpnk-nixos-system-rog-26.05.20260822.a9e6d84`). Build included `home-manager-glats.service` and HM generation derivations.
- [x] 2.2 `nix flake check --no-build "path:$PWD"` — PASS (exit 0; all checks passed; incompatible Darwin systems omitted by host platform).
- [ ] 2.3 macm5: attempted `nix eval --offline --raw .#darwinConfigurations.macm5.config.system.build.toplevel.drvPath` and standalone `homeConfigurations.macm5.activationPackage.drvPath`; both BLOCKED on x86_64-linux by IFD trying to build an `aarch64-darwin` bootstrap-tools derivation (platform mismatch), ending at `gentle-ai-assets-4.1.1`. Linux standalone HM evals passed: rog `/nix/store/nsizzbd5504wskg3byc144aknxsgls51-home-manager-generation.drv`, thinkcentre `/nix/store/pcdzq3jwcmh7ryc317piyfs2x5jwq5va-home-manager-generation.drv`, t14 `/nix/store/qgayw271v7qh296ilz2qr5pcr03q010n-home-manager-generation.drv`. `nix eval --offline --json .#homeConfigurations --apply builtins.attrNames` — PASS; configs are macm5, rog, t14, thinkcentre.
- [x] 2.4 Added superseded note to `openspec/changes/gentle-ai-v4-odd-v2-only/{tasks.md,proposal.md}` (preserved all content).

Verification evidence: `nix eval --offline --raw .#nixosConfigurations.thinkcentre.config.system.build.toplevel.drvPath` — PASS `/nix/store/2sdgxwzsi0x7v95axxs5zk7aipp7w8l2-nixos-system-thinkcentre-26.05.20260822.a9e6d84.drv`; t14 — PASS `/nix/store/cagxn07c34p1b7qd7mjc91wzi8nnff4b-nixos-system-t14-26.05.20260822.a9e6d84.drv`. `nix fmt -- flake.nix hosts/rog/home/default.nix pkgs/gentle-ai-assets/default.nix pkgs/gentle-ai-assets/render.nix pkgs/gentle-ai/default.nix shared/claude-code.nix shared/opencode/runtime-config.nix` — PASS (7 files processed, 0 changed).

## Phase 3: Activation and Acceptance

- [x] 3.1 `nixos-build switch` on rog — explicitly authorized by user ("continua y terminalo"). Keep previous generation for rollback. Evidence: see "Live verification" below (V1).
- [x] 3.2 Live checks: `systemctl is-active home-manager-glats.service` = active; `gentle-ai --version` = 4.1.1; `ai-assets-reconcile` on PATH; `~/.config/opencode-v2` has v4 assets, no `sdd-task-result.ts`; upstream V2 review transport present.
- [x] 3.3 User runs ONE real ODD session in opencode2 (user action; not automatable here).
  Evidence 2026-10-15 13:12: user restarted opencode2 (new PID 255988); screenshot
  ~/Pictures/2026-10-15_13-12.png shows default agent gentle-orchestrator "Organic Driven
  Development coordinator" on Claude Opus 5.5, no sdd-* agents. In-session: `gentle-ai --version`
  = 4.1.1, PATH has gentle-ai-v2-managed (no f5dd). ODD task run by the orchestrator: delegated
  read-only map to native `gentle-ai-explore` (completed), then inline removal of the empty
  skills/sdd-* dirs in ~/.config/opencode-v2 and ~/.claude (0 left; no files deleted).
- [ ] 3.4 Commit on `feat/adopt-gentle-ai-v4-odd` — NOT authorized yet; needs separate approval. Respect chain strategy decision first.

## Live verification (rog, 2026-10-15, read-only)

| # | Check | Result | Evidence |
|---|-------|--------|----------|
| V1 | Active system | PASS | `readlink /run/current-system` and `readlink -f /nix/var/nix/profiles/system` both = `/nix/store/i2bqdag9k420mvkq2jsz1nwqz5yxxpnk-nixos-system-rog-26.05.20260822.a9e6d84` |
| V2 | HM service | PASS | `systemctl is-active home-manager-glats.service` = active; ExecMainStatus=0, ActiveEnter 11:04:39; invocation 54336b1a… journal (29 lines) has no error/collision/fail; reconcile runs silently inside setupOpencodePluginRuntime-v2, syncOpencodeSkillsToOpenfang-v2, deployClaudeCodeAssets. Only failure is the earlier 11:02:26 run (`asset collision: ~/.claude/agents/review-risk.md`), resolved by moving 55 files (21 .claude / 19 opencode-v2 / 15 .openfang) to `~/.local/opencode-v2/tmp/opencode/asset-drift-backup-20261015T110335` |
| V3 | gentle-ai 4.1.1 + reconcile | PASS | login shell: `/etc/profiles/per-user/glats/bin/gentle-ai --version` = `gentle-ai 4.1.1` (gentle-ai-v2-managed → gentle-ai-4.1.1); `ai-assets-reconcile` in HM path |
| V4 | opencode-v2 tree | PASS (cosmetic residue) | plugins = engram, host-config, opencode-review-transport, rtk, skill-registry; no sdd-task-result.ts. `.agents` has gentle-ai-explore/worker/verify, gentle-orchestrator (default_agent), no sdd-*. ~/.claude/agents has no sdd-*.md. v4 skills present. Residue: 11 empty `skills/sdd-*` dirs (0 files, no SKILL.md) in opencode-v2 and 12 in ~/.claude/skills — not loadable |
| V5 | Ownership manifests | PASS | .claude 4507, opencode-v2 4514, .openfang 4494 entries; all revision 898d3976…, pending=0, prior=0; sha256 match for every entry, 0 mismatch, 0 missing; no sdd-* keys |
| V6 | Routing | PASS | opencode.json: gentle-orchestrator → anthropic/claude-opus-5-5 (primary), gentle-ai-worker → openai/gpt-6-luna, gentle-ai-explore → opencode-go/glm-5.3-flash, gentle-ai-verify → anthropic/claude-sonnet-5-5; rog activeProviderName = anthropic-openai-opencode |
| V7 | opencode2 binary | PASS | `opencode2 --version` = `opencode v2.0.14` |

Notes for 3.3: the opencode2 process running before the switch (PID 13159, started 10:39) inherited a PATH with the legacy `gentle-ai-f5dd1a6…` (reports `dev`) in front, and loaded pre-switch config. Start the real ODD session from a fresh login shell and a fresh opencode2 process. Unowned legacy `~/.openfang/skills/sdd-*/{skill.toml,prompt_context.md}` (dated 10:31) remain because legacyOpenfang is empty; this does not affect opencode2. `shared/rules/explore-mcp.md` still mentions "`sdd-explore`" in the orchestrator system prompt (wording only).

## Provider profile flattening (2026-10-15)

- [x] Flatten provider profiles to gentle-ai-* role keys (no remap) — `shared/opencode/providers-base.nix`: all 33 profiles (canonical + legacy) renamed `sdd-explore`→`gentle-ai-explore`, `sdd-apply`→`gentle-ai-worker`, `sdd-verify`→`gentle-ai-verify`; dead `sdd-{init,propose,spec,design,tasks,archive,onboard}` keys and their per-key comments deleted (no `sdd-research` existed); remap `map (provider: ... filterAttrs ...)` removed, now `providers = canonicalProviders ++ legacyProviders;`. `openai-anthropic-go` override set was only dead keys, so it is now `phases = anthropicOpenaiPhases;` (resolved routing identical to `openai-anthropic-medium`). File 1070→822 lines (+96/−344). Equivalence: JSON of `{providers, providerAllowlist, activeProviderName, activeProvider, nvidiaProvider}` evaluated before vs after is byte-for-byte equal (33 profiles, 0 per-profile mismatches). `python3 shared/opencode/v2-agents.test.py` PASS (baseline-commit remap in the test intentionally kept), `home-launcher.test.py` and `asset-ownership.test.py` PASS, `nix flake check --no-build` all checks passed, rog toplevel built: `/nix/store/al2dgk8cam0v977ssm4772jcs3s2l1ji-nixos-system-rog-26.05.20260822.a9e6d84`.

## model-fit re-fit: anthropic-openai-opencode (2026-10-15)

- [x] Update model-fit skill to flat 14-key schema and re-fit rog's `anthropic-openai-opencode` to ODD roles — `shared/assets/skills/model-fit/SKILL.md`: legacy explore/apply/verify remap line removed, 14 role keys listed once, "editing a profile = editing those keys directly", routing-key "phase" wording → "role". `shared/opencode/providers-base.nix`: Gate 1 (open truncation without finish_reason) removes all opencode-go roles — `gentle-ai-explore` and `jd-fix-agent` `opencode-go/glm-5.3-flash` → `openai/gpt-6-luna` (opencode#50146 open; Luna AA-LCR v1.1 83% vs Haiku 5.5 77% at the same $0.10/$0.50, artificialanalysis.ai); six `review-*` `opencode-go/deepseek-v4-pro` → `openai/gpt-6.1-sol` (opencode#41582 open mid-tool-call cuts naming DeepSeek-V4-Pro, #44148 Go-gateway cutoffs, #47934 misbilling; Sol $2/$10 keeps lenses cross-family vs Sonnet verify/judges). Orchestrator/neutral Opus 5.5, worker Luna, verify/jd-judge-a/b Sonnet 5.5 kept. All IDs verified present in `opencode2 models` and models.dev/api.json (tool_call true). No live model probes run. `v2-agents.test.py` pinned shape updated → PASS; `nix flake check --no-build path:$PWD` all checks passed; rog toplevel built: `/nix/store/b4dp11jcbcwbnmhm6hdzi9h16n9s2jnp-nixos-system-rog-26.05.20260822.a9e6d84`. Not activated.
