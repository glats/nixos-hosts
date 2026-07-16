# Tasks: Unify Review Gate (OpenCode + Claude Code)

**Change name**: `unificar-review-gate-opencode-claude-code`
**Net change**: ~30 lines, 4 files (1 create, 3 edit)

---

## 1. Setup

### 1.1 Confirm current git state

- Check `git status` — working tree clean
- Check `git log --oneline -3` — know current HEAD
- **Verification**: Clean working tree, known commit

### 1.2 Confirm assets directory does not exist

- `ls shared/assets` — should return "No such file or directory"
- **Verification**: `shared/assets/` absent, ready for creation

---

## 2. Implement

### 2.1 Create `shared/assets/review-gate.md`

- Write the platform-agnostic review gate content from the [design doc](design.md#L55-L75)
- Content is the exact text from lines 410-429 of `shared/opencode/assets/opencode/review-gate.md`, with one change: `"via the \`question\` tool"` → `"via an interactive prompt"`
- **Verification**: File exists, contains exactly `done`, `retry`, `reiterate` as three options, no `question` tool reference, no OpenCode/Claude-specific tool names

### 2.2 Edit `lib/packages.nix` — add `extraAssetsShared`

- Add `extraAssetsShared = ./../shared/assets;` to the `sharedOpencodePaths` attrset
- Add `extraAssetsShared` to the `inherit` call in both the linux and darwin `gentle-ai-assets` callPackage sites
- **Verification**: `git diff lib/packages.nix` shows ~3 lines added (1 attr, 2 inherits)

### 2.3 Edit `pkgs/gentle-ai-assets/default.nix` — add parameter + copy

- Add `extraAssetsShared ? null` to the function parameters
- Add a new installPhase block (using `optionalString`) to copy `extraAssetsShared/*` into `$TEMP_DIR/`, matching the existing `extraAssets` pattern
- **Verification**: `git diff pkgs/gentle-ai-assets/default.nix` shows parameter + copy block

### 2.4 Edit `shared/claude-code.nix` — change derivation source path

- Change source path on line 153 from:
  ```
  source = "${pkgs.gentle-ai-assets}/share/gentle-ai/claude/sdd-orchestrator.md";
  ```
  to:
  ```
  source = "${pkgs.gentle-ai-assets}/share/gentle-ai/review-gate.md";
  ```
- **Verification**: `git diff shared/claude-code.nix` shows only line 153 changed (path segment only), no other edits

---

## 3. Verify

### 3.1 Format and lint

- Run `format-nix` (formats all changed files)
- Run `nix flake check --no-build` — must exit 0
- **Verification**: No errors from either command

### 3.2 No regression: OpenCode untouched

- `git diff shared/opencode.nix` — zero changes (RG-003)
- `git diff shared/opencode/` — zero changes (RG-003)
- **Verification**: Both diffs empty

### 3.3 Build test

- Run `nix build .#gentle-ai-assets` (or the platform-specific variant, e.g. `.#gentle-ai-assets-linux`) to verify derivation produces `review-gate.md` in the store
- Run `nix build .#nixosConfigurations.t14.config.system.build.toplevel` — fastest host build to verify path resolves end-to-end (RG-005)
- **Verification**: Both builds succeed, confirming the derivation copy and the derivation path resolve correctly

### 3.4 Content verification

- Read `shared/assets/review-gate.md` — confirm:
  - Exactly 3 options: done, retry, reiterate (RG-002)
  - No `"question"` tool reference — uses `"interactive prompt"` instead (RG-002)
  - No platform-specific tool names (RG-002)
- **Verification**: Content passes all checks

---

## 4. Cleanup

### 4.1 Stage and commit

- `git add -A`
- Commit with conventional commit message, e.g.:
  ```
  feat(review-gate): unify review gate across OpenCode and Claude Code
  ```
- **Verification**: `git log --oneline -3` shows commit at HEAD

### 4.2 Archive reference

- Update `openspec/changes/unificar-review-gate-opencode-claude-code/archive.md` with implementation summary (if archive phase follows)
- **Verification**: Archive doc reflects what was done
