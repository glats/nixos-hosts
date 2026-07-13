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
        # RISKY: glm-5.1 "gives up too quickly" on failures. OK for spec, not for apply/verify.
        "z-ai/glm-5.1" = {
          name = "GLM 5.1";
        };
        "minimaxai/minimax-m3" = {
          name = "MiniMax M3";
        };
        # BROKEN: minimax-m2.7 — TUI crash concurrent tools (opencode#19463), stops mid-plan (oh-my-openagent#3198).
        # Do not assign to explore or any phase requiring parallel tool calls.
        "minimaxai/minimax-m2.7" = {
          name = "MiniMax M2.7";
        };
        "deepseek-ai/deepseek-v4-flash" = {
          name = "DeepSeek V4 Flash";
        };
        # RISKY on NIM: deepseek-v4-pro — tool-call streaming may not continue in agent workflows
        # (NVIDIA forum Apr 27), requires chat_template_kwargs or hangs (opencode#24264).
        # Use nemotron-3-ultra for orchestration/reasoning phases instead.
        "deepseek-ai/deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
        };
        "nvidia/nemotron-3-ultra-550b-a55b" = {
          name = "Nemotron 3 Ultra";
        };
        # RISKY: step-3.7-flash — 11B active = low knowledge storage. Fragile on long multi-turn.
        # Terminal-Bench gap (59.5 vs 82.7). Best with Advisor Mode. Use only for tasks with clear scope.
        "stepfun-ai/step-3.7-flash" = {
          name = "Step 3.7 Flash";
        };
        "mistralai/mistral-medium-3.5-128b" = {
          name = "Mistral Medium 3.5";
        };
        # RISKY: gemma-4 — mixed implementation quality. Best as "coding partner" not autonomous agent.
        "google/gemma-4-31b-it" = {
          name = "Gemma 4";
        };
        # BROKEN: qwen3.5 on hosted NIM — "System message must be at beginning" (opencode#16560, #20785).
        # Fix PR #16981 not merged. Tool calls fail silently without custom chat template. Do not assign.
        "qwen/qwen3.5-397b-a17b" = {
          name = "Qwen 3.5";
        };
        # BROKEN: gpt-oss-120b multi-turn — subagent stops mid-reasoning (opencode#27210).
        # Requires Responses API, not Chat Completions. Do not assign to any phase.
        "openai/gpt-oss-120b" = {
          name = "GPT OSS 120b";
        };
        # BROKEN: kimi-k2.6 on NIM — HTTP 500 "unhashable type: 'dict'" (opencode#26662, #26405),
        # infinite "!!!" repetition loops, 30 RPH. Do not assign to any phase.
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

  # Anthropic provider: built-in in OpenCode, auth via /connect (Claude Pro/Max/Teams/Enterprise OAuth).
  # Models assigned per tier below. No apiKey needed — OpenCode handles OAuth natively.
  anthropicProvider = {
    anthropic = {
      models = {
        "claude-opus-4-8" = {
          name = "Claude Opus 4.8";
        };
        "claude-sonnet-4-6" = {
          name = "Claude Sonnet 4.6";
        };
        "claude-haiku-4-5" = {
          name = "Claude Haiku 4.5";
        };
      };
    };
  };

  allProviders = nvidiaProvider // opencodeProvider // anthropicProvider;

  providers = [
    {
      name = "anthropic-full";
      phases = {
        # claude-opus-4-8: strongest reasoning, architecture, and planning
        gentle-orchestrator = "anthropic/claude-opus-4-8";
        # claude-haiku-4-5: fast, cheap — enough for init boilerplate
        sdd-init = "anthropic/claude-haiku-4-5";
        # claude-sonnet-4-6: balanced — good for codebase exploration
        sdd-explore = "anthropic/claude-sonnet-4-6";
        # claude-opus-4-8: architectural decisions benefit from strongest model
        sdd-propose = "anthropic/claude-opus-4-8";
        # claude-sonnet-4-6: structured writing, good enough
        sdd-spec = "anthropic/claude-sonnet-4-6";
        # claude-opus-4-8: architecture decisions
        sdd-design = "anthropic/claude-opus-4-8";
        # claude-sonnet-4-6: mechanical breakdown
        sdd-tasks = "anthropic/claude-sonnet-4-6";
        # claude-sonnet-4-6: implementation
        sdd-apply = "anthropic/claude-sonnet-4-6";
        # claude-sonnet-4-6: validation against spec
        sdd-verify = "anthropic/claude-sonnet-4-6";
        # claude-haiku-4-5: 0.33x cost, fastest — copy and close
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "anthropic/claude-sonnet-4-6";
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "anthropic-medium";
      phases = {
        # claude-sonnet-4-6: balanced default for coordination
        gentle-orchestrator = "anthropic/claude-sonnet-4-6";
        sdd-init = "anthropic/claude-haiku-4-5";
        sdd-explore = "anthropic/claude-sonnet-4-6";
        # claude-opus-4-8: only the two heaviest architecture phases get opus
        sdd-propose = "anthropic/claude-opus-4-8";
        sdd-spec = "anthropic/claude-sonnet-4-6";
        sdd-design = "anthropic/claude-opus-4-8";
        sdd-tasks = "anthropic/claude-sonnet-4-6";
        sdd-apply = "anthropic/claude-sonnet-4-6";
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "anthropic/claude-sonnet-4-6";
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "anthropic-light";
      phases = {
        # claude-sonnet-4-6: good enough for light tier coordination
        gentle-orchestrator = "anthropic/claude-sonnet-4-6";
        sdd-init = "anthropic/claude-haiku-4-5";
        sdd-explore = "anthropic/claude-sonnet-4-6";
        sdd-propose = "anthropic/claude-sonnet-4-6";
        sdd-spec = "anthropic/claude-sonnet-4-6";
        sdd-design = "anthropic/claude-sonnet-4-6";
        sdd-tasks = "anthropic/claude-haiku-4-5";
        sdd-apply = "anthropic/claude-sonnet-4-6";
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "anthropic/claude-haiku-4-5";
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "nvidia";
      phases = {
        gentle-orchestrator = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        sdd-init = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-explore = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        sdd-propose = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        sdd-spec = "nvidia/mistralai/mistral-medium-3.5-128b";
        sdd-design = "nvidia/mistralai/mistral-medium-3.5-128b";
        sdd-tasks = "nvidia/minimaxai/minimax-m3";
        sdd-apply = "nvidia/minimaxai/minimax-m3";
        sdd-verify = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
        sdd-archive = "nvidia/deepseek-ai/deepseek-v4-flash";
        sdd-onboard = "nvidia/deepseek-ai/deepseek-v4-flash";
        neutral = "nvidia/nvidia/nemotron-3-ultra-550b-a55b";
      };
    }
    # PLAN DEPENDENCY: github-copilot model availability depends on Copilot plan:
    #   Free/Student — only gpt-4.1, gpt-4o, gpt-4o-mini (none of the below work)
    #   Pro — gpt-5.x (except 5.5), claude-sonnet-4.6, claude-haiku-4.5
    #   Pro+/Max/Business/Enterprise — all models below including claude-opus-4.8
    # Provider auth issues: Business/Enterprise may need token exchange (opencode#20759 OPEN).
    # Verify with `opencode run -m github-copilot/<model> "hi"` if models fail to respond.
    {
      name = "github-copilot";
      phases = {
        # gpt-5.4: fast execution + tool orchestration (binaryverseai), 400K ctx
        gentle-orchestrator = "github-copilot/gpt-5.4";
        # gpt-5.4-mini: 0.33x cost, 400K ctx, budget king (Ray Busuttil guide)
        sdd-init = "github-copilot/gpt-5.4-mini";
        # gpt-5.4: 400K ctx for large repo exploration, fast tool calls
        sdd-explore = "github-copilot/gpt-5.4";
        # claude-sonnet-4.6: best architecture + code review (0.71 recall, agent-validator)
        sdd-propose = "github-copilot/claude-sonnet-4.6";
        sdd-spec = "github-copilot/claude-sonnet-4.6";
        sdd-design = "github-copilot/claude-sonnet-4.6";
        # gpt-5.4-mini: 0.33x cost, fast for task decomposition
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        # gpt-5.3-codex: precision coding + terminal workflows (Stefan Stranger), 400K ctx
        sdd-apply = "github-copilot/gpt-5.3-codex";
        # claude-sonnet-4.6: better code-quality recall (0.71) than gpt-5.4 for spec-match
        sdd-verify = "github-copilot/claude-sonnet-4.6";
        # claude-haiku-4.5: 0.33x cost, 39s avg — fastest for simple file ops
        sdd-archive = "github-copilot/claude-haiku-4.5";
        # gpt-5.4-mini: fast, cheap, good enough for guided walkthrough
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        # claude-sonnet-4.6: balanced default — cross-family from orchestrator (Rubber Duck principle)
        neutral = "github-copilot/claude-sonnet-4.6";
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
