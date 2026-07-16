# Delta Spec: history-scrub

Domain for scrubbing Personal Identifiable Information (PII) from git history using `git filter-repo`, including force-push to GitHub and post-scrub verification.

## ADDED Requirements

### Requirement: Git Filter-Repo Removes PII from All History

The system MUST use `git filter-repo` with text-based replacements to remove ALL occurrences of the following PII from the entire git history (all branches, tags, and refs):

- `Redacted Name` (full name)
- `work@example.com` (work email, reveals employer)
- `personal@example.com` (personal email)

The replacements file MUST replace these values with redacted placeholders such as `Redacted Name`, `work@example.com`, and `personal@example.com`, or with equivalent SHA-preserving neutral text.

After the rewrite, ZERO occurrences of the PII above MUST exist in ANY reachable commit.

#### Scenario: Zero PII in reachable history after scrub

- GIVEN the repository after Stage 3 completion
- WHEN `git log --all --oneline | xargs -I{} git show {} | grep -i "[redacted]"` is executed
- THEN the command MUST return empty (no matches)
- AND `git log --all --oneline | xargs -I{} git show {} | grep "Redacted Name"` MUST return empty

#### Scenario: PII replaced with neutral placeholders

- GIVEN the repository after Stage 3
- WHEN `git log --all --oneline | xargs -I{} git log -1 --format="%an %ae" {}` is executed
- THEN no author name MUST contain `Redacted Name`
- AND no author email MUST contain `work@example.com` or `personal@example.com` matching `jcuzmar`

#### Scenario: Encrypted blobs are unaffected

- GIVEN the repository after Stage 3
- WHEN sops-encrypted files in `secrets/` are inspected
- THEN the encrypted content MUST still be decryptable
- AND the `.sops.yaml` age key references MUST remain unchanged

### Requirement: Worktrees Pruned Before History Rewrite

ALL git worktrees MUST be pruned and removed before executing `git filter-repo`. Worktrees hold separate checkouts that reference the old commit graph and WILL break after history rewrite.

The `code-work --done` command (or equivalent) MUST be run for each active worktree. No worktrees other than the main checkout MUST exist during the filter-repo operation.

#### Scenario: No worktrees exist before filter-repo

- GIVEN the repository immediately before Stage 3 execution
- WHEN `git worktree list` is executed
- THEN the output MUST show exactly ONE worktree (the main checkout)
- AND no additional worktree directories MUST exist under the repository

### Requirement: Backup Ref Before Force Push

A backup reference (tag or branch) pointing to the pre-scrub HEAD MUST be created before force-pushing rewrites history. This enables rollback to the pre-scrub state if the history rewrite produces unexpected results.

The backup ref MUST be named `refs/tags/pre-history-scrub` or an equivalent non-deletable tag name.

#### Scenario: Backup tag exists before scrub

- GIVEN the repository immediately before Stage 3 force push
- WHEN `git tag --list "pre-history-scrub"` is executed
- THEN the tag `pre-history-scrub` MUST exist
- AND `git rev-parse pre-history-scrub` MUST resolve to the pre-scrub HEAD commit

#### Scenario: Backup tag survives force push

- GIVEN Stage 3 force push is complete
- WHEN `git tag --list "pre-history-scrub"` is executed
- THEN the tag MUST still exist locally
- AND the tag MUST point to the correct pre-scrub commit SHA

### Requirement: No Open Pull Requests Before Force Push

There MUST be zero open pull requests on the GitHub remote before executing the force push. Open PRs reference commit SHAs that will be invalidated by the history rewrite and cannot be recovered.

If open PRs exist, they MUST be closed or merged before proceeding.

#### Scenario: No open PRs on remote

- GIVEN the repository immediately before Stage 3 force push
- WHEN `gh pr list --state open` is executed
- THEN the output MUST be empty (no open pull requests)

#### Scenario: Closed/merged PRs are acceptable

- GIVEN `gh pr list --state open` returns empty
- WHEN the force push is executed
- THEN closed and merged PRs do NOT block the operation

### Requirement: Force Push to GitHub

After `git filter-repo` completes successfully, the rewritten history MUST be force-pushed to the GitHub remote (`origin`).

The force push MUST use `--force` (or `--force-with-lease` if safety checks on the remote ref are desired).

All branches and tags MUST be pushed after the rewrite, not just the current branch.

#### Scenario: GitHub remote reflects rewritten history

- GIVEN the repository after Stage 3 force push
- WHEN `git log --all --oneline | wc -l` is executed locally
- AND the GitHub remote commit count is compared
- THEN both MUST show the same number of commits (all refs synchronized)

#### Scenario: Clone from remote is clean

- GIVEN Stage 3 is complete with force push to GitHub
- WHEN a fresh clone is created with `git clone https://github.com/glats/.nixos.git /tmp/test-scrub-clone`
- THEN `git log --all --oneline | xargs -I{} git show {} | grep -i "[redacted]"` in the clone MUST return empty
- AND `nix flake check --no-build` in the clone MUST pass

### Requirement: Archived OpenSpec Artifacts Scrubbed by History Rewrite

Archived OpenSpec artifacts under `openspec/changes/archive/` that contain PII MUST be scrubbed by the `git filter-repo` text replacement. No manual editing of archived artifacts is required -- the history rewrite handles all file content.

#### Scenario: Archived artifacts have no PII in history

- GIVEN the repository after Stage 3
- WHEN `git log --all --oneline -- openspec/changes/archive/ | xargs -I{} git show {}:openspec/changes/archive/2026-07-06-multi-github-identity/proposal.md | grep "Redacted Name"` is executed
- THEN the command MUST return empty (the PII is replaced in history)

### Requirement: Post-Scrub Validation

After the force push, `nix flake check --no-build` MUST pass on the rewritten repository. This validates that the history rewrite did not corrupt any files critical to repository evaluation.

#### Scenario: Flake check passes after scrub

- GIVEN the repository after Stage 3 force push
- WHEN `nix flake check --no-build` is executed
- THEN the check MUST exit with code 0

#### Scenario: All Nix files remain valid

- GIVEN the repository after Stage 3
- WHEN `format-nix` is executed
- THEN the formatter MUST not report any parse errors
- AND the diff after formatting MUST be clean (no changes needed)

### Requirement: Commit Messages Scrubbed

Commit messages that contained PII MUST be scrubbed by the `git filter-repo` text replacement. After Stage 3, the git log MUST contain zero PII in commit messages, author names, or author emails.

#### Scenario: Commit authors are redacted

- GIVEN the repository after Stage 3
- WHEN `git log --all --format="%an" | sort -u` is executed
- THEN the output MUST NOT contain `Redacted Name`
- AND the author names MUST be consistent redacted values across all commits

#### Scenario: Commit emails are redacted

- GIVEN the repository after Stage 3
- WHEN `git log --all --format="%ae" | sort -u` is executed
- THEN the output MUST NOT contain `work@example.com` or `personal@example.com`

## MODIFIED Requirements

None. All requirements in this domain are new.

## REMOVED Requirements

None.

## RENAMED Requirements

None.
