# Conditional offline approval; deployment remains unverified

The current Gentle AI v4 / ODD candidate passes the bounded NONLIVE checks reviewed here. **Verdict: CONDITIONAL / OFFLINE PASS, not full SDD verification PASS and not ready to deploy.** No new demonstrated migration P0/P1/P2 defect was found. Previously demonstrated ownership defects #3917/#3918 remain resolved by #3923 and the fresh scoped race run. Native Darwin, catalog validity, organic runtime behavior and actual rollout/rollback remain separate acceptance gates.

The user stopped real testing (#3934). This review did not request renewed consent, inspect credentials or session databases, log in, copy authentication, start services, call providers/MCP canaries, use SSH/native Mac access, activate, stage, commit or publish. Only this report was added to the repository; externally staged work is preserved. No task checkbox changed.

## Reviewed state and evidence identity

Observed `git rev-parse HEAD` is **`4750736cd68f517a871ac7448639c94546472390`**, on dirty `master`, not the parent-supplied `0224533c`. Both objects exist. Actual command output takes precedence over supplied/historical state. The 4750736c bootstrap reference is historical ownership evidence, not the candidate's committed source: the candidate remains uncommitted/unpublished.

The review covered filesystem proposal, all four delta specs, design, tasks, current apply progress, the complete owned diff and all five untracked implementation/test files. Historical proposal/design planning-only language is superseded by the later implementation authorization and current stop boundary, not rewritten here. Tasks show **6/11 completed actions** (1.2, 2.1–2.4, 3.2); that is not 6/14 accepted scenarios.

| Fingerprint | SHA-256 |
|---|---|
| Current contents of 31 owned implementation/consumer/test/runbook paths, including absent deleted paths and five untracked files | `3229f4238f8a9071e4790e8db6f781c60f80aff29e86f2083f9f471d8f783ed3` |
| Owned tracked `git diff --binary HEAD` | `3ff8666a2a6b15e5cfa2ebbf07ffac39e500edcd3f44d5feb020bc2b5560afd8` |
| Existing staged `git diff --cached --binary` | `89dfdbb95e7ce6359c3835e659285ec01ca06587b1086c43110d9a60581ca6f6` |

The content fingerprint hashes compact, sorted-key JSON entries `{path, sha256}`, sorted by path; deleted paths have `sha256: null`. Its exact path manifest is in `/home/glats/.local/opencode-v2/tmp/opencode/final-v4-fingerprint.json`. Tracking artifacts, including this report, are excluded. Unrelated changes excluded from ownership/review authority are `docs/opencode-v2-final-cutover.md`, `hosts/rog/home/default.nix`, and the openlogi-cross-host, rog-shutdown-s5-diagnose-and-fix and simplify-worktree-cli tracking files. The actual ROG profile selection is nevertheless used when evaluating the candidate.

Untracked source files are necessary for Nix evaluation/builds. Use `path:` installables; a Git-filtered `.#...` source is not sufficient proof of this dirty candidate. Do not stage files merely to make Nix see them.

## Findings and inspected boundaries

No new actionable P0/P1/P2 product-code defect was demonstrated within this bounded review. The following are acceptance limitations, not invented implementation bugs or guarantees.

| Boundary | Observed result | Remaining boundary |
|---|---|---|
| Pin, binary, assets and toolchain | Source/lock agree on `ff77164d4f56f1665b22fb6fac51c2ccbb769400`; version 4.0.0, canonical vendorHash, Go 1.26.6. Fresh offline Linux binary/assets builds resolve the recorded outputs. | Native Darwin build and actual runtime compatibility are not established by version discovery. |
| Upstream rendering | Vendored build-only exporter calls actual upstream internal renderers, requires real native V2 discovery and exports the 13-role graph plus runtime-specific OpenCode/Claude prompts. No exporter executable is shipped. | A major-version probe and staged declaration are not a receipt or organic compatibility proof. |
| Transport ownership | Exact tagged Bun relay, command-path-only substitution; opaque output and dispatched role are forwarded. Native Go owns nonce/role/capability/authority/admission. 24 fresh fixtures pass. | Promise-hook fixtures mock Plugin.define; they do not certify live native SDK execution or organic tool behavior. CLI/SDK remain 2.0.14. |
| Private HM wrapper | Source and current consumer tree use the absolute compiled HM wrapper; complete V2 environment and private bare `opencode` discovery remain intact. Prior actual ELF/quoted-root/registry checks are reused for unchanged implementation. | Darwin wrapper/runtime proof is pending; there is no public bare-runtime alias or authority bypass. |
| Graph, overrides and permissions | Fresh six-way Linux integrated/standalone generated JSON inspection agrees on profiles/grants. Read-only roles have only deny-valued normalized edit rules; all managed subagents deny delegation; worker/general edit grants remain allowed and delegation denied. Orchestrator grants selected ODD/review/JD/general/explore routes after wildcard denial. Python full-profile parity and last-wins overrides pass. | Darwin-root projection is not a native macm5 evaluation. Shell-allowed actors can still invoke Git: prompt authorization is not executable no-consent Git enforcement. |
| Provider identifiers | Existing policy/profile JSON is preserved outside approved ODD mappings; native NVIDIA declaration is retained. | No authoritative offline actual-provider catalog was established. Zero missing built-in identifiers remains UNVERIFIED; no model/catalog network call or account access was used to fill it. |
| Ownership bootstrap and union trees | Exact 4750736c source/lock and complete old source lists, V2 remaps/markers, Claude-specific commands/agents/styles, and immutable desired trees are present. Existing actual-tree synthetic bootstrap/update/rollback proof is reused for matching built outputs. | Custom historical source lists or modified/unproven bytes require explicit reconciliation; no ownership is inferred from filenames alone. |
| Reconciliation | Fresh scoped race suite passes. Schema 2 separates original Before from immediate pending Prior, clears pending authority after completion, and serializes cooperating reconcilers. Foreign/modified/symlink conflicts refuse; absent installs do not clobber. | Known external-editor final-check-to-rename window, no cross-root transaction, no whole-generation rollback or power-loss directory-fsync guarantee. No new demonstrated race defect is claimed. |
| Installed public assets | Read-only comparison of only declared V2 asset/template paths found 4,544 exact prior-tree matches, two absent paths, no changed/unproven collisions and no symlinks. Current skills directory and its files are copies, not HM symlinks. Foreign registry/helper files remain outside owned inventory. | This does not activate anything or certify all hosts/Claude/OpenFang installed state. A future HM symlink collision must refuse, not be forcibly deleted. |
| Legacy/disabled plugins | Current `.config/opencode-v2/plugins` has the six expected production files, including the old SDD adapter; 11 installed SDD skills remain. `~/.opencode/plugins` is absent. Candidate desired tree removes owned SDD assets. Current and baseline V2 code have no `home.opencode.plugins.*.enable` toggle surface. | S3's disabled-toggle/older-legacy inventory is not fully accepted. Unknown old plugin bytes are foreign, not permission for generic deletion. Installed SDD is expected until an authorized cutover, not evidence candidate activation failed. |
| Authorization and ODD recovery | Local guidance explicitly denies implied staging/publishing/activation consent; source-default TDD and full identity/readback/outage/conflict/pending-mirror instructions are rendered. Tagged native tests prove read-only diagnostics/nondeciding delivery boundaries. | There is no shipping Go ODD persistence executor or global arbitrary-Git consent guard. Model compliance/recovery remains UNVERIFIED; do not add a substitute policy engine merely to turn these gates green. |

## Focused checks and evidence reuse

| Check | Result |
|---|---|
| `git diff --check` | Fresh PASS. |
| `bun test pkgs/gentle-ai-assets/opencode-review-transport.test.ts` | Fresh PASS: 24 tests, 58 assertions. |
| `GOPROXY=off go -C pkgs/nixos-scripts test -race -count=1 ./internal/aiassets` | Fresh PASS. |
| `python3 shared/opencode/v2-agents.test.py --odd-candidate` | Fresh PASS: ODD graph, permissions, complete profile/policy/NVIDIA parity, user overrides and rendered recovery contract. |
| Offline generated JSON grant inspection | Fresh PASS for rog/thinkcentre/t14, integrated and standalone. Exact public result: `final-v4-grants.json` in approved scratch. Checks inspect normalized allow/deny aliases, not merely the presence of a deny somewhere in the list. |
| `nix build --offline --no-write-lock-file --no-link --print-out-paths path:/home/glats/.nixos#gentle-ai path:/home/glats/.nixos#gentle-ai-assets` | Fresh PASS; cached outputs `/nix/store/qib05gd4hc6dc0yqlbaa67ld0y5g35v9-gentle-ai-4.0.0` and `/nix/store/ia2an10mnvws4f2sksxlh1xfl7wkvs9a-gentle-ai-assets-4.0.0`. |
| Exact-tag sandboxed native contracts | Reused stored JSONL, inspected directly: 9/46 transaction and 55/197 CLI top-level/subtests, zero failures; 64/243 total. Output `/nix/store/idhxvip10r17h6w86m0k4dxw6hzndhb3-gentle-ai-offline-contract-proof-4.0.0/share/gentle-ai/offline-evidence/`. |
| Actual V2/Claude/OpenFang synthetic ownership/recovery/rollback fixtures and compiled wrapper/registry tests | Reused current stored-tree evidence from apply progress and #3923; consumer derivations/outputs were resolved offline and are present. No real consumer reconciliation was executed. |
| Path-flake check and nine Linux drvPath evaluations | Reused existing unchanged-module evidence; inspected `offline-continuation-flake-check.log` and `review-fixes-eval-matrix.log`. The interrupted t14 evaluation is followed by successful remaining targets, not silently counted as success. |
| Ordinary full Go suite | Reused PASS from `review-fixes-go.log`. |
| Broad full Go race suite | Existing FAIL in unchanged netconsole TestServe fixture; inspected log. Not reported green and not repaired here. |
| Darwin native/system/integrated/standalone proof | UNVERIFIED. Prior Linux IFD limitation not retried. Darwin cross-compilation is compile-only. |

Logs reused above live under `/home/glats/.local/opencode-v2/tmp/opencode/gentle-v4-apply/`. One ad-hoc grant-query lambda had invalid spacing and failed before evaluation; the corrected query passed. That was review-harness syntax, not candidate RED or a product regression.

## Fourteen scenario acceptances

"Partial" means useful proof exists but the approved scenario is not fully accepted. No native/model/activation result is inferred from fixtures. S4 is established for its specified t14 inspection scope and S6 for its documentation-only scope; neither is fleet deployment approval.

| Scenario | Acceptance status | Minimum missing proof |
|---|---|---|
| S1 Pin/derivations | PARTIAL | Native Darwin binary/assets and organic compatibility. |
| S2 Enabled deploy | PARTIAL | Separately authorized real HM deployment on each host. |
| S3 Disabled/legacy retirement | PARTIAL | Applicable legacy/toggle ownership inventory and fleet behavior. |
| S4 Grants | FULL, specified t14 inspection scope | Linux six-way generated-grant inspection passes. Additional macm5/native runtime coverage remains a fleet gate, not implied by S4. |
| S5 Retire commands | PARTIAL | Authorized installed-byte canary cutover. |
| S6 Runbook | FULL, documentation scope | Execution is separately authorized, not part of this documentation pass. |
| S7 Shared gate | PARTIAL | Darwin targets/native builds and authoritative catalog resolution; broad race failure remains disclosed. |
| S8 Routing/catalog | PARTIAL | Actual built-in catalog resolution; preserved profile JSON alone is insufficient. |
| S9 Admit roles | PARTIAL | Authorized real bound lens/refuter/validator receipts per host. |
| S10 Refuse invalid transport | PARTIAL | Organic configured-runtime negatives; offline tagged/native refusal coverage passes. |
| S11 Authorization | PARTIAL | Actual model/runtime adherence; no arbitrary Git/publication enforcement claim. |
| S12 Resume | PARTIAL | Organic ODD file/mirror readback/outage/conflict recovery. |
| S13 Unfinished work | PARTIAL | Future explicitly selected handoff behavior; existing history retained, no bulk conversion. |
| S14 V2 continuity | PARTIAL | Native Darwin/fleet runtime/MCP/session continuity and actual rollback proof. |

## Minimum continuation without restarting live testing

Keep this candidate and its offline evidence. Do not activate or publish it as fully verified. Stop #3934 remains effective; the isolated-credential preflight produced zero requests and no session/receipt. Do not read/copy the production DB or supply login instructions as an automatic workaround.

The next independent non-model gate is **native Mac candidate evaluation/build**, only when the user chooses to perform it with the actual candidate source present. An existing Mac checkout of current committed master does not contain these uncommitted v4 changes. `git pull` alone cannot transfer them. First arrange a separately approved source-only handoff/fresh candidate directory, including all new source files and preserved bootstrap evidence. This review performs no transfer, rsync, commit or push and supplies no credential-copy operation. Verify source identity before building; the Gentle pin alone does not fingerprint every candidate file.

The following commands are for a native Mac with that approved candidate already present, not for the existing baseline checkout and not commands executed by this review. Package outputs and the username `juan` are confirmed in `lib/packages.nix` and `flake.nix`. Start offline; a missing cached dependency is UNAVAILABLE, not approval to silently change inputs or source.

```sh
cd <approved-candidate-directory>
jq -e '.nodes["gentle-ai-src"].locked.rev == "ff77164d4f56f1665b22fb6fac51c2ccbb769400" and .nodes["gentle-ai-src"].original.rev == "ff77164d4f56f1665b22fb6fac51c2ccbb769400"' flake.lock
nix eval --offline --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.system.build.toplevel.drvPath
nix eval --offline --no-write-lock-file --raw path:.#darwinConfigurations.macm5.config.home-manager.users.juan.home.activationPackage.drvPath
nix eval --offline --no-write-lock-file --raw path:.#homeConfigurations.macm5.activationPackage.drvPath
nix build --offline --no-write-lock-file --no-link --print-out-paths path:.#gentle-ai path:.#gentle-ai-assets
nix build --offline --no-write-lock-file --no-link --print-out-paths path:.#darwinConfigurations.macm5.config.system.build.toplevel path:.#homeConfigurations.macm5.activationPackage
```

Building an activation package/system is not activating it. Do not run its activation script, `switch`, an upstream installer, model tests or authentication setup. Native Mac success would close platform build/evaluation subgates only. Authoritative catalog validity, organic authorization/recovery/receipts, and actual per-host rollout/rollback still require their own evidence and scope; none is requested or attempted here.
