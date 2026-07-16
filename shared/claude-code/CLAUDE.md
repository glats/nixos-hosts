# Universal Agent Rules (applies to all projects)

## Global Rules (ALWAYS FOLLOW)

### Code Language Policy - ENGLISH ONLY

**All code must ALWAYS be in English. NO EXCEPTIONS.**

- Variable names: englishOnly
- Function names: useEnglishCamelCase()
- Class names: EnglishPascalCase
- Comments: // Always in English
- Documentation: Written in English
- Commit messages: english format (feat:, fix:, docs:)
- Log messages: English text
- Error strings: "Error message in English"
- Configuration descriptions: English descriptions
- File names: use-english-names.md
- ANY text inside code: ENGLISH

**NO SPANISH IN CODE.**
**NO MIXED LANGUAGES.**
**NO EMOJIS IN CODE OR OUTPUT.**

Even if user writes "crear funcion", output: `function createUser()` not `function crearUsuario()`.

### No Emojis Policy

**NEVER use emojis.** Use text indicators only: "WARNING:", "INFO:", "ERROR:", "SUCCESS:".

## Operating Protocol

### Plan Before Act

Before any tool call, decide ALL files and resources you will need. Batch independent reads together in parallel.

### Respond to User

- Do NOT stop to ask clarifying questions about obvious things. Proactively gather context, plan, implement, and verify.
- If legitimately blocked, ask ONE question at a time, then STOP.
- Default to short answers. Do NOT present option menus or exhaustive lists unless there is a real fork.
- NEVER agree with user claims without verification. Check code/docs first.
- Never add "Co-Authored-By" or AI attribution to commits.
- Never build after changes.

### Research First

**NEVER guess.** Before stating a technical claim, research using MCP tools: github, context7, exa. If you think "it works like X", stop and verify.

### Verify Before Done

After every implementation task: verify the change solves the problem, run formatter if available, run tests if they exist, confirm no warnings.

## Secret Handling

**CRITICAL**: Never expose or mishandle sensitive credentials.

- Never execute `sops -d` or decrypt secrets
- Never read `/run/secrets/` or `~/.config/sops-nix/secrets/`
- Never expose env vars with API_KEY, SECRET, TOKEN, or PASSWORD
- To verify a secret exists, read the ENCRYPTED yaml file — do NOT decrypt it

## Delegation Rules

Core principle: **does this inflate my context without need?**

| Action | Inline | Delegate |
|--------|--------|----------|
| Read to decide/verify (1-3 files) | Yes | — |
| Read to explore (4+ files) | — | Yes via Agent |
| Write atomic (one file) | Yes | — |
| Write with analysis (multiple files) | — | Yes via Agent |
| Bash for state (git, gh) | Yes | — |
| Bash for execution (test, build) | — | Yes via Agent |

**Decision rule**: "will the output fit in < 50 lines and do I need it immediately?" Yes → inline. No → delegate.

## Skills

When you detect these contexts, load the skill BEFORE writing code:

| Context | Skill |
| ------- | ----- |
| Go tests, Bubbletea TUI testing | go-testing |
| Creating new AI skills | skill-creator |
| Editing `.nix` files | nix-verify |

Do NOT load nix-verify for non-Nix files.

## Engram Persistent Memory

Call `mem_save` PROACTIVELY after: decisions, bug fixes, discoveries, patterns, config changes. Self-check after EVERY task: "Did I make a decision, fix a bug, learn something non-obvious? If yes, call mem_save NOW."

Before ending a session, call `mem_session_summary`. This is NOT optional.
