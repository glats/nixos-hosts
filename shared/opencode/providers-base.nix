{
  lib ? throw "providers-base.nix must be imported with lib",
  activeProviderName ? "personal",
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
    "ollama-cloud"
    "anthropic"
    "openai"
    "github-copilot"
    "nvidia"
  ];

  providers = [
    {
      name = "personal";
      tiers = {
        big = [
          "anthropic/claude-opus-5-5"
          "openai/gpt-6-astra"
        ];
        mid = [
          "anthropic/claude-sonnet-5-5"
          "openai/gpt-6.1-sol"
          "ollama-cloud/deepseek-v4-pro"
        ];
        low = [
          "anthropic/claude-haiku-5-5"
          "openai/gpt-6.1-terra"
          "ollama-cloud/minimax-m3.1-flash"
        ];
      };
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "ollama-cloud/deepseek-v4-pro";
        gentle-ai-worker = "ollama-cloud/minimax-m3.1-flash";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "ollama-cloud/minimax-m3.1-flash";
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
      name = "personal-degraded";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
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
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "anthropic-ollama";
      tiers = {
        big = [ "anthropic/claude-opus-5-5" ];
        mid = [
          "anthropic/claude-sonnet-5-5"
          "ollama-cloud/deepseek-v4-pro"
        ];
        low = [
          "ollama-cloud/minimax-m3.1-flash"
          "anthropic/claude-haiku-5-5"
        ];
      };
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "ollama-cloud/deepseek-v4-pro";
        gentle-ai-worker = "ollama-cloud/minimax-m3.1-flash";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "ollama-cloud/minimax-m3.1-flash";
        review-readability = "ollama-cloud/deepseek-v4-pro";
        review-refuter = "ollama-cloud/deepseek-v4-pro";
        review-reliability = "ollama-cloud/deepseek-v4-pro";
        review-resilience = "ollama-cloud/deepseek-v4-pro";
        review-risk = "ollama-cloud/deepseek-v4-pro";
        review-validator = "ollama-cloud/deepseek-v4-pro";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "openai-ollama";
      tiers = {
        big = [ "openai/gpt-6-astra" ];
        mid = [
          "openai/gpt-6.1-sol"
          "ollama-cloud/deepseek-v4-pro"
        ];
        low = [
          "ollama-cloud/minimax-m3.1-flash"
          "openai/gpt-6.1-terra"
        ];
      };
      roles = {
        gentle-orchestrator = "openai/gpt-6-astra";
        gentle-ai-explore = "ollama-cloud/deepseek-v4-pro";
        gentle-ai-worker = "ollama-cloud/minimax-m3.1-flash";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "ollama-cloud/minimax-m3.1-flash";
        review-readability = "ollama-cloud/deepseek-v4-pro";
        review-refuter = "ollama-cloud/deepseek-v4-pro";
        review-reliability = "ollama-cloud/deepseek-v4-pro";
        review-resilience = "ollama-cloud/deepseek-v4-pro";
        review-risk = "ollama-cloud/deepseek-v4-pro";
        review-validator = "ollama-cloud/deepseek-v4-pro";
        neutral = "openai/gpt-6-astra";
      };
    }
    {
      name = "work";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "github-copilot/claude-sonnet-5.5";
        gentle-ai-worker = "github-copilot/claude-haiku-5.5";
        gentle-ai-verify = "github-copilot/gpt-6.1-sol";
        jd-judge-a = "github-copilot/gpt-6.1-sol";
        jd-judge-b = "github-copilot/gpt-6.1-sol";
        jd-fix-agent = "github-copilot/claude-haiku-5.5";
        review-readability = "github-copilot/gpt-6.1-sol";
        review-refuter = "github-copilot/gpt-6.1-sol";
        review-reliability = "github-copilot/gpt-6.1-sol";
        review-resilience = "github-copilot/gpt-6.1-sol";
        review-risk = "github-copilot/gpt-6.1-sol";
        review-validator = "github-copilot/gpt-6.1-sol";
        neutral = "anthropic/claude-opus-5-5";
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
