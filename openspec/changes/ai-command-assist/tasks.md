# Tasks: ai-command-assist

> **Source**: sdd/ai-command-assist/proposal (revision 2), sdd/ai-command-assist/spec
> **Change**: ~20-line HM module + 3 host imports — shell-gpt CLI with nvidia NIM
> **Total delta**: ~30 lines across 4 files

## Review Workload Forecast

| Metric | Value |
|--------|-------|
| Estimated changed lines | ~30 |
| Files touched | 4 (1 new, 3 modified) |
| New code | ~20 lines (declarative Nix only) |
| Custom scripts/derivations | 0 |
| Flake inputs added | 0 |
| 400-line budget risk | None |
| Chained PRs | Not needed |

## Dependencies

- **Requirement**: `pkgs.shell-gpt` (already in nixpkgs — no new flake inputs)
- **Requirement**: `NVIDIA_API_KEY` env var (already exported by `shared/opencode.nix` via sops-nix)
- **Build dependency**: Phase 1 → Phase 2 → Phase 3

---

## Phase 1: Module Creation

**Duration**: ~2 min
**Depends on**: Nothing

### Task 1.1 — Create `home-linux/shell-gpt.nix`

- **File**: `home-linux/shell-gpt.nix` (NEW)
- **Action**: Write the HM module exposing `home.shell-gpt.{enable,model,baseUrl,provider}` options
- **Options**:
  - `enable` (boolean, default false) — `lib.mkEnableOption`
  - `model` (str, default `"nvidia/nemotron-3-ultra-550b-a55b"`)
  - `baseUrl` (str, default `"https://integrate.api.nvidia.com/v1"`)
  - `provider` (str, default `"nvidia"`, documentation only)
- **Config when enabled**:
  - `home.packages = [ pkgs.shell-gpt ]`
  - `home.sessionVariables` for `API_BASE_URL`, `OPENAI_API_KEY`, `DEFAULT_MODEL`
- **Config when disabled**: No packages, no env vars
- **Gate**: `lib.mkIf cfg.enable`

### Task 1.2 — Verify single file

- **Action**: Run `nix flake check --no-build`
- **Expectation**: Pass (module exists but isn't imported by any host yet — no error from orphan HM modules)

---

## Phase 2: Host Integration

**Duration**: ~5 min
**Depends on**: Phase 1

### Task 2.1 — Add import to `hosts/rog/home/modules.nix`

- **File**: `hosts/rog/home/modules.nix`
- **Action**: Append `../../../home-linux/shell-gpt.nix` to the module import list
- **Pattern**: Same as existing host-conditional imports (line before `remote-desktop.nix`)
- **Comment**: `# home.shell-gpt.enable = true;  # uncomment to enable shell-gpt`

### Task 2.2 — Add import to `hosts/thinkcentre/home/modules.nix`

- **File**: `hosts/thinkcentre/home/modules.nix`
- **Action**: Append `../../../home-linux/shell-gpt.nix` to the module import list
- **Comment**: `# home.shell-gpt.enable = true;  # uncomment to enable shell-gpt`

### Task 2.3 — Add import to `hosts/t14/home/omarchy.nix`

- **File**: `hosts/t14/home/omarchy.nix`
- **Action**: Add `../../../home-linux/shell-gpt.nix` to the `imports` list (in compatible shared modules section, after `../../../home-linux/remote-desktop.nix`)
- **Comment**: `# home.shell-gpt.enable = true;  # uncomment to enable shell-gpt`
- **Note**: Import exists but enable stays commented — t14 gets the module path evaluated but shell-gpt is NOT installed

---

## Phase 3: Verification

**Duration**: ~5 min
**Depends on**: Phase 2

### Task 3.1 — Run `nix flake check --no-build`

- **Action**: Validate all Nix expressions parse and evaluate
- **Expectation**: Exit code 0 across all hosts (rog, thinkcentre, t14, mact2)
- **Fallback**: If mact2 fails, check if error is pre-existing (per AGENTS.md)

### Task 3.2 — Run `format-nix`

- **Action**: Format the entire repository
- **Expectation**: No formatting diff (or git diff --stat shows only formatter changes)
- **Verify**: `git diff --stat` to review

### Task 3.3 — Build dry-run on rog (if available)

- **Action**: `nixos-build dry` (auto-detects host)
- **Expectation**: Shows what would change; no evaluation errors
- **Check**: `sgpt` binary appears in the planned changes

### Task 3.4 — Final diff review

- **Action**: Inspect `git diff --cached --stat` and `git diff --cached`
- **Checklist**:
  - [ ] `home-linux/shell-gpt.nix` exists and has correct module structure
  - [ ] Options use correct defaults (model, baseUrl, provider)
  - [ ] `OPENAI_API_KEY = "$NVIDIA_API_KEY"` (literal string, NOT interpolated)
  - [ ] rog import exists with commented enable
  - [ ] thinkcentre import exists with commented enable
  - [ ] t14 import exists with commented enable
  - [ ] `home-linux/shared-modules.nix` is NOT modified
  - [ ] No secrets exposed in plaintext
  - [ ] No new flake inputs added

---

## Phase 4: Commit

**Duration**: ~1 min
**Depends on**: Phase 3

### Task 4.1 — Stage changes

- **Action**: `git add -A`
- **Verify**: `git diff --cached --stat` shows 4 files

### Task 4.2 — Commit

- **Action**: `git commit`
- **Message**: `feat(shell-gpt): add nvidia NIM-powered command assistant`
- **Body**: Brief one-liner describing the module and hosts

---

## Spec Gap Notes

The spec (requirement 1, scenario "Module enabled on rog") lists two additional
`sessionVariables` that the module code in this change does not set:

| Variable | In spec? | In module code? |
|----------|----------|-----------------|
| `SHELL_INTERACTION = "true"` | Yes | No |
| `DEFAULT_EXECUTE_SHELL_CMD = "false"` | Yes | No |

**Decision**: The module code provided in the tasks phase includes only the three
essential env vars (`API_BASE_URL`, `OPENAI_API_KEY`, `DEFAULT_MODEL`). shell-gpt
defaults to `SHELL_INTERACTION=true` and `DEFAULT_EXECUTE_SHELL_CMD=false` at
runtime, so the omission has no behavioral effect. If explicit env var parity
with the spec is desired, add them to `home-linux/shell-gpt.nix` in a follow-up.

---

## Rollback Plan

1. `home.shell-gpt.enable = false` — removes package and env vars instantly
2. `nixos-build dry` before switching to verify
3. Remove `./shell-gpt.nix` import lines from all 3 host files
4. Delete `home-linux/shell-gpt.nix`
5. No custom code to delete; no new secrets to clean up

## Success Criteria (from spec)

1. `nix flake check --no-build` passes with module imported
2. `nixos-build dry` succeeds on rog with `home.shell-gpt.enable = true`
3. `sgpt --shell "list files sorted by size"` works with nvidia NIM
4. Confirmation prompt appears before execution
5. `home.shell-gpt.enable = false` cleanly disables
