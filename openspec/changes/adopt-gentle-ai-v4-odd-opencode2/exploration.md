# Exploration: adopt-gentle-ai-v4-odd-opencode2

Change: adopt Gentle AI v4 with ODD in the OpenCode V2 harness (opencode2), primarily on rog.
Investigated read-only on 2026-10-14. Classifications: VERIFIED (command evidence), UNVERIFIED (prior claim, not disproven), CONTRADICTED.

## Verified Facts

### Upstream (MCP research)
- VERIFIED — Gentle AI v4.0.0 tag = commit `ff77164d4f56f1665b22fb6fac51c2ccbb769400` (GitHub `get_commit` on `v4.0.0`). Release notes (v4.0.0, published 2026-10-01): "SDD Retires, ODD Leads, Module Path Moves to /v4".
- VERIFIED — ODD = Organic Driven Development. In v4.0.0 it becomes the ONLY development workflow; SDD and OpenSpec are retired. ODD delegation follows an "evidence budget" instead of file counts: work stays inline only when evidence fits one parallel batch (<=3 calls, ~10k tokens); otherwise one explorer returns a bounded `path:line` handoff. Independent native review (RDD) and test-first development remain available. Every non-Pi runtime gets a managed orchestrator prompt from one shared contract.
- VERIFIED — v4.0.0 gives OpenCode V2 "managed plugins and native review"; `gentle-ai install` requires `opencode --version` to succeed on PATH for the OpenCode agent (upstream `docs/quickstart.md`).
- VERIFIED — Upstream has moved past v4.0.0: releases v4.1.0 ("Proportionate Native Review and a Clean SDD Exit" — cleans up installed Gentle-owned SDD agents/skills/commands/hooks/profiles on sync) and v4.1.1 exist. Pin choice (4.0.0 vs 4.1.x) is an open decision.

### Repository / branches
- VERIFIED — master at `4750736c` pins `gentle-ai-src = github:Gentleman-Programming/gentle-ai/v2.5.0`; `pkgs/gentle-ai/default.nix` sets `version = src.rev`.
- VERIFIED — `feature/gentle-ai-4` = one commit `3e2078e8` ("working") on top of master; 34 files (+2039/-1299). It pins exactly commit `ff77164d...` (= v4.0.0, confirmed tag) via flake.nix + flake.lock (`nix show flake.lock node` output).
- VERIFIED — feature branch `pkgs/gentle-ai/default.nix` hardcodes `version = "4.0.0"` and ldflags `-X main.version=4.0.0`; adds `pkgs/nixos-scripts/cmd/ai-assets-reconcile` + `internal/aiassets/{reconcile.go,reconcile_test.go}` (all tracked in the branch), `shared/ai-assets-tree.nix`, `pkgs/gentle-ai-assets/render.nix` (+render_test.go), and test files (contracts.test.py, asset-ownership.test.py, render_test.go).
- VERIFIED — feature branch removes SDD-era V2 plugins `sdd-task-result.ts` and `opencode-review-transport.ts` from `pkgs/gentle-ai-assets/v2-plugins/` (only `skill-registry.ts` remains; the review-transport plugin is now produced through upstream rendering — its test file still exists and was updated; runtime-config.nix references the rendered paths). This matches upstream "SDD retires" and "OpenCode V2 managed plugins".
- VERIFIED — the feature branch DOES include the `shared/skills.nix` fix (`git diff master...feature/gentle-ai-4 -- shared/skills.nix`): `.claude/skills/rom-downloader` is no longer deployed by HM (ai-assets-reconcile owns real files and refuses symlinked paths); only `.agents/skills/rom-downloader` remains.
- VERIFIED — `nix eval 'git+file:///home/glats/.nixos?ref=feature/gentle-ai-4#nixosConfigurations.rog.config.system.build.toplevel.drvPath'` succeeds: `/nix/store/0vjf76y4s4nw8sqrxnl8zmm5ac40278s-nixos-system-rog-26.05.20260822.a9e6d84.drv`. The branch evaluates cleanly.

### Live rog state (hostname VERIFIED = rog)
- VERIFIED — current system: `/nix/store/ag4cjdjmy5qv63ckrcgk2n36qkz5vahf-nixos-system-rog-26.05.20260822.a9e6d84`; nixos-version `26.05.20260822.a9e6d84`.
- VERIFIED — `systemctl is-active home-manager-glats.service` = active (exited) since 2026-10-14 22:34:14.
- VERIFIED — gentle-ai binary in HM environment: `gentle-ai --version` prints `dev`; derivation path is `gentle-ai-f5dd1a6cf1823371374c7b2bef5b71e4790a146a`. The name matches master's `version = src.rev` scheme — this is a **v2.5.0-based build from master's pin**, NOT the feature branch (which would be named `gentle-ai-4.0.0` and print `4.0.0`).
- VERIFIED — `ai-assets-reconcile` is NOT in `~/.nix-profile/bin` and NOT in PATH; `opencode`/`opencode-v2` are not on PATH (OpenCode V2 CLI lives at `/nix/store/08ckbjx2...-opencode-v2-2.0.14/`, i.e. **opencode CLI 2.0.14**, not on PATH in this shell; rtk 0.41.0 present).
- VERIFIED — `~/.config/opencode-v2/` contains: skills/ (full SDD-era skill set: sdd-* agents exist), plugins/ (engram.ts, host-config.ts, opencode-review-transport.ts, rtk.ts, sdd-task-result.ts, skill-registry.ts), agents (opencode.json `agents` key lists gentle-orchestrator, jd-*, review-*, sdd-* including sdd-explore), cli.json, opencode.json (106 KB). This is a **v3/SDD-era Gentle AI stack** — live state matches master's pin/promises, not the feature branch.
- VERIFIED — `~/.claude/skills/rom-downloader` symlink EXISTS pointing into the HM generation, plus a `rom-downloader.backup/` directory beside it. Master worktree's `shared/skills.nix` still deploys `.claude/skills/rom-downloader`.
- UNVERIFIED — whether the live rog system drv equals the feature-branch drv `0vjf76y4...` (comparison of built drv for live system not computed; binary version evidence already shows live ≠ feature branch for the gently binary, so considered effectively contradicted for the v4 asset set).

### Prior Engram claims vs reality
- UNVERIFIED/CONTRADICTED (nuanced) — #4239/#4240 claims ("rog switched to a system including ai-assets-reconcile", "skills.nix rom-downloader entry removed"): the live system/HM generation contains NO ai-assets-reconcile and `shared/skills.nix` on master still deploys `.claude/skills/rom-downloader` (present live as symlink + backup dir). What DID land live is the reconciliation-failure hardening (`.gentle-ai-owned.json` + `.gentle-ai-owned.lock` exist in `~/.config/opencode-v2/`), and HM activation is green. The remediation logic only fully exists on `feature/gentle-ai-4`.
- VERIFIED (from recent Engram manual observations, alive in mem_context) — the two real breakages today were: (a) untracked Go files broke `nixos-scripts` on the dirty flake tree ("cmd/ai-assets-reconcile: directory not found"), fixed by committing them to the feature branch; (b) HM activation failure "refusing symlink: /home/glats/.claude/skills/rom-downloader", addressed by the skills.nix fix (now on the feature branch and seemingly partially live).
- VERIFIED — old change `gentle-ai-v4-odd-v2-only` tasks.md: 7 tasks checked, 4 unchecked; open items are domain 3 live gates: 3.1–3.2 (offline planning complete), 3.4 ("After proof and explicit model/network plus ODD delegation/MCP auth ...") and 3.5 (rollback verification). Engram history (#4066–#4165) shows many private OAuth-mediated "organic ODD cycles" repeatedly failing before/during worker dispatch; the change stalled on LIVE ODD-cycle proof, not on repository/repo packaging work.

### What ODD requires in opencode2 (from upstream evidence + repo state)
Operational shape of "Gentle AI 4 ODD usable in opencode2":
1. `gentle-ai` binary built from the v4 pin reporting version `4.0.0` (or chosen newer).
2. `gentle-ai install`-equivalent assets rendered for opencode-v2 into `~/.config/opencode-v2/`: managed orchestrator prompt (gentle-orchestrator as a managed agent — the shared ODD contract, not the v3 SDD one), skills (including choking-command set replacing SDD skills), managed plugins (the v4 set; `sdd-task-result.ts` and the V1-style review transport retire), and skill-registry.
3. ai-assets reconciliation so `.claude/skills` and opencode-v2 owned assets are consistent (`ai-assets-reconcile` from the branch).
4. An actual session in opencode-v2 harness using the ruleset.

## Affected Areas
- `flake.nix` / `flake.lock` — pin swap v2.5.0 → v4.0.0 (or 4.1.x).
- `pkgs/gentle-ai/default.nix` — version/ldflags 4.0.0.
- `pkgs/gentle-ai-assets/*` — skill/plugin rendering incl. V2 plugin set (retire SDD-era plugins).
- `pkgs/nixos-scripts/cmd/ai-assets-reconcile`, `internal/aiassets` — new Go reconcile binary (only on feature branch).
- `shared/ai-assets-tree.nix`, `shared/claude-code.nix`, `shared/skills.nix`, `shared/opencode/*` (agents, runtime-config, providers-base, v2-agents), `shared/rules/authorization.md`.
- `hosts/rog/home/default.nix` (and the other hosts for whole-flake rollout).
- Live artifacts: `~/.config/opencode-v2/{opencode.json,skills,plugins,cli.json}`.

## Approaches

1. **Finish from `feature/gentle-ai-4`** — cherry-pick/merge the branch's single "working" commit into the new change (branch evaluates cleanly, includes skills.nix fix, fixes the two breakages seen today, pins authentic v4.0.0).
   - Pros: All the packaging + reconcile + test infrastructure already done; branch evaluates; diff already built around exactly this goal; cheapest path.
   - Cons: Single squashed commit named "working" (history noise); provider edits inside it (providers-base model cuts and activeProviderName switch) may enshrine choices never explicitly re-reviewed in this new change context; must re-verify every claim since branch content lints unknown (tests passing state assumed from commit message "working" only).
   - Effort: Low–Medium.
2. **Restart from master** — re-do the pin swap, asset rendering, and reconcile from scratch in a fresh change.
   - Pros: Clean decisions, no inherited provider/model choices, full ownership of every line.
   - Cons: Rebuilds ~900 lines of tested code (reconcile.go 347 + tests 333, render.nix + tests, asset-ownership tests, ai-assets-tree.nix 104); repeats the exact failures already debugged today; slower and higher re-risk.
   - Effort: High.
3. **Hybrid** — adopt the branch's mechanical packaging (pin, pkgs, reconcile, ai-assets-tree, skills.nix fix) but re-review and re-decide the app-facing layer (providers-base.nix model cuts, activeProviderName, agent list) herself against current model reality.
   - Pros: Keeps proven offline work; isolates the risky judgment ("which model providers must exist in v4 stack") to an explicit app decision instead of inheriting "working" commit content.
   - Cons: Requires care to not split the branch; deltas must be reverted on top.
   - Effort: Medium.

## Recommendation
Approach 3 (hybrid), executed as adoption of feature/gentle-ai-4 plumbing with an explicit app-config re-review, because the branch is VERIFIED-based only on what inspection proves, and everything else inside was only ever committed as "working" for goal-related machine plumbing solvable by reading it. The critical insight from the old change: the stall was at LIVE ODD-cycle proof (private paid model cycle / organic ODD acceptance gating), NOT at repository plumbing. This new change should decouple: the plumbing (pin v4 on opencode2 with reconciled assets) is fully static and testable; the "usable" acceptance must be defined in live-verifiable terms explicitly listing what counts and does NOT require paid model cycles.

### Minimal, live-verifiable acceptance for "Gentle AI 4 ODD usable in opencode2 on rog"
1. `gentle-ai --version` on rog prints `4.0.0` (or chosen newer) from a Nix-built derivation whose source pin matches an upstream tag/release.
2. `~/.config/opencode-v2/opencode.json` references only v4-managed assets: no `sdd-*` SDD-era skills/agents sourced into opencode2 from gentle-ai (SDD agents keep AS opencode's own modules since they're reusable), managed `gentle-orchestrator` prompt matches upstream v4 ODD contract, skill-registry plugin present, SDD-era plugins (`sdd-task-result.ts`, v1-style review transport) absent from `~/.config/opencode-v2/plugins`.
3. `ai-assets-reconcile` available and runs clean (no owned/symlink conflicts on `~/.claude/skills`/`~/.config/opencode-v2`).
4. `nixos-build safe`/`dry` passes and HM generation switches green with the new assets reconciled (no-op claim: does NOT require paid model calls, does NOT require running an ODD delegation cycle).
5. Explicitly out of scope of acceptance: actually orchestrating a full organic ODD production cycle with private paid models (that was old change 3.4 territory and can be gated later; may be re-requested as a separate optional follow-up given private OAuth cycles stalled historically).

## Risks
- feature/gentle-ai-4 hides mixed concerns (plumbing + provider/model selection cuts) in one commit; merging wholesale could seal provider decisions under a noise-named commit ("working").
- Live `~/.config/opencode-v2/plugins/` and skills dir contain backends rendered from current master; switching pins without running the reconciler leaves doubled/incompatible assets (today's real breakages proved exactly this failure mode on the non-updated assets).
- Uncommitted master tree dirt (providers-base.nix, hosts/rog/home/default.nix) overlaps files touched by the branch; turning the branch into a change needs explicit dirt reconciliation or careful merge so nothing is silently overwritten.
- v2.5.0 → v4.0.0 upstream jump retires SDD; old openspec/changes SDD history and active `openspec/changes` persisted artifacts for OTHER changes must be preserved (old change said so and remains sensible).
- Old private OAuth paid-cycle dependency: if the user wants live ODD cycle acceptance, cost and stalling risk persist; recommended to NOT require it in this change.
- Other-host parity (thinkcentre/t14/macm5) unknown state; only rog was live-verified; remote-host proof stays unverified until evaluated.

## Open Decisions for the User
1. Pin v4.0.0 (as prepared on feature branch) or jump to v4.1.1 (retires SDD assets more completely; "Clean SDD Exit" — possibly exactly the end-state the user wants)?
2. How to treat the branch's provider-base/model-selection cuts inside it: adopt wholesale, re-review, or keep master's current live providers and defer model selection to a later change?
3. Whether the old `gentle-ai-v4-odd-v2-only` change should be formally closed/superseded by this new change, leaving its unused (offline-complete) planning as historical evidence.
4. Acceptance strictly offline-verifiable (repo/generation/asset-level correctness) or must include one live opencode session using gentle-ai v4 commands? A single non-paid opencode session invocation of ODD-orchestrator (e.g. help/doctor without paid cycle) could bridge "provable" and "usable" without the stalled private-OAuth risk.
5. Which previous live-rogomal fixed-up untracked/uncommitted masters changes (CHKSKS dirty + rom-downloader.backup on disk) should be cleaned up as part of the new change or resolved by simply merging the fix share of the feature branch.

## Ready for Proposal
Yes — with decisions 1–4 above answered by the user; the recommended track is hybrid (Approach 3) with acceptance defined by the offline branch above.
