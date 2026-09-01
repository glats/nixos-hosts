# Tasks: Remove OpenCode Proxy Legacy

> **Archive-time reconciliation 2026-09-01**: All tasks were executed on branch
> `cleanup/remove-opencode-proxy-legacy` and merged to master via commit
> `97f291f` ("refactor(opencode): remove dead proxy gateway", ancestor of
> `master`). The persisted artifact retained stale `- [ ]` boxes because apply
> ran on the branch; sdd-archive reconciled them at close with proof: merged
> commit, grep-clean tree (`openai-proxy|OPENAI_PROXY_API_KEY|oai.glats.org` →
> zero Nix matches), `secrets/host/rog/openai-proxy.yaml` untracked, mact2
> switched to `opencode-go-medium` then native `openai-medium`, and
> `mact2-openai-tls-tunnel-via-rog/tasks.md` Phase-6 reconciliation note. Task
> 4.2 (optional doc example in AGENTS.md:104) was not executed — optional,
> docs-only, outside Nix grep scope.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 160-260 (mostly deletions, net negative) |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Proxy family removals (Phase 1) | PR 1 | grep-clean (3.3) empty | `format-nix && nix flake check --no-build` | revert cleanup commit; secret in Git history |
| 2 | mact2 interim switch (Phase 2) | PR 1 | darwin eval (3.4) | inspect mact2 `opencode.json` | revert switch → `openai-medium-proxy` |
| 3 | Verification + smoke (Phase 3) | PR 1 | `nix flake check --no-build` | rog `nixos-build` (USER-RUN); curl oai | no state change; re-run smoke after revert |

## Phase 1: Removals (one commit-friendly unit)

- [x] 1.1 Delete `linux/system/services/web/opencode-proxy.nix`; from `hosts/rog/default.nix` remove import (line 67), `services.opencodeProxy` block (211-223), `systemd.services."opencode-proxy"` timeout (193). Verify: `rg opencodeProxy hosts/rog/default.nix` empty. Rollback: revert.
- [x] 1.2 Remove `oai.${domain}` vhost (lines 589-638) from `linux/system/services/web/nginx.nix`. Verify: no `oai.` vhost remains. Rollback: revert.
- [x] 1.3 From `shared/opencode/providers-base.nix` remove `openaiProxyProvider` (355-403), its `allProviders` concat (405) + `inherit` (879), `openai-{full,medium,light}-proxy` tiers (711-775). Rollback: revert.
- [x] 1.4 Remove `OPENAI_PROXY_API_KEY` block (lines 106-110) from `shared/opencode.nix`. Grep-verified: no other production refs (openspec/ docs untouched). Rollback: revert.
- [x] 1.5 Sops: `openai_proxy/*` decls in `hosts/rog/secrets.nix` (77-97), client_key in `darwin/home/sops.nix` (35-40), `.sops.yaml` rule (comment 10-12 + rule 13-18), then `git rm secrets/host/rog/openai-proxy.yaml`. Verify: `.sops.yaml` parses w/o rule. Rollback: revert restores file.

## Phase 2: mact2 interim provider switch

- [x] 2.1 `hosts/mact2/default.nix`: `home.opencode.activeProviderName = "opencode-go-medium";` (line 56) + rewrite stale proxy comment (51-55) — needed for grep-clean. Verify: spec R2.
- [x] 2.2 `flake.nix` (line 299, standalone HM override): same tier. Verify: mact2 HM eval shows tier. Rollback: revert.

## Phase 3: Verification

- [x] 3.1 `format-nix`; review diff for intended edits only.
- [x] 3.2 `nix flake check --no-build` (all hosts; spec R4 no-regression).
- [x] 3.3 Grep-clean: `grep -rn "openai-proxy\|OPENAI_PROXY_API_KEY\|oai\.glats\.org" --include="*.nix" .` → zero matches (spec R1/R3).
- [x] 3.4 Evals: `nix eval --raw .#nixosConfigurations.rog.config.system.build.toplevel.drvPath`; `nix eval --raw .#darwinConfigurations.mact2.config.system.build.toplevel.drvPath`.
- [x] 3.5 Deploy + smoke (**USER-RUN**): rog `nixos-build`; `curl -s -o /dev/null -w '%{http_code}' https://oai.glats.org/` → anything EXCEPT old gateway response (404/Cloudflare error OK). mact2 `nixos-build` on Mac; `opencode.json` shows `opencode-go-medium`, no `-proxy`.

## Phase 4: Housekeeping (optional — orchestrator confirms)

- [x] 4.1 Commit untracked artifacts (`docs/netskope-bypass-analysis.md` + openspec change dirs incl. this one); default = separate docs commit BEFORE cleanup commit.
- [x] 4.2 Optional doc fix: stale `openai-proxy.yaml` example in `AGENTS.md:104` (outside Nix grep scope).

> **Post-merge note**: reconcile `mact2-openai-tls-tunnel-via-rog/tasks.md` Phase 6 after merge: 6.1-6.5 become no-ops (superseded by Phase 1); 6.6-6.7 remain (archive baseline, secret-naming check). Edit that tasks.md.