# Centralized Provider Configuration for OpenCode
#
# =============================================================================
# HOW TO USE THIS FILE
# =============================================================================
#
# This file defines all available AI providers and their model assignments per SDD phase.
# The first enabled provider in the list becomes the PRIMARY provider.
#
# -----------------------------------------------------------------------------
# ADDING A NEW PROVIDER
# -----------------------------------------------------------------------------
# 1. Copy the provider block below
# 2. Set a unique `name` (must match the provider identifier in opencode)
# 3. Set `enabled` to true to activate, false to deactivate
# 4. Set model per phase in the `phases` attrset
#
# Example:
#   {
#     name = "my-provider";
#     enabled = true;
#     phases = {
#       apply = "my-model/v1";
#       verify = "my-model/v1";
#       explore = "my-model/v2";
#       tasks = "my-model/v1";
#     };
#   }
#
# -----------------------------------------------------------------------------
# ENABLING/DISABLING A PROVIDER
# -----------------------------------------------------------------------------
# Simply set `enabled = true` or `enabled = false`.
# The filter in opencode.nix automatically excludes disabled providers.
#
# -----------------------------------------------------------------------------
# CHANGING MODEL FOR A PHASE
# -----------------------------------------------------------------------------
# Edit the model string in `phases.<phase>`.
# Valid phases: apply, verify, explore, tasks, propose, spec, design, init, archive, onboard, orchestrator, neutral
#
# Example - change apply model:
#   phases.apply = "different-model/gpt-5";
#
# -----------------------------------------------------------------------------
# ROTATING PROVIDERS (changing primary)
# -----------------------------------------------------------------------------
# The PRIMARY provider is the FIRST enabled provider in the list.
# To change primary:
#   1. Disable the current primary (set enabled = false)
#   2. Enable the desired provider earlier in the list
#
# Example - make github-copilot the primary:
#   providers = [
#     { name = "github-copilot"; enabled = true; ... }  <- becomes primary
#     { name = "opencode-go"; enabled = true; ... }     <- now secondary
#   ];
#
# -----------------------------------------------------------------------------
# PROVIDER DETAILS
# -----------------------------------------------------------------------------
# opencode-go: Uses OAuth via /connect command - no static API key needed
# github-copilot: Uses OAuth via /connect command - no static API key needed
# github-copilot-student: Student tier with different rate limits
#
# All providers are authentication-based, not key-based.
#
# -----------------------------------------------------------------------------
# WEEKLY ROTATION STRATEGY
# -----------------------------------------------------------------------------
# When you hit week limits on opencode-go:
# 1. Disable opencode-go (set enabled = false)
# 2. Enable github-copilot (set enabled = true) BEFORE opencode-go in the list
# 3. Rebuild and switch
#
# Example rotation configuration:
#   providers = [
#     { name = "github-copilot"; enabled = true; ... }   <- primary (active)
#     { name = "opencode-go"; enabled = false; ... }     <- disabled until next week
#     { name = "github-copilot-student"; enabled = false; ... }
#   ];
#
# =============================================================================

{ lib ? throw "providers.nix must be imported with lib: import ./providers.nix { inherit lib; }"
}:

let
  # Library functions for provider lookup
  inherit (lib) head filterAttrs length attrValues listToAttrs mapAttrs;

  # All available providers
  # First enabled provider = primary (used for neutral agent default)
  providers = [
    # =========================================================================
    # PRIMARY PROVIDER - opencode-go (default)
    # =========================================================================
    # This is the main provider. When you hit week limits, disable this
    # and enable github-copilot above it in the list.
    {
      name = "opencode-go";
      enabled = true;
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
        # Legacy phase names (for compatibility)
        apply = "opencode-go/minimax-m2.7";
        verify = "opencode-go/glm-5.1";
        explore = "opencode-go/deepseek-v4-flash";
        tasks = "opencode-go/deepseek-v4-pro";
      };
    }

    # =========================================================================
    # FALLBACK PROVIDER - github-copilot (DISABLED by default)
    # =========================================================================
    # UNCOMMENT AND MOVE ABOVE opencode-go WHEN YOU HIT WEEK LIMITS
    # This provider uses Claude/GPT models optimized for different SDD phases.
    #
    # Cost estimates (~9x = ~9x cheaper than Opus):
    # - Claude Sonnet 4.6: ~9x
    # - Claude Opus 4.6: 3x (expensive, use sparingly)
    # - Claude Haiku 4.5: 0.33x (very cheap)
    # - GPT-5.4-Codex: ~6x
    #
    # To activate:
    #   1. Uncomment this entire block
    #   2. Set enabled = true
    #   3. Set opencode-go enabled = false
    #   4. Run: nixos-build && nixos-build switch
    #
    # {
    #   name = "github-copilot";
    #   enabled = false;  # CHANGE TO true TO ACTIVATE
    #   phases = {
    #     # orchestrator: Claude Sonnet 4.6 (~1x-9x in June)
    #     # Sufficient for coordination and flow
    #     sdd-orchestrator = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-propose (fundamental architecture): Claude Opus 4.6 (3x)
    #     # Use sparingly - only when critical
    #     sdd-propose = "github-copilot/claude-opus-4.6";
    #
    #     # sdd-design (technical architecture): Claude Sonnet 4.6 (~9x)
    #     # Covers most cases
    #     sdd-design = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-explore (codebase analysis): Claude Sonnet 4.6 (~9x)
    #     # Excellent for exploration
    #     sdd-explore = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-spec: Claude Sonnet 4.6 (~9x)
    #     # Very good at structured writing
    #     sdd-spec = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-tasks: Claude Sonnet 4.6 (~9x)
    #     # Ideal for breakdowns
    #     sdd-tasks = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-apply (coding): Claude Sonnet 4.6 + GPT-5.4-Codex (alternate)
    #     # ~9x / ~6x - Alternate based on code type
    #     sdd-apply = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-verify: Claude Sonnet 4.6 (~9x)
    #     # Good for validation
    #     sdd-verify = "github-copilot/claude-sonnet-4.6";
    #
    #     # sdd-archive: Claude Haiku 4.5 or Gemini 3 Flash (0.33x)
    #     # Very cheap and fast
    #     sdd-archive = "github-copilot/claude-haiku-4.5";
    #
    #     # sdd-onboard: Claude Sonnet 4.6 (~9x)
    #     sdd-onboard = "github-copilot/claude-sonnet-4.6";
    #
    #     # default/neutral: Claude Sonnet 4.6 (~9x)
    #     neutral = "github-copilot/claude-sonnet-4.6";
    #
    #     # Legacy phase names (for compatibility)
    #     apply = "github-copilot/claude-sonnet-4.6";
    #     verify = "github-copilot/claude-sonnet-4.6";
    #     explore = "github-copilot/claude-sonnet-4.6";
    #     tasks = "github-copilot/claude-sonnet-4.6";
    #   };
    # }

    # =========================================================================
    # ALTERNATIVE PROVIDER - github-copilot-student (DISABLED by default)
    # =========================================================================
    # Student tier with different rate limits and model availability.
    # Keep disabled unless specifically needed.
    {
      name = "github-copilot-student";
      enabled = false;
      phases = {
        sdd-orchestrator = "github-copilot-student/gpt-4.1";
        sdd-init = "github-copilot-student/claude-haiku-4.5";
        sdd-explore = "github-copilot-student/gemini-3.1-pro-preview";
        sdd-propose = "github-copilot-student/gpt-4.1";
        sdd-spec = "github-copilot-student/gpt-4.1";
        sdd-design = "github-copilot-student/gpt-4.1";
        sdd-tasks = "github-copilot-student/gpt-5.4-mini";
        sdd-apply = "github-copilot-student/gemini-3.1-pro-preview";
        sdd-verify = "github-copilot-student/gemini-3.1-pro-preview";
        sdd-archive = "github-copilot-student/claude-haiku-4.5";
        sdd-onboard = "github-copilot-student/gpt-4.1";
        neutral = "github-copilot-student/gpt-4.1";
        # Legacy phase names (for compatibility)
        apply = "github-copilot-student/gemini-3.1-pro-preview";
        verify = "github-copilot-student/gemini-3.1-pro-preview";
        explore = "github-copilot-student/gemini-3.1-pro-preview";
        tasks = "github-copilot-student/gpt-5.4-mini";
      };
    }
  ];

  # Get model for a specific phase from a provider
  getModelForPhase = phase: provider:
    provider.phases.${phase} or null;

  # Get all enabled providers
  activeProviders = filterAttrs (name: provider: provider.enabled) (builtins.listToAttrs (
    builtins.map (p: { name = p.name; value = p; }) providers
  ));

  # Get list of active providers as a list
  activeProviderList = builtins.attrValues activeProviders;

  # Get the primary (first enabled) provider
  primaryProvider = if length activeProviderList > 0 then head activeProviderList else null;

  # Get model for a phase from the primary provider
  primaryModelForPhase = phase:
    if primaryProvider != null
    then getModelForPhase phase primaryProvider
    else null;
in
{
  inherit providers;

  # Function to get model for a phase from a specific provider
  # Usage: getModelForPhase "apply" (builtins.head providers)
  inherit getModelForPhase;

  # Filtered list of enabled providers
  inherit activeProviders;
  inherit activeProviderList;

  # Primary provider (first enabled)
  inherit primaryProvider;

  # Helper to get primary model for a phase
  # Usage: primaryModelForPhase "apply"
  inherit primaryModelForPhase;
}
