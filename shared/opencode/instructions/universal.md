## Skills (Auto-load based on context)

When you detect any of these contexts, IMMEDIATELY load the corresponding skill BEFORE writing any code.

| Context | Skill to load |
| ------- | ------------- |
| Go tests, Bubbletea TUI testing | go-testing |
| Creating new AI skills | skill-creator |
| Editing `.nix` files only (packages, services, options, lib functions within .nix) | nix-verify |

**Do NOT load nix-verify for non-Nix files** (JSON, YAML, TOML, Markdown, etc.) even if they
live inside this NixOS repository. The skill is exclusively for verifying Nix language constructs.

Load skills BEFORE writing code. Apply ALL patterns. Multiple skills can apply simultaneously.

## SDD Review Gate

After `sdd-apply` completes, the review gate ALWAYS presents exactly 3 options:

1. **done**      — proceed to verify, then archive
2. **retry**     — re-apply the same tasks (quick fix loop)
3. **reiterate** — re-explore everything from scratch (direction change)

No other options. No "proceed", no "redo", no custom branches. These 3 only.
