## Exploration: Point gentle-ai to fork branch + fix PR #988 comments

### Current State

The `gentle-ai-src` flake input in `flake.nix` points to `github:Gentleman-Programming/gentle-ai/main` (rev `84fcf3d`). This is the upstream repo where PR #988 (SDD path convention fixes) is **open but NOT merged**. CodeRabbit left 3 unresolved comments on that PR branch (`glats/gentle-ai`, branch `fix/sdd-filesystem-path-convention`).

The PR fixes path confusion between Engram topic keys (`sdd/` prefix) and filesystem paths (`openspec/`). Three nits remain to be addressed before the user can confidently point nixos-hosts to the fork branch.

### Affected Areas

**Gentle-ai fork (glats/gentle-ai, branch fix/sdd-filesystem-path-convention)**:
- `internal/assets/skills/sdd-apply/SKILL.md` — Missing standalone "Filesystem path convention" note
- `internal/assets/skills/sdd-archive/SKILL.md` — Incomplete archive path on line "What to Do" step 4
- `internal/assets/skills/sdd-explore/SKILL.md` — Missing explicit "Output Contract" section

**nixos-hosts**:
- `flake.nix` line 44 — `gentle-ai-src.url` must change to fork branch
- `flake.lock` — regenerated after input update (automatic via `nix flake lock --update-input`)

**Consumers of gentle-ai-src in nixos-hosts**:
- `pkgs/gentle-ai-assets/vanilla.nix` — copies `internal/assets/skills/` to `$out/share/gentle-ai/skills/`
- `pkgs/gentle-ai/default.nix` — uses `gentle-ai-src.rev` as version
- `pkgs/gentle-ai-assets/default.nix` — layers local overrides on top of vanilla

### Part A: CodeRabbit Fixes (glats/gentle-ai)

#### Fix 1: sdd-apply — Standalone "Filesystem path convention" note
- **Current text** (inline in "Execution and Persistence Contract" bullet): `Do NOT read or write filesystem paths under sdd/ — use openspec/ for filesystem artifacts.`
- **Problem**: Not a standalone bolded paragraph like sdd-explore and sdd-init have. The PR's goal is consistency.
- **Proposed fix**: Add a bolded standalone paragraph after the artifact store bullet list, matching the pattern from sdd-explore and sdd-init:
  ```
  **Filesystem path convention**: The SDD artifact directory is `openspec/`.
  Do NOT use `sdd/`, `.sdd/`, or `sdds/` as filesystem paths — these do not
  exist. Engram topic keys use the `sdd/` prefix for memory organization only.
  ```
- **Effort**: Low (add 3 lines to `internal/assets/skills/sdd-apply/SKILL.md`)

#### Fix 2: sdd-archive — Full canonical archive path
- **Current text** (line ~34, "What to Do" step 4): `Move change folder to archive/YYYY-MM-DD-{name}/.`
- **Problem**: Missing `openspec/changes/` prefix. Per `_shared/openspec-convention.md`, canonical path is `openspec/changes/archive/YYYY-MM-DD-{change-name}/`. Abbreviated path risks agents creating archive at repo root.
- **Proposed fix**: Change to `Move change folder to openspec/changes/archive/YYYY-MM-DD-{change-name}/.`
- **Effort**: Trivial (one-line replacement)

#### Fix 3: sdd-explore — Explicit "Output Contract" section
- **Current state**: Return format is implied by Step 6 (return format at end) + Rule ("Return envelope per `_shared/sdd-phase-common.md`"). No explicit section.
- **Problem**: sdd-init has a standalone "Output Contract" section. sdd-explore lacks discoverable return contract.
- **Proposed fix**: Add an "Output Contract" section after "Rules" (or before "What to Do"), matching sdd-init's pattern:
  ```
  ## Output Contract
  Return status, executive_summary, artifacts, next_recommended, risks.
  Include current state, affected areas, approaches, recommendation.
  See `_shared/sdd-phase-common.md` Section D for envelope format.
  ```
- **Effort**: Low (add ~4 lines)

#### Additional: Markdownlint warnings
CodeRabbit flagged MD022 (blank lines around headings) warnings on both sdd-apply and sdd-explore. These are pre-existing formatting issues in the YAML frontmatter area that don't affect functionality. Worth fixing as a polish pass since they're quick wins.

### Part B: Flake Input Change (nixos-hosts)

- **Current** (`flake.nix` lines 42-46):
  ```nix
  gentle-ai-src = {
    url = "github:Gentleman-Programming/gentle-ai/main";
    flake = false;
  };
  ```
- **Proposed**:
  ```nix
  gentle-ai-src = {
    url = "github:glats/gentle-ai/main";
    flake = false;
  };
  ```
- **Post-change action**: Run `nix flake lock --update-input gentle-ai-src` to regenerate `flake.lock`
- **Verification**: `nix flake check --no-build` after the lock update
- **Effort**: Trivial (one URL change + lock update)

### Part C: Connected Repos

| Repo | Owner | Branch | Access |
|------|-------|--------|--------|
| `glats/gentle-ai` | glats (fork) | `fix/sdd-filesystem-path-convention` | Full push (owned fork) |
| `glats/nixos-hosts` | glats | default branch | Full push |

Push strategy: Both repos are directly owned by glats. Standard `git push` with commit + PR flow applies.

### Approaches

1. **Two commits on fork, one commit on nixos-hosts (recommended)**
   - Commit fixes to `glats/gentle-ai` fork branch (3 files, ~10 lines)
   - Commit flake URL change to `glats/nixos-hosts` (1 line + lock)
   - Both changes are independent and small
   - Pros: Clean, minimal, each repo gets exactly what it needs
   - Cons: Two repos to coordinate
   - Effort: Low

2. **Sync fork main, then fixes → point nixos-hosts to fork main (selected)**
   - Sync `glats/gentle-ai/main` with upstream `Gentleman-Programming/gentle-ai/main` first
   - Cherry-pick PR #988 commits + 3 CodeRabbit fixes onto `glats/gentle-ai/main`
   - Point nixos-hosts `gentle-ai-src` to `github:glats/gentle-ai/main`
   - Pros: Clean — no ephemeral branch, fork main is the canonical source until PR merges
   - Cons: Must sync fork main with upstream first (one extra step)
   - Effort: Low

### Recommendation

**Approach 2** (selected by user): Sync `glats/gentle-ai/main` with upstream first, then apply the 3 CodeRabbit fixes to `glats/gentle-ai/main`, then point nixos-hosts to `github:glats/gentle-ai/main`. The fork's `main` branch becomes the canonical source until PR #988 merges upstream, at which point nixos-hosts switches back to `github:Gentleman-Programming/gentle-ai/main`.

**Pre-requisite**: Sync `glats/gentle-ai/main` with latest upstream before applying fixes. This ensures the fork has all recent changes from `Gentleman-Programming/gentle-ai/main`.

Note: The CodeRabbit comment says "match sdd-init and sdd-apply" for the Output Contract section, but sdd-apply actually does NOT have an Output Contract section either. The fix should follow sdd-init's pattern only.

### Risks

- **Low**: All changes are documentation-only (skill file annotations). No logic, no code path changes.
- **Low**: Fork branch URL change is reversible by reverting flake URL or running `git checkout` on flake.nix.
- **Low**: The PR #988 has merge conflicts ("mergeable_state: blocked") — but this doesn't affect pointing to the fork branch since we're not merging, just consuming the branch directly.
- **Note**: When PR #988 eventually merges upstream, nixos-hosts should switch back to `github:Gentleman-Programming/gentle-ai/main` to stay on the canonical source. This is a future concern, not a risk for this change.

### Ready for Proposal

Yes — the scope is clear, the files to change are identified, the effort is trivial, and there are no unknowns.
