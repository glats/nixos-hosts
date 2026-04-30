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
#
# Both providers are authentication-based, not key-based.
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

    {
      name = "github-copilot";
      enabled = false;
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
        # Legacy phase names (for compatibility)
        apply = "github-copilot/gemini-3.1-pro-preview";
        verify = "github-copilot/gemini-3.1-pro-preview";
        explore = "github-copilot/gemini-3.1-pro-preview";
        tasks = "github-copilot/gpt-5.4-mini";
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
