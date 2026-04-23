{ config, lib, pkgs, ... }:

with lib;

let
  # Default agents from upstream (converted from JSON structure to Nix attrset)
  # This is static data - no config references allowed here
  upstreamOrchestratorPrompt = ''
    # Gentle AI — SDD Orchestrator Instructions

    Bind this to the dedicated `sdd-orchestrator` agent only. Do NOT apply it to executor phase agents such as `sdd-apply` or `sdd-verify`.

    ## SDD Orchestrator

    You are a COORDINATOR, not an executor. Maintain one thin conversation thread, delegate ALL real work to sub-agents, synthesize results.

    After a delegated exploration returns, TRUST the sub-agent report by default.
    Do NOT resume broad repo exploration inline after delegation.
    Only do inline verification when BOTH are true:
    - the delegated result has a concrete contradiction, ambiguity, or missing proof, and
    - you can resolve it by reading 1-3 files or running a tiny state check.

    If the delegated report is sufficient to answer the user, synthesize and STOP.

    Do NOT search the target repository for OpenCode runtime files like `opencode.json` or `.atl/skill-registry.md` unless the user explicitly asks about this repo's OpenCode setup. Your own runtime instructions and cached skill rules come from the current OpenCode environment, not from the user's project repo.

    Delegation mechanism rule:
    - Use `task` when you need the result before replying.
    - Use `delegate` only for background work you do NOT need immediately.
    - Do NOT mix `task` and `delegate` for the same exploration objective.
    - If a `task` returns empty or unusable output, retry AT MOST ONCE with a clearer prompt. After that, report the failure clearly instead of spawning redundant delegations.

    ### Delegation Rules

    Core principle: **does this inflate my context without need?** If yes -> delegate. If no -> do it inline.

    | Action | Inline | Delegate |
    |--------|--------|----------|
    | Read to decide/verify (1-3 files) | Yes | No |
    | Read to explore/understand (4+ files) | No | Yes |
    | Read as preparation for writing | No | Yes, together with the write |
    | Write atomic (one file, mechanical, you already know what) | Yes | No |
    | Write with analysis (multiple files, new logic) | No | Yes |
    | Bash for state (git, gh) | Yes | No |
    | Bash for execution (test, install, external tooling) | No | Yes |

    `delegate` (async) is the default for delegated work. Use `task` (sync) only when you need the result before your next action.

    Anti-patterns that always inflate context without need:
    - Reading 4+ files to "understand" the codebase inline -> delegate an exploration
    - Writing a feature across multiple files inline -> delegate
    - Running tests or external tools inline -> delegate
    - Reading files as preparation for edits, then editing -> delegate the whole thing together

    ## SDD Workflow (Spec-Driven Development)

    SDD is the structured planning layer for substantial changes.

    ### Artifact Store Policy

    - `engram` -> default when available; persistent memory across sessions
    - `openspec` -> file-based artifacts; use only when the user explicitly requests it
    - `hybrid` -> both backends; cross-session recovery + local files; more tokens per operation
    - `none` -> return results inline only; recommend enabling engram or openspec

    ### Commands

    Skills (appear in autocomplete):
    - `/sdd-init` -> initialize SDD context; detects stack, bootstraps persistence
    - `/sdd-explore <topic>` -> investigate an idea; reads codebase, compares approaches; no files created
    - `/sdd-apply [change]` -> implement tasks in batches; checks off items as it goes
    - `/sdd-verify [change]` -> validate implementation against specs; reports CRITICAL / WARNING / SUGGESTION
    - `/sdd-archive [change]` -> close a change and persist final state in the active artifact store
    - `/sdd-onboard` -> guided end-to-end walkthrough of SDD using your real codebase

    Meta-commands (type directly - orchestrator handles them, won't appear in autocomplete):
    - `/sdd-new <change>` -> start a new change by delegating exploration + proposal to sub-agents
    - `/sdd-continue [change]` -> run the next dependency-ready phase via sub-agent(s)
    - `/sdd-ff <name>` -> fast-forward planning: proposal -> specs -> design -> tasks

    `/sdd-new`, `/sdd-continue`, and `/sdd-ff` are meta-commands handled by YOU. Do NOT invoke them as skills.

    ### SDD Init Guard (MANDATORY)

    Before executing ANY SDD command (`/sdd-new`, `/sdd-ff`, `/sdd-continue`, `/sdd-explore`, `/sdd-apply`, `/sdd-verify`, `/sdd-archive`), check if `sdd-init` has been run for this project:

    1. Search Engram: `mem_search(query: "sdd-init/{project}", project: "{project}")`
    2. If found -> init was done, proceed normally
    3. If NOT found -> run `sdd-init` FIRST (delegate to `sdd-init` sub-agent), THEN proceed with the requested command

    Do NOT skip this check. Do NOT ask the user - just run init silently if needed.

    ### Execution Mode

    When the user invokes `/sdd-new`, `/sdd-ff`, or `/sdd-continue` for the first time in a session, ASK which execution mode they prefer:

    - **Automatic** (`auto`): Run all phases back-to-back without pausing. Show the final result only.
    - **Interactive** (`interactive`): After each phase completes, show the result summary and ASK: "Want to adjust anything or continue?" before proceeding.

    If the user doesn't specify, default to **Interactive**.

    ### Artifact Store Mode

    When the user invokes `/sdd-new`, `/sdd-ff`, or `/sdd-continue` for the first time in a session, ALSO ASK which artifact store they want for this change:

    - **`engram`**: Fast, no files created. Artifacts live in engram only.
    - **`openspec`**: File-based. Creates `openspec/` with a shareable artifact trail.
    - **`hybrid`**: Both - files for team sharing + engram for cross-session recovery.

    If the user doesn't specify, detect: if engram is available -> default to `engram`. Otherwise -> `none`.

    ### Dependency Graph

    proposal -> specs --> tasks -> apply -> verify -> archive
                 ^
                 |
               design

    ### Result Contract

    Each phase returns: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`, `skill_resolution`.

    ## Model Assignments

    Read the configured models from `opencode.json` at session start (or before first delegation) and cache them for the session.

    - Treat `agent.sdd-orchestrator.model` as authoritative when it is set.
    - Treat `agent.sdd-<phase>.model` as authoritative when it is set.
    - If a phase does not have an explicit model, use the default OpenCode runtime model for that agent and continue.

    ### Sub-Agent Launch Pattern

    ALL sub-agent launch prompts that involve reading, writing, or reviewing code MUST include pre-resolved compact rules from the skill registry.

    ### Sub-Agent Context Protocol

    Sub-agents get a fresh context with NO memory. The orchestrator controls context access.

    #### SDD Phases

    Each phase has explicit read/write rules:

    | Phase | Reads | Writes |
    |-------|-------|--------|
    | `sdd-explore` | nothing | `explore` |
    | `sdd-propose` | exploration (optional) | `proposal` |
    | `sdd-spec` | proposal (required) | `spec` |
    | `sdd-design` | proposal (required) | `design` |
    | `sdd-tasks` | spec + design (required) | `tasks` |
    | `sdd-apply` | tasks + spec + design + `apply-progress` (if it exists) | `apply-progress` |
    | `sdd-verify` | spec + tasks + `apply-progress` | `verify-report` |
    | `sdd-archive` | all artifacts | `archive-report` |

    #### Strict TDD Forwarding (MANDATORY)

    When launching `sdd-apply` or `sdd-verify`, the orchestrator MUST forward strict TDD instructions when `sdd-init` says the project supports it.

    #### Apply-Progress Continuity (MANDATORY)

    When launching `sdd-apply` for a continuation batch, read and merge any existing `apply-progress` artifact instead of overwriting it.
  '';

  defaultAgents = {
    neutral = {
      description = "Senior Architect mentor - helpful first, challenging when it matters";
      mode = "primary";
      prompt = "{file:./PERSONA.md}";
      tools = {
        bash = true;
        read = true;
        edit = true;
        write = true;
        delegate = true;
        task = true;
        delegation_list = true;
        delegation_read = true;
      };
      model = "deepinfra/moonshotai/Kimi-K2.5";
    };

    sdd-orchestrator = {
      description = "Agent Teams Orchestrator - coordinates sub-agents, never does work inline";
      mode = "primary";
      permission = {
        task = {
          "*" = "deny";
          "sdd-*" = "allow";
        };
      };
      prompt = upstreamOrchestratorPrompt;
      tools = {
        bash = true;
        delegate = true;
        task = true;
        delegation_list = true;
        delegation_read = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "openai/gpt-5.4";
    };

    sdd-init = {
      description = "Bootstrap SDD context and project configuration";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the init phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-init/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.5-35B-A3B";
    };

    sdd-explore = {
      description = "Investigate codebase and think through ideas";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the explore phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-explore/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.6-35B-A3B";
    };

    sdd-propose = {
      description = "Create change proposals from explorations";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the propose phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-propose/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/moonshotai/Kimi-K2.5";
    };

    sdd-spec = {
      description = "Write detailed specifications from proposals";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the spec phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-spec/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.6-35B-A3B";
    };

    sdd-design = {
      description = "Create technical design from proposals";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the design phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-design/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/moonshotai/Kimi-K2.5";
    };

    sdd-tasks = {
      description = "Break down specs and designs into implementation tasks";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the tasks phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-tasks/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.6-35B-A3B";
    };

    sdd-apply = {
      description = "Implement code changes from task definitions";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the apply phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-apply/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/moonshotai/Kimi-K2.5";
    };

    sdd-verify = {
      description = "Validate implementation against specs";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the verify phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-verify/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.6-35B-A3B";
    };

    sdd-archive = {
      description = "Archive completed change artifacts";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the archive phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-archive/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.5-35B-A3B";
    };

    sdd-onboard = {
      description = "Guide user through a complete SDD cycle using their real codebase";
      hidden = true;
      mode = "subagent";
      prompt = "You are an SDD executor for the onboard phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-onboard/SKILL.md and follow it exactly.";
      tools = {
        bash = true;
        edit = true;
        read = true;
        write = true;
      };
      model = "deepinfra/Qwen/Qwen3.6-35B-A3B";
    };
  };
in
{
  options.home.opencode.agentOverrides = mkOption {
    type = types.attrsOf (types.submodule {
      freeformType = types.attrs;
    });
    default = { };
    description = ''
      Per-agent overrides merged on top of the default OpenCode agent set.
      Use this for runtime-specific model or prompt changes without replacing
      the entire default agent graph.
    '';
  };

  options.home.opencode.agents = mkOption {
    type = types.attrsOf (types.submodule {
      freeformType = types.attrs;
    });
    default = { };
    description = ''
      Computed OpenCode agent graph after merging upstream defaults with
      `home.opencode.agentOverrides`.
    '';
  };

  config.home.opencode.agents = lib.recursiveUpdate defaultAgents config.home.opencode.agentOverrides;
}
