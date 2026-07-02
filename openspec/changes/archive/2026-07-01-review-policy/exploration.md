# Exploration: Global SDD Review Policy + Iteration Protocol

## Current State

The SDD review policy exists as `sdd-review-policy.md` in two projects:
- `/Users/jcuzmar/Work/backend/IFT-3501/.opencode/sdd-review-policy.md`
- `/Users/jcuzmar/Work/backend/REF-CREATE/.opencode/sdd-review-policy.md`

Both projects reference it via their `.opencode/opencode.json`:
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "/Users/jcuzmar/.config/opencode/AGENTS.md",
    "./sdd-review-policy.md"
  ]
}
```

The policy enforces: after every `sdd-apply` slice, stop for human review. There is no iteration protocol yet (the "when apply fails review, iterate from explore" behavior is currently undefined).

The global OpenCode config is managed by nix via `/Users/jcuzmar/.config/nix/shared/opencode.nix`. Its `instructions` field is:
```json
"instructions": ["SYSTEM_RULES.md"]
```

## Affected Areas

- `/Users/jcuzmar/.config/nix/shared/opencode.nix` (lines 72, 80-124) — generates opencode.json `instructions` and deploys files via `home.file` + activation script
- `/Users/jcuzmar/.config/opencode/opencode.json` — runtime config, nix-managed
- `/Users/jcuzmar/.config/opencode/SYSTEM_RULES.md` — global rules, nix-managed
- `/Users/jcuzmar/.config/opencode/AGENTS.md` — global skill index, nix-managed
- `/Users/jcuzmar/.config/opencode/sdd-orchestrator.md` — orchestrator instructions, nix-managed
- `/Users/jcuzmar/.config/opencode/skills/sdd-apply/SKILL.md` — executor for apply phase (no review gate logic currently)
- `/Users/jcuzmar/.config/opencode/skills/_shared/sdd-phase-common.md` — shared phase protocol (no iteration protocol)
- `/Users/jcuzmar/.config/opencode/skills/_shared/sdd-status-contract.md` — status schema (no review-checkpoint field)
- IFT-3501 and REF-CREATE `.opencode/` directories — current consumers of the policy

---

## Config Resolution: How OpenCode Resolves `opencode.json`

### Mechanism

OpenCode resolves config from multiple locations in precedence order (confirmed via docs at opencode.ai/docs/config/):

1. **Remote config** (`.well-known/opencode`) — organizational defaults
2. **Global config** (`~/.config/opencode/opencode.json`) — user preferences
3. **Custom config** (`OPENCODE_CONFIG` env var) — custom overrides
4. **Project config** (`opencode.json` in project root, or `.opencode/opencode.json`) — project-specific
5. **`.opencode` directories** — agents, commands, plugins
6. **Inline config** (`OPENCODE_CONFIG_CONTENT`) — runtime overrides
7. **Managed config files** (e.g., `/Library/Application Support/opencode/` on macOS)
8. **macOS managed preferences** (`.mobileconfig` via MDM)

### Merge or Replace?

**Confirmed via `opencode debug config` output from within IFT-3501:**

The resolved `instructions` array is:
```json
[
    "SYSTEM_RULES.md",                        // from GLOBAL ~/.config/opencode/opencode.json
    "/Users/jcuzmar/.config/opencode/AGENTS.md",  // from PROJECT .opencode/opencode.json
    "./sdd-review-policy.md"                     // from PROJECT .opencode/opencode.json
]
```

**Verdict: ARRAYS ARE MERGED (CONCATENATED)**. The OpenCode docs state: "Configuration files are merged together, not replaced. Later configs override earlier ones only for conflicting keys." For the `instructions` array, this means concatenation, not replacement. Global instructions appear first, project instructions second.

Additional note: AGENTS.md files (project-level and global) are ALSO loaded separately by OpenCode's rules mechanism (see `/docs/rules/`), independent of the `instructions` array. The project's explicit reference to AGENTS.md is redundant but harmless.


## Location Analysis

### Location 1: `~/.config/opencode/sdd-review-policy.md` (global, manual)

**How it works**: Place the policy file in `~/.config/opencode/` alongside SYSTEM_RULES.md and AGENTS.md. Since `instructions` arrays merge, if the nix-managed opencode.json has `instructions: ["SYSTEM_RULES.md"]`, OpenCode would need to also find `sdd-review-policy.md`. This requires EITHER:
- Adding it to the nix-managed `instructions` array, OR
- Adding it via another config layer (e.g., project-level)

**Survival**: The policy FILE would survive nix rebuilds — the activation script only touches files in its explicit list (`opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md package.json .gitignore tui.json`). A file named `sdd-review-policy.md` is NOT in that list, so it would not be overwritten. However, the REFERENCE to it in `opencode.json` would NOT survive — each rebuild replaces `opencode.json` with the nix-managed version which only has `instructions: ["SYSTEM_RULES.md"]`.

**Scope**: All projects on this machine, since the global instructions array feeds into all OpenCode sessions regardless of project.

**Opt-out**: Projects CANNOT opt out of global instructions — they are always concatenated. The only opt-out would be to not run OpenCode on this machine.

**Maintenance**: Manual — edit the file directly in `~/.config/opencode/`. Survives nix rebuilds for the FILE content but NOT for the reference in opencode.json (which is reset each rebuild).

**Risks**:
- The reference in opencode.json is lost on every nix rebuild since the nix-managed JSON replaces it
- File could be accidentally deleted (no nix protection)
- No version control (unless manually added to a repo)
- Confusion about why the policy "disappears" after a rebuild (the file is there, but not referenced)


### Location 2: `~/.config/opencode/sdd-review-policy.md` (global, via nix)

**How it works**: Modify `/Users/jcuzmar/.config/nix/shared/opencode.nix` to:
1. Add a `home.file` entry for `sdd-review-policy.md` (similar to SYSTEM_RULES.md at line 89-92)
2. Add `"sdd-review-policy.md"` to the `instructions` array at line 72
3. Add `"sdd-review-policy.md"` to the activation script's file list at line 143

The file would be deployed from the nix store as a real copy (via the activation script's symlink-to-copy conversion), and survive all rebuilds.

**Survival**: Full survival. On each rebuild: (a) home.file creates a symlink to the nix store, (b) activation script converts to real copy, (c) `opencode.json` always includes the reference. The file content is versioned in the nixos-hosts repo.

**Scope**: All hosts that import `shared/opencode.nix` — currently: t14 (via omarchy.nix), mact2 (via home-darwin/shared-modules.nix), and presumably rog/thinkcentre. Any host that enables `home.opencode.enable = true` gets the policy. Different hosts could hypothetically have different policy files if configured per-host, but the shared module applies to all.

**Opt-out**: Projects cannot opt out of global instructions. All projects on all hosts that run OpenCode via this nix config would get the policy. The only way to "opt out" a specific host would be to not import the shared opencode module (but this would also remove SYSTEM_RULES.md, AGENTS.md, agent config, etc.).

**Maintenance**: Edit the policy file in the nixos-hosts repo, rebuild. The file can live at `shared/opencode/sdd-review-policy.md` (alongside SYSTEM_RULES.md and IDENTITY.md which are already there). Changes require `nixos-rebuild switch` or `home-manager switch` to deploy.

**Risks**:
- Every rebuild triggers the full nix pipeline (evaluation, store path change is minimal for a text file)
- No per-project opt-out mechanism
- All hosts get the same policy (might not want review gates on non-dev hosts like thinkcentre)
- If the nix build fails, opencode.json could be in an inconsistent state


### Location 3: Per-project `.opencode/sdd-review-policy.md` (already in use)

**How it works**: Each project has its own `.opencode/opencode.json` that lists `./sdd-review-policy.md` in `instructions`. This is the current mechanism for IFT-3501 and REF-CREATE. Since instructions merge, the project's policy is added AFTER the global `SYSTEM_RULES.md`.

**Survival**: Not applicable — this is per-project, not global. Survives as long as the project's `.opencode/` directory exists.

**Scope**: Only projects that explicitly add the file and reference it. New projects need to be bootstrapped.

**Opt-out**: Natural — projects that don't have the file simply don't get the policy. Projects that have it could remove the reference or delete the file.

**Maintenance**: Manual per-project. If the policy changes, every project's copy must be updated. This is the current pain point — the user wants this GLOBAL.

**Risks**:
- Drift between project copies
- Forgetting to add to new projects
- No enforcement — a project could accidentally delete the file


### Location 4: Embedded in orchestrator instructions (`sdd-orchestrator.md`)

**How it works**: The orchestrator instructions at `/Users/jcuzmar/.config/opencode/sdd-orchestrator.md` are loaded as the orchestrator's prompt. A new section could be added to describe the review gate + iteration protocol. The orchestrator coordinates all SDD phases, so it could enforce stopping after apply and requesting review before the next apply.

The orchestrator already coordinates phase transitions. Adding a review gate would mean: after `sdd-apply` returns, check for a review checkpoint. If missing or not approved, do not launch the next apply. For the iteration protocol: when apply fails review, the orchestrator would re-launch `sdd-explore` for the change, which upserts via topic_key (overwriting previous exploration), then continues through propose/spec/design/tasks/apply.

**Survival**: Full survival — `sdd-orchestrator.md` is nix-managed via:
```nix
".config/${runtimeCfg.dir}/sdd-orchestrator.md" = {
  force = true;
  source = "${pkgs.gentle-ai-assets}/share/gentle-ai/opencode/sdd-orchestrator.md";
};
```
Wait — this file comes from `gentle-ai-assets`, which is the "DO NOT TOUCH" layer. The orchestrator prompt in `opencode.json` is `{file:./AGENTS.md}`, which DOES load orchestrator instructions from the nix-managed AGENTS.md. So the actual orchestrator instructions live in `~/.config/opencode/AGENTS.md` (which comes from `pkgs.gentle-ai-assets`), and the orchestrator's main instruction file is `~/.config/opencode/sdd-orchestrator.md` (also from gentle-ai-assets).

Both are in the "layer 2" (DO NOT TOUCH) category. However, the `instructions` array in `opencode.json` could reference additional files.

**BUT**: The user said "NO TOCAR Gentle AI skills (layer 2: `~/.config/opencode/skills/sdd-*/`)". The `sdd-orchestrator.md` file is also from gentle-ai-assets. Modifying it risks breaking on upstream updates.

**Survival**: If modified in-place in `~/.config/opencode/`, it would be overwritten on each rebuild (it's in the activation script's file list). To modify it via nix, you'd need to change the source path or overlay it. The `gentle-ai-assets` package is an external input — modifications there would conflict with upstream updates.

**Scope**: All OpenCode sessions on all hosts (the orchestrator runs everywhere).

**Opt-out**: If embedded in the orchestrator itself, projects cannot opt out without disabling the orchestrator entirely.

**Maintenance**: Would need to either (a) modify gentle-ai-assets (undesirable), (b) overlay the file via nix (complex), or (c) find another injection point.

**Risks**:
- Modifying gentle-ai-assets files breaks the "DO NOT TOUCH" contract
- Upstream updates to sdd-orchestrator.md would overwrite local changes
- The orchestrator file is ~32KB and tightly coupled to the SDD skill set


### Location 5: As part of AGENTS.md

**How it works**: The global `~/.config/opencode/AGENTS.md` is loaded by OpenCode for all sessions. Currently it is the skill index (trigger table). The policy could be appended as a new section, e.g., `## SDD Review Policy`.

The AGENTS.md is nix-managed via:
```nix
".config/${runtimeCfg.dir}/AGENTS.md" = {
  force = true;
  source = "${pkgs.gentle-ai-assets}/share/gentle-ai/AGENTS.md";
};
```
This also comes from `gentle-ai-assets` — the "DO NOT TOUCH" layer. However, the `instructions` field in `opencode.json` already loads this file: the orchestrator prompt is `{file:./AGENTS.md}`.

**BUT**: AGENTS.md is autoloaded by OpenCode's rules mechanism (separate from the `instructions` array). From the docs: "AGENTS.md files are combined with instruction files." So AGENTS.md would be in context for ALL agents, not just the orchestrator.

**Survival**: Same as Location 4 — nix-managed, but comes from gentle-ai-assets. Would be overwritten on rebuild if modified in-place.

**Scope**: All agents in all sessions — the AGENTS.md is global context.

**Opt-out**: None — global AGENTS.md is always loaded.

**Maintenance**: Same problem as Location 4 — the file comes from gentle-ai-assets. Would need a nix overlay or a separate instruction file.

**Risks**:
- AGENTS.md is loaded for ALL agents (explore, apply, etc.), bloating every sub-agent's context
- The review policy is orchestrator-level logic, not relevant to executors
- Conflicts with "DO NOT TOUCH" constraint


### Location 6: OpenCode Plugin or MCP Server

**How it works**: OpenCode supports plugins (`.ts` files in `~/.config/opencode/plugins/`) and MCP servers. A plugin could hook into tool calls and enforce review gates. An MCP server could track review checkpoints.

The nix config already has plugin support via `home.opencode.plugins`:
```nix
managedPlugins = {
  "background-agents.ts" = { ... };
  "engram.ts" = { ... };
  "secret-guard.ts" = { ... };
};
```

**Survival**: If the plugin is added to the nix config (new entry in `managedPlugins`), it would survive rebuilds. The plugin file would be copied from the nix store and cmp-guarded against changes.

**Scope**: All OpenCode sessions. Could be configured per-host.

**Opt-out**: Could be toggled via nix option (`home.opencode.plugins.sddReviewGate.enable`).

**Maintenance**: Would need to write a TypeScript plugin using the OpenCode plugin SDK. The plugin would need access to the tool call lifecycle to intercept `sdd-apply` completions and enforce review gates.

**Risks**:
- Writing a plugin is significant dev work (new codebase, not just config)
- Plugin SDK API is not well-documented — would need reverse engineering
- The plugin runs in the OpenCode process; bugs could crash the TUI
- Overengineering — a simple instruction file could achieve the same result
- The iteration protocol (re-launch explore after failed review) requires orchestrator coordination, which a plugin cannot do — plugins observe/instrument, they don't control SDD phase transitions


### Location 7: Embedded in SDD Schema (`_shared/sdd-phase-common.md`)

**How it works**: The `_shared/sdd-phase-common.md` file is shared across ALL SDD phase executors. Adding iteration protocol here would make every executor aware of the review gate and re-exploration flow.

**BUT**: This file is in `~/.config/opencode/skills/_shared/` — part of the skill layer that the user said "NO TOCAR" (layer 2). Also, phase executors are NOT orchestrators — they should not be making phase-transition decisions. The orchestrator controls the flow.

**Survival**: Same as all skill files — nix-managed via the activation script's `skills/` directory sync. Modifications would be overwritten on rebuild.

**Scope**: All SDD phase executors (potentially bloating their context with policy they can't act on).

**Opt-out**: None — all executors get it.

**Maintenance**: Same "DO NOT TOUCH" problem.

**Risks**:
- Violates executor/orchestrator separation — executors should not make workflow decisions
- Bloat: every apply agent would load policy text it cannot act on
- Overwritten on skills update


### Location 8: NixOS Module Option

**How it works**: The existing nix code already has `home.opencode.*` options (enable, activeProviderName, disabledProviders, extraInitContent, agents, agentOverrides, permissions, plugins, tuiPlugins, extraMcps, mcps). A new option could be added:

```nix
options.home.opencode.extraInstructions = mkOption {
  type = types.listOf types.str;
  default = [];
  description = "Additional instruction files appended to the OpenCode instructions array.";
};
```

Then in `mkRuntimeConfig` (line 72), the instructions would be:
```nix
instructions = [ "SYSTEM_RULES.md" ] ++ cfg.extraInstructions;
```

And a corresponding `home.file` entry would deploy the instruction file(s) if they exist. The activation script's file list would need the new filename(s).

**Survival**: Full — this is the nix-native approach. The option would be set in `shared/opencode-profile.nix` (or per-host).

**Scope**: Configurable — default could be set in the shared profile, overridden per-host.

**Opt-out**: Natural — hosts that don't set the option don't get the extra instructions. Projects cannot opt out (global instructions always merge).

**Maintenance**: Add the file to `shared/opencode/`, add the option, wire it up. Changes require nix rebuild.

**Risks**:
- Adds complexity to the nix module
- Need to ensure the instruction file is deployed (home.file entry) AND referenced in opencode.json (instructions array)
- The activation script's file list at line 143 would need the filename added — otherwise the file would be a symlink (read-only from nix store) and OpenCode can't write to it (though for a policy file, write access may not be needed)


## Activation Script Deep Dive

### What the `makeOpencodeConfigMutable` activation script does:

1. **Symlink-to-copy conversion**: For files in the list (`opencode.json IDENTITY.md SYSTEM_RULES.md AGENTS.md sdd-orchestrator.md package.json .gitignore tui.json`), it checks if the target is a symlink. If yes, it resolves the link and copies the real file from the nix store. This converts read-only nix store symlinks to writable real files.

2. **Permissions fix**: Ensures all those files are writable (chmod 644).

3. **Directory sync for skills/ and commands/**: Copies files from the nix store with per-file cmp-guard (only copies if content differs), removes orphaned files (files in target that don't exist in source). This keeps skills/ and commands/ in sync with the nix store while preserving any local modifications (since cmp only overwrites if content differs).

4. **Skill patching**: Runs `sed` to remove a frontmatter compatibility marker from sdd-apply and sdd-verify skill files.

### Why symlink-to-copy?

The comment at line 127-128 explains: "NixOS symlink farm changes store paths on every rebuild; real copies avoid false 'config changed' signals that cause OpenCode to re-initialize." If `opencode.json` were a symlink to `/nix/store/xxx-hash-opencode.json`, every nix rebuild would create a new store path hash, and OpenCode would detect a config change and re-initialize. By making it a real copy, the file path stays stable and OpenCode only sees changes when content actually differs.

### Key implication for adding new files:

Any new file that needs to survive rebuilds must be:
1. Added to the `home.file` block (to get it into `~/.config/opencode/` initially)
2. Added to the activation script's file list at line 143 (to convert from symlink to real copy)
3. Optionally referenced in `opencode.json`'s `instructions` array (if it's an instruction file)


## Open Questions

1. **Array merge behavior for non-instructions fields**: The `instructions` array is confirmed to merge (concatenate). Are ALL arrays in opencode.json merged? Or do some replace? The docs say "keys" are merged, but array behavior might differ by key.

2. **Iteration protocol placement**: The iteration protocol ("when apply fails review, iterate from explore") is fundamentally orchestrator logic. Where should it live — in the instruction file (read by the orchestrator) or embedded in the orchestrator's existing prompt? If in the instruction file, the orchestrator reads it as context. If embedded in sdd-orchestrator.md, it becomes part of the DO-NOT-TOUCH layer.

3. **What triggers the iteration protocol?**: Currently there is no `review-checkpoint` artifact/topic in the SDD status schema. The orchestrator would need to know (a) that a review happened, (b) the verdict, and (c) whether to re-launch explore vs. continue apply. This requires either a new artifact convention or the orchestrator reading the review-checkpoint from engram/filesystem.

4. **Host differentiation**: Should ALL hosts get the review policy? The thinkcentre host is headless and may not need SDD review gates. The current nix config applies `shared/opencode.nix` to all hosts. Would this be undesirable for some hosts?

5. **Policy file content vs. reference**: Is the policy file content itself the primary artefact, or is it the INSTRUCTIONS array reference that matters? Both need to survive rebuilds for the policy to be effective.

6. **Existing orchestrator knowledge of review gates**: The orchestrator currently has NO knowledge of review gates. The `sdd-orchestrator.md` describes the SDD workflow as `proposal -> specs -> tasks -> apply -> verify -> archive` with no review checkpoints. Adding review gates would require updating the orchestrator's mental model of the workflow.

7. **Redundancy of explicit AGENTS.md in project instructions**: The IFT-3501 project explicitly references `"/Users/jcuzmar/.config/opencode/AGENTS.md"` in its instructions, but AGENTS.md is auto-loaded by OpenCode's rules mechanism. Is this intentional (belt-and-suspenders) or accidental (user wasn't sure how merging works)?
