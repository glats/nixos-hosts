# Tasks: scrub-sensitive-data

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Stage 1 estimated lines | 200-220 |
| Stage 2 estimated lines | 150-200 |
| Stage 3 estimated lines | 0 (execution only) |
| **Total estimated lines** | **350-420** |
| 400-line budget risk | Medium |
| Chained PRs recommended | No |
| Decision needed before apply | No |

**Rationale**: The total is near the 400-line budget. Stage 1 is the heaviest (major rewrites of `home-linux/git.nix` and `home-darwin/git.nix`, plus PII redaction across docs). However, the change has a natural structure: Stage 1 and Stage 2 are distinct phases, each independently verifiable. If the total exceeds 400, split into two PRs: Stage 1 (PR #1) and Stage 2+3 (PR #2).

---

## Stage 1: Encrypt PII (1 commit, ~200-220 lines)

**Goal**: Remove all plaintext PII from Nix files and docs. Store name/email in sops. Wire git identity through HM activation scripts.

### 1.1 Create `secrets/user/identities.yaml` (sops-encrypted)

**File**: `secrets/user/identities.yaml` (NEW)

**Action**: Run `sops secrets/user/identities.yaml` to create the encrypted file with content:
```yaml
personal:
    name: "Redacted Name"
    email: "personal@example.com"
work:
    name: "jcuzmar"
    email: "work@example.com"
```

**Verification**: `sops -d secrets/user/identities.yaml` decrypts successfully and shows both blocks.

**Dependencies**: None (parallel with 1.2)

---

### 1.2 Update `.sops.yaml` with identities.yaml rule

**File**: `.sops.yaml`

**Action**: Add a specific creation rule BEFORE the catch-all `secrets/user/.+` rule that includes ALL hosts (including mact2):

```yaml
  # Identities file -- needed on all hosts including macOS
  - path_regex: secrets/user/identities.yaml
    key_groups:
      - age:
          - *admin_glats
          - *host_rog
          - *host_thinkcentre
          - *host_t14
          - *host_mact2
```

**Rationale**: The existing `secrets/user/.+` catch-all intentionally excludes mact2 (for `atlassian.yaml`). The identities file needs ALL hosts.

**Checklist**:
- [x] Rule inserted before `secrets/user/.+` catch-all
- [x] All 5 age keys listed (admin_glats, rog, thinkcentre, t14, mact2)
- [x] `format-nix` passes

**Dependencies**: None (parallel with 1.1)

---

### 1.3 Update `shared/git-identity.nix` -- strip PII, rename keys

**File**: `shared/git-identity.nix`

**Action**: Replace current content (name/email per identity) with signing-key-only attrs using `personal`/`work` keys:

```nix
{
  personal = {
    signingKey = "CFD6C7FED46F6870BE13CE87D39580F75062BEFC";
  };
  work = {
    signingKey = "B658D64F6FDBCFD1EBA53509A1D4ECB0118566C8";
  };
}
```

**Key decisions in this task**:
- Attrset keys renamed `glats`->`personal`, `jcuzmar`->`work` atomically (all consumers updated in same commit)
- GPG fingerprints stay (they are public identifiers)
- Name/email removed entirely (moved to sops)

**Checklist**:
- [x] `glats` key renamed to `personal`
- [x] `jcuzmar` key renamed to `work`
- [x] `name` and `email` fields removed from both blocks
- [x] `signingKey` fingerprints preserved
- [x] `grep -E "(Redacted Name|personal@|personal@)" shared/git-identity.nix` returns zero

**Dependencies**: None

---

### 1.4 Update `shared/sops.nix` -- add identity secret declarations

**File**: `shared/sops.nix`

**Action**: Add two new sops secret declarations for the identity values:

```nix
  # Identity values from sops (name + email for git/GPG)
  sops.secrets."identities/personal" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
  sops.secrets."identities/work" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
```

**Placement**: After existing secret declarations, before the HM module closure.

**Checklist**:
- [x] `identities/personal` declared with correct `sopsFile`
- [x] `identities/work` declared with correct `sopsFile`
- [x] `mode = "0400"` as specified in design
- [x] `format-nix` passes

**Dependencies**: 1.2 (needs .sops.yaml rule before file encryption succeeds)

---

### 1.5 Rewrite `home-linux/git.nix` -- activation script + git include

**File**: `home-linux/git.nix`

**Action**: Replace current git config with sops-activation-based approach:

1. Set `user.name` / `user.email` to placeholder values via `lib.mkForce` (overrides omarchy defaults on t14)
2. Add `home.activation.writeGitIdentity` (entry after `writeBoundary`) that:
   - Reads decrypted sops identity files (`/run/secrets/identities/personal` etc.)
   - Uses `awk` to extract `name:` and `email:` lines
   - Writes `~/.config/git/identity-personal` and `~/.config/git/identity-work`
   - Gracefully exits 0 if sops files not available
3. Wire `includes` with `{ path = "~/.config/git/identity-personal" }` and `{ condition = "gitdir:~/Work/**"; path = "~/.config/git/identity-work"; }`
4. Keep signing config referencing `identities.personal.signingKey` / `identities.work.signingKey`

**Reference**: Design Decision 2 (lines 92-117) and design section 1e (lines 435-501).

**Checklist**:
- [x] Activation script reads `identities/personal` and `identities/work` secrets
- [x] `awk` extraction matches `name: ...` and `email: ...` format (quotes stripped)
- [x] Graceful degradation: `[ ! -f "$_secrets_file" ]` check with `return 0`
- [x] `user.name`/`user.email` set to placeholder with `lib.mkForce`
- [x] `include.path` references `~/.config/git/identity-personal`
- [x] `includeIf "gitdir:~/Work/**"` references `~/.config/git/identity-work`
- [x] Work signing config preserved in `includes` block
- [x] `format-nix` passes

**Dependencies**: 1.3 (uses `identities.personal`/`work` keys), 1.4 (needs sops declarations)

---

### 1.6 Rewrite `home-darwin/git.nix` -- Darwin activation script

**File**: `home-darwin/git.nix`

**Action**: Same pattern as Linux but with Darwin-specific identity layout:

1. Default identity is `work` (Darwin is work machine)
2. `include.path` for `~/.config/git/identity-work` as default
3. `includeIf "gitdir:~/Personal/**"` for `~/.config/git/identity-personal`
4. Same activation script pattern as Linux
5. `github.user = primaryUser` stays

**Reference**: Design section 1f (lines 510-581).

**Checklist**:
- [x] Activation script identical to Linux (same awk extraction logic)
- [x] Default identity is `work`, not `personal`
- [x] `includeIf "gitdir:~/Personal/**"` for personal identity
- [x] `signing.key = identities.work.signingKey` (default key for Darwin)
- [x] Optional personal signing config
- [x] `format-nix` passes

**Dependencies**: 1.3 (uses `identities` keys), 1.4 (needs sops declarations)

---

### 1.7 Redact `docs/multi-github-identity.md`

**File**: `docs/multi-github-identity.md`

**Action**: Replace all PII references with placeholders that reference `secrets/user/identities.yaml`:

- `Redacted Name` -> `your personal name`
- `personal@example.com` -> `your personal email`
- `work@example.com` -> `your work email`
- `glats` -> `personal` (identity label context)
- `jcuzmar` -> `work` (identity label context)
- Add note that real values are stored in `secrets/user/identities.yaml` (sops-encrypted)

**Checklist**:
- [x] `grep -E "(Redacted Name|work@example\.com|personal@example\.com)" docs/multi-github-identity.md` returns zero
- [x] `grep -i "sops\|secrets/user/identities" docs/multi-github-identity.md` returns matches
- [x] Document references new identity labels (`personal`/`work`)

**Dependencies**: None

---

### 1.8 Redact `openspec/specs/gh-auth/spec.md`

**File**: `openspec/specs/gh-auth/spec.md`

**Action**: Update the git identity requirement table:
- Replace PII literal strings with "Value from `secrets/user/identities.yaml`"
- Update scenario expectations to match sops identity values
- Identity labels already use `personal`/`work` (the spec was already partially updated in the delta)

**Checklist**:
- [x] `grep -E "(Redacted Name|work@example\.com|personal@example\.com)" openspec/specs/gh-auth/spec.md` returns zero
- [x] Table references sops identity file, not literal PII

**Dependencies**: None

---

### 1.9 Stage 1 Verification

Run all acceptance criteria:

```bash
# No PII in git-identity.nix
grep -E "(Redacted Name|work@example\.com|personal@example\.com)" shared/git-identity.nix
# Expected: zero output → PASS

# No PII in docs
grep -E "(Redacted Name|work@example\.com|personal@example\.com)" docs/multi-github-identity.md
# Expected: zero output → PASS

# No PII in live spec
grep -E "(Redacted Name|work@example\.com|personal@example\.com)" openspec/specs/gh-auth/spec.md
# Expected: zero output → PASS

# Identity file decrypts (user must run: sops edit secrets/user/identities.yaml)
# Expected: 2 → PENDING (user action)

# Flake check passes → PASS (nix flake check --no-build)

# Format check → PASS (format-nix && git diff --stat)
```

**Artifacts produced**: Git commit with message:
```
feat(identity): encrypt PII via sops, rename identity labels to personal/work
```

**Dependencies**: 1.1 through 1.8

---

## Stage 2: Rename Identity Labels (2-3 commits, ~150-200 lines)

**Goal**: Rename sops paths, MCP wrappers/configs, GPG paths, and token check labels from `glats`/`jcuzmar` to `personal`/`work`. Backward-compat aliases for one transition cycle.

### 2.1 Add new keys to `secrets/shared/passwords.yaml` (sops edit)

**File**: `secrets/shared/passwords.yaml` (sops-encrypted)

**Action**: Use `sops edit secrets/shared/passwords.yaml` to add NEW keys with identical values alongside OLD keys:

| New Key | Source (old key) |
|---------|-----------------|
| `github/pat_work` | Copy value from `github/pat_jcuzmar` |
| `github/gpg_personal_fingerprint` | Copy from `github/gpg_glats_fingerprint` |
| `github/gpg_personal_key` | Copy from `github/gpg_glats_key` |
| `github/gpg_work_fingerprint` | Copy from `github/gpg_jcuzmar_fingerprint` |
| `github/gpg_work_key` | Copy from `github/gpg_jcuzmar_key` |

**IMPORTANT**: The YAML structure inside the encrypted file is a flat key mapping. Add each new key with its decrypted value manually. Both old and new keys coexist.

**Checklist**:
- [ ] All 5 new keys added
- [ ] Values match their old-key counterparts exactly
- [ ] Old keys still present (both coexist)
- [ ] File is still sops-encrypted (verified via `sops -d`)
- [ ] Git diff shows only encrypted blob changes (additive, no old data removed)

**Dependencies**: None (can run in parallel with Stage 1)

---

### 2.2 Add new sops declarations to `shared/sops.nix`

**File**: `shared/sops.nix`

**Action**: Add new secret declarations ALONGSIDE the old ones (both coexist):

```nix
  # NEW: work PAT
  sops.secrets."github/pat_work" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  # NEW: personal GPG keys
  sops.secrets."github/gpg_personal_fingerprint" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/gpg_personal_key" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  # NEW: work GPG keys
  sops.secrets."github/gpg_work_fingerprint" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/gpg_work_key" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
```

**Checklist**:
- [ ] All 5 new declarations present
- [ ] Old declarations NOT removed (both coexist)
- [ ] `format-nix` passes

**Dependencies**: 2.1 (new keys must exist in encrypted file)

---

### 2.3 Add `pat_work` to `modules/base/sops.nix`

**File**: `modules/base/sops.nix`

**Action**: Add new system-level sops declaration:

```nix
  sops.secrets."github/pat_work" = {
    owner = "glats";
    group = "users";
    mode = "0400";
  };
```

System username `glats` in `owner` is CORRECT -- this is the OS-level user.

**Checklist**:
- [ ] `pat_work` declared with correct owner/group/mode
- [ ] Old `pat_jcuzmar` declaration still present
- [ ] `format-nix` passes

**Dependencies**: None

---

### 2.4 Update `home-linux/gpg.nix` -- new sops paths

**File**: `home-linux/gpg.nix`

**Action**: Replace all old sops path references with new ones:

| Old | New |
|-----|-----|
| `gpg_glats_fingerprint` | `gpg_personal_fingerprint` |
| `gpg_glats_key` | `gpg_personal_key` |
| `gpg_jcuzmar_fingerprint` | `gpg_work_fingerprint` |
| `gpg_jcuzmar_key` | `gpg_work_key` |

Also rename the `importKey` first arg labels: `glats` -> `personal`, `jcuzmar` -> `work`.

**Checklist**:
- [ ] All 4 sops path references updated
- [ ] importKey label arguments updated
- [ ] `format-nix` passes

**Dependencies**: 2.2 (new declarations must exist)

---

### 2.5 Update `home-darwin/gpg.nix` -- new sops paths

**File**: `home-darwin/gpg.nix`

**Action**: Same path renames as 2.4 but for Darwin.

**Checklist**:
- [ ] All 4 sops path references updated
- [ ] importKey label arguments updated
- [ ] `format-nix` passes

**Dependencies**: 2.2 (new declarations must exist)

---

### 2.6 Add new MCP wrappers to `modules/features/services/github-mcp-server.nix`

**File**: `modules/features/services/github-mcp-server.nix`

**Action**: Add new `github-mcp-server-personal` and `github-mcp-server-work` wrappers alongside the old `-glats` and `-jcuzmar` wrappers. All 4 wrappers coexist during transition.

- `personal` wrapper reads `github/pat` (same PAT as old `glats` wrapper)
- `work` wrapper reads `github/pat_work` (same PAT as old `jcuzmar` wrapper)
- Include all 4 in `environment.systemPackages`

**Checklist**:
- [ ] New `personal` wrapper declared with correct name and path
- [ ] New `work` wrapper declared with correct name and path
- [ ] Old `glats` and `jcuzmar` wrappers still present
- [ ] All 4 wrappers included in systemPackages
- [ ] `format-nix` passes

**Dependencies**: None

---

### 2.7 Add new MCP wrappers to `home-darwin/github-mcp-server-wrapper.nix`

**File**: `home-darwin/github-mcp-server-wrapper.nix`

**Action**: Same dual-wrapper approach as 2.6 but for Darwin:

- New `personal` wrapper reads `github/pat`
- New `work` wrapper reads `github/pat_work`
- Old wrappers kept during transition

**Note**: Old `jcuzmar` wrapper now points to `github/pat_work` (was reading `github/token` from `atlassian.yaml`).

**Checklist**:
- [ ] New wrappers created
- [ ] Old wrappers preserved
- [ ] `format-nix` passes

**Dependencies**: None

---

### 2.8 Add new MCP config entries to `shared/opencode/mcps-base.nix`

**File**: `shared/opencode/mcps-base.nix`

**Action**: Add new `github-personal` and `github-work` config entries alongside old `github-glats` and `github-jcuzmar`:

```nix
defaultMcps = {
  "github-personal" = {
    type = "local";
    command = [ "github-mcp-server-personal" "stdio" ];
    enabled = true;
  };
  "github-work" = {
    type = "local";
    command = [ "github-mcp-server-work" "stdio" ];
    enabled = true;
  };
  # OLD entries kept during transition
  "github-glats" = { ... };
  "github-jcuzmar" = { ... };
};
```

**Checklist**:
- [ ] New `github-personal` entry references `github-mcp-server-personal`
- [ ] New `github-work` entry references `github-mcp-server-work`
- [ ] Old entries preserved
- [ ] `format-nix` passes

**Dependencies**: 2.6, 2.7 (new wrappers must exist)

---

### 2.9 Update label references in `github-token-check.nix`

**File**: `modules/features/services/github-token-check.nix`

**Action**: Rename token check labels from `glats`/`jcuzmar` to `personal`/`work`:

```nix
check_token "personal" "${config.sops.secrets."github/pat".path}"
check_token "work"    "${config.sops.secrets."github/pat_work".path}"
```

**Checklist**:
- [ ] First argument to `check_token` uses `personal`/`work`
- [ ] Sops paths use new names (`pat_work` instead of `pat_jcuzmar`)
- [ ] `format-nix` passes

**Dependencies**: None

---

### 2.10 Update label comment in `home-linux/shell.nix`

**File**: `home-linux/shell.nix`

**Action**: Update the warning message label from `glats` to `personal`:

```nix
echo "WARNING: GitHub token (personal) expired! ..."
```

Only the label text changes. The sops path stays `github/pat`.

**Checklist**:
- [ ] Label text updated from `glats` to `personal`
- [ ] No other changes to the file
- [ ] `format-nix` passes

**Dependencies**: None

---

### 2.11 Cleanup: remove old labels, aliases, wrappers

**Files**:
- `secrets/shared/passwords.yaml` (sops edit: remove old keys)
- `shared/sops.nix` (remove old declarations)
- `modules/base/sops.nix` (remove `pat_jcuzmar` declaration)
- `modules/features/services/github-mcp-server.nix` (remove old wrappers)
- `home-darwin/github-mcp-server-wrapper.nix` (remove old wrappers)
- `shared/opencode/mcps-base.nix` (remove old MCP entries)
- `home-linux/gpg.nix`, `home-darwin/gpg.nix` (ensure no old refs remain)

**Action**: After all hosts have been rebuilt and verified with new paths:
1. `sops edit secrets/shared/passwords.yaml` to remove old keys
2. Delete old sops secret declarations from Nix files
3. Delete old wrapper definitions
4. Delete old MCP config entries

**GRACE PERIOD**: Do NOT commit this until at least one full build cycle on each host has verified the new paths work.

**Checklist**:
- [ ] `grep -rn "pat_jcuzmar\|gpg_glats_\|gpg_jcuzmar_" modules/ home-linux/ home-darwin/ shared/` returns zero
- [ ] `grep "github-mcp-server-glats\|github-mcp-server-jcuzmar"` returns zero
- [ ] `grep "github-glats\|github-jcuzmar"` returns zero
- [ ] `format-nix` passes
- [ ] `nix flake check --no-build` passes

**Dependencies**: 2.1 through 2.10

---

### 2.12 Stage 2 Verification

Run all acceptance criteria:

```bash
# No old identity labels in Nix code
grep -rn "identities\.glats\|identities\.jcuzmar" home-linux/ home-darwin/ shared/
# Expected: zero output

# No old sops path names
grep -rn "pat_jcuzmar\|gpg_glats_\|gpg_jcuzmar_" modules/ home-linux/ home-darwin/ shared/
# Expected: zero output (after cleanup)

# System usernames preserved
grep -rn "users\.users\.glats\|users\.users\.personal" modules/base/ hosts/
# Expected: "users.users.glats" found, "users.users.personal" NOT found

# SSH configs unchanged
grep "User = " home-linux/ssh.nix home-darwin/ssh.nix
# Expected: User = "glats" and User = "jcuzmar" still present

# Build check
nix flake check --no-build

# Format check
format-nix && git diff --stat
```

**Dependencies**: 2.1 through 2.11

---

## Stage 3: Scrub Git History (no code changes, execution only)

**Goal**: Remove all PII from git history using `git filter-repo`.

### 3.1 Prerequisites

**Action**: Execute prerequisite checks:

```bash
# Verify only main worktree
git worktree list
# Expected: exactly 1 entry

# Close all worktrees
code-work --done   # for each active worktree

# Create backup tag
tag_before=$(git rev-parse HEAD)
git tag pre-history-scrub "$tag_before"

# Verify no open PRs
gh pr list --state open
# Expected: empty
```

**Checklist**:
- [ ] No worktrees other than main checkout
- [ ] `pre-history-scrub` tag exists and points to current HEAD
- [ ] Zero open PRs on GitHub

**Dependencies**: Stage 2 commits merged

---

### 3.2 Create replacement files

**Action**: Create filter-repo input files:

```bash
cat > /tmp/scrub-replacements.txt <<'EOF'
Redacted Name==>Redacted Name
work@example.com==>work@example.com
personal@example.com==>personal@example.com
EOF

cat > /tmp/scrub-mailmap.txt <<'EOF'
Redacted Name <personal@example.com> Redacted Name <personal@example.com>
Redacted Name <work@example.com> Redacted Name <work@example.com>
EOF
```

**Checklist**:
- [ ] replacements.txt contains all 3 PII strings to replace
- [ ] mailmap.txt maps author/committer entries to redacted values
- [ ] Replacement values are neutral placeholders

**Dependencies**: None

---

### 3.3 Execute git filter-repo

**Action**: Run the history rewrite:

```bash
git filter-repo \
  --replace-text /tmp/scrub-replacements.txt \
  --mailmap /tmp/scrub-mailmap.txt \
  --force
```

**Checklist**:
- [ ] `git filter-repo` exits with code 0
- [ ] Repository is in a clean state after rewrite
- [ ] All commits still valid (no empty commit errors unless expected)

**Dependencies**: 3.1, 3.2

---

### 3.4 Post-scrub validation

**Action**:

```bash
# Check for PII in history
git log --all --oneline | xargs -I{} git show {} 2>/dev/null | grep -i "[redacted]"
# Expected: zero output

git log --all --oneline | xargs -I{} git show {} 2>/dev/null | grep "Redacted Name"
# Expected: zero output

# Check author emails
git log --all --format="%ae" | sort -u
# Expected: personal@example.com, work@example.com (NOT work@example.com or personal@example.com)

# Flake check
nix flake check --no-build

# Format check
format-nix && git diff --stat

# Sops decrypt check (encrypted blobs unaffected)
sops -d secrets/shared/passwords.yaml > /dev/null 2>&1
echo "Exit code: $?"
# Expected: 0
```

**Checklist**:
- [ ] Zero `[redacted]` in `git log --all`
- [ ] Zero `Redacted Name` in `git log --all`
- [ ] Author emails are only `personal@example.com` and `work@example.com`
- [ ] `nix flake check --no-build` passes
- [ ] `format-nix` produces zero diff
- [ ] `sops -d` decrypts all secrets correctly

**Dependencies**: 3.3

---

### 3.5 Force push to GitHub

**Action**:

```bash
git push --force --all origin
git push --force --tags origin
```

**Checklist**:
- [ ] All branches pushed
- [ ] All tags pushed (including `pre-history-scrub`)
- [ ] Remote commit count matches local

**Dependencies**: 3.4 (validation must pass first)

---

### 3.6 Fresh clone verification

**Action**:

```bash
cd /tmp && rm -rf scrub-test
git clone https://github.com/glats/.nixos.git scrub-test
cd scrub-test

# Check for PII
git log --all --oneline | xargs -I{} git show {} 2>/dev/null | grep -i "[redacted]"
# Expected: zero output

# Flake check on cloned repo
nix flake check --no-build
```

**Checklist**:
- [ ] Fresh clone from remote is PII-free
- [ ] `nix flake check --no-build` passes on clone
- [ ] System usernames (`glats`/`jcuzmar`) still appear correctly in config files

**Dependencies**: 3.5

---

## Execution Order

```
Stage 1 (parallel group):
  1.1 ──┐
  1.2 ──┤
  1.3 ──┤ (no deps between these)
  1.7 ──┤
  1.8 ──┘
        │
Stage 1 (sequential):
  1.4 ── depends on 1.2 (sops rule needed)
  1.5 ── depends on 1.3, 1.4
  1.6 ── depends on 1.3, 1.4
  1.9 ── depends on all Stage 1
        │
        V
   [Commit 1: feat(identity): encrypt PII via sops, rename identity labels to personal/work]
        │
Stage 2 (parallel group):
  2.1 ──┐
  2.3 ──┤
  2.9 ──┤ (no deps between these)
  2.10 ─┘
  2.4 ── depends on 2.2
  2.5 ── depends on 2.2
        │
Stage 2 (sequential):
  2.2 ── depends on 2.1
  2.6 ── no deps (but sequential to 2.7-2.8 for clarity)
  2.7 ── no deps
  2.8 ── depends on 2.6, 2.7
  2.11 ─ depends on all Stage 2 (grace period)
  2.12 ─ depends on 2.11
        │
        V
   [Commit 2: feat(identity): add work/personal sops keys and MCP wrappers]
   [Commit 3: feat(identity): switch all references to personal/work names]
   [Commit 4: feat(identity): remove old glats/jcuzmar labels and sops aliases]
        │
Stage 3 (execution, no commits):
  3.1 ── prerequisite checks
  3.2 ── create replacement files
  3.3 ── execute filter-repo
  3.4 ── post-scrub validation
  3.5 ── force push
  3.6 ── fresh clone verification
```

## Key Risks During Execution

| Risk | Mitigation |
|------|-----------|
| HM activation fails without identity secrets | Activation script exits 0 if secrets unavailable; placeholder `user.name`/`user.email` used |
| Partial rebuild during Stage 2 transition | Both old and new sops keys exist, both old and new declarations are active; no breakage |
| filter-repo modifies encrypted sops blobs | Encrypted ciphertext does NOT contain plaintext PII strings; replacements won't match |
| Old MCP configs still referenced by OpenCode | Both old and new configs exist during transition; user removes old ones at their pace |
| System username accidentally renamed | Code review checklist in design Decision 7; grep-based guard lines in acceptance criteria |
| Git history rewrite invalidates open PRs | Pre-checks verify zero open PRs before force push |
| `format-nix` changes diff after Stage 3 | All format changes should be committed BEFORE Stage 3 (filter-repo rewrites entire history) |
