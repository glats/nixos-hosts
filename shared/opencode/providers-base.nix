{ lib ? throw "providers-base.nix must be imported with lib"
, activeProviderName ? "opencode-go-medium"
,
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
        # RISKY: grok-4.5 — 500/503 on Go gateway (opencode#40343, #42962), $15 quota tier burns fast.
        "grok-4.5" = {
          name = "Grok 4.5";
          thinking = false;
        };
        # Released 2026-08-14. Clean. 1M ctx, $1.40/$4.40.
        "glm-5.3" = {
          name = "GLM 5.3";
          thinking = false;
        };
        # RISKY: glm-5.2 — multi-sourced upstream without sticky routing: cold-cache
        # re-bills on identical requests (opencode#35402 OPEN).
        "glm-5.2" = {
          name = "GLM 5.2";
          thinking = false;
        };
        # RISKY: glm-5.1 "gives up too quickly" on failures. OK for spec, not apply/verify.
        "glm-5.1" = {
          name = "GLM 5.1";
          thinking = false;
        };
        # RISKY: gpt-5.6-luna — 403 for some accounts (opencode#40343 OPEN). 2x usage multiplier on Go.
        "gpt-5.6-luna" = {
          name = "GPT 5.6 Luna";
          thinking = false;
        };
        # Released 2026-07-16. RISKY: 503 "Endpoint is unavailable" reports (opencode#43071, #42962).
        "kimi-k3" = {
          name = "Kimi K3";
          thinking = false;
        };
        "kimi-k2.7-code" = {
          name = "Kimi K2.7 Code";
          thinking = false;
        };
        "kimi-k2.6" = {
          name = "Kimi K2.6";
          thinking = false;
        };
        # RISKY: mimo-v2.5/pro — 403 for some accounts (opencode#40343 OPEN).
        "mimo-v2.5" = {
          name = "MiMo V2.5";
          thinking = false;
        };
        "mimo-v2.5-pro" = {
          name = "MiMo V2.5 Pro";
          thinking = false;
        };
        "minimax-m3" = {
          name = "MiniMax M3";
          thinking = false;
        };
        "minimax-m2.7" = {
          name = "MiniMax M2.7";
          thinking = false;
        };
        # Qwen: old Anthropic-transport BROKEN annotation resolved — models now served
        # via /messages route. RISKY: intermittent 503s as of 2026-08-17 (opencode#43071, #42962).
        "qwen3.8-max" = {
          name = "Qwen 3.8 Max";
          thinking = false;
        };
        "qwen3.7-max" = {
          name = "Qwen 3.7 Max";
          thinking = false;
        };
        "qwen3.7-plus" = {
          name = "Qwen 3.7 Plus";
          thinking = false;
        };
        "qwen3.6-plus" = {
          name = "Qwen 3.6 Plus";
          thinking = false;
        };
        "deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
          thinking = false;
        };
        # RISKY: deepseek-v4-flash — cache reads dropped to 0 mid-session, ~27x cost
        # spike burned Go quota (opencode#42935 OPEN, 2026-08-16).
        "deepseek-v4-flash" = {
          name = "DeepSeek V4 Flash";
          thinking = false;
        };
        # RISKY: hy3 — 403 for some accounts (opencode#40343 OPEN). High request count when working.
        "hy3" = {
          name = "Hy3";
          thinking = false;
        };

        # ---- Free tier (audit 2026-08-23, fuente: `opencode models | grep free`) ----
        # Gateway-wide caveat (#41236 OPEN): TODOS los modelos free de Zen muestran
        # fallos upstream intermitentes (503/TLS timeouts) que NO son por modelo —
        # el retry suele funcionar.
        # ✅ nemotron-3-ultra-free: mejor modelo agentic free. SWE-Bench Verified ~70-72%,
        # GPQA 87, 1M ctx (RULER@1M 94.7), tool calling verificado, TTFT más rápido del
        # set free (1.67s, LMSpeed). Crash de reasoning-variants corregido (PRs #26690/#26810).
        "nemotron-3-ultra-free" = {
          name = "Nemotron 3 Ultra Free";
          thinking = false;
        };
        # ✅ mimo-v2.5-free: 70 tok/s, TTFT 2.95s (LMSpeed), sesión más barata ($0.0101).
        # Uso +286% (opencode.ai/data). Probado como worker de apply/tasks en audits previos.
        "mimo-v2.5-free" = {
          name = "MiMo V2.5 Free";
          thinking = false;
        };
        # ✅ nemotron-3.5-lightning-free: released 2026-08-11. MoE 30B-A3B construido para
        # ejecución ligera de alto volumen (tool calls, validación, delegación a subagents).
        # OpenCode listado como harness partner. Débil en coding duro (Terminal-Bench 2.1:
        # 24.6%, SWE-Bench ~52%) — solo fases mecánicas/ligeras.
        "nemotron-3.5-lightning-free" = {
          name = "Nemotron 3.5 Lightning Free";
          thinking = false;
        };
        # ⚠️ hy3-free: Tencent Hunyuan 3 — fuerte escritor productivo/coding (blind eval
        # 2.67/4 > GLM-5.1; varianza tool-calls ±4% entre scaffolds). Hereda la flakiness
        # gateway del free tier (#41236) — reintentos suelen recuperar.
        "hy3-free" = {
          name = "Hy3 Free";
          thinking = false;
        };
        # ⚠️ RISKY (según routing): familia stealth Ox Alpha tiene DOS rutas al mismo
        # modelo upstream (opencode#44300, renames #43690/#43837):
        #   - ESTA ruta (zen/v1): verificado EN VIVO 2026-08-23 — tool calls OK ✅
        #   - zen/go/v1 (ox-alpha-free en provider opencode-go): colgado incluso en chat
        #     plano ese mismo día 🔴
        # Historial: tools→503 en ambas rutas (#44300/#44382), truncado silencioso
        # persistido como completo (#44044), generaciones largas cortadas sin finish_reason
        # quemando todo el presupuesto en reasoning (#44385). Reservar para fases de
        # turnos cortos (orquestación). Re-auditar cuando upstream cierre #44300.
        "x-preview-f-free" = {
          name = "X Preview F Free";
          thinking = false;
        };
        # 🔴 BROKEN (clientes estrictos): muse-spark-1.2-contributor-free — el stream SIEMPRE
        # termina sin finish_reason, determinístico en cada request (opencode#43882);
        # error de serialización por campo `id` faltante (opencode#44086, closed);
        # "Tool execution aborted" mid-tarea que requiere "Proceed" manual (opencode#43913).
        # No asignar a ninguna fase.
        "muse-spark-1.2-contributor-free" = {
          name = "Muse Spark 1.2 Contributor Free";
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

  # GitHub Copilot provider: models sync dynamically from Copilot API.
  # Static definition here prevents false "model not valid" validation
  # errors when the TUI validates before dynamic sync completes (race condition).
  # OpenCode handles auth via /connect (OAuth) — no apiKey needed.
  # Model availability depends on Copilot plan:
  #   Free — gpt-4.1, gpt-4o, gpt-4o-mini only
  #   Pro — gpt-5.x (except 5.5), claude-sonnet-4.6, claude-haiku-4.5
  #   Pro+/Max/Business/Enterprise — all models including claude-opus-4.8, gpt-5.5
  githubCopilotProvider = {
    github-copilot = {
      models = {
        # OpenAI models
        "gpt-5-mini" = {
          name = "GPT-5 Mini";
        };
        "gpt-5.3-codex" = {
          name = "GPT-5.3 Codex";
        };
        "gpt-5.4" = {
          name = "GPT-5.4";
        };
        "gpt-5.4-mini" = {
          name = "GPT-5.4 Mini";
        };
        "gpt-5.4-nano" = {
          name = "GPT-5.4 Nano";
        };
        "gpt-5.5" = {
          name = "GPT-5.5";
        };
        "gpt-5.6-luna" = {
          name = "GPT-5.6 Luna";
        };
        "gpt-5.6-sol" = {
          name = "GPT-5.6 Sol";
        };
        "gpt-5.6-terra" = {
          name = "GPT-5.6 Terra";
        };
        "raptor-mini" = {
          name = "Raptor Mini";
        };
        # Anthropic models
        "claude-haiku-4.5" = {
          name = "Claude Haiku 4.5";
        };
        "claude-sonnet-4.5" = {
          name = "Claude Sonnet 4.5";
        };
        "claude-sonnet-4.6" = {
          name = "Claude Sonnet 4.6";
        };
        "claude-sonnet-5" = {
          name = "Claude Sonnet 5";
        };
        "claude-opus-4.5" = {
          name = "Claude Opus 4.5";
        };
        "claude-opus-4.6" = {
          name = "Claude Opus 4.6";
        };
        "claude-opus-4.7" = {
          name = "Claude Opus 4.7";
        };
        "claude-opus-4.8" = {
          name = "Claude Opus 4.8";
        };
        "claude-opus-4.8-fast" = {
          name = "Claude Opus 4.8 Fast";
        };
        "claude-opus-5" = {
          name = "Claude Opus 5";
        };
        "claude-fable-5" = {
          name = "Claude Fable 5";
        };
        # Google Gemini models
        "gemini-2.5-pro" = {
          name = "Gemini 2.5 Pro";
        };
        "gemini-3-flash-preview" = {
          name = "Gemini 3 Flash";
        };
        "gemini-3.1-pro-preview" = {
          name = "Gemini 3.1 Pro";
        };
        "gemini-3.5-flash" = {
          name = "Gemini 3.5 Flash";
        };
        "gemini-3.6-flash" = {
          name = "Gemini 3.6 Flash";
        };
        # Microsoft models
        "mai-code-1-flash-picker" = {
          name = "MAI Code 1 Flash";
        };
        # Moonshot AI models
        "kimi-k2.7-code" = {
          name = "Kimi K2.7 Code";
        };
        # xAI models
        "grok-4.5" = {
          name = "Grok 4.5";
        };
      };
    };
  };

  allProviders = nvidiaProvider // opencodeProvider // anthropicProvider // githubCopilotProvider;

  providers = [
    {
      name = "alpha-free";
      phases = {
        gentle-orchestrator = "opencode/x-preview-f-free";
        sdd-init = "opencode/nemotron-3.5-lightning-free";
        sdd-explore = "opencode/x-preview-f-free";
        sdd-propose = "opencode/x-preview-f-free";
        sdd-spec = "opencode/hy3-free";
        sdd-design = "opencode/nemotron-3-ultra-free";
        sdd-tasks = "opencode/nemotron-3.5-lightning-free";
        sdd-apply = "opencode/mimo-v2.5-free";
        sdd-verify = "opencode/x-preview-f-free";
        sdd-archive = "opencode/nemotron-3.5-lightning-free";
        sdd-onboard = "opencode/x-preview-f-free";
        neutral = "github-copilot/gpt-5.5";
      };
    }
    {
      name = "openai-go-balanced";
      phases = {
        # Hybrid recommended for ChatGPT Plus/Pro + OpenCode Go:
        # - OpenAI GPT-5.6 Terra/Luna: best fixed-plan value for judgment-heavy phases.
        # - OpenCode Go: absorbs the high-volume/tool-loop phases so ChatGPT limits are less likely.
        # - Avoids GPT-5.3-Codex-Spark because OpenAI documents it as Pro-only.
        # - Avoids GPT-5.4/5.4-mini because OpenAI says ChatGPT-account Codex removes them on 2026-08-31.
        gentle-orchestrator = "openai/gpt-5.6-terra";
        sdd-init = "opencode-go/deepseek-v4-flash";
        # Explore is the biggest limit-burner in large repos: many reads, MCP research, long context.
        sdd-explore = "opencode-go/deepseek-v4-pro";
        # Propose/spec/design benefit more from judgment than raw volume, so keep them on Terra.
        sdd-propose = "openai/gpt-5.6-terra";
        sdd-spec = "openai/gpt-5.6-terra";
        sdd-design = "openai/gpt-5.6-terra";
        # Mechanical decomposition is cheap volume work; offload it to Go.
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        # Apply is the highest edit volume phase; MiniMax M3 gives large context and better Go headroom.
        sdd-apply = "opencode-go/minimax-m3";
        # Final acceptance/judgment pass stays on OpenAI.
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "openai/gpt-5.6-luna";
        neutral = "openai/gpt-5.6-terra";
      };
    }
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
      name = "github-copilot-safe";
      phases = {
        # claude-sonnet-5: GitHub positions it for general-purpose coding and agent tasks.
        # Safer update than 5.6 because there are current 5.6 access reports and an open
        # OpenCode subagent model-selection bug (#36250) not tied to Sonnet 5 specifically.
        gentle-orchestrator = "github-copilot/gpt-5.5";
        # gpt-5.4-mini: proven cheap helper model already working in current tier.
        sdd-init = "github-copilot/gpt-5.4-mini";
        # claude-sonnet-5: 1M context + agent-task positioning makes it a good explore/default upgrade.
        sdd-explore = "github-copilot/claude-sonnet-5";
        # claude-sonnet-5: balanced upgrade for architecture and structured writing.
        sdd-propose = "github-copilot/claude-sonnet-5";
        sdd-spec = "github-copilot/claude-sonnet-5";
        sdd-design = "github-copilot/claude-sonnet-5";
        # gpt-5.4-mini: still the cheapest reliable decomposition worker in this provider.
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        # gpt-5.3-codex: coding-specialized and already stable in the current tier.
        sdd-apply = "github-copilot/gpt-5.3-codex";
        # claude-sonnet-5: strong review/reasoning default without jumping to risky 5.6.
        sdd-verify = "github-copilot/claude-sonnet-5";
        # claude-haiku-4.5: fastest low-cost housekeeping model.
        sdd-archive = "github-copilot/claude-haiku-4.5";
        # gpt-5.4-mini: good enough for guided walkthroughs while staying cheap.
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        neutral = "github-copilot/claude-sonnet-5";
      };
    }
    {
      name = "github-copilot-pro";
      phases = {
        # claude-sonnet-5: GitHub positions it for general-purpose coding and agent tasks.
        # Safer update than 5.6 because there are current 5.6 access reports and an open
        # OpenCode subagent model-selection bug (#36250) not tied to Sonnet 5 specifically.
        gentle-orchestrator = "github-copilot/gpt-5.4";
        # gpt-5.4-mini: proven cheap helper model already working in current tier.
        sdd-init = "github-copilot/gpt-5.4-mini";
        # claude-sonnet-5: 1M context + agent-task positioning makes it a good explore/default upgrade.
        sdd-explore = "github-copilot/claude-sonnet-5";
        # claude-sonnet-5: balanced upgrade for architecture and structured writing.
        sdd-propose = "github-copilot/claude-sonnet-5";
        sdd-spec = "github-copilot/claude-sonnet-5";
        sdd-design = "github-copilot/claude-sonnet-5";
        # gpt-5.4-mini: still the cheapest reliable decomposition worker in this provider.
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        # gpt-5.3-codex: coding-specialized and already stable in the current tier.
        sdd-apply = "github-copilot/gpt-5.3-codex";
        # claude-sonnet-5: strong review/reasoning default without jumping to risky 5.6.
        sdd-verify = "github-copilot/claude-sonnet-5";
        # claude-haiku-4.5: fastest low-cost housekeeping model.
        sdd-archive = "github-copilot/claude-haiku-4.5";
        # gpt-5.4-mini: good enough for guided walkthroughs while staying cheap.
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        neutral = "github-copilot/claude-sonnet-5";
      };
    }
    {
      name = "github-copilot-experimental";
      phases = {
        # EXPERIMENTAL / ACCOUNT-DEPENDENT:
        # GitHub documents GPT-5.6 Luna/Sol/Terra as supported, but OpenCode has reports of
        # 403/model access issues for some Copilot integrations/accounts (#36575, #38722).
        # Keep this tier opt-in only until upstream access is consistently reliable.
        # gpt-5.6-sol: GitHub recommends it for deep reasoning and long-running agentic work.
        gentle-orchestrator = "github-copilot/gpt-5.6-sol";
        # gpt-5.6-luna: GitHub positions it as the cheaper/faster 5.6 option.
        sdd-init = "github-copilot/gpt-5.6-luna";
        sdd-explore = "github-copilot/gpt-5.6-sol";
        sdd-propose = "github-copilot/gpt-5.6-sol";
        sdd-spec = "github-copilot/gpt-5.6-sol";
        sdd-design = "github-copilot/gpt-5.6-sol";
        sdd-tasks = "github-copilot/gpt-5.6-luna";
        sdd-apply = "github-copilot/gpt-5.6-sol";
        sdd-verify = "github-copilot/gpt-5.6-sol";
        sdd-archive = "github-copilot/gpt-5.6-luna";
        sdd-onboard = "github-copilot/gpt-5.6-luna";
        neutral = "github-copilot/gpt-5.6-sol";
      };
    }
    {
      name = "openai-full";
      phases = {
        # OpenAI OAuth in OpenCode uses ChatGPT Plus/Pro login and the Codex backend.
        # Current explicit stable allowlist for subscription auth includes gpt-5.5,
        # gpt-5.4, gpt-5.4-mini, and gpt-5.3-codex-spark.
        # Newer 5.6 aliases may appear for some accounts, but we keep the stable tiers
        # pinned to the documented/explicitly allowed set until account behavior is clearer.
        gentle-orchestrator = "openai/gpt-5.5";
        sdd-init = "openai/gpt-5.4-mini";
        sdd-explore = "openai/gpt-5.5";
        sdd-propose = "openai/gpt-5.5";
        # spec is structured writing more than frontier reasoning.
        sdd-spec = "openai/gpt-5.4";
        sdd-design = "openai/gpt-5.5";
        sdd-tasks = "openai/gpt-5.4-mini";
        sdd-apply = "openai/gpt-5.3-codex-spark";
        sdd-verify = "openai/gpt-5.5";
        sdd-archive = "openai/gpt-5.4-mini";
        sdd-onboard = "openai/gpt-5.4-mini";
        neutral = "openai/gpt-5.5";
      };
    }
    {
      name = "openai-medium";
      phases = {
        # Balanced default: gpt-5.4 for the heavy SDD thinking phases, 5.4-mini for
        # cheap helper phases, and codex-spark only where code editing matters most.
        gentle-orchestrator = "openai/gpt-5.4";
        sdd-init = "openai/gpt-5.4-mini";
        sdd-explore = "openai/gpt-5.4";
        sdd-propose = "openai/gpt-5.4";
        sdd-spec = "openai/gpt-5.4";
        sdd-design = "openai/gpt-5.4";
        sdd-tasks = "openai/gpt-5.4-mini";
        sdd-apply = "openai/gpt-5.3-codex-spark";
        sdd-verify = "openai/gpt-5.4";
        sdd-archive = "openai/gpt-5.4-mini";
        sdd-onboard = "openai/gpt-5.4-mini";
        neutral = "openai/gpt-5.4";
      };
    }
    {
      name = "openai-light";
      phases = {
        # Cheapest conservative tier available on ChatGPT Plus/Pro OAuth.
        # Keep 5.4 for the phases most likely to degrade if everything is mini.
        gentle-orchestrator = "openai/gpt-5.4-mini";
        sdd-init = "openai/gpt-5.4-mini";
        sdd-explore = "openai/gpt-5.4";
        sdd-propose = "openai/gpt-5.4";
        sdd-spec = "openai/gpt-5.4";
        sdd-design = "openai/gpt-5.4";
        sdd-tasks = "openai/gpt-5.4-mini";
        sdd-apply = "openai/gpt-5.4-mini";
        sdd-verify = "openai/gpt-5.4";
        sdd-archive = "openai/gpt-5.4-mini";
        sdd-onboard = "openai/gpt-5.4-mini";
        neutral = "openai/gpt-5.4-mini";
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
        # glm-5.3: released 2026-08-14, replaces glm-5.1 (which "gives up too quickly").
        sdd-design = "opencode-go/glm-5.3";
        sdd-tasks = "opencode-go/deepseek-v4-pro";
        sdd-apply = "opencode-go/deepseek-v4-pro";
        sdd-verify = "opencode-go/glm-5.3";
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
        sdd-design = "opencode-go/deepseek-v4-pro";
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        # minimax-m3: 1M ctx (kimi-k2.7-code solo 262K) — apply grandes no explotan. Messages transport, sin issues frescos.
        sdd-apply = "opencode-go/minimax-m3";
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
      # Audit 2026-08-23 (`opencode models | grep free`): 6 modelos free en opencode/,
      # 1 en opencode-go/. Excluidos por hang/broken: x-preview-f-free y ox-alpha-free
      # (payload con tools → network_error, #44382/#44385), muse-spark-1.2-contributor-free
      # (sin finish_reason en cada request, #43882). deepseek-v4-flash-free ya no existe
      # en el catálogo free actual.
      phases = {
        # nemotron-3-ultra-free: mejor modelo agentic free (SWE-Bench ~70%, 1M ctx,
        # tool calling verificado, TTFT 1.67s) — exactamente lo que necesita orquestación.
        gentle-orchestrator = "opencode/nemotron-3-ultra-free";
        # nemotron-3.5-lightning-free: construido para ejecución ligera de alto volumen.
        sdd-init = "opencode/nemotron-3.5-lightning-free";
        # nemotron-3-ultra-free: 1M ctx + RULER@1M 94.7 — mejor para explorar repos grandes.
        sdd-explore = "opencode/nemotron-3-ultra-free";
        # nemotron-3-ultra-free: GPQA 87 — mejor razonamiento/planning free.
        sdd-propose = "opencode/nemotron-3-ultra-free";
        # hy3-free: mejor escritor productivo free (blind eval > GLM-5.1).
        sdd-spec = "opencode/hy3-free";
        # nemotron-3-ultra-free: decisiones de arquitectura.
        sdd-design = "opencode/nemotron-3-ultra-free";
        # nemotron-3.5-lightning-free: descomposición mecánica a alto volumen.
        sdd-tasks = "opencode/nemotron-3.5-lightning-free";
        # mimo-v2.5-free: 70 tok/s para edits de código, worker de apply probado en audits previos.
        sdd-apply = "opencode/mimo-v2.5-free";
        # nemotron-3-ultra-free: SWE-Bench Verified ~70% — mejor reviewer free contra spec.
        sdd-verify = "opencode/nemotron-3-ultra-free";
        # nemotron-3.5-lightning-free: la clase más rápida/barata para copy-and-close.
        sdd-archive = "opencode/nemotron-3.5-lightning-free";
        # mimo-v2.5-free: walkthrough guiado barato.
        sdd-onboard = "opencode/mimo-v2.5-free";
        # nemotron-3-ultra-free: default balanceado.
        neutral = "opencode/nemotron-3-ultra-free";
      };
    }
  ];

  activeProvider = builtins.foldl'
    (
      acc: p: if p.name == activeProviderName then p else acc
    )
    null
    providers;
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
