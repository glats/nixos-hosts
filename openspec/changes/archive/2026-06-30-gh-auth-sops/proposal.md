# Proposal: GitHub auth via sops-nix for linux hosts

## Intent

Configure `gh`, `git`, and GitHub MCP server to always be authenticated on rog, thinkcentre, and t14 using sops-nix. Darwin (mact2) excluded.

## Scope

**In Scope**:
- Set git user identity for all linux hosts
- Export `GH_TOKEN` from sops in zsh init
- Remove unused `sops.secrets."git-credentials"` from rog
- Leverage `programs.gh.gitCredentialHelper` (default-enabled) for git auth

**Out of Scope**: Darwin/mact2, token rotation docs, GPG signing.

## Capabilities

**New**: None (configuration change, not new capability).
**Modified**: None (no spec-level behavior changes).

## Approach

HM's `programs.gh.gitCredentialHelper` (default `true`) sets `credential.helper` to `gh auth git-credential`. No manual `~/.git-credentials` materialization needed.

**Changes**:
1. `hosts/rog/secrets.nix`: Remove `sops.secrets."git-credentials"` (lines 49-55).
2. `home-linux/git.nix`: Add `settings.user.name = "Redacted Name"`, `settings.user.email = "personal@example.com"`.
3. `home-linux/shell.nix`: Add to `programs.zsh.initContent` (lib.mkAfter):
   ```nix
   if [ -f "${config.sops.secrets."github/pat".path}" ]; then
     export GH_TOKEN="$(cat ${config.sops.secrets."github/pat".path})"
   fi
   ```

**Mechanism**: `programs.gh.enable = true` → `gitCredentialHelper` default → `credential.helper` uses `gh auth git-credential` → reads `$GH_TOKEN` → git ops authenticated. No separate credentials file.

**Unchanged**: `gh.nix`, `github-mcp-server.nix`, `modules/base/sops.nix`, darwin files.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `hosts/rog/secrets.nix` | Modified | Remove unused `git-credentials` secret |
| `home-linux/git.nix` | Modified | Add `user.name` and `user.email` |
| `home-linux/shell.nix` | Modified | Add `GH_TOKEN` export |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `GH_TOKEN` only in interactive zsh | Low | MCP reads sops directly; git uses credential helper; `gh` only from shell |
| First activation on rog: HM won't clobber hand-placed `~/.git-credentials` | Low | Existing `backupFileExtension = "backup"` renames to `.backup` |
| Token scope: `gho_` PAT must have `repo` and `read:org` | Medium | Verify in GitHub UI before apply |
| Token rotation requires re-encrypting sops | Low | Normal sops flow; document later |

## Rollback Plan

Revert 3 file changes, run `nixos-build switch`, restore `~/.git-credentials` from `.backup` if needed.

## Dependencies

- `sops.secrets."github/pat"` already in `modules/base/sops.nix`
- `programs.gh.enable = true` already in `home-linux/gh.nix`
- `programs.git.enable = true` already in `home-linux/git.nix`

## Success Criteria

- [ ] `git push`/`pull` over HTTPS works on all 3 hosts
- [ ] `gh pr list`/`gh issue list` works on all 3 hosts
- [ ] GitHub MCP server continues working (no regression)
- [ ] `git config user.name` = "Redacted Name"
- [ ] `git config user.email` = "personal@example.com"
- [ ] No `~/.git-credentials` materialized by HM

## Alternatives

**Explore Option A** (materialize `~/.git-credentials`): Rejected — `gitCredentialHelper` is cleaner, avoids token duplication.
**Option B** (`home.sessionVariables`): Rejected — strings not file paths; needs custom activation.
**Option C** (custom helper + `gh auth login`): Rejected — fragile; process spawn per op.
