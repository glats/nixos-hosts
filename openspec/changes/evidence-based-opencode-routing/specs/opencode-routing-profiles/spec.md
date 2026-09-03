# opencode-routing-profiles Specification

## Purpose

Evidence-backed, manually-selected OpenCode provider profiles in
`shared/opencode/providers-base.nix`: unique names, full phase coverage,
canonical-first/legacy-last ordering, no replaced-name aliases. New capability
(no prior spec); pairs with a MODIFIED delta to `opencode-runtime-proxy`.

## Requirements

### Requirement: Unique Names, Replacements Absorbed

Each `providers[].name` MUST be unique. `alpha-free` and the old
`opencode-free` MUST collapse into one new `opencode-free`. `anthropic-copilot`
MUST become `work-copilot-anthropic`. No alias for a replaced name may remain.

#### Scenario: Replaced names gone, new names unique [hosts: rog, t14, thinkcentre, mact2]
- GIVEN `providers-base.nix` post-change
- WHEN all `name` values are scanned
- THEN each appears once, and `alpha-free`/`anthropic-copilot` appear nowhere

### Requirement: Canonical Block First, Legacy Block Last

`opencode-free`, `work-copilot-anthropic`, `anthropic-light/medium/full`,
`reliable`, `high-volume`, `quality`, `cross-provider-review`, and
`openai-opencode-balanced` MUST precede all non-replaced legacy entries, which MUST
sit under a `# LEGACY` comment marker.

#### Scenario: Canonical entries precede legacy marker
- GIVEN the ordered `providers` list
- WHEN `opencode-free`'s index is compared to the first legacy entry's index
- THEN canonical index is lower and a `# LEGACY` comment precedes the legacy run

### Requirement: Full Phase + Neutral Coverage

Every canonical profile MUST map `gentle-orchestrator`, all 10 SDD phases,
and `neutral` to a non-null model.

#### Scenario: 12-key completeness
- GIVEN a canonical profile's `phases` attrset
- WHEN compared to the 12 required keys
- THEN all 12 are present with non-null values

### Requirement: `opencode-free` Is 100% Free-Tier

MUST use only `opencode/*-free` models; MUST NOT use `x-preview-f-free` or
`muse-spark-1.2-contributor-free`. Baseline: `nemotron-3-ultra-free` for
judgment (`gentle-orchestrator`, `sdd-explore`, `sdd-design`, `sdd-verify`,
`neutral`), `nemotron-3.5-lightning-free` for mechanical phases (`sdd-init`,
`sdd-tasks`, `sdd-archive`), `mimo-v2.5-free` for apply/onboard.

#### Scenario: Exclusions honored
- GIVEN `opencode-free`'s phase values
- WHEN checked against the exclusion list
- THEN none select the two excluded models, and all use `opencode/*-free`

#### Scenario: Baseline distribution matches evidence
- GIVEN `opencode-free`
- WHEN `gentle-orchestrator`/`sdd-explore`/`sdd-design`/`sdd-verify` and
  `sdd-apply`/`sdd-onboard` are read
- THEN the former select `nemotron-3-ultra-free` and the latter `mimo-v2.5-free`

### Requirement: `work-copilot-anthropic` Uses Only Real, Declared Auth

MUST assign only IDs already declared under `githubCopilotProvider` or
`anthropicProvider`. MUST NOT claim Claude Pro/Max OAuth substitutes for
Anthropic API billing — the `anthropic` provider here authenticates via
OpenCode's native `/connect` OAuth, a separate credential path from Copilot's
own `/connect`. Given the user's low Copilot credit and larger Anthropic
quota, orchestration/help phases prefer `github-copilot/*`; heavy phases
prefer `anthropic/*`.

#### Scenario: All IDs resolve to declared providers
- GIVEN `work-copilot-anthropic`'s phase values
- WHEN each is checked against `allProviders`
- THEN each resolves inside `githubCopilotProvider` or `anthropicProvider`

#### Scenario: Copilot-first, Anthropic-heavy split
- GIVEN the profile
- WHEN `gentle-orchestrator`/`sdd-init`/`sdd-tasks`/`sdd-onboard` vs
  `sdd-propose`/`sdd-design`/`sdd-apply`/`sdd-verify` are read
- THEN the first group uses `github-copilot/*`, the second `anthropic/*`

#### Scenario: No unverified OAuth-equivalence claim
- GIVEN spec/design/comments for this profile
- WHEN searched for a Claude-OAuth-as-Anthropic-API-billing claim
- THEN none exists; auth is stated as native per-provider `/connect` OAuth

### Requirement: Anthropic Tiers Are Manual Selection, Not Fallback

`anthropic-light/medium/full` MUST only use `claude-haiku-4-5`,
`claude-sonnet-4-6`, or `claude-opus-4-8`, fixed at definition time. No
runtime fallback, retry-to-other-model, or quota-based switching MAY exist
anywhere in the catalog.

#### Scenario: Opus usage scales full > medium > light
- GIVEN the three tiers
- WHEN Opus-assignment counts are compared
- THEN full > medium > light (light uses zero Opus assignments)

#### Scenario: No automatic failover logic
- GIVEN `getModelForPhase` and profile definitions
- WHEN inspected
- THEN no branch selects a model based on quota, error, or health signals

### Requirement: Intent Profiles Use Declared, Non-Broken, Evidenced Models

`reliable`, `high-volume`, `quality`, `cross-provider-review` MUST select only
already-declared provider models, MUST NOT select any model annotated
`BROKEN` in-file, MUST carry an evidence comment on `gentle-orchestrator` and
one heavy phase, and MUST NOT read runtime quota/usage/cost data.

#### Scenario: No BROKEN model selected
- GIVEN the four profiles' phase values
- WHEN checked against `BROKEN`-annotated model IDs
- THEN no match exists

#### Scenario: cross-provider-review spans 2+ provider families
- GIVEN its 12 phase values
- WHEN provider prefixes are collected into a set
- THEN the set has at least two distinct prefixes

### Requirement: `openai-opencode-balanced` Retained; Legacy Preserved

`openai-opencode-balanced` MUST remain with its current mapping (counts as
canonical, already evidenced). All non-replaced legacy names (`copilot-custom`,
`nvidia`, `github-copilot*`, `openai-full/medium/light`, `opencode-go-*`)
MUST remain selectable with unchanged phase mappings, moved below the legacy
marker.

#### Scenario: Legacy set unchanged and still selectable
- GIVEN pre/post-change legacy name sets
- WHEN diffed
- THEN identical, and `activeProviderName = "nvidia"` still resolves

### Requirement: Host/Flake References Migrate Atomically

Every reference to `alpha-free` or `anthropic-copilot` MUST update to
`opencode-free`/`work-copilot-anthropic` in the same change, with no
intermediate broken state.

#### Scenario: t14 and mact2 migrate [hosts: t14, mact2]
- GIVEN `hosts/t14/home/default.nix` and `hosts/mact2/default.nix` (the
  module wired via `mkDarwinHost`/`flake.nix`)
- WHEN `activeProviderName` is read
- THEN t14 shows `"opencode-free"` and mact2 shows `"work-copilot-anthropic"`

#### Scenario: No stray references repo-wide
- GIVEN the repository post-migration
- WHEN `.nix` files are searched for the two replaced names
- THEN zero matches outside `openspec/` history and `.worktrees/` snapshots
- AND the unreferenced root `darwin/default.nix` (dead code, not wired by
  `mkDarwinHost`) needs no edit since its existing `"opencode-free"` value
  still resolves

### Requirement: Nix Evaluation Validates the Catalog

#### Scenario: format-nix and flake check pass [hosts: rog, t14, thinkcentre, mact2]
- GIVEN the modified files
- WHEN `format-nix` then `nix flake check --no-build` run
- THEN both succeed for every affected host

### Requirement: Uncertain Model Availability Is Flagged, Never Assumed

Any model whose account-level availability is unconfirmed (e.g. Copilot
plan-gated `claude-opus-4.8`, `gpt-5.5`) MUST carry a plan-dependency comment.
No artifact MAY assert guaranteed availability without a live smoke test.

#### Scenario: Plan-gated model carries a comment
- GIVEN a `work-copilot-anthropic` assignment using a Pro+/Max-gated model
- WHEN surrounding comments are read
- THEN a plan-dependency note is present

#### Scenario: Live-verification step is required, not assumed
- GIVEN a profile with unconfirmed account access
- WHEN design/tasks artifacts for this change are read
- THEN they include a task to run `opencode run -m <provider>/<model> "hi"`
  before calling that profile production-ready, and no artifact claims
  confirmed access without it
