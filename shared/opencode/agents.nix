{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  # Import centralized provider configuration
  providersConfig = import ./providers.nix { inherit lib; };

  # Project context injected into all SDD sub-agent prompts
  # Prevents path hallucination (e.g. /home/gl1ats/ instead of /home/glats/)
  # and ensures agents know the correct working directory
  projectContext = ''
    ENVIRONMENT: User home is ${config.home.homeDirectory}. Username is ${config.home.username}.
    All file paths MUST use this home directory. NEVER guess or hallucinate paths.'';

  # Generate SDD sub-agent prompt with project context
  mkSddPrompt = phase: ''
    You are an SDD executor for the ${phase} phase, not the orchestrator. Do this phase's work yourself. Do NOT delegate, Do NOT call task/delegate, and Do NOT launch sub-agents. Read your skill file at ~/.config/opencode/skills/sdd-${phase}/SKILL.md and follow it exactly.

    ${projectContext}

    {file:./SYSTEM_RULES.md}'';

  # Import orchestrator prompt from extracted file
  upstreamOrchestratorPrompt = import ./orchestrator-prompt.nix { inherit config; };

  # Get model for a specific phase from a provider entry
  getModelForPhase = phase: provider: provider.phases.${phase} or null;

  # Get all SDD phase names
  sddPhases = [
    "sdd-init"
    "sdd-explore"
    "sdd-propose"
    "sdd-spec"
    "sdd-design"
    "sdd-tasks"
    "sdd-apply"
    "sdd-verify"
    "sdd-archive"
    "sdd-onboard"
  ];

  # Build agent models attrset from providers
  # Uses active provider's models (set in providers.nix)
  agentModels =
    let
      active = providersConfig.activeProvider;
    in
    if active != null then
      builtins.mapAttrs (phase: _: getModelForPhase phase active) (
        builtins.listToAttrs (
          map (p: {
            name = p;
            value = null;
          }) sddPhases
        )
      )
    else
      { };

  # Final models - sourced exclusively from providers.nix
  # If no provider is active, returns empty set (build will fail with clear error)
  models =
    if providersConfig.activeProvider != null then
      agentModels
      // {
        neutral = getModelForPhase "neutral" providersConfig.activeProvider;
        gentle-orchestrator = getModelForPhase "gentle-orchestrator" providersConfig.activeProvider;
      }
    else
      # No active provider - this is an error condition
      # Check activeProviderName in providers.nix
      throw "No active provider found. Check activeProviderName in modules/home/opencode/providers.nix";

  # Standard SDD sub-agent toolset (shared by all 10 sub-agents)
  sddToolset = {
    bash = true;
    edit = true;
    read = true;
    write = true;
    mem_search = true;
    mem_save = true;
    mem_get_observation = true;
  };

  # Generate an SDD sub-agent from a phase + description.
  # Optional promptSuffix for phases that need extra prompt text.
  # Optional maxSteps for phases with step budgets.
  mkSddAgent =
    {
      phase,
      description,
      promptSuffix ? "",
      maxSteps ? null,
    }:
    {
      inherit description;
      hidden = true;
      mode = "subagent";
      prompt = mkSddPrompt phase + promptSuffix;
      tools = sddToolset;
      model = models.${"sdd-" + phase};
    }
    // lib.optionalAttrs (maxSteps != null) { inherit maxSteps; };

  # sdd-explore's prompt suffix: enforces a strict step budget
  sddExploreSuffix = "\n\nCRITICAL: You have a limited step budget. Be EFFICIENT with reads:\n- Use Grep/Glob to FIND relevant files first, then read ONLY the specific sections you need\n- NEVER read entire large files (200+ lines) — use offset/limit parameters to read targeted sections\n- If a file is long, read the first 50 lines to understand structure, then use Grep for specifics\n- Prioritize breadth (scan many files) over depth (reading whole files)";

  # The 10 SDD sub-agents, generated via mkSddAgent
  sddAgents = {
    sdd-init = mkSddAgent {
      phase = "init";
      description = "Bootstrap SDD context and project configuration";
    };
    sdd-explore = mkSddAgent {
      phase = "explore";
      description = "Investigate codebase and think through ideas";
      maxSteps = 15;
      promptSuffix = sddExploreSuffix;
    };
    sdd-propose = mkSddAgent {
      phase = "propose";
      description = "Create change proposals from explorations";
    };
    sdd-spec = mkSddAgent {
      phase = "spec";
      description = "Write detailed specifications from proposals";
    };
    sdd-design = mkSddAgent {
      phase = "design";
      description = "Create technical design from proposals";
    };
    sdd-tasks = mkSddAgent {
      phase = "tasks";
      description = "Break down specs and designs into implementation tasks";
    };
    sdd-apply = mkSddAgent {
      phase = "apply";
      description = "Implement code changes from task definitions";
    };
    sdd-verify = mkSddAgent {
      phase = "verify";
      description = "Validate implementation against specs";
    };
    sdd-archive = mkSddAgent {
      phase = "archive";
      description = "Archive completed change artifacts";
    };
    sdd-onboard = mkSddAgent {
      phase = "onboard";
      description = "Guide user through a complete SDD cycle using their real codebase";
    };
  };
in
{
  options.home.opencode.agentOverrides = mkOption {
    type = types.attrsOf (
      types.submodule {
        freeformType = types.attrs;
      }
    );
    default = { };
    description = ''
      Per-agent overrides merged on top of the default OpenCode agent set.
      Use this for runtime-specific model or prompt changes without replacing
      the entire default agent graph.
    '';
  };

  options.home.opencode.agents = mkOption {
    type = types.attrsOf (
      types.submodule {
        freeformType = types.attrs;
      }
    );
    default = { };
    description = ''
      Computed OpenCode agent graph after merging upstream defaults with
      `home.opencode.agentOverrides`.
    '';
  };

  config.home.opencode.agents =
    let
      manualAgents = {
        neutral = {
          description = "Senior Architect mentor - helpful first, challenging when it matters";
          mode = "primary";
          prompt = "{file:./IDENTITY.md}\n\n{file:./SYSTEM_RULES.md}\n\n{file:./CAVEMAN_RULES.md}";
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
          model = models.neutral;
        };

        gentle-orchestrator = {
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
            mem_search = true;
            mem_save = true;
            mem_get_observation = true;
          };
          model = models.gentle-orchestrator;
        };
      };
    in
    lib.recursiveUpdate (manualAgents // sddAgents) config.home.opencode.agentOverrides;
}
