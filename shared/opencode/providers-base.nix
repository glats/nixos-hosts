{
  lib ? throw "providers-base.nix must be imported with lib",
  activeProviderName ? "opencode-go-medium",
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
        "nemotron-3-ultra-550b-a55b" = {
          name = "Nemotron 3 Ultra";
          modelID = "nvidia/nemotron-3-ultra-550b-a55b";
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

  providerAllowlist = [
    "opencode"
    "opencode-go"
    "anthropic"
    "openai"
    "github-copilot"
    "nvidia"
  ];

  providers = [
    {
      name = "openai-anthropic-opencode";
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/minimax-m3.1-flash";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "anthropic-openai-opencode";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/minimax-m3.1-flash";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "anthropic-opencode";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/minimax-m3.1-flash";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "anthropic-opencode-openai";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "openai-opencode-anthropic";
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "anthropic/claude-haiku-5-5";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "anthropic/claude-haiku-5-5";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "opencode-anthropic-openai";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "opencode-go/glm-5.3";
      };
    }
    {
      name = "opencode-openai-anthropic";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "anthropic/claude-haiku-5-5";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "anthropic/claude-haiku-5-5";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "opencode-go/glm-5.3";
      };
    }
    {
      name = "anthropic-openai";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "openai-anthropic";
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "anthropic/claude-haiku-5-5";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "anthropic/claude-haiku-5-5";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "openai-opencode";
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/minimax-m3.1-flash";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "opencode-anthropic";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "anthropic/claude-haiku-5-5";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "anthropic/claude-haiku-5-5";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/glm-5.3";
      };
    }
    {
      name = "opencode-openai";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/glm-5.3";
      };
    }
    {
      name = "anthropic-copilot";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "github-copilot/claude-sonnet-5.5";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "github-copilot/claude-sonnet-5.5";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "github-copilot/claude-sonnet-5.5";
      };
    }
    {
      name = "work-copilot-anthropic-light";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-6.1-sol";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "github-copilot/claude-sonnet-5.5";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "github-copilot/claude-sonnet-5.5";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "github-copilot/claude-sonnet-5.5";
      };
    }
    {
      name = "anthropic-light";
      roles = {
        gentle-orchestrator = "anthropic/claude-sonnet-5-5";
        gentle-ai-explore = "anthropic/claude-haiku-5-5";
        gentle-ai-worker = "anthropic/claude-haiku-5-5";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "anthropic/claude-haiku-5-5";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "anthropic/claude-sonnet-5-5";
      };
    }
    {
      name = "anthropic-medium";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "anthropic/claude-sonnet-5-5";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "anthropic/claude-sonnet-5-5";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "anthropic-full";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        gentle-ai-worker = "anthropic/claude-sonnet-5-5";
        gentle-ai-verify = "anthropic/claude-opus-5-5";
        jd-judge-a = "anthropic/claude-opus-5-5";
        jd-judge-b = "anthropic/claude-opus-5-5";
        jd-fix-agent = "anthropic/claude-sonnet-5-5";
        review-readability = "anthropic/claude-opus-5-5";
        review-refuter = "anthropic/claude-opus-5-5";
        review-reliability = "anthropic/claude-opus-5-5";
        review-resilience = "anthropic/claude-opus-5-5";
        review-risk = "anthropic/claude-opus-5-5";
        review-validator = "anthropic/claude-opus-5-5";
        neutral = "anthropic/claude-sonnet-5-5";
      };
    }
    {
      name = "openai-full";
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "openai/gpt-6-astra";
        jd-judge-a = "openai/gpt-6-astra";
        jd-judge-b = "openai/gpt-6-astra";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "openai/gpt-6-astra";
        review-refuter = "openai/gpt-6-astra";
        review-reliability = "openai/gpt-6-astra";
        review-resilience = "openai/gpt-6-astra";
        review-risk = "openai/gpt-6-astra";
        review-validator = "openai/gpt-6-astra";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "openai-medium";
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "openai-light";
      roles = {
        gentle-orchestrator = "openai/gpt-6-luna";
        gentle-ai-explore = "openai/gpt-6-luna";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "openai/gpt-6-luna";
        jd-judge-a = "openai/gpt-6-luna";
        jd-judge-b = "openai/gpt-6-luna";
        jd-fix-agent = "openai/gpt-6-luna";
        review-readability = "openai/gpt-6-luna";
        review-refuter = "openai/gpt-6-luna";
        review-reliability = "openai/gpt-6-luna";
        review-resilience = "openai/gpt-6-luna";
        review-risk = "openai/gpt-6-luna";
        review-validator = "openai/gpt-6-luna";
        neutral = "openai/gpt-6-luna";
      };
    }
    {
      name = "github-copilot-light";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-5.4-mini";
        gentle-ai-explore = "github-copilot/gpt-5.4-mini";
        gentle-ai-worker = "github-copilot/gpt-5.3-codex";
        gentle-ai-verify = "github-copilot/claude-sonnet-5.5";
        jd-judge-a = "github-copilot/claude-sonnet-5.5";
        jd-judge-b = "github-copilot/claude-sonnet-5.5";
        jd-fix-agent = "github-copilot/gpt-5.3-codex";
        review-readability = "github-copilot/claude-sonnet-5.5";
        review-refuter = "github-copilot/claude-sonnet-5.5";
        review-reliability = "github-copilot/claude-sonnet-5.5";
        review-resilience = "github-copilot/claude-sonnet-5.5";
        review-risk = "github-copilot/claude-sonnet-5.5";
        review-validator = "github-copilot/claude-sonnet-5.5";
        neutral = "github-copilot/gpt-5.4-mini";
      };
    }
    {
      name = "github-copilot-medium";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-6.1-sol";
        gentle-ai-explore = "github-copilot/claude-sonnet-5.5";
        gentle-ai-worker = "github-copilot/claude-haiku-5.5";
        gentle-ai-verify = "github-copilot/claude-sonnet-5.5";
        jd-judge-a = "github-copilot/claude-sonnet-5.5";
        jd-judge-b = "github-copilot/claude-sonnet-5.5";
        jd-fix-agent = "github-copilot/gpt-5.3-codex";
        review-readability = "github-copilot/claude-sonnet-5.5";
        review-refuter = "github-copilot/claude-sonnet-5.5";
        review-reliability = "github-copilot/claude-sonnet-5.5";
        review-resilience = "github-copilot/claude-sonnet-5.5";
        review-risk = "github-copilot/claude-sonnet-5.5";
        review-validator = "github-copilot/claude-sonnet-5.5";
        neutral = "github-copilot/claude-sonnet-5.5";
      };
    }
    {
      name = "github-copilot-full";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-6-astra";
        gentle-ai-explore = "github-copilot/gpt-6-astra";
        gentle-ai-worker = "github-copilot/gpt-5.3-codex";
        gentle-ai-verify = "github-copilot/gpt-6-astra";
        jd-judge-a = "github-copilot/gpt-6-astra";
        jd-judge-b = "github-copilot/claude-opus-5.5";
        jd-fix-agent = "github-copilot/gpt-5.3-codex";
        review-readability = "github-copilot/claude-opus-5.5";
        review-refuter = "github-copilot/gpt-6-astra";
        review-reliability = "github-copilot/gpt-6-astra";
        review-resilience = "github-copilot/claude-opus-5.5";
        review-risk = "github-copilot/gpt-6-astra";
        review-validator = "github-copilot/gpt-6-astra";
        neutral = "github-copilot/gpt-6-astra";
      };
    }
    {
      name = "nvidia";
      roles = {
        gentle-orchestrator = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        gentle-ai-explore = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        gentle-ai-worker = "nvidia/minimaxai/minimax-m3";
        gentle-ai-verify = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        jd-judge-a = "nvidia/nemotron-3-ultra-550b-a55b";
        jd-judge-b = "nvidia/nemotron-3-ultra-550b-a55b";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "nvidia/nemotron-3-ultra-550b-a55b";
        review-refuter = "nvidia/nemotron-3-ultra-550b-a55b";
        review-reliability = "nvidia/nemotron-3-ultra-550b-a55b";
        review-resilience = "nvidia/nemotron-3-ultra-550b-a55b";
        review-risk = "nvidia/nemotron-3-ultra-550b-a55b";
        review-validator = "nvidia/nemotron-3-ultra-550b-a55b";
        neutral = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
      };
    }
    {
      name = "github-copilot";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-5.4";
        gentle-ai-explore = "github-copilot/gpt-5.4";
        gentle-ai-worker = "github-copilot/gpt-5.3-codex";
        gentle-ai-verify = "github-copilot/claude-sonnet-4.6";
        jd-judge-a = "github-copilot/claude-sonnet-4.6";
        jd-judge-b = "github-copilot/claude-sonnet-4.6";
        jd-fix-agent = "github-copilot/gpt-5.3-codex";
        review-readability = "github-copilot/claude-sonnet-4.6";
        review-refuter = "github-copilot/claude-sonnet-4.6";
        review-reliability = "github-copilot/claude-sonnet-4.6";
        review-resilience = "github-copilot/claude-sonnet-4.6";
        review-risk = "github-copilot/claude-sonnet-4.6";
        review-validator = "github-copilot/claude-sonnet-4.6";
        neutral = "github-copilot/claude-sonnet-4.6";
      };
    }
    {
      name = "opencode-go-full";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/deepseek-v4-pro";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "opencode-go/deepseek-v4-pro";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/glm-5.3";
      };
    }
    {
      name = "opencode-go-medium";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/minimax-m3.1-flash";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/glm-5.3";
      };
    }
    {
      name = "opencode-go-light";
      roles = {
        gentle-orchestrator = "opencode-go/glm-5.3-flash";
        gentle-ai-explore = "opencode-go/minimax-m3.1-flash";
        gentle-ai-worker = "opencode-go/minimax-m3.1-flash";
        gentle-ai-verify = "opencode-go/glm-5.3-flash";
        jd-judge-a = "opencode-go/glm-5.3-flash";
        jd-judge-b = "opencode-go/glm-5.3-flash";
        jd-fix-agent = "opencode-go/minimax-m3.1-flash";
        review-readability = "opencode-go/glm-5.3-flash";
        review-refuter = "opencode-go/glm-5.3-flash";
        review-reliability = "opencode-go/glm-5.3-flash";
        review-resilience = "opencode-go/glm-5.3-flash";
        review-risk = "opencode-go/glm-5.3-flash";
        review-validator = "opencode-go/glm-5.3-flash";
        neutral = "opencode-go/glm-5.3-flash";
      };
    }
  ];

  _assertUniqueProviderNames =
    let
      names = map (p: p.name) providers;
    in
    assert lib.assertMsg (
      lib.length names == lib.length (lib.unique names)
    ) "providers-base.nix: duplicate provider name in providers list";
    true;

  activeProvider = builtins.foldl' (acc: p: if p.name == activeProviderName then p else acc) null (
    assert _assertUniqueProviderNames;
    providers
  );
  getModelForRole = role: provider: if provider == null then null else provider.roles.${role} or null;

in
{
  inherit
    nvidiaProvider
    providerAllowlist
    providers
    activeProviderName
    activeProvider
    getModelForRole
    ;
}
