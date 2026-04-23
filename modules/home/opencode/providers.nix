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
        "accounts/fireworks/models/glm-5" = {
          name = "GLM 5";
        };
        "accounts/fireworks/models/kimi-k2p5" = {
          name = "Kimi K2.5";
        };
        "accounts/fireworks/models/deepseek-v3p2" = {
          name = "DeepSeek V3.2";
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
          context = 128000;
        };
        "zai-org/GLM-5.1" = {
          name = "GLM 5.1";
          context = 128000;
        };
        "zai-org/GLM-4.7-Flash" = {
          name = "GLM 4.7 Flash";
          context = 128000;
        };
        "moonshotai/Kimi-K2.5" = {
          name = "Kimi K2.5";
          context = 256000;
        };
        "Qwen/Qwen3-Max" = {
          name = "Qwen3 Max";
          context = 250000;
        };
        "Qwen/Qwen3-Max-Thinking" = {
          name = "Qwen3 Max Thinking";
          context = 250000;
        };
        "Qwen/Qwen3.5-397B-A17B" = {
          name = "Qwen3.5 397B A17B";
          context = 262000;
        };
        "Qwen/Qwen3.5-122B-A10B" = {
          name = "Qwen3.5 122B A10B";
          context = 262000;
        };
        "Qwen/Qwen3.5-35B-A3B" = {
          name = "Qwen3.5 35B A3B";
          context = 262000;
        };
        "Qwen/Qwen3.5-27B" = {
          name = "Qwen3.5 27B";
          context = 262000;
        };
        "Qwen/Qwen3.5-4B" = {
          name = "Qwen3.5 4B";
          context = 262000;
        };
        "Qwen/Qwen3.5-2B" = {
          name = "Qwen3.5 2B";
          context = 262000;
        };
        "Qwen/Qwen3.5-0.8B" = {
          name = "Qwen3.5 0.8B";
          context = 262000;
        };
        "Qwen/Qwen3.6-35B-A3B" = {
          name = "Qwen3.6 35B A3B";
          context = 262000;
        };
        "Qwen/Qwen3-Coder-480B-A35B-Instruct-Turbo" = {
          name = "Qwen3 Coder 480B";
          context = 262000;
        };
        "deepseek-ai/DeepSeek-V3.2" = {
          name = "DeepSeek V3.2";
          context = 128000;
        };
        "deepseek-ai/DeepSeek-V3.2-Exp" = {
          name = "DeepSeek V3.2 Exp";
          context = 128000;
        };
        "deepseek-ai/DeepSeek-V3" = {
          name = "DeepSeek V3";
          context = 128000;
        };
        "deepseek-ai/DeepSeek-V3.1" = {
          name = "DeepSeek V3.1";
          context = 128000;
        };
        "stepfun-ai/Step-3.5-Flash" = {
          name = "Step 3.5 Flash";
          context = 256000;
        };
        "MiniMaxAI/MiniMax-M2.5" = {
          name = "MiniMax M2.5";
          context = 8192000;
        };
        "nvidia/NVIDIA-Nemotron-3-Super-120B-A12B" = {
          name = "Nemotron 3 Super 120B";
          context = 256000;
        };
        "nvidia/Nemotron-3-Nano-30B-A3B" = {
          name = "Nemotron 3 Nano 30B";
          context = 256000;
        };
        "google/gemma-4-26B-A4B-it" = {
          name = "Gemma 4 26B A4B";
          context = 262000;
        };
        "google/gemma-4-31B-it" = {
          name = "Gemma 4 31B";
          context = 262000;
        };
        "google/gemini-2.5-flash" = {
          name = "Gemini 2.5 Flash";
          context = 1000000;
        };
        "google/gemini-1.5-flash" = {
          name = "Gemini 1.5 Flash";
          context = 1000000;
        };
        "google/gemini-1.5-flash-8b" = {
          name = "Gemini 1.5 Flash 8B";
          context = 1000000;
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
          context = 200000;
        };
        "claude-4-opus-20250514" = {
          name = "Claude 4 Opus";
          context = 200000;
        };
        "claude-3-haiku" = {
          name = "Claude 3 Haiku";
          context = 200000;
        };
        "claude-sonnet-4-6" = {
          name = "Claude Sonnet 4.6";
          context = 200000;
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
          context = 256000;
        };
        "gpt-5.4-mini" = {
          name = "GPT-5.4 Mini";
          context = 256000;
        };
        "gpt-5.4-nano" = {
          name = "GPT-5.4 Nano";
          context = 256000;
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
