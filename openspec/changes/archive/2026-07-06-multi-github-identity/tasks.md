# SDD Tasks: multi-github-identity

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Estimated changed lines (additions + deletions) | ~160 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Decision needed before apply | No |

**Rationale**: Total estimated diff is well under the 400-line budget. The largest file change is `home-darwin/git.nix` (net ~-6 lines after refactor). All other files are small, focused changes. A single PR is safe for review.

---

## Task Breakdown

### Phase 1: Secrets + Identity Definitions + Git Config

#### Task 1.1: Add secrets to sops (manual prerequisite)

**Description**: Add `github.pat_jcuzmar` (jcuzmar's GitHub PAT) and `github.gpg_key_fingerprint` (GPG fingerprint `B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8`) to `secrets/shared/passwords.yaml` via `sops edit`. Re-encrypt for all four hosts (rog, thinkcentre, t14, mact2).

**Files affected**:
- `secrets/shared/passwords.yaml` (modified via sops, not direct edit)

**Verification**:
- `sops -d secrets/shared/passwords.yaml | grep -q github.pat_jcuzmar` — should find the key
- `sops -d secrets/shared/passwords.yaml | grep -q github.gpg_key_fingerprint` — should find the key

**Dependencies**: None (manual step, requires user to provide secret values)

---

#### Task 1.2: Create shared identity definitions module

**Description**: Create `shared/git-identity.nix` — a plain attribute set defining both identities (glats and jcuzmar) with `name` and `email` fields. Single source of truth imported by both Linux and macOS git configs.

**Files affected**:
- `shared/git-identity.nix` (NEW, ~12 lines)

**Exact content** (from design section 4.1):
```nix
{
  glats = {
    name = "Redacted Name";
    email = "personal@example.com";
  };
  jcuzmar = {
    name = "jcuzmar";
    email = "work@example.com";
  };
}
```

**Verification**:
- `nix eval .#lib.intersectAttrs --apply 'x: x' shared/git-identity.nix` or simple syntax check
- `nix flake check --no-build` — must pass (module is imported by git.nix files)

**Dependencies**: None

---

#### Task 1.3: Add sops declarations for new secrets

**Description**: Add `github/pat_jcuzmar` declaration to `shared/sops.nix` and `github/gpg_key_fingerprint` declaration to `home-darwin/sops.nix`.

**Files affected**:
- `shared/sops.nix` (MODIFIED, +4 lines)
- `home-darwin/sops.nix` (MODIFIED, +4 lines)

**Changes**:
1. In `shared/sops.nix`: Add after the existing `github/pat` block (line 47-50):
   ```nix
   sops.secrets."github/pat_jcuzmar" = {
     sopsFile = ../secrets/shared/passwords.yaml;
     mode = "0400";
   };
   ```

2. In `home-darwin/sops.nix`: Add after the existing `github/token` block (line 35-38):
   ```nix
   sops.secrets."github/gpg_key_fingerprint" = {
     sopsFile = ../secrets/shared/passwords.yaml;
     mode = "0400";
   };
   ```

**Verification**:
- `nix flake check --no-build` — must pass for all hosts
- Inspect rendered sops config to confirm both new secrets appear

**Dependencies**: Task 1.1 (secrets must exist in passwords.yaml before declaration)

---

#### Task 1.4: Refactor home-linux/git.nix with identity definitions and includes

**Description**: Import `shared/git-identity.nix`, replace hardcoded name/email strings with identity references, add `programs.git.includes` block for jcuzmar identity under `~/Work/**`. Preserve `lib.mkForce` on default user.name and user.email.

**Files affected**:
- `home-linux/git.nix` (MODIFIED, 19 → ~28 lines, +9 net)

**Changes**:
1. Add `identities = import ../shared/git-identity.nix;` let binding (after the function args)
2. Replace `"Redacted Name"` with `identities.glats.name` and `"personal@example.com"` with `identities.glats.email`
3. Add `includes` list after `settings`:
   ```nix
   includes = [
     {
       condition = "gitdir:~/Work/**";
       contents = {
         user.name = identities.jcuzmar.name;
         user.email = identities.jcuzmar.email;
       };
     }
   ];
   ```

**Verification**:
- `nix flake check --no-build` — must pass for rog, thinkcentre, t14
- Inspect rendered `~/.gitconfig` on a Linux host: default user block + includeIf for ~/Work/**

**Dependencies**: Task 1.2

---

#### Task 1.5: Refactor home-darwin/git.nix — remove home.file, add includes, move GPG to sops

**Description**: Major refactor of macOS git config. Remove `home.file.".git-falabella"` block (lines 3-14), replace `includeIf."gitdir:~/Work/**".path` with inline `programs.git.includes`, add glats includeIf for `~/Personal/**`, move GPG signing key from hardcoded string to sops path reference. Import shared identities.

**Files affected**:
- `home-darwin/git.nix` (MODIFIED, 41 → ~35 lines, net -6)

**Changes**:
1. Add `config, lib` to function args: `{ pkgs, config, primaryUser, lib, ... }:`
2. Add `identities = import ../shared/git-identity.nix;` let binding
3. Remove entire `home.file.".git-falabella"` block (lines 3-14)
4. Replace hardcoded user name/email with `identities.jcuzmar.name` / `identities.jcuzmar.email`
5. Remove `includeIf."gitdir:~/Work/**".path = "~/.git-falabella";` from settings
6. Change `signing.key` from hardcoded string to `builtins.readFile config.sops.secrets."github/gpg_key_fingerprint".path`
7. Add `includes` list with two entries:
   - `gitdir:~/Work/**` → jcuzmar identity (same as default, preserves structure)
   - `gitdir:~/Personal/**` → glats identity (no signing key — global signing applies)

**Verification**:
- `nix flake check --no-build` — must pass for mact2
- `~/.git-falabella` should no longer be created on next build
- `git log --show-signature -1` on mact2 should still show GPG signature

**Dependencies**: Task 1.2, Task 1.3

---

### Phase 2: MCP Wrappers + Config

#### Task 2.1: Parametrize Linux MCP wrapper into dual wrappers

**Description**: Refactor `modules/features/services/github-mcp-server.nix` to use a `mkGithubMcpWrapper` helper function that produces two named wrappers (`github-mcp-server-glats` reading `github/pat`, `github-mcp-server-jcuzmar` reading `github/pat_jcuzmar`). Remove the old single `github-mcp-server-wrapped`.

**Files affected**:
- `modules/features/services/github-mcp-server.nix` (MODIFIED, 43 → ~55 lines, +12 net)

**Changes**:
1. Replace the single `github-mcp-server-wrapped` let binding with a `mkGithubMcpWrapper` function
2. Define `githubMcpServerGlats` (reads `github/pat`) and `githubMcpServerJcuzmar` (reads `github/pat_jcuzmar`)
3. Update `environment.systemPackages` to include both new wrappers plus the original `pkgs.github-mcp-server`

**Verification**:
- `nix flake check --no-build` — must pass for rog, thinkcentre, t14
- `which github-mcp-server-glats github-mcp-server-jcuzmar` — both should exist on Linux hosts

**Dependencies**: Task 1.3 (pat_jcuzmar secret must be declared)

---

#### Task 2.2: Parametrize macOS MCP wrapper into dual wrappers

**Description**: Refactor `home-darwin/github-mcp-server-wrapper.nix` using the same `mkGithubMcpWrapper` pattern. Key difference: macOS jcuzmar wrapper reads `github/token` (from atlassian.yaml), NOT `github/pat_jcuzmar` (backward compat).

**Files affected**:
- `home-darwin/github-mcp-server-wrapper.nix` (MODIFIED, 25 → ~40 lines, +15 net)

**Changes**:
1. Replace single `githubMcpServerWrapped` with `mkGithubMcpWrapper` function
2. Define `githubMcpServerGlats` (reads `github/pat`) and `githubMcpServerJcuzmar` (reads `github/token`)
3. Update `home.packages` to include both wrappers

**Verification**:
- `nix flake check --no-build` — must pass for mact2
- Both wrapper binaries available in PATH on mact2

**Dependencies**: Task 1.3 (gpg_key_fingerprint and pat_jcuzmar must be declared)

---

#### Task 2.3: Update MCP base config with dual entries

**Description**: Replace the single `github` entry in `shared/opencode/mcps-base.nix` with two named entries: `github-glats` (command: `github-mcp-server-glats`) and `github-jcuzmar` (command: `github-mcp-server-jcuzmar`). Both enabled by default.

**Files affected**:
- `shared/opencode/mcps-base.nix` (MODIFIED, 82 → ~90 lines, +8 net)

**Changes**:
1. In `defaultMcps` let block, replace the `github` attrset (lines 12-19) with:
   ```nix
   "github-glats" = {
     type = "local";
     command = [ "github-mcp-server-glats" "stdio" ];
     enabled = true;
   };
   "github-jcuzmar" = {
     type = "local";
     command = [ "github-mcp-server-jcuzmar" "stdio" ];
     enabled = true;
   };
   ```

**Verification**:
- `nix flake check --no-build` — must pass for all hosts
- Both MCP entries visible in rendered opencode config

**Dependencies**: Task 2.1, Task 2.2 (wrappers must exist)

---

#### Task 2.4: Remove obsolete github override from macOS mcps-extra

**Description**: Remove the `github` entry from `home-darwin/opencode/mcps-extra.nix` (lines 14-22). The base config now provides `github-glats` and `github-jcuzmar` which resolve to platform-specific wrappers via PATH.

**Files affected**:
- `home-darwin/opencode/mcps-extra.nix` (MODIFIED, 82 → ~72 lines, -10 net)

**Changes**:
1. Delete the `github` attrset from `extraMcps` (lines 14-22)
2. Update the file comment on line 1 to remove "github" from the list

**Verification**:
- `nix flake check --no-build` — must pass for mact2
- No `github` key in rendered extraMcps (only `github-glats` and `github-jcuzmar` from base)

**Dependencies**: Task 2.3

---

### Phase 3: Cleanup + Verification

#### Task 3.1: Remove unused git-credentials.yaml

**Description**: Delete `secrets/shared/git-credentials.yaml` from the repository. Confirmed unused — zero Nix module references.

**Files affected**:
- `secrets/shared/git-credentials.yaml` (REMOVED)

**Verification**:
- `git status` shows the file as deleted
- `grep -r "git-credentials" .` returns zero results in .nix files
- `nix flake check --no-build` still passes

**Dependencies**: None (can be done anytime, but logically belongs in cleanup phase)

---

#### Task 3.2: Final verification — all acceptance criteria

**Description**: Run full verification across all four hosts. Check all acceptance criteria from the spec.

**Verification checklist**:

| AC | Criterion | Method |
|----|-----------|--------|
| AC-1 | Linux ~/dev/* shows glats identity | Manual: `cd ~/dev/* && git config user.name` → "Redacted Name" |
| AC-2 | Linux ~/Work/* shows jcuzmar identity | Manual: `cd ~/Work/* && git config user.name` → "jcuzmar" |
| AC-3 | macOS ~/dev/* shows jcuzmar identity | Manual: `cd ~/dev/* && git config user.name` → "jcuzmar" |
| AC-4 | macOS ~/Personal/* shows glats identity | Manual: `cd ~/Personal/* && git config user.name` → "Redacted Name" |
| AC-5 | MCP github-glats connects | Manual: MCP connection test |
| AC-6 | MCP github-jcuzmar connects | Manual: MCP connection test |
| AC-7 | `nix flake check --no-build` all hosts | Automated |
| AC-8 | ~/.git-falabella removed on mact2 | Manual: `ls ~/.git-falabella` → should fail |
| AC-9 | git-credentials.yaml removed | Manual: `ls secrets/shared/git-credentials.yaml` → should fail |
| AC-10 | GPG signing works on mact2 | Manual: `git log --show-signature -1` |

**Dependencies**: Tasks 1.1-1.5, 2.1-2.4, 3.1

---

## Execution Order

```
Task 1.1 (manual: add secrets to sops)
    |
Task 1.2 (create shared/git-identity.nix)     [parallel with 1.1]
    |
    +-- Task 1.3 (add sops declarations)       [depends: 1.1, 1.2]
    |       |
    |       +-- Task 1.5 (refactor darwin/git.nix) [depends: 1.2, 1.3]
    |
    +-- Task 1.4 (refactor linux/git.nix)      [depends: 1.2]
    
    === PHASE 1 COMPLETE === nix flake check --no-build ===
    
Task 2.1 (Linux MCP wrappers)                  [depends: 1.3]
Task 2.2 (macOS MCP wrappers)                  [depends: 1.3]  [parallel with 2.1]
    |
Task 2.3 (MCP base config)                     [depends: 2.1, 2.2]
    |
Task 2.4 (macOS mcps-extra cleanup)            [depends: 2.3]
    
    === PHASE 2 COMPLETE === nix flake check --no-build ===
    
Task 3.1 (remove git-credentials.yaml)
Task 3.2 (final verification)                  [depends: all]
    
    === PHASE 3 COMPLETE === ALL DONE ===
```

**Parallelizable**:
- 1.1 and 1.2 can run in parallel
- 2.1 and 2.2 can run in parallel
- 3.1 can run anytime after Phase 1

**Critical path**: 1.1 → 1.3 → 1.5 → 2.1/2.2 → 2.3 → 2.4 → 3.2

---

## Phase Verification Commands

| Phase | Command | Expected |
|-------|---------|----------|
| Phase 1 | `nix flake check --no-build` | Passes for all 4 hosts |
| Phase 2 | `nix flake check --no-build` | Passes for all 4 hosts |
| Phase 3 | `nix flake check --no-build` | Passes for all 4 hosts |
| Phase 3 | `git diff --stat` | Shows secrets/shared/git-credentials.yaml deleted |

---

## Risk Notes

1. **sops encryption**: Task 1.1 requires manual `sops edit` — the new secrets MUST be encrypted for all four hosts' age keys before proceeding. If a host is missed, that host's build will fail.
2. **GPG fingerprint trailing newline**: The sops value for `github/gpg_key_fingerprint` MUST NOT have a trailing newline, or `builtins.readFile` will include it and git signing may break. Verify with `sops -d ... | xxd | tail`.
3. **t14 omarchy-nix compatibility**: The `lib.mkForce` on defaults is preserved. The `includeIf` blocks are separate HM options that do not inherit `mkForce`. This has been validated in the design.
