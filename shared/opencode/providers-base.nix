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

  allProviders = nvidiaProvider;

  activeProviderName = "opencode-free";

  providers = [
    {
      name = "nvidia";
      phases = {
        gentle-orchestrator = "nvidia/deepseek-ai/deepseek-v4-pro";
        sdd-init = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-explore = "nvidia/qwen/qwen3.5-397b-a17b";
        sdd-propose = "nvidia/qwen/qwen3.5-397b-a17b";
        sdd-spec = "nvidia/qwen/qwen3.5-397b-a17b";
        sdd-design = "nvidia/qwen/qwen3.5-397b-a17b";
        sdd-tasks = "nvidia/qwen/qwen3.5-397b-a17b";
        sdd-apply = "nvidia/minimaxai/minimax-m2.7";
        sdd-verify = "nvidia/qwen/qwen3.5-397b-a17b";
        sdd-archive = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-onboard = "nvidia/deepseek-ai/deepseek-v4-flash";
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
        sdd-tasks = "github-copilot/claude-sonnet-4.6";
        sdd-apply = "github-copilot/gpt-5.4";
        sdd-verify = "github-copilot/gpt-5.4-mini";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        neutral = "github-copilot/claude-sonnet-4.6";
      };
    }
    {
      name = "opencode-go";
      phases = {
        gentle-orchestrator = "opencode-go/kimi-k2.6";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/deepseek-v4-flash";
        sdd-propose = "opencode-go/qwen3.7-max";
        sdd-spec = "opencode-go/qwen3.7-max";
        sdd-design = "opencode-go/qwen3.7-max";
        sdd-tasks = "opencode-go/deepseek-v4-pro";
        sdd-apply = "opencode-go/mimo-v2.5-pro";
        sdd-verify = "opencode-go/qwen3.7-max";
        sdd-archive = "opencode-go/minimax-m3";
        sdd-onboard = "opencode-go/minimax-m3";
        neutral = "opencode-go/minimax-m3";
      };
    }
    {
      name = "opencode-go2";
      phases = {
        gentle-orchestrator = "opencode-go/kimi-k2.6";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/qwen3.7-plus";
        sdd-propose = "opencode-go/qwen3.7-plus";
        sdd-spec = "opencode-go/qwen3.7-plus";
        sdd-design = "opencode-go/glm-5.1";
        sdd-tasks = "opencode-go/kimi-k2.6";
        sdd-apply = "opencode-go/minimax-m3";
        sdd-verify = "opencode-go/glm-5.1";
        sdd-archive = "opencode-go/deepseek-v4-pro";
        sdd-onboard = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/kimi-k2.6";
      };
    }
    {
      name = "opencode-go3";
      phases = {
        gentle-orchestrator = "opencode-go/kimi-k2.6";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/qwen3.7-plus";
        sdd-propose = "opencode-go/kimi-k2.6";
        sdd-spec = "opencode-go/qwen3.7-plus";
        sdd-design = "opencode-go/kimi-k2.6";
        sdd-tasks = "opencode-go/kimi-k2.6";
        sdd-apply = "opencode-go/minimax-m3";
        sdd-verify = "opencode-go/kimi-k2.6";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "opencode-free";
      phases = {
        gentle-orchestrator = "opencode-go/kimi-k2.6";
        sdd-init = "opencode/deepseek-v4-flash-free";
        sdd-explore = "opencode-go/qwen3.7-plus";
        sdd-propose = "opencode-go/kimi-k2.6";
        sdd-spec = "opencode-go/qwen3.7-plus";
        sdd-design = "opencode/nemotron-3-ultra-free";
        sdd-tasks = "opencode-go/kimi-k2.6";
        sdd-apply = "opencode-go/minimax-m3";
        sdd-verify = "opencode/nemotron-3-ultra-free";
        sdd-archive = "opencode/deepseek-v4-flash-free";
        sdd-onboard = "opencode/deepseek-v4-flash-free";
        neutral = "opencode-go/deepseek-v4-flash";
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
