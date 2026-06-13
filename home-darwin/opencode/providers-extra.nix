# Extra providers beyond the base 3 (nvidia, github-copilot, opencode-go)
# These are macOS-specific providers that can be merged with providers-base.nix
{ lib ? throw "providers-extra.nix must be imported with lib"
,
}:

let
  # Generate a provider attrset from a compact specification.
  # Returns `{ name = { npm, name, options, models }; }` ready to merge.
  mkProvider =
    { name
    , displayName
    , baseURL
    , apiKeyEnv
    , apiKeyValue ? "{env:${apiKeyEnv}}"
    , models
    , extraOptions ? { }
    ,
    }:
    {
      ${name} = {
        npm = "@ai-sdk/openai-compatible";
        name = displayName;
        options = {
          baseURL = baseURL;
          apiKey = apiKeyValue;
        }
        // extraOptions;
        inherit models;
      };
    };

  groqProvider = mkProvider {
    name = "groq";
    displayName = "Groq";
    baseURL = "https://api.groq.com/openai/v1";
    apiKeyEnv = "GROQ_API_KEY";
    models = {
      "llama-3.1-8b-instant" = {
        name = "Llama 3.1 8B Instant";
      };
      "llama-3.3-70b-versatile" = {
        name = "Llama 3.3 70B Versatile";
      };
      "meta-llama/llama-4-scout-17b-16e-instruct" = {
        name = "Llama 4 Scout";
      };
      "openai/gpt-oss-120b" = {
        name = "GPT-OSS 120B";
      };
      "openai/gpt-oss-20b" = {
        name = "GPT-OSS 20B";
      };
      "qwen/qwen3-32b" = {
        name = "Qwen3 32B";
      };
    };
  };

  cerebrasProvider = mkProvider {
    name = "cerebras";
    displayName = "Cerebras";
    baseURL = "https://api.cerebras.ai/v1";
    apiKeyEnv = "CEREBRAS_API_KEY";
    models = {
      "qwen-3-235b-a22b-instruct-2507" = {
        name = "Qwen3 235B";
      };
    };
  };

  mistralProvider = mkProvider {
    name = "mistral";
    displayName = "Mistral";
    baseURL = "https://api.mistral.ai/v1";
    apiKeyEnv = "MISTRAL_API_KEY";
    models = {
      "codestral-latest" = {
        name = "Codestral";
      };
      "devstral-latest" = {
        name = "Devstral";
      };
      "devstral-medium-latest" = {
        name = "Devstral Medium";
      };
      "devstral-small-2507" = {
        name = "Devstral Small";
      };
      "magistral-medium-latest" = {
        name = "Magistral Medium";
      };
      "magistral-small-latest" = {
        name = "Magistral Small";
      };
      "mistral-large-latest" = {
        name = "Mistral Large";
      };
      "mistral-medium-latest" = {
        name = "Mistral Medium";
      };
      "mistral-small-latest" = {
        name = "Mistral Small";
      };
      "mistral-tiny-latest" = {
        name = "Mistral Tiny";
      };
      "open-mistral-nemo" = {
        name = "Mistral Nemo";
      };
      "ministral-3b-latest" = {
        name = "Ministral 3B";
      };
      "ministral-8b-latest" = {
        name = "Ministral 8B";
      };
    };
  };

  cohereProvider = mkProvider {
    name = "cohere";
    displayName = "Cohere";
    baseURL = "https://api.cohere.ai/compatibility/v1";
    apiKeyEnv = "COHERE_API_KEY";
    models = {
      "command-a-03-2025" = {
        name = "Command A";
      };
      "command-a-reasoning-08-2025" = {
        name = "Command A Reasoning";
      };
      "command-a-translate-08-2025" = {
        name = "Command A Translate";
      };
      "command-a-vision-07-2025" = {
        name = "Command A Vision";
      };
      "command-r-plus-08-2024" = {
        name = "Command R Plus";
      };
      "command-r-08-2024" = {
        name = "Command R";
      };
      "command-r7b-12-2024" = {
        name = "Command R7B";
      };
    };
  };

  geminiProvider = mkProvider {
    name = "gemini";
    displayName = "Gemini";
    baseURL = "https://generativelanguage.googleapis.com/v1beta/openai";
    apiKeyEnv = "GEMINI_API_KEY";
    models = {
      "gemini-2.5-flash" = {
        name = "Gemini 2.5 Flash";
      };
      "gemini-2.5-flash-lite" = {
        name = "Gemini 2.5 Flash Lite";
      };
      "gemini-3.1-flash-lite-preview" = {
        name = "Gemini 3.1 Flash Lite";
      };
      "gemini-3-flash-preview" = {
        name = "Gemini 3 Flash";
      };
    };
  };

  cloudflareProvider = mkProvider {
    name = "cloudflare";
    displayName = "Cloudflare Workers AI";
    baseURL = "https://api.cloudflare.com/client/v4/accounts/{env:CLOUDFLARE_ACCOUNT_ID}/ai/v1";
    apiKeyEnv = "CLOUDFLARE_API_TOKEN";
    models = {
      "@cf/meta/llama-3.3-70b-instruct-fp8-fast" = {
        name = "Llama 3.3 70B";
      };
      "@cf/meta/llama-3.1-8b-instruct-fp8-fast" = {
        name = "Llama 3.1 8B";
      };
      "@cf/meta/llama-4-scout-17b-16e-instruct" = {
        name = "Llama 4 Scout";
      };
      "@cf/mistralai/mistral-small-3.1-24b-instruct" = {
        name = "Mistral Small 3.1";
      };
      "@cf/qwen/qwq-32b" = {
        name = "QwQ 32B";
      };
      "@cf/qwen/qwen2.5-coder-32b-instruct" = {
        name = "Qwen2.5 Coder 32B";
      };
      "@cf/qwen/qwen3-30b-a3b-fp8" = {
        name = "Qwen3 30B";
      };
      "@cf/google/gemma-3-12b-it" = {
        name = "Gemma 3 12B";
      };
      "@cf/google/gemma-4-26b-a4b-it" = {
        name = "Gemma 4 26B";
      };
      "@cf/openai/gpt-oss-120b" = {
        name = "GPT-OSS 120B";
      };
      "@cf/openai/gpt-oss-20b" = {
        name = "GPT-OSS 20B";
      };
      "@cf/nvidia/nemotron-3-120b-a12b" = {
        name = "Nemotron 3 120B";
      };
      "@cf/ibm-granite/granite-4.0-h-micro" = {
        name = "Granite 4.0";
      };
      "@cf/moonshotai/kimi-k2.5" = {
        name = "Kimi K2.5";
      };
    };
  };

  openrouterProvider = mkProvider {
    name = "openrouter";
    displayName = "OpenRouter";
    baseURL = "https://openrouter.ai/api/v1";
    apiKeyEnv = "OPENROUTER_API_KEY";
    extraOptions = {
      headers = {
        "HTTP-Referer" = "https://github.com/glats/nixos-hosts";
        "X-Title" = "opencode";
      };
    };
    models = {
      "openai/gpt-oss-120b:free" = {
        name = "GPT-OSS 120B Free";
      };
      "openai/gpt-oss-20b:free" = {
        name = "GPT-OSS 20B Free";
      };
      "nvidia/nemotron-3-super-120b-a12b:free" = {
        name = "Nemotron 3 Super Free";
      };
      "nousresearch/hermes-3-llama-3.1-405b:free" = {
        name = "Hermes 3 405B Free";
      };
      "google/gemma-3n-e4b-it:free" = {
        name = "Gemma 3n E4B Free";
      };
      "google/gemma-3-4b-it:free" = {
        name = "Gemma 3 4B Free";
      };
      "nvidia/nemotron-3-nano-30b-a3b:free" = {
        name = "Nemotron 3 Nano Free";
      };
      "nvidia/nemotron-nano-12b-v2-vl:free" = {
        name = "Nemotron Nano 12B Free";
      };
      "nvidia/nemotron-nano-9b-v2:free" = {
        name = "Nemotron Nano 9B Free";
      };
      "cognitivecomputations/dolphin-mistral-24b-venice-edition:free" = {
        name = "Dolphin Mistral 24B Free";
      };
      "openrouter/free" = {
        name = "OpenRouter Free";
      };
      "openrouter/owl-alpha" = {
        name = "OWL Alpha";
      };
      "poolside/laguna-m.1:free" = {
        name = "Laguna M.1 Free";
      };
      "poolside/laguna-xs.2:free" = {
        name = "Laguna XS.2 Free";
      };
      "tencent/hy3-preview:free" = {
        name = "HY3 Preview Free";
      };
      "z-ai/glm-4.5-air:free" = {
        name = "GLM 4.5 Air Free";
      };
      "baidu/qianfan-ocr-fast:free" = {
        name = "Qianfan OCR Free";
      };
      "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free" = {
        name = "Nemotron 3 Nano Reasoning Free";
      };
    };
  };

  huggingfaceProvider = mkProvider {
    name = "huggingface";
    displayName = "HuggingFace";
    baseURL = "https://router.huggingface.co/v1";
    apiKeyEnv = "HF_API_KEY";
    models = {
      "deepseek-ai/DeepSeek-V3-0324" = {
        name = "DeepSeek V3";
      };
      "deepseek-ai/DeepSeek-R1" = {
        name = "DeepSeek R1";
      };
      "google/gemma-3-27b-it" = {
        name = "Gemma 3 27B";
      };
      "meta-llama/Llama-3.1-8B-Instruct" = {
        name = "Llama 3.1 8B";
      };
      "meta-llama/Llama-3.3-70B-Instruct" = {
        name = "Llama 3.3 70B";
      };
      "Qwen/Qwen3-8B" = {
        name = "Qwen3 8B";
      };
      "Qwen/QwQ-32B" = {
        name = "QwQ 32B";
      };
    };
  };

  kiloProvider = mkProvider {
    name = "kilo";
    displayName = "Kilo";
    baseURL = "https://api.kilo.ai/api/gateway";
    apiKeyEnv = "KILO_API_KEY";
    models = {
      "kilo-auto/free" = {
        name = "Kilo Auto Free";
      };
      "nvidia/nemotron-3-super-120b-a12b:free" = {
        name = "Nemotron 3 Super Free";
      };
      "openrouter/free" = {
        name = "OpenRouter Free";
      };
      "openrouter/owl-alpha" = {
        name = "OWL Alpha";
      };
      "stepfun/step-3.5-flash:free" = {
        name = "Step 3.5 Flash Free";
      };
      "poolside/laguna-m.1:free" = {
        name = "Laguna M.1 Free";
      };
      "poolside/laguna-xs.2:free" = {
        name = "Laguna XS.2 Free";
      };
      "tencent/hy3-preview:free" = {
        name = "HY3 Preview Free";
      };
      "inclusionai/ling-2.6-1t:free" = {
        name = "Ling 2.6 1T Free";
      };
    };
  };

  llm7Provider = mkProvider {
    name = "llm7";
    displayName = "LLM7";
    baseURL = "https://api.llm7.io/v1";
    apiKeyEnv = "LLM7_API_KEY";
    apiKeyValue = "not-needed";
    models = {
      "GLM-4.6V-Flash" = {
        name = "GLM 4.6V Flash";
      };
      "codestral-latest" = {
        name = "Codestral";
      };
      "gpt-oss-20b" = {
        name = "GPT-OSS 20B";
      };
      "deepseek-r1-0528" = {
        name = "DeepSeek R1 0528";
      };
      "mistral-small-3.1-24b" = {
        name = "Mistral Small 3.1";
      };
      "qwen2.5-coder-32b" = {
        name = "Qwen2.5 Coder 32B";
      };
    };
  };

  # Merge all extra providers into a single attrset
  extraProviders =
    groqProvider
    // cerebrasProvider
    // mistralProvider
    // cohereProvider
    // geminiProvider
    // cloudflareProvider
    // openrouterProvider
    // huggingfaceProvider
    // kiloProvider
    // llm7Provider;
in
{
  inherit
    groqProvider
    cerebrasProvider
    mistralProvider
    cohereProvider
    geminiProvider
    cloudflareProvider
    openrouterProvider
    huggingfaceProvider
    kiloProvider
    llm7Provider
    extraProviders
    ;
}
