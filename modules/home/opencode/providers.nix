{ lib ? throw "providers.nix must be imported with lib" }:

let
  # ============================================================
  # Provider definitions — models available for tier assignment
  # Only models that PASSED verify-models.py are listed here
  # ============================================================

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
      "z-ai/glm5" = { name = "GLM 5"; };
      "z-ai/glm4.7" = { name = "GLM 4.7"; };
      "minimaxai/minimax-m2.7" = { name = "MiniMax M2.7"; };
      "minimaxai/minimax-m2.5" = { name = "MiniMax M2.5"; };
      "deepseek-ai/deepseek-v4-flash" = { name = "DeepSeek V4 Flash"; };
      "deepseek-ai/deepseek-v4-pro" = { name = "DeepSeek V4 Pro"; };
      "nvidia/nemotron-3-super-120b-a12b" = { name = "Nemotron 3 Super"; };
      "google/gemma-4-31b-it" = { name = "Gemma 4 31B"; };
      "meta/llama-4-maverick-17b-128e-instruct" = { name = "Llama 4 Maverick"; };
      "openai/gpt-oss-120b" = { name = "GPT-OSS 120B"; };
      "openai/gpt-oss-20b" = { name = "GPT-OSS 20B"; };
      "qwen/qwen3-coder-480b-a35b-instruct" = { name = "Qwen3 Coder 480B"; };
      "qwen/qwen3-next-80b-a3b-instruct" = { name = "Qwen3 Next 80B"; };
      "meta/llama-3.3-70b-instruct" = { name = "Llama 3.3 70B"; };
      "meta/llama-3.1-8b-instruct" = { name = "Llama 3.1 8B"; };
      "moonshotai/kimi-k2.6" = { name = "Kimi K2.6"; };
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
        "meta-llama/llama-4-scout-17b-16e-instruct" = { name = "Llama 4 Scout"; };
        "openai/gpt-oss-120b" = { name = "GPT-OSS 120B"; };
        "openai/gpt-oss-20b" = { name = "GPT-OSS 20B"; };
        "qwen/qwen3-32b" = { name = "Qwen3 32B"; };
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
        "qwen-3-235b-a22b-instruct-2507" = { name = "Qwen3 235B"; };
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
      };
    };
  };

  mistralProvider = {
    mistral = {
      npm = "@ai-sdk/openai-compatible";
      name = "Mistral";
      options = {
        baseURL = "https://api.mistral.ai/v1";
        apiKey = "{env:MISTRAL_API_KEY}";
      };
      models = {
        "codestral-latest" = { name = "Codestral"; };
        "devstral-latest" = { name = "Devstral"; };
        "devstral-medium-latest" = { name = "Devstral Medium"; };
        "devstral-small-2507" = { name = "Devstral Small"; };
        "magistral-medium-latest" = { name = "Magistral Medium"; };
        "magistral-small-latest" = { name = "Magistral Small"; };
        "mistral-large-latest" = { name = "Mistral Large"; };
        "mistral-medium-latest" = { name = "Mistral Medium"; };
        "mistral-small-latest" = { name = "Mistral Small"; };
        "mistral-tiny-latest" = { name = "Mistral Tiny"; };
        "open-mistral-nemo" = { name = "Mistral Nemo"; };
        "ministral-3b-latest" = { name = "Ministral 3B"; };
        "ministral-8b-latest" = { name = "Ministral 8B"; };
      };
    };
  };

  cohereProvider = {
    cohere = {
      npm = "@ai-sdk/openai-compatible";
      name = "Cohere";
      options = {
        baseURL = "https://api.cohere.ai/compatibility/v1";
        apiKey = "{env:COHERE_API_KEY}";
      };
      models = {
        "command-a-03-2025" = { name = "Command A"; };
        "command-a-reasoning-08-2025" = { name = "Command A Reasoning"; };
        "command-a-translate-08-2025" = { name = "Command A Translate"; };
        "command-a-vision-07-2025" = { name = "Command A Vision"; };
        "command-r-plus-08-2024" = { name = "Command R Plus"; };
        "command-r-08-2024" = { name = "Command R"; };
        "command-r7b-12-2024" = { name = "Command R7B"; };
      };
    };
  };

  geminiProvider = {
    gemini = {
      npm = "@ai-sdk/openai-compatible";
      name = "Gemini";
      options = {
        baseURL = "https://generativelanguage.googleapis.com/v1beta/openai";
        apiKey = "{env:GEMINI_API_KEY}";
      };
      models = {
        "gemini-2.5-flash" = { name = "Gemini 2.5 Flash"; };
        "gemini-2.5-flash-lite" = { name = "Gemini 2.5 Flash Lite"; };
        "gemini-3.1-flash-lite-preview" = { name = "Gemini 3.1 Flash Lite"; };
        "gemini-3-flash-preview" = { name = "Gemini 3 Flash"; };
      };
    };
  };

  cloudflareProvider = {
    cloudflare = {
      npm = "@ai-sdk/openai-compatible";
      name = "Cloudflare Workers AI";
      options = {
        baseURL = "https://api.cloudflare.com/client/v4/accounts/{env:CLOUDFLARE_ACCOUNT_ID}/ai/v1";
        apiKey = "{env:CLOUDFLARE_API_TOKEN}";
      };
      models = {
        "@cf/meta/llama-3.3-70b-instruct-fp8-fast" = { name = "Llama 3.3 70B"; };
        "@cf/meta/llama-3.1-8b-instruct-fp8-fast" = { name = "Llama 3.1 8B"; };
        "@cf/meta/llama-4-scout-17b-16e-instruct" = { name = "Llama 4 Scout"; };
        "@cf/mistralai/mistral-small-3.1-24b-instruct" = { name = "Mistral Small 3.1"; };
        "@cf/qwen/qwq-32b" = { name = "QwQ 32B"; };
        "@cf/qwen/qwen2.5-coder-32b-instruct" = { name = "Qwen2.5 Coder 32B"; };
        "@cf/qwen/qwen3-30b-a3b-fp8" = { name = "Qwen3 30B"; };
        "@cf/google/gemma-3-12b-it" = { name = "Gemma 3 12B"; };
        "@cf/google/gemma-4-26b-a4b-it" = { name = "Gemma 4 26B"; };
        "@cf/openai/gpt-oss-120b" = { name = "GPT-OSS 120B"; };
        "@cf/openai/gpt-oss-20b" = { name = "GPT-OSS 20B"; };
        "@cf/nvidia/nemotron-3-120b-a12b" = { name = "Nemotron 3 120B"; };
        "@cf/ibm-granite/granite-4.0-h-micro" = { name = "Granite 4.0"; };
        "@cf/moonshotai/kimi-k2.5" = { name = "Kimi K2.5"; };
      };
    };
  };

  openrouterProvider = {
    openrouter = {
      npm = "@ai-sdk/openai-compatible";
      name = "OpenRouter";
      options = {
        baseURL = "https://openrouter.ai/api/v1";
        apiKey = "{env:OPENROUTER_API_KEY}";
        headers = {
          "HTTP-Referer" = "https://github.com/glats/nixos-hosts";
          "X-Title" = "opencode";
        };
      };
      models = {
        "openai/gpt-oss-120b:free" = { name = "GPT-OSS 120B Free"; };
        "openai/gpt-oss-20b:free" = { name = "GPT-OSS 20B Free"; };
        "nvidia/nemotron-3-super-120b-a12b:free" = { name = "Nemotron 3 Super Free"; };
        "nousresearch/hermes-3-llama-3.1-405b:free" = { name = "Hermes 3 405B Free"; };
        "google/gemma-3n-e4b-it:free" = { name = "Gemma 3n E4B Free"; };
        "google/gemma-3-4b-it:free" = { name = "Gemma 3 4B Free"; };
        "nvidia/nemotron-3-nano-30b-a3b:free" = { name = "Nemotron 3 Nano Free"; };
        "nvidia/nemotron-nano-12b-v2-vl:free" = { name = "Nemotron Nano 12B Free"; };
        "nvidia/nemotron-nano-9b-v2:free" = { name = "Nemotron Nano 9B Free"; };
        "cognitivecomputations/dolphin-mistral-24b-venice-edition:free" = { name = "Dolphin Mistral 24B Free"; };
        "openrouter/free" = { name = "OpenRouter Free"; };
        "openrouter/owl-alpha" = { name = "OWL Alpha"; };
        "poolside/laguna-m.1:free" = { name = "Laguna M.1 Free"; };
        "poolside/laguna-xs.2:free" = { name = "Laguna XS.2 Free"; };
        "tencent/hy3-preview:free" = { name = "HY3 Preview Free"; };
        "z-ai/glm-4.5-air:free" = { name = "GLM 4.5 Air Free"; };
        "baidu/qianfan-ocr-fast:free" = { name = "Qianfan OCR Free"; };
        "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free" = { name = "Nemotron 3 Nano Reasoning Free"; };
      };
    };
  };

  huggingfaceProvider = {
    huggingface = {
      npm = "@ai-sdk/openai-compatible";
      name = "HuggingFace";
      options = {
        baseURL = "https://router.huggingface.co/v1";
        apiKey = "{env:HF_API_KEY}";
      };
      models = {
        "deepseek-ai/DeepSeek-V3-0324" = { name = "DeepSeek V3"; };
        "deepseek-ai/DeepSeek-R1" = { name = "DeepSeek R1"; };
        "google/gemma-3-27b-it" = { name = "Gemma 3 27B"; };
        "meta-llama/Llama-3.1-8B-Instruct" = { name = "Llama 3.1 8B"; };
        "meta-llama/Llama-3.3-70B-Instruct" = { name = "Llama 3.3 70B"; };
        "Qwen/Qwen3-8B" = { name = "Qwen3 8B"; };
        "Qwen/QwQ-32B" = { name = "QwQ 32B"; };
      };
    };
  };

  kiloProvider = {
    kilo = {
      npm = "@ai-sdk/openai-compatible";
      name = "Kilo";
      options = {
        baseURL = "https://api.kilo.ai/api/gateway";
        apiKey = "{env:KILO_API_KEY}";
      };
      models = {
        "kilo-auto/free" = { name = "Kilo Auto Free"; };
        "nvidia/nemotron-3-super-120b-a12b:free" = { name = "Nemotron 3 Super Free"; };
        "openrouter/free" = { name = "OpenRouter Free"; };
        "openrouter/owl-alpha" = { name = "OWL Alpha"; };
        "stepfun/step-3.5-flash:free" = { name = "Step 3.5 Flash Free"; };
        "poolside/laguna-m.1:free" = { name = "Laguna M.1 Free"; };
        "poolside/laguna-xs.2:free" = { name = "Laguna XS.2 Free"; };
        "tencent/hy3-preview:free" = { name = "HY3 Preview Free"; };
        "inclusionai/ling-2.6-1t:free" = { name = "Ling 2.6 1T Free"; };
      };
    };
  };

  llm7Provider = {
    llm7 = {
      npm = "@ai-sdk/openai-compatible";
      name = "LLM7";
      options = {
        baseURL = "https://api.llm7.io/v1";
        apiKey = "not-needed";
      };
      models = {
        "GLM-4.6V-Flash" = { name = "GLM 4.6V Flash"; };
        "codestral-latest" = { name = "Codestral"; };
        "gpt-oss-20b" = { name = "GPT-OSS 20B"; };
        "deepseek-r1-0528" = { name = "DeepSeek R1 0528"; };
        "mistral-small-3.1-24b" = { name = "Mistral Small 3.1"; };
        "qwen2.5-coder-32b" = { name = "Qwen2.5 Coder 32B"; };
      };
    };
  };

allProviders =
  nvidiaProvider
  // groqProvider
    // cerebrasProvider
    // opencodeZenProvider
    // mistralProvider
    // cohereProvider
    // geminiProvider
    // cloudflareProvider
    // openrouterProvider
    // huggingfaceProvider
    // kiloProvider
    // llm7Provider;

  activeProviderName = "opencode-go";

  # ============================================================
  # Tier assignments — best verified model per SDD phase
  # ============================================================

  providers = [
    # --- Single-provider tiers ---

    {
      name = "nvidia";
      phases = {
        sdd-orchestrator = "nvidia/z-ai/glm-5.1";
        sdd-init = "nvidia/minimaxai/minimax-m2.7";
        sdd-explore = "nvidia/z-ai/glm-5.1";
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

  {
    name = "nvidia2";
    phases = {
      # GLM5: best agentic/coding model verified (SWE-Bench #1)
      sdd-orchestrator = "nvidia/z-ai/glm5";
      # Nemotron 3 Super: 732ms, 120B — fast init
      sdd-init = "nvidia/nvidia/nemotron-3-super-120b-a12b";
      # Llama 4 Maverick: 398ms, fast exploration
      sdd-explore = "nvidia/meta/llama-4-maverick-17b-128e-instruct";
      # GLM5: strong proposal writer
      sdd-propose = "nvidia/z-ai/glm5";
      # Qwen3 Coder 480B: structured spec generation
      sdd-spec = "nvidia/qwen/qwen3-coder-480b-a35b-instruct";
      # GLM5: deep reasoning for design
      sdd-design = "nvidia/z-ai/glm5";
      # Qwen3 Coder 480B: precise task decomposition
      sdd-tasks = "nvidia/qwen/qwen3-coder-480b-a35b-instruct";
      # MiniMax M2.7: coding strong, 24s acceptable for apply
      sdd-apply = "nvidia/minimaxai/minimax-m2.7";
      # GLM4.7: 9.7s, good analysis
      sdd-verify = "nvidia/z-ai/glm4.7";
      # GPT-OSS 20B: 332ms, fast archive
      sdd-archive = "nvidia/openai/gpt-oss-20b";
      # GPT-OSS 20B: fast onboard
      sdd-onboard = "nvidia/openai/gpt-oss-20b";
      neutral = "nvidia/z-ai/glm5";
    };
  }

    {
      name = "groq";
      phases = {
        # Llama 3.3 70B: 324ms, best reasoning on Groq
        sdd-orchestrator = "groq/llama-3.3-70b-versatile";
        # Llama 3.1 8B: 646ms, fast init
        sdd-init = "groq/llama-3.1-8b-instant";
        # Llama 4 Scout: 407ms, fast explore
        sdd-explore = "groq/meta-llama/llama-4-scout-17b-16e-instruct";
        # GPT-OSS 120B: 275ms, strong proposal
        sdd-propose = "groq/openai/gpt-oss-120b";
        # Qwen3 32B: 325ms, structured spec
        sdd-spec = "groq/qwen/qwen3-32b";
        # GPT-OSS 120B: strong design reasoning
        sdd-design = "groq/openai/gpt-oss-120b";
        # Qwen3 32B: structured tasks
        sdd-tasks = "groq/qwen/qwen3-32b";
        # GPT-OSS 20B: 228ms, fast apply
        sdd-apply = "groq/openai/gpt-oss-20b";
        # Llama 3.1 8B: fast verify
        sdd-verify = "groq/llama-3.1-8b-instant";
        # GPT-OSS 20B: fast archive
        sdd-archive = "groq/openai/gpt-oss-20b";
        # Llama 3.1 8B: fast onboard
        sdd-onboard = "groq/llama-3.1-8b-instant";
        neutral = "groq/llama-3.3-70b-versatile";
      };
    }

    {
      name = "cerebras";
      phases = {
        # Only qwen-3-235b verified on Cerebras
        sdd-orchestrator = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-init = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-explore = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-propose = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-spec = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-design = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-tasks = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-apply = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-verify = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-archive = "cerebras/qwen-3-235b-a22b-instruct-2507";
        sdd-onboard = "cerebras/qwen-3-235b-a22b-instruct-2507";
        neutral = "cerebras/qwen-3-235b-a22b-instruct-2507";
      };
    }

    {
      name = "mistral";
      phases = {
        # Magistral Medium: best reasoning in Mistral family
        sdd-orchestrator = "mistral/magistral-medium-latest";
        # Mistral Tiny: 408ms, fast init
        sdd-init = "mistral/mistral-tiny-latest";
        # Mistral Small: 420ms, fast explore
        sdd-explore = "mistral/mistral-small-latest";
        # Magistral Medium: strong proposal writing
        sdd-propose = "mistral/magistral-medium-latest";
        # Mistral Large: structured spec
        sdd-spec = "mistral/mistral-large-latest";
        # Magistral Medium: deep design reasoning
        sdd-design = "mistral/magistral-medium-latest";
        # Mistral Large: precise task decomposition
        sdd-tasks = "mistral/mistral-large-latest";
        # Devstral Medium: coding specialist, 418ms
        sdd-apply = "mistral/devstral-medium-latest";
        # Devstral: code review/verify, 417ms
        sdd-verify = "mistral/devstral-latest";
        # Mistral Tiny: fast archive
        sdd-archive = "mistral/mistral-tiny-latest";
        # Ministral 3B: 327ms, ultra-fast onboard
        sdd-onboard = "mistral/ministral-3b-latest";
        neutral = "mistral/magistral-medium-latest";
      };
    }

    {
      name = "cohere";
      phases = {
        # Command A Reasoning: 350ms, specialized reasoning
        sdd-orchestrator = "cohere/command-a-reasoning-08-2025";
        # Command R7B: 307ms, ultra-fast init
        sdd-init = "cohere/command-r7b-12-2024";
        # Command R7B: fast explore
        sdd-explore = "cohere/command-r7b-12-2024";
        # Command A: strong proposal, 2.4s
        sdd-propose = "cohere/command-a-03-2025";
        # Command A Reasoning: structured specs
        sdd-spec = "cohere/command-a-reasoning-08-2025";
        # Command A Reasoning: deep design
        sdd-design = "cohere/command-a-reasoning-08-2025";
        # Command R Plus: structured tasks, 609ms
        sdd-tasks = "cohere/command-r-plus-08-2024";
        # Command A: coding apply
        sdd-apply = "cohere/command-a-03-2025";
        # Command A Reasoning: analysis/verify
        sdd-verify = "cohere/command-a-reasoning-08-2025";
        # Command R7B: fast archive
        sdd-archive = "cohere/command-r7b-12-2024";
        # Command R7B: fast onboard
        sdd-onboard = "cohere/command-r7b-12-2024";
        neutral = "cohere/command-a-03-2025";
      };
    }

    {
      name = "gemini";
      phases = {
        # Gemini 2.5 Flash: 1.4s, best available
        sdd-orchestrator = "gemini/gemini-2.5-flash";
        # Flash Lite: 610ms, fast init
        sdd-init = "gemini/gemini-2.5-flash-lite";
        # Flash Lite: fast explore
        sdd-explore = "gemini/gemini-2.5-flash-lite";
        # Gemini 2.5 Flash: proposal
        sdd-propose = "gemini/gemini-2.5-flash";
        # Gemini 3 Flash: structured spec
        sdd-spec = "gemini/gemini-3-flash-preview";
        # Gemini 2.5 Flash: design
        sdd-design = "gemini/gemini-2.5-flash";
        # Gemini 3 Flash: tasks
        sdd-tasks = "gemini/gemini-3-flash-preview";
        # Flash Lite: fast apply
        sdd-apply = "gemini/gemini-2.5-flash-lite";
        # Flash Lite: fast verify
        sdd-verify = "gemini/gemini-2.5-flash-lite";
        # Flash Lite: fast archive
        sdd-archive = "gemini/gemini-2.5-flash-lite";
        # Flash Lite: fast onboard
        sdd-onboard = "gemini/gemini-2.5-flash-lite";
        neutral = "gemini/gemini-2.5-flash";
      };
    }

    # --- Combined tiers ---

    {
      name = "stable";
      phases = {
        # Mistral Magistral Medium: 14/14 OK, 499ms, no rate limits
        sdd-orchestrator = "mistral/magistral-medium-latest";
        # Cohere R7B: 7/7 OK, 307ms, rock solid
        sdd-init = "cohere/command-r7b-12-2024";
        # Cloudflare Llama 3.1 8B: 14/15 OK, 446ms, no rate limits
        sdd-explore = "cloudflare/@cf/meta/llama-3.1-8b-instruct-fp8-fast";
        # Cohere Command A Reasoning: 7/7 OK, 350ms
        sdd-propose = "cohere/command-a-reasoning-08-2025";
        # Mistral Large: 14/14 OK, structured output
        sdd-spec = "mistral/mistral-large-latest";
        # Cohere Command A Reasoning: deep design, no limits
        sdd-design = "cohere/command-a-reasoning-08-2025";
        # Mistral Large: precise tasks
        sdd-tasks = "mistral/mistral-large-latest";
        # Mistral Devstral Medium: coding, 418ms
        sdd-apply = "mistral/devstral-medium-latest";
        # Mistral Devstral: code verify, 417ms
        sdd-verify = "mistral/devstral-latest";
        # Cloudflare GPT-OSS 20B: fast archive
        sdd-archive = "cloudflare/@cf/openai/gpt-oss-20b";
        # Cohere R7B: fast onboard
        sdd-onboard = "cohere/command-r7b-12-2024";
        neutral = "mistral/magistral-medium-latest";
      };
    }

    {
      name = "fast";
      phases = {
        # Groq GPT-OSS 120B: 275ms, strong
        sdd-orchestrator = "groq/openai/gpt-oss-120b";
        # Groq Llama 3.1 8B: 646ms
        sdd-init = "groq/llama-3.1-8b-instant";
        # Cloudflare Llama 4 Scout: 518ms
        sdd-explore = "cloudflare/@cf/meta/llama-4-scout-17b-16e-instruct";
        # Groq GPT-OSS 120B: 275ms
        sdd-propose = "groq/openai/gpt-oss-120b";
        # Groq Qwen3 32B: 325ms, structured
        sdd-spec = "groq/qwen/qwen3-32b";
        # Cerebras Qwen3 235B: 1.3s, deep reasoning
        sdd-design = "cerebras/qwen-3-235b-a22b-instruct-2507";
        # Groq Qwen3 32B: 325ms
        sdd-tasks = "groq/qwen/qwen3-32b";
        # Groq GPT-OSS 20B: 228ms, fastest
        sdd-apply = "groq/openai/gpt-oss-20b";
        # Cloudflare Mistral Small: 477ms
        sdd-verify = "cloudflare/@cf/mistralai/mistral-small-3.1-24b-instruct";
        # Cloudflare GPT-OSS 20B: 502ms
        sdd-archive = "cloudflare/@cf/openai/gpt-oss-20b";
        # Groq Llama 3.1 8B: 646ms
        sdd-onboard = "groq/llama-3.1-8b-instant";
        neutral = "groq/openai/gpt-oss-120b";
      };
    }

    {
      name = "budget";
      phases = {
        # OpenRouter GPT-OSS 120B Free
        sdd-orchestrator = "openrouter/openai/gpt-oss-120b:free";
        # LLM7 GPT-OSS 20B: no key needed
        sdd-init = "llm7/gpt-oss-20b";
        # Kilo Step 3.5 Flash: 714ms
        sdd-explore = "kilo/stepfun/step-3.5-flash:free";
        # OpenCode Zen Big Pickle: 1.8s
        sdd-propose = "opencode/big-pickle";
        # LLM7 Codestral: structured
        sdd-spec = "llm7/codestral-latest";
        # OpenCode Zen Big Pickle
        sdd-design = "opencode/big-pickle";
        # LLM7 Qwen2.5 Coder: structured tasks
        sdd-tasks = "llm7/qwen2.5-coder-32b";
        # OpenCode Zen MiniMax M2.5: coding
        sdd-apply = "opencode/minimax-m2.5-free";
        # LLM7 Mistral Small: verify
        sdd-verify = "llm7/mistral-small-3.1-24b";
        # LLM7 GPT-OSS 20B: fast archive
        sdd-archive = "llm7/gpt-oss-20b";
        # Kilo OpenRouter Free: onboard
        sdd-onboard = "kilo/openrouter/free";
        neutral = "openrouter/openai/gpt-oss-120b:free";
      };
    }

    # --- Preserved tiers (DO NOT MODIFY) ---

    {
      name = "github-copilot";
      phases = {
        sdd-orchestrator = "github-copilot/claude-sonnet-4.6";
        sdd-init = "github-copilot/claude-sonnet-4.6";
        sdd-explore = "github-copilot/claude-sonnet-4.6";
        sdd-propose = "github-copilot/claude-sonnet-4.6";
        sdd-spec = "github-copilot/claude-sonnet-4.6";
        sdd-design = "github-copilot/claude-sonnet-4.6";
        sdd-tasks = "github-copilot/claude-sonnet-4.6";
        sdd-apply = "github-copilot/claude-sonnet-4.6";
        sdd-verify = "github-copilot/claude-sonnet-4.6";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/claude-sonnet-4.6";
        neutral = "github-copilot/claude-sonnet-4.6";
      };
    }

    {
      name = "github-copilot-student";
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
      };
    }

    {
      name = "opencode-go";
      phases = {
        sdd-orchestrator = "opencode-go/kimi-k2.6";
        sdd-init = "opencode-go/minimax-m2.7";
        sdd-explore = "opencode-go/deepseek-v4-flash";
        sdd-propose = "opencode-go/kimi-k2.6";
        sdd-spec = "opencode-go/qwen3.6-plus";
        sdd-design = "opencode-go/glm-5.1";
        sdd-tasks = "opencode-go/deepseek-v4-pro";
        sdd-apply = "opencode-go/minimax-m2.7";
        sdd-verify = "opencode-go/glm-5.1";
        sdd-archive = "opencode-go/mimo-v2.5-pro";
        sdd-onboard = "opencode-go/mimo-v2.5-pro";
        neutral = "opencode-go/kimi-k2.6";
      };
    }
  ];

  activeProvider = builtins.foldl' (acc: p: if p.name == activeProviderName then p else acc) null providers;
  getModelForPhase = phase: provider: if provider == null then null else provider.phases.${phase} or null;

in
{
  inherit nvidiaProvider groqProvider cerebrasProvider opencodeZenProvider;
  inherit mistralProvider cohereProvider geminiProvider cloudflareProvider;
  inherit openrouterProvider huggingfaceProvider kiloProvider llm7Provider;
  inherit allProviders providers activeProviderName activeProvider getModelForPhase;
}
