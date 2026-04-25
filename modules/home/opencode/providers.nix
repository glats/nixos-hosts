{ config, lib, pkgs, ... }:

with lib;

let
  # Static default providers - no config references in defaults
  defaultProviders = {
    fireworks = {
      npm = "@ai-sdk/openai-compatible";
      name = "Fireworks AI";
      options = {
        baseURL = "https://api.fireworks.ai/inference/v1";
        apiKey = "FIREWORKS_API_KEY_PLACEHOLDER";
      };
      models = {
        "accounts/fireworks/models/kimi-k2p6" = {
          name = "Kimi K2.6;";
        };
        "accounts/fireworks/models/glm-5p1" = {
          name = "GLM 5.1";
        };
        "accounts/fireworks/models/minimax-m2p7" = {
          name = "MiniMax M2.7";
        };
      };
    };

    deepinfra = {
      npm = "@ai-sdk/openai-compatible";
      name = "DeepInfra";
      options = {
        baseURL = "https://api.deepinfra.com/v1/openai";
        apiKey = "DEEPINFRA_API_KEY_PLACEHOLDER";
      };
      models = {
        "zai-org/GLM-5" = {
          name = "GLM 5";
        };
        "zai-org/GLM-5.1" = {
          name = "GLM 5.1";
        };
        "zai-org/GLM-4.7-Flash" = {
          name = "GLM 4.7 Flash";
        };
        "moonshotai/Kimi-K2.5" = {
          name = "Kimi K2.5";
        };
        "Qwen/Qwen3-Max" = {
          name = "Qwen3 Max";
        };
        "Qwen/Qwen3-Max-Thinking" = {
          name = "Qwen3 Max Thinking";
        };
        "Qwen/Qwen3.5-397B-A17B" = {
          name = "Qwen3.5 397B A17B";
        };
        "Qwen/Qwen3.5-122B-A10B" = {
          name = "Qwen3.5 122B A10B";
        };
        "Qwen/Qwen3.5-35B-A3B" = {
          name = "Qwen3.5 35B A3B";
        };
        "Qwen/Qwen3.5-27B" = {
          name = "Qwen3.5 27B";
        };
        "Qwen/Qwen3.5-4B" = {
          name = "Qwen3.5 4B";
        };
        "Qwen/Qwen3.5-2B" = {
          name = "Qwen3.5 2B";
        };
        "Qwen/Qwen3.5-0.8B" = {
          name = "Qwen3.5 0.8B";
        };
        "Qwen/Qwen3.6-35B-A3B" = {
          name = "Qwen3.6 35B A3B";
        };
        "Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo" = {
          name = "Qwen3 Coder 480B";
        };
        "deepseek-ai/DeepSeek-V3.2" = {
          name = "DeepSeek V3.2";
        };
        "deepseek-ai/DeepSeek-V3.2-Exp" = {
          name = "DeepSeek V3.2 Exp";
        };
        "deepseek-ai/DeepSeek-V3" = {
          name = "DeepSeek V3";
        };
        "deepseek-ai/DeepSeek-V3.1" = {
          name = "DeepSeek V3.1";
        };
        "stepfun-ai/Step-3.5-Flash" = {
          name = "Step 3.5 Flash";
        };
        "MiniMaxAI/MiniMax-M2.5" = {
          name = "MiniMax M2.5";
        };
        "nvidia/NVIDIA-Nemotron-3-Super-120B-A12B" = {
          name = "Nemotron 3 Super 120B";
        };
        "nvidia/Nemotron-3-Nano-30B-A3B" = {
          name = "Nemotron 3 Nano 30B";
        };
        "google/gemma-4-26B-A4B-it" = {
          name = "Gemma 4 26B A4B";
        };
        "google/gemma-4-31B-it" = {
          name = "Gemma 4 31B";
        };
        "google/gemini-2.5-flash" = {
          name = "Gemini 2.5 Flash";
        };
        "google/gemini-1.5-flash" = {
          name = "Gemini 1.5 Flash";
        };
        "google/gemini-1.5-flash-8b" = {
          name = "Gemini 1.5 Flash 8B";
        };
      };
    };

    anthropic = {
      npm = "@ai-sdk/anthropic";
      name = "Anthropic";
      options = {
        apiKey = "ANTHROPIC_API_KEY_PLACEHOLDER";
      };
      models = {
        "claude-4-sonnet-20250514" = {
          name = "Claude 4 Sonnet";
        };
        "claude-4-opus-20250514" = {
          name = "Claude 4 Opus";
        };
        "claude-3-haiku" = {
          name = "Claude 3 Haiku";
        };
        "claude-sonnet-4-6" = {
          name = "Claude Sonnet 4.6";
        };
      };
    };

    openai = {
      npm = "@ai-sdk/openai";
      name = "OpenAI";
      options = {
        apiKey = "OPENAI_API_KEY_PLACEHOLDER";
      };
      models = {
        "gpt-5.4" = {
          name = "GPT-5.4";
        };
        "gpt-5.4-mini" = {
          name = "GPT-5.4 Mini";
        };
        "gpt-5.4-nano" = {
          name = "GPT-5.4 Nano";
        };
      };
    };

    github-copilot = {
      npm = "@opencode-ai/github-copilot";
      name = "GitHub Copilot";
      options = {
        # OAuth-based authentication via /connect command
        # No static API key required - user authenticates interactively
        # Run: /connect -> GitHub Copilot -> Authorize at github.com/login/device
      };
      models = {
        # Anthropic models
        "claude-haiku-4.5" = {
          name = "Claude Haiku 4.5";
        };
        "claude-opus-4.6" = {
          name = "Claude Opus 4.6";
        };
        "claude-sonnet-4.6" = {
          name = "Claude Sonnet 4.6";
        };
        # OpenAI models
        "gpt-4.1" = {
          name = "GPT-4.1";
        };
        "gpt-5.4" = {
          name = "GPT-5.4";
        };
        "gpt-5.4-mini" = {
          name = "GPT-5.4 Mini";
        };
        "gpt-5.3-codex" = {
          name = "GPT-5.3 Codex";
        };
        # Google models
        "gemini-2.5-flash" = {
          name = "Gemini 2.5 Flash";
        };
        "gemini-2.5-pro" = {
          name = "Gemini 2.5 Pro";
        };
      };
    };
  };
in
{
  options.home.opencode.providers = mkOption {
    type = types.attrsOf (types.submodule {
      freeformType = types.attrs;
    });
    default = defaultProviders;
    description = ''
      OpenCode provider configurations with API endpoints and model definitions.
      API keys should use placeholder strings that will be replaced at build time
      via secret path interpolation.
    '';
  };

  # Provider secret paths for sops-nix integration
  # These are set in config section to avoid infinite recursion
  options.home.opencode.providerSecrets = mkOption {
    type = types.attrsOf types.str;
    default = { };
    description = ''
      Paths to sops-encrypted API keys for each provider.
      These paths are used at build time to inject actual key values.
    '';
  };

  # Set the actual secret paths in the config section
  config.home.opencode.providerSecrets = {
    fireworks = config.sops.secrets."opencode/fireworks_api_key".path or "/run/secrets/opencode/fireworks_api_key";
    deepinfra = config.sops.secrets."opencode/deepinfra_api_key".path or "/run/secrets/opencode/deepinfra_api_key";
    anthropic = config.sops.secrets."opencode/anthropic_api_key".path or "/run/secrets/opencode/anthropic_api_key";
    openai = config.sops.secrets."opencode/openai_api_key".path or "/run/secrets/opencode/openai_api_key";
  };
}
