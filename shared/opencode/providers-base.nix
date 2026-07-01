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
        # RISKY: glm-5.2 — cache bug opencode#33998 causes context drops. Do not assign to orchestrator, design, or explore.
        "glm-5.2" = {
          name = "GLM 5.2";
          thinking = false;
        };
        "glm-5.1" = {
          name = "GLM 5.1";
          thinking = false;
        };
        # BLOCKED: kimi-k2.6 onboard — hermes-agent#35180 (HTTP 400 on thinking toggle). Re-evaluate when merged.
        "kimi-k2.6" = {
          name = "Kimi K2.6";
          thinking = false;
        };
        "kimi-k2.7-code" = {
          name = "Kimi K2.7 Code";
          thinking = false;
        };
        "deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
          thinking = false;
        };
        "deepseek-v4-flash" = {
          name = "DeepSeek V4 Flash";
          thinking = false;
        };
        "mimo-v2.5" = {
          name = "MiMo V2.5";
          thinking = false;
        };
        "mimo-v2.5-pro" = {
          name = "MiMo V2.5 Pro";
          thinking = false;
        };
        # BROKEN (upstream): Qwen 3.6+/3.7+ models on the opencode-go endpoint use
        # Anthropic Messages transport which emits content-block shapes the AI SDK
        # rejects (invalid_union, discriminator "type"). When upstream fixes land,
        # re-enable by swapping phase assignments below. See:
        #   opencode/opencode#23960 — anthropic-sdk content-block union mismatch
        #   opencode/opencode#32418 — reasoning_content in content_block_start
        #   opencode/opencode#29754 — Qwen reasoning block shape
        #   opencode/opencode#33055 — Cloudflare 524 HTML in text blocks
        #   opencode/opencode#33303 — content_block_delta missing fields
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
      name = "opencode-go-full";
      phases = {
        gentle-orchestrator = "opencode-go/deepseek-v4-pro";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "opencode-go/deepseek-v4-pro";
        sdd-spec = "opencode-go/deepseek-v4-pro";
        sdd-design = "opencode-go/glm-5.1";
        sdd-tasks = "opencode-go/deepseek-v4-pro";
        sdd-apply = "opencode-go/deepseek-v4-pro";
        sdd-verify = "opencode-go/glm-5.1";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        neutral = "opencode-go/deepseek-v4-pro";
      };
    }
    {
      name = "opencode-go-medium";
      phases = {
        gentle-orchestrator = "opencode-go/deepseek-v4-pro";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "opencode-go/deepseek-v4-pro";
        sdd-spec = "opencode-go/deepseek-v4-pro";
        sdd-design = "opencode-go/glm-5.1";
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        sdd-apply = "opencode-go/deepseek-v4-flash";
        sdd-verify = "opencode-go/deepseek-v4-pro";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "opencode-go-light";
      phases = {
        gentle-orchestrator = "opencode-go/deepseek-v4-flash";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "opencode-go/deepseek-v4-pro";
        sdd-spec = "opencode-go/deepseek-v4-pro";
        sdd-design = "opencode-go/deepseek-v4-pro";
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        sdd-apply = "opencode-go/deepseek-v4-flash";
        sdd-verify = "opencode-go/deepseek-v4-pro";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        neutral = "opencode-go/deepseek-v4-flash";
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
