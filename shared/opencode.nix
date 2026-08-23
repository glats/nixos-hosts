{ config
, lib
, pkgs
, inputs
, ...
}:

with lib;

let
  # Import centralized provider configuration
  providers = import ./opencode/providers.nix { inherit lib; };

  # Single runtime configuration
  runtimeConfig = {
    dir = "opencode";
    label = "default";
  };

  mkRuntimeConfig = import ./opencode/runtime-config.nix;
in
{
  imports = [
    ./opencode/agents.nix
    ./ai-assets.nix
    ./opencode/permissions.nix
    ./opencode/plugins.nix
  ];

  options.home.opencode = {
    enable = mkEnableOption "OpenCode configuration with declarative JSON generation";

    disabledProviders = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Built-in providers to disable (e.g. cloudflare-workers-ai).";
    };

    extraInitContent = mkOption {
      type = types.lines;
      default = "";
      description = "Extra zsh initContent appended after API key exports. Use for platform-specific shell setup.";
    };

    activeProviderName = mkOption {
      type = types.str;
      default = lib.mkDefault "opencode-go-full";
      description = ''
        Name of the active OpenCode provider tier (e.g. "opencode-go-full",
        "github-copilot"). Per-host plain assignments override this default
        without needing `mkForce`.
      '';
    };
  };

  config = mkMerge [
    # Main configuration
    (mkIf config.home.opencode.enable {
      home.packages = with pkgs; [
        gentle-ai
        engram
        poppler-utils # PDF page rendering: needed by OpenCode read tool and Claude Code for PDF support
      ];

      # Export API keys from sops secrets at shell startup
      programs.zsh.initContent = lib.mkAfter ''
              if [ -f "${config.sops.secrets."opencode/nvidia_api_key".path}" ]; then
                export NVIDIA_API_KEY="$(cat ${config.sops.secrets."opencode/nvidia_api_key".path})"
              fi
              if [ -f "${config.sops.secrets."opencode/groq_api_key".path}" ]; then
                export GROQ_API_KEY="$(cat ${config.sops.secrets."opencode/groq_api_key".path})"
              fi
            if [ -f "${config.sops.secrets."opencode/cerebras_api_key".path}" ]; then
              export CEREBRAS_API_KEY="$(cat ${config.sops.secrets."opencode/cerebras_api_key".path})"
            fi
          if [ -f "${config.sops.secrets."opencode/opencode_go_api_key".path}" ]; then
            export OPENCODE_API_KEY="$(cat ${config.sops.secrets."opencode/opencode_go_api_key".path})"
          fi
            if [ -f "${config.sops.secrets."opencode/openrouter_api_key".path}" ]; then
              export OPENROUTER_API_KEY="$(cat ${config.sops.secrets."opencode/openrouter_api_key".path})"
            fi
          if [ -f "${config.sops.secrets."opencode/mistral_api_key".path}" ]; then
            export MISTRAL_API_KEY="$(cat ${config.sops.secrets."opencode/mistral_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/cohere_api_key".path}" ]; then
            export COHERE_API_KEY="$(cat ${config.sops.secrets."opencode/cohere_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/gemini_api_key".path}" ]; then
            export GEMINI_API_KEY="$(cat ${config.sops.secrets."opencode/gemini_api_key".path})"
          fi
        if [ -f "${config.sops.secrets."opencode/cloudflare_api_key".path}" ]; then
          export CLOUDFLARE_API_TOKEN="$(cat ${config.sops.secrets."opencode/cloudflare_api_key".path})"
        fi
        if [ -f "${config.sops.secrets."opencode/cloudflare_account_id".path}" ]; then
          export CLOUDFLARE_ACCOUNT_ID="$(cat ${config.sops.secrets."opencode/cloudflare_account_id".path})"
        fi
          if [ -f "${config.sops.secrets."opencode/huggingface_api_key".path}" ]; then
            export HF_API_KEY="$(cat ${config.sops.secrets."opencode/huggingface_api_key".path})"
          fi
          if [ -f "${config.sops.secrets."opencode/kilo_api_key".path}" ]; then
            export KILO_API_KEY="$(cat ${config.sops.secrets."opencode/kilo_api_key".path})"
          fi
        ${config.home.opencode.extraInitContent}
      '';
    })

    # Single runtime configuration
    (mkIf config.home.opencode.enable (mkRuntimeConfig {
      inherit
        config
        lib
        pkgs
        providers
        ;
      cfg = config.home.opencode;
      inherit runtimeConfig;
    }))
  ];
}
