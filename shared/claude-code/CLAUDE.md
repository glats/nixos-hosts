# Universal Agent Rules

## Code Language Policy — ENGLISH ONLY

**All code ALWAYS in English. NO EXCEPTIONS.**

Variable names, functions, classes, comments, docs, commits, logs, errors, config, file names — everything in English. No Spanish in code. No mixed languages.

Even if user writes "crear funcion", output `function createUser()` not `function crearUsuario()`.

## No Emojis

**NEVER use emojis** in code, output, docs, comments, file names, commits, or responses. Use text: "WARNING:", "INFO:", "ERROR:", "SUCCESS:".

## Operating Protocol

### Plan Before Act

Decide ALL files needed before making calls. Batch independent reads in parallel.

### Respond to User

- Don't ask clarifying questions about obvious things. Gather context and act.
- If blocked, ask ONE question, then stop.
- Short answers. No option menus unless there's a real fork.
- Never agree without verifying. Check code/docs first.
- If user is wrong, explain with evidence. If you're wrong, acknowledge.
- Never add AI attribution to commits. Use conventional commits only.

### Research First

**NEVER guess.** Before any technical claim, verify via available tools (web search, docs, code search). If you think "it works like X", stop and verify.

### Verify Before Done

After every implementation: verify the change solves the problem, run formatter if available, run tests if they exist, confirm no warnings.

## Delegation Rules

Core principle: **does this inflate my context without need?**

| Action | Inline | Delegate |
|--------|--------|----------|
| Read 1-3 files to decide | Yes | — |
| Read 4+ files to explore | — | Yes |
| Write one file | Yes | — |
| Write multiple files / new logic | — | Yes |
| Bash for state (git, gh) | Yes | — |
| Bash for execution (test, build) | — | Yes |

Rule of thumb: "will the output fit in under 50 lines and do I need it now?" Yes → inline. No → delegate.

## Secret Handling

Never expose credentials. Don't decrypt secrets. Don't read secret files directly. Don't echo env vars with API_KEY, SECRET, TOKEN, or PASSWORD. To verify a secret exists, read the encrypted file — don't decrypt it.

## Engram Persistent Memory

Call `mem_save` after every: decision, bug fix, discovery, convention, or config change. Self-check after each task: "Did I decide, fix, or learn something worth remembering?"

Before ending a session, call `mem_session_summary`. Not optional.
