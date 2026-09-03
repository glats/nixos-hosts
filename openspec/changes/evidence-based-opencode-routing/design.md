# Design: Evidence-Based OpenCode Routing

## Technical Approach

`providers-base.nix` keeps its current shape (`allProviders` catalog + `providers` list + `activeProvider`/`getModelForPhase` lookups); only the `providers` list contents and order change. Split it conceptually into two literal Nix lists concatenated at the end: `canonicalProviders` (new/replacement profiles, defined first in the file) and `legacyProviders` (everything not replaced, moved as-is under a `# LEGACY` marker). `providers = canonicalProviders ++ legacyProviders;` gives "canonical first, legacy last" as a structural guarantee, not a comment convention. Uniqueness is enforced by construction (each name written once across both lists) plus a build-time assertion. `allProviders` is untouched — it's the model catalog (nvidia/opencode/anthropic/github-copilot), independent of which profiles reference which models; canonical profiles only need to reference IDs already present there (`anthropicProvider`/`githubCopilotProvider`/`opencodeProvider` already declare everything required).

## Architecture Decisions

### Decision: Two named lists concatenated, not one flat list with sort assumptions

**Choice**: `let canonicalProviders = [...]; legacyProviders = [...]; in providers = canonicalProviders ++ legacyProviders;`
**Alternatives considered**: (a) One flat `providers` list relying on manual ordering discipline; (b) tag each entry with `tier = "canonical" | "legacy"` and filter/sort at eval time.
**Rationale**: (a) has no structural guarantee — a future edit could insert a legacy entry above canonical by mistake with no error. (b) adds a sort/filter step with no benefit since order in a Nix list literal is already deterministic. Two named `let` bindings give free structural ordering, a clean diff (canonical block replaces old list top, legacy block is an unmodified move), and a natural place to hang the `# LEGACY` comment (directly above `legacyProviders = [`).

### Decision: Uniqueness enforced by an `assert` in the same file, not just spec discipline

**Choice**: Add `assert (let names = map (p: p.name) providers; in lib.length names == lib.length (lib.unique names)) || throw "duplicate provider name in providers-base.nix";` before the final `in`.
**Alternatives considered**: Rely on `nix flake check` catching downstream breakage; rely only on the spec's Given/When/Then test description.
**Rationale**: The spec scenario "each appears once" needs a concrete enforcement point, and Nix evaluation is the only gate that runs on every `nixos-build`/`nix flake check`. An assert fails fast at eval time with a clear location, instead of a silent duplicate where `activeProvider` picks whichever entry `foldl'` lands on last (current code's actual behavior — see Risks).

### Decision: Fold `alpha-free` + old `opencode-free` into one canonical `opencode-free` by literal replacement, not merge function

**Choice**: Delete both old blocks (lines 357-374 `alpha-free`, lines 749-783 old `opencode-free`) from the list; write one new `opencode-free` entry in `canonicalProviders` using the exact free-tier baseline distribution from the proposal/spec (nemotron-3-ultra-free for judgment, nemotron-3.5-lightning-free for mechanical, mimo-v2.5-free for apply/onboard, hy3-free for spec — matching the old `opencode-free`'s already-validated spec assignment, since that one was more evidence-backed than `alpha-free`'s x-preview-f-free-heavy version).
**Alternatives considered**: Programmatic merge (`lib.recursiveUpdate` of the two old phase attrsets) to "combine best of both".
**Rationale**: The spec requires exclusion of `x-preview-f-free` (used pervasively in old `alpha-free`) and `muse-spark-1.2-contributor-free`. A merge function keeps ambiguity about which source wins per key; a literal rewrite makes every phase assignment auditable in one block with inline evidence comments, matching the file's existing per-model comment convention.

### Decision: `work-copilot-anthropic` phase split is copy-edited from old `anthropic-copilot`, only IDs corrected

**Choice**: Keep the exact copilot-first/anthropic-heavy shape of the old `anthropic-copilot` profile (already spec-compliant: init/tasks/onboard/orchestrator on `github-copilot/*`, propose/design/apply/verify on `anthropic/*`) but rename to `work-copilot-anthropic` and fix any ID not present in `allProviders`. Checking the old block: all its IDs (`github-copilot/gpt-5.6-luna`, `github-copilot/claude-sonnet-5`, `github-copilot/gpt-5.4-mini`, `anthropic/claude-haiku-4-5`, `anthropic/claude-sonnet-5`... ) — note `anthropic/claude-sonnet-5` does **not** exist in `anthropicProvider` (only `claude-opus-4-8`, `claude-sonnet-4-6`, `claude-haiku-4-5` are declared there). This must become `anthropic/claude-sonnet-4-6` in the new profile.
**Alternatives considered**: Add `claude-sonnet-5` to `anthropicProvider.models` to keep the old ID intact.
**Rationale**: The spec's Anthropic tier requirement pins `anthropic-light/medium/full` to exactly `claude-haiku-4-5`/`claude-sonnet-4-6`/`claude-opus-4-8` — adding a 4th undeclared Anthropic model contradicts that closed set and the "no unverified claim" requirement. Fixing the reference (not the catalog) is the narrower, spec-compliant change.

### Decision: Intent profiles (`reliable`, `high-volume`, `quality`, `cross-provider-review`) are new canonical entries, not aliases of existing tiers

**Choice**: Each gets its own 12-key `phases` attrset selecting only non-`BROKEN` models already in `allProviders`, per the mapping table below.
**Alternatives considered**: Alias intent names to existing tier names (`reliable = anthropic-medium`, etc.) via a lookup indirection.
**Rationale**: Spec requires each carries its own evidence comment and provider-family diversity check (`cross-provider-review` needs ≥2 provider prefixes) — aliasing would just re-tag an existing profile and fail the "own evidence comment" scenario; the spec models these as independent profiles.

## Data Flow

```
providers-base.nix
  allProviders (catalog: nvidia + opencode + anthropic + github-copilot models)
        │
        ├─ canonicalProviders [ opencode-free, work-copilot-anthropic,
        │                        anthropic-light/medium/full,
        │                        reliable, high-volume, quality,
         │                        cross-provider-review, openai-opencode-balanced ]
        ├─ # LEGACY marker
        └─ legacyProviders [ copilot-custom, nvidia, github-copilot*,
                              openai-full/medium/light, opencode-go-* ]
                │
        providers = canonicalProviders ++ legacyProviders
                │
        activeProvider = foldl' (pick by activeProviderName) providers
                │
        getModelForPhase phase activeProvider
                │
   providers.nix (merges providers-extra.nix if present)
                │
   agents.nix: reads config.home.opencode.activeProviderName (HM option, host-set)
             → builds `models` per SDD phase + neutral + gentle-orchestrator
                │
   overlayAgent → defaultAgents → config.home.opencode.agents
                │
   runtime-config.nix → written opencode.json per host
                │
   Hosts set activeProviderName:
     t14/home/default.nix      → "opencode-free"   (was "alpha-free")
     mact2/default.nix         → "work-copilot-anthropic" (was "anthropic-copilot")
     rog/home/default.nix      → "copilot-custom" (legacy, untouched)
     thinkcentre/home/default.nix → "openai-medium" (legacy, untouched)
     flake.nix (thinkcentre standalone HM) → "openai-medium" (legacy, untouched)
     darwin/default.nix (dead code, unwired) → "opencode-free" (already correct, no edit needed)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `shared/opencode/providers-base.nix` | Modify | Split `providers` into `canonicalProviders` (new block, top) + `legacyProviders` (unmodified entries, under `# LEGACY`) ++ concatenation; add uniqueness `assert`; remove `alpha-free` and old `anthropic-copilot`/old `opencode-free` blocks; add `opencode-free`, `work-copilot-anthropic`, `anthropic-light/medium/full` (verify existing three already match spec — they do, keep as canonical), `reliable`, `high-volume`, `quality`, `cross-provider-review`; keep `openai-opencode-balanced` in canonical block. |
| `hosts/t14/home/default.nix` | Modify | `activeProviderName = "alpha-free"` → `"opencode-free"`. |
| `hosts/mact2/default.nix` | Modify | `activeProviderName = "anthropic-copilot"` → `"work-copilot-anthropic"`. |
| `hosts/rog/home/default.nix` | Verify only | `"copilot-custom"` — legacy, unaffected, no edit. |
| `hosts/thinkcentre/home/default.nix` | Verify only | `"openai-medium"` — legacy, unaffected, no edit. |
| `flake.nix` | Verify only | thinkcentre standalone HM block also sets `"openai-medium"` — legacy, unaffected, no edit. |
| `darwin/default.nix` | Verify only | Root-level file, not wired via `mkDarwinHost`/flake — dead code per spec; already `"opencode-free"`; no edit required but confirm still unwired. |
| `shared/opencode/agents.nix` | Verify only | Reads `activeProviderName` generically; no phase-key changes needed since all 12 keys stay the same shape. |
| `shared/opencode/providers.nix` | Verify only | Merge logic (`base // extras`) is untouched by this change. |

## Interfaces / Contracts

No new options. `providers[].phases` keeps its existing 12-key shape (`gentle-orchestrator`, 10 `sdd-*` phases, `neutral`) — verified against `agents.nix`'s `sddPhases` list plus its two extra lookups (`neutral`, `gentle-orchestrator`).

```nix
# canonical block skeleton (excerpt)
let
  canonicalProviders = [
    { name = "opencode-free"; phases = { /* 12 keys, opencode/*-free only */ }; }
    { name = "work-copilot-anthropic"; phases = { /* github-copilot/* + anthropic/* only */ }; }
    { name = "anthropic-light"; phases = { /* haiku/sonnet only, 0 opus */ }; }
    { name = "anthropic-medium"; phases = { /* haiku/sonnet + 2 opus */ }; }
    { name = "anthropic-full"; phases = { /* opus-heavy */ }; }
    { name = "reliable"; phases = { /* no BROKEN, evidence comment on orchestrator + 1 heavy phase */ }; }
    { name = "high-volume"; phases = { /* opencode-go/* concurrency-favoring */ }; }
    { name = "quality"; phases = { /* highest-judgment declared models */ }; }
    { name = "cross-provider-review"; phases = { /* ≥2 distinct provider prefixes across 12 keys */ }; }
    { name = "openai-opencode-balanced"; phases = { /* unchanged from current file */ }; }
  ];
  # LEGACY: non-replaced profiles, mappings unchanged, moved verbatim.
  legacyProviders = [
    { name = "copilot-custom"; phases = { ... }; }
    { name = "nvidia"; phases = { ... }; }
    { name = "github-copilot"; phases = { ... }; }
    { name = "github-copilot-safe"; phases = { ... }; }
    { name = "github-copilot-pro"; phases = { ... }; }
    { name = "github-copilot-experimental"; phases = { ... }; }
    { name = "openai-full"; phases = { ... }; }
    { name = "openai-medium"; phases = { ... }; }
    { name = "openai-light"; phases = { ... }; }
    { name = "opencode-go-full"; phases = { ... }; }
    { name = "opencode-go-medium"; phases = { ... }; }
    { name = "opencode-go-light"; phases = { ... }; }
  ];
  providers = canonicalProviders ++ legacyProviders;
  _uniqueNamesAssertion =
    let names = map (p: p.name) providers;
    in assert (lib.length names == lib.length (lib.unique names));
      providers;
in
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Nix eval | Uniqueness, no replaced names | `nix eval .#nixosConfigurations.t14.config.system.build.toplevel --dry-run` (forces `providers-base.nix` eval, assert fires on duplicate); `rg '"alpha-free"|"anthropic-copilot"' --glob '!openspec' --glob '!.worktrees'` returns zero matches. |
| Nix eval | Full phase coverage | Manual scan (or a throwaway `nix eval --expr` script) confirming each canonical profile's `phases` attrset has all 12 keys non-null. |
| Nix eval | `format-nix && nix flake check --no-build` | Standard repo gate, run for all affected hosts (t14, mact2, rog, thinkcentre — rog/thinkcentre unaffected but part of `checks.x86_64-linux`). |
| Live smoke test | Model availability for plan-gated IDs | `opencode run -m anthropic/claude-opus-4-8 "hi"`, `opencode run -m github-copilot/claude-sonnet-5 "hi"` before declaring `work-copilot-anthropic`/`anthropic-full` production-ready. Required by spec; not automatable in this repo's CI, run manually and record result in tasks.md. |
| Structural | Legacy set diff | `git diff` on `legacyProviders` block must show pure relocation (no phase-value changes) — verify via `git diff --word-diff` limited to that hunk. |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. This change edits static Nix provider/model mapping tables only; `getModelForPhase` is a pure lookup with no dynamic selection logic (explicitly out of scope per proposal).

## Migration / Rollout

Single atomic patch: catalog restructure + both host reference migrations (`t14`, `mact2`) land together, since `nix flake check` evaluates all `nixosConfigurations` and would fail if any host still names a deleted profile mid-migration. No feature flag needed — this is a config-value rename plus catalog reorg, not new runtime behavior. Rollback: `git revert` the single commit; since replacements are intentionally not aliased, revert restores `alpha-free`/`anthropic-copilot` verbatim rather than leaving a dangling alias.

## Open Questions

- [ ] Exact model assignments for `reliable`/`high-volume`/`quality`/`cross-provider-review` are proposed at task-writing time from already-declared, non-`BROKEN` models (task-level decision, not architecture-level) — sdd-tasks should enumerate final IDs per phase.
- [ ] Live smoke test results for `claude-opus-4-8` (Anthropic native OAuth) and Copilot-side `claude-sonnet-5`/`gpt-5.5` availability are unconfirmed until run manually; tasks.md must include this as a blocking step before marking `work-copilot-anthropic`/`anthropic-full` ready.
