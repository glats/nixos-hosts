{
  lib ? throw "providers-base.nix must be imported with lib",
}:

let
  nvidiaProvider = {
    nvidia = {
      npm = "@ai-sdk/openai-compatible";
      name = "NVIDIA NIM";
      options = {
        baseURL = "https://integrate.api.nvidia.com/v1";
        apiKey = "{env:NVIDIA_API_KEY}";
        headers = {
          "Authorization" = "Bearer {env:NVIDIA_API_KEY}";
        };
      };
      models = {
        "z-ai/glm-5.1" = {
          name = "GLM 5.1";
        };
        "minimaxai/minimax-m3" = {
          name = "MiniMax M3";
        };
        "minimaxai/minimax-m2.7" = {
          name = "MiniMax M2.7";
        };
        "deepseek-ai/deepseek-v4-flash" = {
          name = "DeepSeek V4 Flash";
        };
        "deepseek-ai/deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
        };
        "nvidia/nemotron-3-ultra-550b-a55b" = {
          name = "Nemotron 3 Ultra";
        };
        "stepfun-ai/step-3.7-flash" = {
          name = "Step 3.7 Flash";
        };
        "mistralai/mistral-medium-3.5-128b" = {
          name = "Mistral Medium 3.5";
        };
        "google/gemma-4-31b-it" = {
          name = "Gemma 4";
        };
        "qwen/qwen3.5-397b-a17b" = {
          name = "Qwen 3.5";
        };
        "openai/gpt-oss-120b" = {
          name = "GPT OSS 120b";
        };
        "moonshotai/kimi-k2.6" = {
          name = "Kimi K2.6";
        };
      };
    };
  };

  opencodeProvider = {
    opencode = {
      models = {
        "qwen3.7-plus" = {
          name = "Qwen 3.7 Plus";
          thinking = false;
        };
        "qwen3.7-max" = {
          name = "Qwen 3.7 Max";
          thinking = false;
        };
        "qwen3.8-ultra" = {
          name = "Qwen 3.8 Ultra";
          thinking = false;
        };
      };
      options = {
        timeout = 3600000;
        chunkTimeout = 3600000;
      };
    };
  };

  allProviders = nvidiaProvider // opencodeProvider;

  activeProviderName = "opencode-go";

  providers = [
    {
      name = "nvidia";
      phases = {
        gentle-orchestrator = "nvidia/deepseek-ai/deepseek-v4-pro";
        sdd-init = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-explore = "nvidia/minimaxai/minimax-m3";
        sdd-propose = "nvidia/deepseek-ai/deepseek-v4-pro";
        sdd-spec = "nvidia/deepseek-ai/deepseek-v4-pro";
        sdd-design = "nvidia/deepseek-ai/deepseek-v4-pro";
        sdd-tasks = "nvidia/minimaxai/minimax-m3";
        sdd-apply = "nvidia/minimaxai/minimax-m3";
        sdd-verify = "nvidia/deepseek-ai/deepseek-v4-pro";
        sdd-archive = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-onboard = "nvidia/deepseek-ai/deepseek-v4-pro";
        neutral = "nvidia/deepseek-ai/deepseek-v4-pro";
      };
    }
    {
      name = "github-copilot";
      phases = {
        gentle-orchestrator = "github-copilot/gpt-5.4";
        sdd-init = "github-copilot/gpt-5.4-mini";
        sdd-explore = "github-copilot/gpt-5.4";
        sdd-propose = "github-copilot/claude-sonnet-4.6";
        sdd-spec = "github-copilot/claude-sonnet-4.6";
        sdd-design = "github-copilot/claude-sonnet-4.6";
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        sdd-apply = "github-copilot/gpt-5.3-codex";
        sdd-verify = "github-copilot/gpt-5.4";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/gpt-5.4";
        neutral = "github-copilot/gpt-5.4";
      };
    }
    {
      name = "opencode-go";
      phases = {
        gentle-orchestrator = "opencode-go/deepseek-v4-pro";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/minimax-m3";
        sdd-propose = "opencode-go/minimax-m3";
        sdd-spec = "opencode-go/mimo-v2.5-pro";
        sdd-design = "opencode-go/deepseek-v4-pro";
        sdd-tasks = "opencode-go/minimax-m3";
        sdd-apply = "opencode-go/minimax-m3";
        sdd-verify = "opencode-go/deepseek-v4-pro";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/deepseek-v4-pro";
      };
    }
    {
      name = "opencode-go2";
      phases = {
        gentle-orchestrator = "opencode-go/deepseek-v4-pro";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/qwen3.7-plus";
        sdd-propose = "opencode-go/qwen3.7-plus";
        sdd-spec = "opencode-go/qwen3.8-ultra";
        sdd-design = "opencode-go/qwen3.8-ultra";
        sdd-tasks = "opencode-go/qwen3.7-plus";
        sdd-apply = "opencode-go/minimax-m3";
        sdd-verify = "opencode-go/qwen3.7-plus";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/deepseek-v4-pro";
      };
    }
    {
      name = "opencode-free";
      phases = {
        gentle-orchestrator = "opencode/deepseek-v4-flash-free";
        sdd-init = "opencode/deepseek-v4-flash-free";
        sdd-explore = "opencode/deepseek-v4-flash-free";
        sdd-propose = "opencode/deepseek-v4-flash-free";
        sdd-spec = "opencode/deepseek-v4-flash-free";
        sdd-design = "opencode/deepseek-v4-flash-free";
        sdd-tasks = "opencode/mimo-v2.5-free";
        sdd-apply = "opencode/mimo-v2.5-free";
        sdd-verify = "opencode/nemotron-3-ultra-free";
        sdd-archive = "opencode/deepseek-v4-flash-free";
        sdd-onboard = "opencode/deepseek-v4-flash-free";
        neutral = "opencode/deepseek-v4-flash-free";
      };
    }
  ];

  activeProvider = builtins.foldl' (
    acc: p: if p.name == activeProviderName then p else acc
  ) null providers;
  getModelForPhase =
    phase: provider: if provider == null then null else provider.phases.${phase} or null;

in
{
  inherit
    nvidiaProvider
    allProviders
    providers
    activeProviderName
    activeProvider
    getModelForPhase
    ;
}
