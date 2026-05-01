{ lib ? throw "providers.nix must be imported with lib" }:

let
  nvidiaProvider = {
    nvidia = {
      npm = "@ai-sdk/openai-compatible";
      name = "NVIDIA NIM";
      options = {
        baseURL = "https://integrate.api.nvidia.com/v1";
        apiKey = "{env:NVIDIA_API_KEY}";
        headers = { "Authorization" = "Bearer {env:NVIDIA_API_KEY}"; };
      };
      models = {
        "z-ai/glm-5.1" = { name = "GLM 5.1"; };
        "minimaxai/minimax-m2.7" = { name = "MiniMax M2.7"; };
        "deepseek-ai/deepseek-v4-flash" = { name = "DeepSeek V4 Flash"; };
        "deepseek-ai/deepseek-v4-pro" = { name = "DeepSeek V4 Pro"; };
        "nvidia/nemotron-3-super-120b-a12b" = { name = "Nemotron 3 Super"; };
      };
    };
  };

  groqProvider = {
    groq = {
      npm = "@ai-sdk/openai-compatible";
      name = "Groq";
      options = {
        baseURL = "https://api.groq.com/openai/v1";
        apiKey = "{env:GROQ_API_KEY}";
      };
      models = {
        "llama-3.1-8b-instant" = { name = "Llama 3.1 8B Instant"; };
        "llama-3.3-70b-versatile" = { name = "Llama 3.3 70B Versatile"; };
        "deepseek-r1-distill-llama-70b" = { name = "DeepSeek R1 Distill Llama 70B"; };
        "gpt-oss-120b" = { name = "GPT-OSS 120B"; };
        "gpt-oss-20b" = { name = "GPT-OSS 20B"; };
      };
    };
  };

  cerebrasProvider = {
    cerebras = {
      npm = "@ai-sdk/openai-compatible";
      name = "Cerebras";
      options = {
        baseURL = "https://api.cerebras.ai/v1";
        apiKey = "{env:CEREBRAS_API_KEY}";
      };
      models = {
        "llama-3.1-8b" = { name = "Llama 3.1 8B"; };
        "llama-3.3-70b" = { name = "Llama 3.3 70B"; };
        "gpt-oss-120b" = { name = "GPT-OSS 120B"; };
      };
    };
  };

  opencodeZenProvider = {
    opencode = {
      npm = "@ai-sdk/openai-compatible";
      name = "OpenCode Zen";
      options = {
        baseURL = "https://opencode.ai/zen/v1";
        apiKey = "{env:OPENCODE_API_KEY}";
      };
      models = {
        "big-pickle" = { name = "Big Pickle"; };
        "minimax-m2.5-free" = { name = "MiniMax M2.5 Free"; };
        "mimo-v2-flash-free" = { name = "MiMo V2 Flash Free"; };
        "nemotron-3-super-free" = { name = "Nemotron 3 Super Free"; };
      };
    };
  };

  allProviders = nvidiaProvider // groqProvider // cerebrasProvider // opencodeZenProvider;

  activeProviderName = "balanced";

  providers = [
    { name = "nvidia"; phases = {
        sdd-orchestrator = "nvidia/z-ai/glm-5.1";
        sdd-init = "nvidia/minimaxai/minimax-m2.7";
        sdd-explore = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-propose = "nvidia/z-ai/glm-5.1";
        sdd-spec = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-design = "nvidia/z-ai/glm-5.1";
        sdd-tasks = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-apply = "nvidia/minimaxai/minimax-m2.7";
        sdd-verify = "nvidia/z-ai/glm-5.1";
        sdd-archive = "nvidia/minimaxai/minimax-m2.7";
        sdd-onboard = "nvidia/minimaxai/minimax-m2.7";
        neutral = "nvidia/z-ai/glm-5.1";
      };
    }
    { name = "groq"; phases = {
        sdd-orchestrator = "groq/llama-3.3-70b-versatile";
        sdd-init = "groq/llama-3.1-8b-instant";
        sdd-explore = "groq/llama-3.1-8b-instant";
        sdd-propose = "groq/llama-3.3-70b-versatile";
        sdd-spec = "groq/deepseek-r1-distill-llama-70b";
        sdd-design = "groq/deepseek-r1-distill-llama-70b";
        sdd-tasks = "groq/deepseek-r1-distill-llama-70b";
        sdd-apply = "groq/llama-3.1-8b-instant";
        sdd-verify = "groq/llama-3.1-8b-instant";
        sdd-archive = "groq/gpt-oss-20b";
        sdd-onboard = "groq/llama-3.1-8b-instant";
        neutral = "groq/llama-3.3-70b-versatile";
      };
    }
    { name = "cerebras"; phases = {
        sdd-orchestrator = "cerebras/llama-3.3-70b";
        sdd-init = "cerebras/llama-3.1-8b";
        sdd-explore = "cerebras/llama-3.1-8b";
        sdd-propose = "cerebras/llama-3.3-70b";
        sdd-spec = "cerebras/llama-3.3-70b";
        sdd-design = "cerebras/gpt-oss-120b";
        sdd-tasks = "cerebras/gpt-oss-120b";
        sdd-apply = "cerebras/llama-3.1-8b";
        sdd-verify = "cerebras/llama-3.1-8b";
        sdd-archive = "cerebras/llama-3.1-8b";
        sdd-onboard = "cerebras/llama-3.1-8b";
        neutral = "cerebras/llama-3.3-70b";
      };
    }
    { name = "opencode"; phases = {
        sdd-orchestrator = "opencode/big-pickle";
        sdd-init = "opencode/minimax-m2.5-free";
        sdd-explore = "opencode/minimax-m2.5-free";
        sdd-propose = "opencode/big-pickle";
        sdd-spec = "opencode/big-pickle";
        sdd-design = "opencode/minimax-m2.5-free";
        sdd-tasks = "opencode/mimo-v2-flash-free";
        sdd-apply = "opencode/minimax-m2.5-free";
        sdd-verify = "opencode/minimax-m2.5-free";
        sdd-archive = "opencode/nemotron-3-super-free";
        sdd-onboard = "opencode/minimax-m2.5-free";
        neutral = "opencode/big-pickle";
      };
    }
    { name = "speed"; phases = {
        sdd-orchestrator = "cerebras/gpt-oss-120b";
        sdd-init = "cerebras/llama-3.1-8b";
        sdd-explore = "groq/llama-3.1-8b-instant";
        sdd-propose = "cerebras/llama-3.3-70b";
        sdd-spec = "groq/llama-3.3-70b-versatile";
        sdd-design = "cerebras/gpt-oss-120b";
        sdd-tasks = "cerebras/gpt-oss-120b";
        sdd-apply = "groq/llama-3.1-8b-instant";
        sdd-verify = "groq/llama-3.1-8b-instant";
        sdd-archive = "groq/gpt-oss-20b";
        sdd-onboard = "groq/llama-3.1-8b-instant";
        neutral = "cerebras/gpt-oss-120b";
      };
    }
    { name = "coding"; phases = {
        sdd-orchestrator = "nvidia/minimaxai/minimax-m2.7";
        sdd-init = "nvidia/minimaxai/minimax-m2.7";
        sdd-explore = "nvidia/minimaxai/minimax-m2.7";
        sdd-propose = "nvidia/minimaxai/minimax-m2.7";
        sdd-spec = "groq/deepseek-r1-distill-llama-70b";
        sdd-design = "nvidia/z-ai/glm-5.1";
        sdd-tasks = "nvidia/minimaxai/minimax-m2.7";
        sdd-apply = "nvidia/minimaxai/minimax-m2.7";
        sdd-verify = "nvidia/z-ai/glm-5.1";
        sdd-archive = "nvidia/minimaxai/minimax-m2.7";
        sdd-onboard = "nvidia/minimaxai/minimax-m2.7";
        neutral = "nvidia/minimaxai/minimax-m2.7";
      };
    }
    { name = "reasoning"; phases = {
        sdd-orchestrator = "nvidia/z-ai/glm-5.1";
        sdd-init = "nvidia/z-ai/glm-5.1";
        sdd-explore = "nvidia/z-ai/glm-5.1";
        sdd-propose = "nvidia/z-ai/glm-5.1";
        sdd-spec = "groq/deepseek-r1-distill-llama-70b";
        sdd-design = "nvidia/z-ai/glm-5.1";
        sdd-tasks = "groq/deepseek-r1-distill-llama-70b";
        sdd-apply = "nvidia/z-ai/glm-5.1";
        sdd-verify = "nvidia/z-ai/glm-5.1";
        sdd-archive = "nvidia/z-ai/glm-5.1";
        sdd-onboard = "nvidia/z-ai/glm-5.1";
        neutral = "nvidia/z-ai/glm-5.1";
      };
    }
    { name = "free"; phases = {
        sdd-orchestrator = "opencode/big-pickle";
        sdd-init = "opencode/minimax-m2.5-free";
        sdd-explore = "opencode/minimax-m2.5-free";
        sdd-propose = "opencode/big-pickle";
        sdd-spec = "opencode/big-pickle";
        sdd-design = "opencode/minimax-m2.5-free";
        sdd-tasks = "opencode/mimo-v2-flash-free";
        sdd-apply = "opencode/minimax-m2.5-free";
        sdd-verify = "opencode/minimax-m2.5-free";
        sdd-archive = "opencode/nemotron-3-super-free";
        sdd-onboard = "opencode/minimax-m2.5-free";
        neutral = "opencode/big-pickle";
      };
    }
    { name = "balanced"; phases = {
        sdd-orchestrator = "nvidia/z-ai/glm-5.1";
        sdd-init = "groq/llama-3.1-8b-instant";
        sdd-explore = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-propose = "nvidia/z-ai/glm-5.1";
        sdd-spec = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-design = "nvidia/z-ai/glm-5.1";
        sdd-tasks = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-apply = "nvidia/minimaxai/minimax-m2.7";
        sdd-verify = "nvidia/z-ai/glm-5.1";
        sdd-archive = "groq/gpt-oss-20b";
        sdd-onboard = "nvidia/minimaxai/minimax-m2.7";
        neutral = "nvidia/z-ai/glm-5.1";
      };
    }
  ];

  activeProvider = builtins.foldl' (acc: p: if p.name == activeProviderName then p else acc) null providers;
  getModelForPhase = phase: provider: if provider == null then null else provider.phases.${phase} or null;

in
{
  inherit nvidiaProvider groqProvider cerebrasProvider opencodeZenProvider allProviders;
  inherit providers activeProviderName activeProvider getModelForPhase;
}