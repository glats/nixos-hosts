# Exploration: anti-hallucination-sdd-paths

## Current State

The SDD orchestrator and sub-agents repeatedly hallucinate `.sdd/`, `sdd/` (as filesystem dir), and `sdds/` paths when the canonical filesystem path is `openspec/`. The root cause is a semantic collision: Engram topic keys use the `sdd/{change-name}/{artifact}` prefix (e.g. `sdd/init/explore`, `sdd/{change-name}/tasks`), and the model confuses those keys with filesystem globs.

The previous fix attempt (see Engram obs #352, "Anti-hallucination .sdd/ fixes across all skills", 2026-06-28) added two single-line anti-hallucination notes to local copies of `sdd-explore/SKILL.md` and `sdd-init/SKILL.md`. The notes are:

- `sdd-explore/SKILL.md:59-60` — "use glob patterns against `openspec/` only. Do NOT use `sdd/`, `.sdd/`, `sdds/`..."
- `sdd-init/SKILL.md:38` — "The canonical SDD filesystem path is `openspec/`. Do NOT use `sdd/`, `.sdd/`, `sdds/`..."

Diff against the upstream nix store confirms these are the only differences:

```
$ diff ~/.config/opencode/skills/sdd-explore/SKILL.md \
       /nix/store/.../share/gentle-ai/skills/sdd-explore/SKILL.md
59,60d58
< **IMPORTANT — Anti-hallucination**: When checking the filesystem...
<
```

That fix is **fragile** for three reasons:

1. **`sdd-orchestrator.md` is unpatched.** Byte-identical to vanilla nix store (31844 bytes, no diff). The orchestrator itself contains the `sdd/{change-name}/{artifact}` Engram-key table (lines 384-391) — the very pattern that triggers the model to also generate `sdd/{...}` filesystem references.

2. **The Nix overlay does not cover `sdd-orchestrator.md`.** `pkgs/gentle-ai-assets/default.nix` only overlays `extraSkills` (under `skills/`) and `extraCommands` (under `opencode/commands/`). The `sdd-orchestrator.md` lives at `$out/share/gentle-ai/opencode/sdd-orchestrator.md` — a root-level file in `opencode/`. `shared/opencode.nix:100` reads it directly from `gentle-ai-assets-vanilla`, bypassing the layered `gentle-ai-assets` entirely. The "extraSkills" mechanism cannot override root-level files.

3. **Local skill overrides also reset on rebuild.** Even though `~/.config/opencode/skills/sdd-explore/SKILL.md` is currently patched, the activation script (`shared/opencode.nix:159-182`) copies the layered `gentle-ai-assets/skills/` to `~/.config/opencode/skills/` with cmp-guard + orphan cleanup. The current layered `gentle-ai-assets` is built from `pkgs/gentle-ai-assets/default.nix`, which only includes the `extraSkills = ./../shared/opencode/skills` overlay. The local repo's `shared/opencode/skills/` contains only `nix-verify/` and `opencode-session-recovery/` — it does NOT contain `sdd-explore/` or `sdd-init/`. So on the next `nixos-build switch`, the activation script will overwrite the live patched files with the vanilla versions from nix store, silently regressing the fix.

**Upstream `Gentleman-Programming/gentle-ai` v1.42.0 (the pinned ref) does NOT have these anti-hallucination notes either.** Checked `internal/assets/opencode/sdd-orchestrator.md` (no diff vs local), `internal/assets/skills/sdd-explore/SKILL.md`, `internal/assets/skills/sdd-init/SKILL.md`, and `internal/assets/skills/_shared/sdd-phase-common.md` at v1.42.0. The same is true for `main` HEAD (fetched live, June 2026). The only `.sdd/` filesystem references in the repo are:

- `internal/assets/windsurf/workflows/sdd-new.md` — Windsurf IDE-specific, NOT loaded by OpenCode. Per `vanilla.nix:23-26` it gets copied to `$out/share/gentle-ai/windsurf/workflows/`, not to `opencode/`.
- `docs/antigravity-sdd-workaround.md` — explanatory docs, not loaded.
- `internal/assets/skills/_shared/sdd-status-contract.md` — `gentle-ai.sdd-status` is a JSON schema name, not a filesystem path.
- Go source files in `internal/cli/`, `internal/agentbuilder/`, `internal/components/sdd/` — `.SDDMode`, `.SDDConfig` are Go struct field accesses, not filesystem refs. Not loaded by skills.

The hallucination therefore does NOT come from a wrong upstream file the model is reading — it comes from the model pattern-matching the `sdd/{change-name}/...` Engram-key template in the orchestrator and skills, and generalising it to a filesystem path. The local anti-hallucination notes are a guardrail, not a removal of the trigger.

## Affected Areas

- `pkgs/gentle-ai-assets/default.nix` — accepts only `extraSkills` and `extraCommands`; needs an `extraAssets` (or generic `extraSourceFiles`) mechanism for root-level `opencode/*.md` files like `sdd-orchestrator.md`.
- `lib/packages.nix` (lines 21-25, 35-38, 65-68) — `sharedOpencodePaths` only wires `extraSkills`. Needs to also wire `extraAssets` (or `extraOrchestrator`) and pass it to `gentle-ai-assets`.
- `shared/opencode.nix` (lines 98-101) — `sdd-orchestrator.md` is sourced from `gentle-ai-assets-vanilla`, bypassing the layered `gentle-ai-assets`. Needs to source from the layered version (or from `extraAssets` directly).
- `shared/opencode/skills/sdd-explore/SKILL.md` — new override file (currently empty/absent). Must be byte-identical to upstream + the anti-hallucination note from the local patched copy.
- `shared/opencode/skills/sdd-init/SKILL.md` — new override file. Same.
- `shared/opencode/opencode/sdd-orchestrator.md` (new location) — or some convention for the root-level `opencode/*.md` override path. Needs a new asset path that the `extraAssets` mechanism can layer on top of vanilla.
- Upstream `Gentleman-Programming/gentle-ai` repo (out of this repo's tree) — `internal/assets/opencode/sdd-orchestrator.md`, `internal/assets/skills/sdd-explore/SKILL.md`, `internal/assets/skills/sdd-init/SKILL.md`, `internal/assets/skills/_shared/sdd-phase-common.md`, `internal/assets/skills/_shared/engram-convention.md` could all benefit from a single canonical "filesystem path is `openspec/`, Engram key prefix is `sdd/`" note. But these are owned by `gentleman-programming` — local fork is faster than waiting for an upstream PR.

## Approaches

### 1. **Local Nix override only** — add `extraAssets` mechanism, layer local override files

- Add `extraAssets` parameter to `pkgs/gentle-ai-assets/default.nix`. Path is `$out/share/gentle-ai/` so a layered dir copy (recursive) can override any sub-path (`opencode/sdd-orchestrator.md`, `skills/sdd-explore/SKILL.md`, etc.). `extraCommands` is already a path-aware mechanism; can be generalised to `extraAssets` for clarity.
- Move the live patched `~/.config/opencode/skills/sdd-explore/SKILL.md` and `sdd-init/SKILL.md` to `shared/opencode/skills/sdd-{explore,init}/SKILL.md` so they survive rebuilds.
- Create `shared/opencode/opencode/sdd-orchestrator.md` with an anti-hallucination note added (currently no override exists).
- Update `shared/opencode.nix:100` to source `sdd-orchestrator.md` from the layered `gentle-ai-assets` instead of `gentle-ai-assets-vanilla`.
- Pros: Self-contained, no upstream dependency, survives `nixos-build switch` immediately. Test: build locally and verify `~/.config/opencode/sdd-orchestrator.md` contains the new note.
- Cons: Permanent local fork divergence. When upstream finally lands a fix, the local files will conflict and need to be re-aligned. The local copies will silently bit-rot if upstream changes upstream versions.
- Effort: **Low–Medium**. ~6 files changed/added, ~1 hour including validation. Pure Nix + copy-paste, no new logic.

### 2. **Upstream PR only** — send anti-hallucination patches to `Gentleman-Programming/gentle-ai`

- Open a single PR that adds the same anti-hallucination note to `sdd-orchestrator.md`, `sdd-explore/SKILL.md`, `sdd-init/SKILL.md`, and `sdd-phase-common.md` upstream. Possibly also `_shared/engram-convention.md` to make the Engram-vs-filesystem distinction canonical.
- Wait for merge. Bump `gentle-ai-src` flake input to a commit hash that includes the fix.
- Pros: Root-cause fix; all gentle-ai consumers benefit. No permanent fork.
- Cons: Latency — review cycles, possible rejection, unclear if Gentleman-Programming accepts contributions from outside. Even after merge, requires a flake input bump + rebuild. Doesn't help anyone who hasn't pulled.
- Effort: **Low** to write, **High** uncertain wall time waiting on maintainer.

### 3. **Both (recommended)** — local override now, upstream PR in parallel

- Implement Approach 1 immediately so the fix is durable. PR the same changes to `Gentleman-Programming/gentle-ai` so they can land upstream.
- Once upstream merges, drop the local override files and rely on the bump. Use the local files as a documented "patch delta" that any consumer can apply.
- Pros: Fix is durable locally today. When upstream merges, the local delta shrinks to zero diff. Avoids the "waiting for maintainer" risk.
- Cons: Two-track maintenance — must remember to drop the local files when upstream lands. Slightly more upfront work.
- Effort: **Medium**. Same code as Approach 1 + a PR write-up.

## Recommendation

**Approach 3 (Both).** The fix is small and the upstream latency is uncertain; the local Nix override is the only way to get durable behavior in the next `nixos-build switch`. Send the PR in parallel — even a rejected PR documents the pattern for the next contributor.

Specific implementation sketch for the local half (Approach 1):

1. `pkgs/gentle-ai-assets/default.nix` — add `extraAssets ? null` parameter. In `installPhase`, after the `extraCommands` block, layer the directory recursively: `cp -r ${extraAssets}/. $out/share/gentle-ai/`. This generalises the existing pattern.
2. `lib/packages.nix` — add `extraAssets = ./../shared/opencode/assets;` to `sharedOpencodePaths`; pass it in both `linuxPackages.gentle-ai-assets` and `darwinPackages.gentle-ai-assets`.
3. Create `shared/opencode/assets/opencode/sdd-orchestrator.md` — copy from nix store vanilla, add anti-hallucination note in the "Artifact Store Policy" section (around line 70).
4. Create `shared/opencode/assets/skills/sdd-explore/SKILL.md` and `sdd-init/SKILL.md` — copy from nix store vanilla, add the same note that's currently in `~/.config/opencode/skills/`.
5. `shared/opencode.nix:100` — change source from `${pkgs.gentle-ai-assets-vanilla}/share/gentle-ai/opencode/sdd-orchestrator.md` to `${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-orchestrator.md`.
6. Verify: `nix flake check --no-build`, then `nixos-build dry`. After switch, `grep -c "Anti-hallucination" ~/.config/opencode/{sdd-orchestrator.md,skills/sdd-explore/SKILL.md,skills/sdd-init/SKILL.md}` should return `1` for each.
7. Send PR to `Gentleman-Programming/gentle-ai` with the same three file changes.

## Risks

- **Vanilla nix store version drift**: the pinned `gentle-ai-src` is `v1.42.0` (commit `aa33ce5b...`). When `nix flake update` is run, vanilla will change. The local override files must be regenerated from the new vanilla, or they'll carry stale logic. Mitigation: document a regeneration script in `shared/opencode/assets/README.md` that diffs against `pkgs.gentle-ai-assets-vanilla` on every flake update.
- **Local skill overrides silently regressed by activation script**: `shared/opencode.nix:159-182` always copies from the layered `gentle-ai-assets/share/gentle-ai/skills/` and orphans anything not in source. The `extraAssets` mechanism in step 1 must run BEFORE the activation script reads from the layered path, which is naturally true since the layered path is built into `gentle-ai-assets` itself. Verified safe.
- **Path generalisation breaks command overrides**: `extraAssets` is broader than `extraCommands`. The existing `extraCommands` mechanism reads files and copies them to `opencode/commands/`. A more general `extraAssets` that copies a whole tree could accidentally overwrite commands with old versions if the user is sloppy. Mitigation: keep `extraCommands` as a separate parameter for clarity, add `extraAssets` as a parallel mechanism. Or: deprecate `extraCommands` and fold into `extraAssets` (more risk, more cleanup).
- **Windsurf `.sdd/` references still in upstream tree**: the Windsurf-specific `internal/assets/windsurf/workflows/sdd-new.md` is unaffected by this change. The `vanilla.nix:41-46` block copies it to `$out/share/gentle-ai/windsurf/workflows/` for any Windsurf user. Not blocking — but the upstream PR should also update the Windsurf workflow to use `openspec/`.
- **The model might still hallucinate from the orchestrator's Engram-key table**: the `sdd/{change-name}/{artifact}` template is still present in `sdd-orchestrator.md` lines 384-391 and elsewhere. The anti-hallucination notes are a guardrail, not a removal. If the model still misfires, the next escalation is to rename the Engram topic prefix from `sdd/` to something unambiguous (e.g. `gentle-ai/sdd/...` or `engram-sdd/...`). Not recommended now — too invasive.

## Ready for Proposal

**Yes — proceed to `sdd-propose`.**

The proposal should produce:

- **Goal**: eliminate `.sdd/`/`sdd/`/`sdds/` filesystem path hallucination in SDD sub-agents, durable across `nixos-build switch`.
- **Scope**: this repo (Nix packaging) + local override files. Upstream PR is a parallel track, not a deliverable.
- **Approach**: Approach 3 (local override + upstream PR). Specs: add `extraAssets` mechanism, create 3 local override files, switch `sdd-orchestrator.md` source to the layered asset path.
- **Effort estimate**: Low–Medium. 1 hour implementation, 30 min validation, 1 hour PR write-up.
- **Open question for the user**: do we want to deprecate `extraCommands` and fold into `extraAssets`? (Recommendation: no, keep separate for clarity.)
- **No follow-up exploration needed** — every approach above has been grounded in real code; no speculation.
