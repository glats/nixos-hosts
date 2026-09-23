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
      options = {
        timeout = 3600000;
        chunkTimeout = 3600000;
      };
    };
  };

  allProviders = nvidiaProvider // opencodeProvider;

  # ============================================================
  # CANONICAL: evidence-backed, manually-selected profiles.
  # Order here is a structural guarantee (canonicalProviders is
  # concatenated before legacyProviders below), not a comment
  # convention — see openspec/changes/evidence-based-opencode-routing.
  # ============================================================
  canonicalProviders = [
    {
      name = "opencode-free";
      # Audit 2026-09-09 (`opencode models --refresh`): catálogo free actual =
      # nemotron-3-ultra-free, nemotron-3.5-lightning-free, mimo-v2.5-free, big-pickle,
      # ling-3.0-flash-fin-free, muse-spark-1.2/1.3-contributor-free. hy3-free y
      # x-preview-f-free rotaron fuera; muse-spark-1.2 sigue BROKEN (#43882, #44659).
      # Reemplaza a las antiguas `alpha-free` y `opencode-free` legacy.
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
        jd-judge-a = "opencode/nemotron-3-ultra-free";
        jd-judge-b = "opencode/nemotron-3-ultra-free";
        jd-fix-agent = "opencode/mimo-v2.5-free";
        review-readability = "opencode/nemotron-3-ultra-free";
        review-refuter = "opencode/nemotron-3-ultra-free";
        review-reliability = "opencode/nemotron-3-ultra-free";
        review-resilience = "opencode/nemotron-3-ultra-free";
        review-risk = "opencode/nemotron-3-ultra-free";
        review-validator = "opencode/nemotron-3-ultra-free";
        neutral = "opencode/nemotron-3-ultra-free";
      };
    }
    {
      name = "anthropic-opencode-free";
      # Audit 2026-09-09 (`opencode models --refresh`): catálogo free actual =
      # nemotron-3-ultra-free, nemotron-3.5-lightning-free, mimo-v2.5-free, big-pickle,
      # ling-3.0-flash-fin-free, muse-spark-1.2/1.3-contributor-free. hy3-free y
      # x-preview-f-free rotaron fuera del catálogo. muse-spark-1.2 sigue BROKEN
      # (#43882, #44659, #45744). Estrategia: cuota Anthropic reservada para juicio —
      # orchestrator en Sonnet 5, spec y verify en Sonnet 4.6; el resto en free de Zen.
      phases = {
        # anthropic/claude-sonnet-5: orquestador en cuota Anthropic (petición explícita).
        gentle-orchestrator = "anthropic/claude-sonnet-5";
        # nemotron-3.5-lightning-free: construido para ejecución ligera de alto volumen.
        sdd-init = "opencode/nemotron-3.5-lightning-free";
        # nemotron-3-ultra-free: 1M ctx + RULER@1M 94.7 — mejor para explorar repos grandes.
        sdd-explore = "opencode-go/glm-5.3-flash";
        # nemotron-3-ultra-free: GPQA 87 — mejor razonamiento/planning free.
        sdd-propose = "opencode/nemotron-3-ultra-free";
        # anthropic/claude-sonnet-4-6: hy3-free rotó fuera del catálogo free (audit 2026-09-09);
        # un spec malo propaga defectos a todo el chain (design→tasks→apply→verify).
        sdd-spec = "anthropic/claude-sonnet-4-6";
        # nemotron-3-ultra-free: decisiones de arquitectura (GPQA 87, 1M ctx).
        sdd-design = "opencode/nemotron-3-ultra-free";
        # nemotron-3.5-lightning-free: descomposición mecánica a alto volumen.
        sdd-tasks = "opencode/nemotron-3.5-lightning-free";
        # mimo-v2.5-free: 70 tok/s para edits de código, worker de apply probado en audits previos.
        sdd-apply = "opencode/mimo-v2.5-free";
        # anthropic/claude-sonnet-4-6: puerta de aceptación — un defecto no detectado cuesta
        # un re-loop completo apply→verify; nemotron-free (~70% SWE-bench) queda corto aquí.
        sdd-verify = "anthropic/claude-sonnet-4-6";
        # nemotron-3.5-lightning-free: la clase más rápida/barata para copy-and-close.
        sdd-archive = "opencode/nemotron-3.5-lightning-free";
        # mimo-v2.5-free: walkthrough guiado barato.
        sdd-onboard = "opencode/mimo-v2.5-free";
        # nemotron-3-ultra-free: default balanceado.
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "opencode/mimo-v2.5-free";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "opencode/nemotron-3-ultra-free";
      };
    }
    {
      name = "work-copilot-anthropic";
      phases = {
        gentle-orchestrator = "github-copilot/gpt-5.6-terra";
        sdd-init = "github-copilot/gpt-5.4-mini";
        sdd-explore = "anthropic/claude-sonnet-4-6";
        sdd-propose = "anthropic/claude-sonnet-4-6";
        sdd-spec = "github-copilot/claude-sonnet-5";
        sdd-design = "anthropic/claude-sonnet-4-6";
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        # Re-fit 2026-09-23: apply is the only may-loop phase in this profile,
        # so it moves to the already-routed Copilot Sonnet 5. GitHub lists it
        # at $2/$10 per MTok versus native Sonnet 4.6 at $3/$15; keep native
        # Sonnet 4.6 for the one-shot acceptance and review judgment gates.
        # Sources: docs.github.com/copilot/reference/copilot-billing/models-and-pricing
        # and docs.anthropic.com/en/docs/about-claude/pricing.
        sdd-apply = "github-copilot/claude-sonnet-5";
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "anthropic/claude-sonnet-4-6";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "github-copilot/gpt-5.6-luna";
      };
    }
    {
      name = "work-copilot-anthropic-light";
      # Audit 2026-09-23: use Copilot Sonnet 5 ($2/$10 per MTok) for the
      # routine SDD path, while retaining native Sonnet 4.6 ($3/$15) only for
      # acceptance and adversarial judgment. Sonnet 5 is GA in Copilot and is
      # documented for general-purpose coding and agent tasks.
      # Sources: docs.github.com/copilot/reference/copilot-billing/models-and-pricing
      # and docs.github.com/copilot/reference/ai-models/model-comparison.
      phases = {
        # Keep the coordinating agent capable without consuming the Terra tier.
        gentle-orchestrator = "github-copilot/claude-sonnet-5";
        # Mechanical and guided phases use the inexpensive native tier.
        sdd-init = "anthropic/claude-haiku-4-5";
        sdd-explore = "github-copilot/claude-sonnet-5";
        sdd-propose = "github-copilot/claude-sonnet-5";
        sdd-spec = "github-copilot/claude-sonnet-5";
        sdd-design = "github-copilot/claude-sonnet-5";
        sdd-tasks = "anthropic/claude-haiku-4-5";
        sdd-apply = "github-copilot/claude-sonnet-5";
        # Preserve the native quality gate where a missed defect causes a re-loop.
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "anthropic/claude-haiku-4-5";
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "github-copilot/claude-sonnet-5";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "github-copilot/claude-sonnet-5";
      };
    }
    {
      name = "anthropic-light";
      phases = {
        # claude-sonnet-5: current Anthropic flagship for orchestration; 4-6 stays the tier workhorse.
        gentle-orchestrator = "anthropic/claude-sonnet-5";
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
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "anthropic/claude-sonnet-4-6";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
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
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "anthropic/claude-sonnet-4-6";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "anthropic/claude-sonnet-4-6";
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
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "anthropic/claude-sonnet-4-6";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "reliable";
      # Evidence: Anthropic native OAuth transport only, zero BROKEN-annotated models,
      # no cross-provider indirection — Opus reserved for the heaviest judgment phase.
      phases = {
        # claude-sonnet-4-6: no BROKEN annotation, stable native OAuth transport.
        gentle-orchestrator = "anthropic/claude-sonnet-4-6";
        sdd-init = "anthropic/claude-haiku-4-5";
        sdd-explore = "anthropic/claude-sonnet-4-6";
        # claude-opus-4-8: heaviest architecture phase, strongest reliable reasoning.
        sdd-propose = "anthropic/claude-opus-4-8";
        sdd-spec = "anthropic/claude-sonnet-4-6";
        sdd-design = "anthropic/claude-opus-4-8";
        sdd-tasks = "anthropic/claude-sonnet-4-6";
        sdd-apply = "anthropic/claude-sonnet-4-6";
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "anthropic/claude-sonnet-4-6";
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "anthropic/claude-sonnet-4-6";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "high-volume";
      # Evidence: OpenCode Go tier — kimi-k3 orchestrator (best model on the Go
      # catalog, amended 2026-09-10, was glm-5.3-flash) and deepseek-v4-pro/flash
      # for the tool-loop-heavy phases, matching `opencode-go-*`/`openai-opencode-balanced` precedent.
      phases = {
        # kimi-k3: agent-first generation (long-horizon agent work; tools +
        # reasoning + structured). Rollback: glm-5.3-flash (1M ctx, structured
        # tool calls, highest Go request headroom).
        gentle-orchestrator = "opencode-go/kimi-k3";
        sdd-init = "opencode-go/deepseek-v4-flash";
        # deepseek-v4-pro: heaviest read/MCP-research phase needs the larger reasoning budget.
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "opencode-go/deepseek-v4-pro";
        sdd-spec = "opencode-go/glm-5.3-flash";
        sdd-design = "opencode-go/deepseek-v4-pro";
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        sdd-apply = "opencode-go/glm-5.3-flash";
        sdd-verify = "opencode-go/deepseek-v4-pro";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "quality";
      # Evidence: Opus-heavy Anthropic tier for maximum judgment quality; only
      # mechanical phases (init/tasks/archive/onboard) step down to Sonnet.
      phases = {
        # claude-opus-4-8: strongest available reasoning for orchestration judgment.
        gentle-orchestrator = "anthropic/claude-opus-4-8";
        sdd-init = "anthropic/claude-sonnet-4-6";
        sdd-explore = "anthropic/claude-opus-4-8";
        # claude-opus-4-8: heaviest architecture phase.
        sdd-propose = "anthropic/claude-opus-4-8";
        sdd-spec = "anthropic/claude-opus-4-8";
        sdd-design = "anthropic/claude-opus-4-8";
        sdd-tasks = "anthropic/claude-sonnet-4-6";
        sdd-apply = "anthropic/claude-opus-4-8";
        sdd-verify = "anthropic/claude-opus-4-8";
        sdd-archive = "anthropic/claude-sonnet-4-6";
        sdd-onboard = "anthropic/claude-sonnet-4-6";
        jd-judge-a = "anthropic/claude-opus-4-8";
        jd-judge-b = "anthropic/claude-opus-4-8";
        jd-fix-agent = "anthropic/claude-opus-4-8";
        review-readability = "anthropic/claude-opus-4-8";
        review-refuter = "anthropic/claude-opus-4-8";
        review-reliability = "anthropic/claude-opus-4-8";
        review-resilience = "anthropic/claude-opus-4-8";
        review-risk = "anthropic/claude-opus-4-8";
        review-validator = "anthropic/claude-opus-4-8";
        neutral = "anthropic/claude-opus-4-8";
      };
    }
    {
      name = "cross-provider-review";
      # Evidence: intentionally spans 4 provider prefixes (anthropic, github-copilot,
      # opencode-go, openai) so review/verification isn't anchored to one vendor's
      # blind spots — no BROKEN-annotated models used.
      phases = {
        # anthropic/claude-sonnet-4-6: cross-family review anchor, native OAuth.
        gentle-orchestrator = "anthropic/claude-sonnet-4-6";
        sdd-init = "github-copilot/gpt-5.4-mini";
        sdd-explore = "opencode-go/deepseek-v4-pro";
        # anthropic/claude-opus-4-8: heaviest phase gets the strongest cross-checked model.
        sdd-propose = "anthropic/claude-opus-4-8";
        sdd-spec = "openai/gpt-5.4";
        sdd-design = "anthropic/claude-opus-4-8";
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        sdd-apply = "opencode-go/glm-5.3-flash";
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "openai/gpt-5.4-mini";
        jd-judge-a = "anthropic/claude-sonnet-4-6";
        jd-judge-b = "anthropic/claude-sonnet-4-6";
        jd-fix-agent = "opencode-go/glm-5.3-flash";
        review-readability = "anthropic/claude-sonnet-4-6";
        review-refuter = "anthropic/claude-sonnet-4-6";
        review-reliability = "anthropic/claude-sonnet-4-6";
        review-resilience = "anthropic/claude-sonnet-4-6";
        review-risk = "anthropic/claude-sonnet-4-6";
        review-validator = "anthropic/claude-sonnet-4-6";
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "openai-opencode";
      # Audit 2026-09-18: OpenCode Go is the high-volume workforce; reserve
      # OpenAI for architecture, implementation, and acceptance judgment.
      # Sources: https://opencode.ai/docs/go/ (Go request headroom, 0-day
      # retention) and https://opencode.ai/docs/zen/ (GPT 5.6 pricing/models).
      phases = {
        # GPT 5.6 Terra: quality anchor for the coordinating agent; the
        # worker phases below keep the OpenCode Go request headroom.
        gentle-orchestrator = "openai/gpt-5.6-terra";
        sdd-init = "opencode-go/deepseek-v4-flash";
        # DeepSeek V4 Pro: the larger Go worker for repository/MCP research.
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "opencode-go/deepseek-v4-pro";
        sdd-spec = "opencode-go/deepseek-v4-pro";
        # GPT 5.6 Sol: reserve the premium engineering path for architecture.
        sdd-design = "openai/gpt-5.6-sol";
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        # GPT 5.6 Terra: implementation and acceptance are the costly failure
        # boundaries, so reserve the premium OpenAI path for them.
        sdd-apply = "openai/gpt-5.6-terra";
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        jd-judge-a = "openai/gpt-5.6-terra";
        jd-judge-b = "openai/gpt-5.6-terra";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-5.6-terra";
        review-refuter = "openai/gpt-5.6-terra";
        review-reliability = "openai/gpt-5.6-terra";
        review-resilience = "openai/gpt-5.6-terra";
        review-risk = "openai/gpt-5.6-terra";
        review-validator = "openai/gpt-5.6-terra";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "openai-opencode-go-heavy";
      # Audit 2026-09-22: opt-in Go-heavy clone of `openai-opencode`.
      # OpenCode Go documents GLM-5.3-Flash and DeepSeek V4 Pro as supported
      # models with 0-day retention, plus materially higher included request
      # headroom than the premium OpenAI path:
      # https://opencode.ai/docs/go/.
      # Keep OpenAI only for coordination and the design/apply/verify failure
      # boundaries; route judges, reviews, and all non-critical SDD work to Go.
      # The Go gateway has open provider/model reliability reports, so this
      # profile is intentionally opt-in rather than a replacement default.
      phases = {
        gentle-orchestrator = "openai/gpt-5.6-terra";
        # GLM-5.3-Flash is the high-headroom mechanical worker.
        sdd-init = "opencode-go/glm-5.3-flash";
        # DeepSeek V4 Pro is the larger Go worker for repository/MCP research
        # and structured planning.
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "opencode-go/deepseek-v4-pro";
        sdd-spec = "opencode-go/deepseek-v4-pro";
        sdd-design = "openai/gpt-5.6-terra";
        sdd-tasks = "opencode-go/glm-5.3-flash";
        sdd-apply = "openai/gpt-5.6-terra";
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "opencode-go/glm-5.3-flash";
        sdd-onboard = "opencode-go/glm-5.3-flash";
        jd-judge-a = "opencode-go/deepseek-v4-pro";
        jd-judge-b = "opencode-go/deepseek-v4-pro";
        jd-fix-agent = "opencode-go/glm-5.3-flash";
        review-readability = "opencode-go/deepseek-v4-pro";
        review-refuter = "opencode-go/deepseek-v4-pro";
        review-reliability = "opencode-go/deepseek-v4-pro";
        review-resilience = "opencode-go/deepseek-v4-pro";
        review-risk = "opencode-go/deepseek-v4-pro";
        review-validator = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/glm-5.3-flash";
      };
    }
    {
      name = "openai-opencode-balanced";
      phases = {
        gentle-orchestrator = "openai/gpt-5.6-terra";
        sdd-init = "opencode-go/deepseek-v4-flash";
        sdd-explore = "opencode-go/deepseek-v4-pro";
        sdd-propose = "openai/gpt-5.6-sol";
        sdd-spec = "openai/gpt-5.6-sol";
        sdd-design = "openai/gpt-5.6-sol";
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        sdd-apply = "openai/gpt-5.6-luna";
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        jd-judge-a = "openai/gpt-5.6-terra";
        jd-judge-b = "openai/gpt-5.6-terra";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-5.6-terra";
        review-refuter = "openai/gpt-5.6-terra";
        review-reliability = "openai/gpt-5.6-terra";
        review-resilience = "openai/gpt-5.6-terra";
        review-risk = "openai/gpt-5.6-terra";
        review-validator = "openai/gpt-5.6-terra";
        neutral = "openai/gpt-5.6-terra";
      };
    }
    {
      name = "opencode-go-openai";
      phases = {
        gentle-orchestrator = "opencode-go/kimi-k3";
        sdd-init = "openai/gpt-5.6-luna";
        sdd-explore = "openai/gpt-5.6-terra";
        sdd-propose = "openai/gpt-5.6-sol";
        sdd-spec = "openai/gpt-5.6-sol";
        sdd-design = "openai/gpt-5.6-sol";
        sdd-tasks = "openai/gpt-5.6-luna";
        sdd-apply = "openai/gpt-5.6-luna";
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "openai/gpt-5.6-luna";
        sdd-onboard = "openai/gpt-5.6-luna";
        jd-judge-a = "openai/gpt-5.6-terra";
        jd-judge-b = "openai/gpt-5.6-terra";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-5.6-terra";
        review-refuter = "openai/gpt-5.6-terra";
        review-reliability = "openai/gpt-5.6-terra";
        review-resilience = "openai/gpt-5.6-terra";
        review-risk = "openai/gpt-5.6-terra";
        review-validator = "openai/gpt-5.6-terra";
        neutral = "openai/gpt-5.6-terra";
      };
    }
    {
      name = "anthropic-opencode-go";
      phases = {
        gentle-orchestrator = "anthropic/claude-sonnet-5";
        sdd-init = "opencode/nemotron-3.5-lightning-free";
        sdd-explore = "opencode/nemotron-3-ultra-free";
        sdd-propose = "opencode/nemotron-3-ultra-free";
        sdd-spec = "opencode-go/glm-5.3-flash";
        sdd-design = "opencode/nemotron-3-ultra-free";
        sdd-tasks = "opencode/nemotron-3.5-lightning-free";
        sdd-apply = "opencode/mimo-v2.5-free";
        sdd-verify = "opencode-go/deepseek-v4-pro";
        sdd-archive = "opencode/nemotron-3.5-lightning-free";
        sdd-onboard = "opencode/mimo-v2.5-free";
        neutral = "opencode/nemotron-3-ultra-free";
      };
    }
    {
      name = "openai-full";
      phases = {
        gentle-orchestrator = "openai/gpt-5.6-sol";
        sdd-init = "openai/gpt-5.6-luna";
        sdd-explore = "openai/gpt-5.6-sol";
        sdd-propose = "openai/gpt-5.6-sol";
        sdd-spec = "openai/gpt-5.6-terra";
        sdd-design = "openai/gpt-5.6-sol";
        sdd-tasks = "openai/gpt-5.6-luna";
        sdd-apply = "openai/gpt-5.6-luna";
        sdd-verify = "openai/gpt-5.6-sol";
        sdd-archive = "openai/gpt-5.6-luna";
        sdd-onboard = "openai/gpt-5.6-luna";
        jd-judge-a = "openai/gpt-5.6-sol";
        jd-judge-b = "openai/gpt-5.6-sol";
        jd-fix-agent = "openai/gpt-5.6-terra";
        review-readability = "openai/gpt-5.6-sol";
        review-refuter = "openai/gpt-5.6-sol";
        review-reliability = "openai/gpt-5.6-sol";
        review-resilience = "openai/gpt-5.6-sol";
        review-risk = "openai/gpt-5.6-sol";
        review-validator = "openai/gpt-5.6-sol";
        neutral = "openai/gpt-5.6-sol";
      };
    }
    {
      name = "openai-medium";
      # Balanced OpenAI tier: Terra for normal SDD judgment and tool work;
      # Luna for bounded helpers and mechanical apply loops.
      phases = {
        gentle-orchestrator = "openai/gpt-5.6-terra";
        sdd-init = "openai/gpt-5.6-luna";
        sdd-explore = "openai/gpt-5.6-terra";
        sdd-propose = "openai/gpt-5.6-terra";
        sdd-spec = "openai/gpt-5.6-terra";
        sdd-design = "openai/gpt-5.6-terra";
        sdd-tasks = "openai/gpt-5.6-luna";
        sdd-apply = "openai/gpt-5.6-luna";
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "openai/gpt-5.6-luna";
        sdd-onboard = "openai/gpt-5.6-luna";
        jd-judge-a = "openai/gpt-5.6-terra";
        jd-judge-b = "openai/gpt-5.6-terra";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-5.6-terra";
        review-refuter = "openai/gpt-5.6-terra";
        review-reliability = "openai/gpt-5.6-terra";
        review-resilience = "openai/gpt-5.6-terra";
        review-risk = "openai/gpt-5.6-terra";
        review-validator = "openai/gpt-5.6-luna";
        neutral = "openai/gpt-5.6-terra";
      };
    }
    {
      name = "openai-light";
      # Luna handles cheap, bounded work. Terra protects the judgment,
      # retrieval, and acceptance phases where Luna is a weaker fit.
      phases = {
        gentle-orchestrator = "openai/gpt-5.6-luna";
        sdd-init = "openai/gpt-5.6-luna";
        sdd-explore = "openai/gpt-5.6-terra";
        sdd-propose = "openai/gpt-5.6-terra";
        sdd-spec = "openai/gpt-5.6-terra";
        sdd-design = "openai/gpt-5.6-terra";
        sdd-tasks = "openai/gpt-5.6-luna";
        sdd-apply = "openai/gpt-5.6-luna";
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "openai/gpt-5.6-luna";
        sdd-onboard = "openai/gpt-5.6-luna";
        jd-judge-a = "openai/gpt-5.6-terra";
        jd-judge-b = "openai/gpt-5.6-terra";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-5.6-terra";
        review-refuter = "openai/gpt-5.6-terra";
        review-reliability = "openai/gpt-5.6-terra";
        review-resilience = "openai/gpt-5.6-terra";
        review-risk = "openai/gpt-5.6-terra";
        review-validator = "openai/gpt-5.6-luna";
        neutral = "openai/gpt-5.6-luna";
      };
    }
  ];

  # ============================================================
  # LEGACY: non-replaced profiles, mappings unchanged, moved as-is.
  # ============================================================
  legacyProviders = [
    {
      name = "copilot-custom";
      phases = {
        gentle-orchestrator = "github-copilot/gpt-5.6-luna";
        sdd-init = "github-copilot/gpt-5.4-mini";
        sdd-explore = "github-copilot/gpt-5.6-terra";
        sdd-propose = "github-copilot/gpt-5.6-terra";
        sdd-spec = "github-copilot/claude-sonnet-5";
        sdd-design = "github-copilot/claude-sonnet-5";
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        sdd-apply = "github-copilot/claude-sonnet-5";
        sdd-verify = "github-copilot/claude-sonnet-5";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        jd-judge-a = "anthropic/claude-sonnet-5";
        jd-judge-b = "anthropic/claude-sonnet-5";
        jd-fix-agent = "anthropic/claude-sonnet-5";
        review-readability = "anthropic/claude-sonnet-5";
        review-refuter = "anthropic/claude-sonnet-5";
        review-reliability = "anthropic/claude-sonnet-5";
        review-resilience = "anthropic/claude-sonnet-5";
        review-risk = "anthropic/claude-sonnet-5";
        review-validator = "anthropic/claude-sonnet-5";
        neutral = "github-copilot/gpt-5.6-luna";
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
        jd-judge-a = "nvidia/nemotron-3-ultra-550b-a55b";
        jd-judge-b = "nvidia/nemotron-3-ultra-550b-a55b";
        jd-fix-agent = "opencode-go/minimax-m3";
        review-readability = "nvidia/nemotron-3-ultra-550b-a55b";
        review-refuter = "nvidia/nemotron-3-ultra-550b-a55b";
        review-reliability = "nvidia/nemotron-3-ultra-550b-a55b";
        review-resilience = "nvidia/nemotron-3-ultra-550b-a55b";
        review-risk = "nvidia/nemotron-3-ultra-550b-a55b";
        review-validator = "nvidia/nemotron-3-ultra-550b-a55b";
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
        jd-judge-a = "github-copilot/claude-sonnet-5";
        jd-judge-b = "github-copilot/claude-sonnet-5";
        jd-fix-agent = "github-copilot/gpt-5.3-codex";
        review-readability = "github-copilot/claude-sonnet-5";
        review-refuter = "github-copilot/claude-sonnet-5";
        review-reliability = "github-copilot/claude-sonnet-5";
        review-resilience = "github-copilot/claude-sonnet-5";
        review-risk = "github-copilot/claude-sonnet-5";
        review-validator = "github-copilot/claude-sonnet-5";
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
        jd-judge-a = "github-copilot/claude-sonnet-5";
        jd-judge-b = "github-copilot/claude-sonnet-5";
        jd-fix-agent = "github-copilot/gpt-5.3-codex";
        review-readability = "github-copilot/claude-sonnet-5";
        review-refuter = "github-copilot/claude-sonnet-5";
        review-reliability = "github-copilot/claude-sonnet-5";
        review-resilience = "github-copilot/claude-sonnet-5";
        review-risk = "github-copilot/claude-sonnet-5";
        review-validator = "github-copilot/claude-sonnet-5";
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
  ];

  providers = canonicalProviders ++ legacyProviders;

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
