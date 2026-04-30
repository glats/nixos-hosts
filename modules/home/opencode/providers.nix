# =============================================================================
# OPENCODE PROVIDER CONFIGURATION
# =============================================================================
#
# To switch providers:
#   1. Change activeProviderName below to the provider you want to use
#   2. All 3 blocks below are valid Nix code - just pick one
#
# Example:
#   activeProviderName = "github-copilot";
#   activeProviderName = "github-copilot-student";
#
# =============================================================================

{ lib ? throw "providers.nix must be imported with lib"
}:

let
  # CHANGE ACTIVE PROVIDER HERE
  activeProviderName = "opencode-go";

  # All 3 providers (all valid Nix - pick via activeProviderName)
  providers = [
    # =========================================================================
    # BLOCK 1: opencode-go (DEFAULT)
    # =========================================================================
    {
      name = "opencode-go";
      phases = {
        sdd-orchestrator = "opencode-go/kimi-k2.5";
        sdd-init = "opencode-go/minimax-m2.7";
        sdd-explore = "opencode-go/deepseek-v4-flash";
        sdd-propose = "opencode-go/kimi-k2.5";
        sdd-spec = "opencode-go/qwen3.6-plus";
        sdd-design = "opencode-go/glm-5.1";
        sdd-tasks = "opencode-go/deepseek-v4-pro";
        sdd-apply = "opencode-go/minimax-m2.7";
        sdd-verify = "opencode-go/glm-5.1";
        sdd-archive = "opencode-go/mimo-v2.5-pro";
        sdd-onboard = "opencode-go/mimo-v2.5-pro";
        neutral = "opencode-go/kimi-k2.5";
      };
    }

    # =========================================================================
    # BLOCK 2: github-copilot (MODELOS CLAUDE)
    # =========================================================================
    {
      name = "github-copilot";
      phases = {
        sdd-orchestrator = "github-copilot/claude-sonnet-4.6";
        sdd-init = "github-copilot/claude-sonnet-4.6";
        sdd-explore = "github-copilot/claude-sonnet-4.6";
        sdd-propose = "github-copilot/claude-opus-4.6";
        sdd-spec = "github-copilot/claude-sonnet-4.6";
        sdd-design = "github-copilot/claude-sonnet-4.6";
        sdd-tasks = "github-copilot/claude-sonnet-4.6";
        sdd-apply = "github-copilot/claude-sonnet-4.6";
        sdd-verify = "github-copilot/claude-sonnet-4.6";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/claude-sonnet-4.6";
        neutral = "github-copilot/claude-sonnet-4.6";
      };
    }

    # =========================================================================
    # BLOCK 3: github-copilot-student
    # =========================================================================
    {
      name = "github-copilot-student";
      phases = {
        sdd-orchestrator = "github-copilot/gpt-4.1";
        sdd-init = "github-copilot/claude-haiku-4.5";
        sdd-explore = "github-copilot/gemini-3.1-pro-preview";
        sdd-propose = "github-copilot/gpt-4.1";
        sdd-spec = "github-copilot/gpt-4.1";
        sdd-design = "github-copilot/gpt-4.1";
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        sdd-apply = "github-copilot/gemini-3.1-pro-preview";
        sdd-verify = "github-copilot/gemini-3.1-pro-preview";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/gpt-4.1";
        neutral = "github-copilot/gpt-4.1";
      };
    }
  ];

  # Find the active provider by name
  activeProvider = builtins.foldl' (acc: p: if p.name == activeProviderName then p else acc) null providers;

in
{
  inherit providers activeProviderName activeProvider;

  # Helper: get model for a phase
  getModelForPhase = phase: provider:
    if provider == null then null
    else provider.phases.${phase} or null;
}
