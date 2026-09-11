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
        neutral = "opencode/nemotron-3-ultra-free";
      };
    }
    {
      name = "work-copilot-anthropic";
      # Replaces old `anthropic-copilot`. Low Copilot credit + larger Anthropic quota:
      # orchestration/help phases prefer github-copilot/*, heavy phases prefer anthropic/*.
      # Auth is two separate native `/connect` OAuth flows (Copilot's own + OpenCode's
      # Anthropic OAuth) — no Claude-Pro/Max-as-Anthropic-API-billing substitution claimed.
      # PLAN DEPENDENCY: github-copilot/claude-sonnet-5 requires a Copilot plan that
      # exposes Sonnet 5 (Pro+/Business/Enterprise tiers) — verify with
      # `opencode run -m github-copilot/claude-sonnet-5 "hi"` before relying on it.
      phases = {
        gentle-orchestrator = "github-copilot/gpt-5.6-luna";
        sdd-init = "github-copilot/gpt-5.4-mini";
        # anthropic/claude-sonnet-4-6: fixed from undeclared "claude-sonnet-5" (old block bug).
        sdd-explore = "anthropic/claude-sonnet-4-6";
        # anthropic/claude-sonnet-4-6: heavy phase, fixed from undeclared "claude-sonnet-5".
        sdd-propose = "anthropic/claude-sonnet-4-6";
        sdd-spec = "github-copilot/claude-sonnet-5";
        sdd-design = "anthropic/claude-sonnet-4-6";
        sdd-tasks = "github-copilot/gpt-5.4-mini";
        sdd-apply = "anthropic/claude-sonnet-4-6";
        sdd-verify = "anthropic/claude-sonnet-4-6";
        sdd-archive = "anthropic/claude-haiku-4-5";
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        neutral = "github-copilot/gpt-5.6-luna";
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
        neutral = "anthropic/claude-sonnet-4-6";
      };
    }
    {
      name = "openai-opencode-balanced";
      phases = {
        # Hybrid recommended for ChatGPT Plus/Pro + OpenCode Go:
        # - OpenAI GPT-5.6 Terra/Luna: best fixed-plan value for judgment-heavy phases.
        # - OpenCode Go: absorbs the high-volume/tool-loop phases (orchestrator,
        #   explore, tasks, archive) so ChatGPT limits are less likely. sdd-apply
        #   moved from Go to Luna on 2026-09-09 (user request to drop GLM 5.3).
        # - Avoids GPT-5.3-Codex-Spark because OpenAI documents it as Pro-only.
        # - Avoids GPT-5.4/5.4-mini because OpenAI says ChatGPT-account Codex removes them on 2026-08-31.
        # Orchestrator upgraded to opencode-go/kimi-k3 on 2026-09-10 (user:
        # best model on the Go catalog; agent-first, tools+reasoning+structured).
        # Rollback: opencode-go/glm-5.3-flash (1M ctx, high Go request headroom).
        gentle-orchestrator = "opencode-go/kimi-k3";
        sdd-init = "opencode-go/deepseek-v4-flash";
        # Explore is the biggest limit-burner in large repos: many reads, MCP research, long context.
        sdd-explore = "opencode-go/deepseek-v4-pro";
        # Propose/spec/design benefit more from judgment than raw volume, so keep them on Terra.
        sdd-propose = "openai/gpt-5.6-sol";
        sdd-spec = "openai/gpt-5.6-sol";
        sdd-design = "openai/gpt-5.6-sol";
        # `deepseek-v4-flash` is the current stable alias for Flash-0731.
        # It remains the fit for high-volume task decomposition: 1M context,
        # tool calls, and substantially more concurrency than V4 Pro.
        sdd-tasks = "opencode-go/deepseek-v4-flash";
        # gpt-5.6-luna (audit 2026-09-09): apply is the tool-loop-heaviest phase,
        # so it goes to the 10x-cheaper OpenAI tier — Luna burns 5/0.5/30 Codex
        # credits per M tokens vs Terra's 50/5/300, and the Plus 5h window allows
        # 250-2000 Luna messages vs 25-200 Terra. Coding quality stays within
        # 0.7pp of Terra (SWE-Bench Pro 62.7 vs 63.4, Coding Agent Index 74.6 vs
        # 77.4), and OpenAI positions Luna for bounded, spec-driven edits — the
        # apply contract. Replaces glm-5.3-flash (user request); no blocking
        # GPT-5.6 issues in opencode-ai/opencode.
        sdd-apply = "openai/gpt-5.6-luna";
        # Final acceptance/judgment pass stays on OpenAI.
        sdd-verify = "openai/gpt-5.6-terra";
        sdd-archive = "opencode-go/deepseek-v4-flash";
        sdd-onboard = "opencode-go/deepseek-v4-flash";
        neutral = "openai/gpt-5.6-terra";
      };
    }
    {
      name = "opencode-go-openai";
      # Audit 2026-09-09. Go ONLY for orchestration; every SDD phase on OpenAI.
      # - gentle-orchestrator = opencode-go/kimi-k3: user-selected best model on the
      #   Go catalog (amended 2026-09-10, superseding the MiMo-V2.5 cheap pilot).
      #   K3 is the agent-first generation ("long-horizon agent work"; tools +
      #   reasoning + structured all supported); the documented K2.x failure was
      #   NIM transport (opencode#26662/#26405), not model behavior. Cost note:
      #   $3.00/$15.00 per M vs Flash $0.15/$0.50. Rollback to
      #   opencode-go/glm-5.3-flash if delegation quality or completion gates regress.
      # - OpenAI tiers by phase fit (Codex credit rates per M tokens:
      #   Sol 125/750, Terra 50/300, Luna 5/0.5/30; Plus 5h windows 10-100 /
      #   25-200 / 250-2000 messages):
      #   * Sol (judgment): propose/spec/design — a bad spec propagates defects
      #     through the whole chain.
      #   * Terra (retrieval + acceptance): explore and verify. Luna is
      #     disqualified for explore by its documented weak long-context
      #     retrieval (MRCR v2 8-needle 512K-1M: 41.3 vs Sol 73.8); verify
      #     beats a full re-loop on Terra's agentic edge over Luna (Coding
      #     Agent Index 77.4 vs 74.6, DeepSWE 69.6 vs 67.2). Sol stays the
      #     escalation option for the verify gate.
      #   * Luna (volume): init/tasks/apply/archive/onboard — bounded,
      #     spec-driven work with deterministic checks; apply stays 10x cheaper
      #     than Terra with SWE-Bench Pro within 0.7pp (62.7 vs 63.4).
      # - No blocking GPT-5.6 issues in opencode-ai/opencode (search 2026-09-09).
      # - All three tiers are Plus/Pro-eligible in Codex (OpenAI help center).
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
        neutral = "openai/gpt-5.6-terra";
      };
    }
    {
      name = "anthropic-opencode-go";
      # Audit 2026-09-09. Gemelo de `anthropic-opencode-free`: mismo backbone free
      # de Zen, pero las dos fases de juicio canjean Anthropic por modelos PAGADOS
      # de opencode-go con mejor fit por fase. El orquestador SE MANTIENE en
      # anthropic/claude-sonnet-5 (requisito del usuario).
      #   sdd-spec   -> glm-5.3-flash (escritura estructurada + mandatory reasoning, 1M ctx)
      #   sdd-verify -> deepseek-v4-pro (gate de aceptación = el mejor razonador de Go)
      # Evidence: el perfil canónico high-volume usa exactamente este par para spec/verify.
      phases = {
        # anthropic/claude-sonnet-5: orquestador en cuota Anthropic (petición explícita).
        gentle-orchestrator = "anthropic/claude-sonnet-5";
        # nemotron-3.5-lightning-free: construido para ejecución ligera de alto volumen.
        sdd-init = "opencode/nemotron-3.5-lightning-free";
        # nemotron-3-ultra-free: 1M ctx + RULER@1M 94.7 — mejor para explorar repos grandes.
        sdd-explore = "opencode/nemotron-3-ultra-free";
        # nemotron-3-ultra-free: GPQA 87 — mejor razonamiento/planning free.
        sdd-propose = "opencode/nemotron-3-ultra-free";
        # opencode-go/glm-5.3-flash: escritura estructurada con mandatory reasoning, 1M ctx.
        sdd-spec = "opencode-go/glm-5.3-flash";
        # nemotron-3-ultra-free: decisiones de arquitectura (GPQA 87, 1M ctx).
        sdd-design = "opencode/nemotron-3-ultra-free";
        # nemotron-3.5-lightning-free: descomposición mecánica a alto volumen.
        sdd-tasks = "opencode/nemotron-3.5-lightning-free";
        # mimo-v2.5-free: 70 tok/s para edits de código, worker de apply probado en audits previos.
        sdd-apply = "opencode/mimo-v2.5-free";
        # opencode-go/deepseek-v4-pro: gate de aceptación — un defecto no detectado cuesta
        # un re-loop completo apply→verify; es el razonador más fuerte de opencode-go.
        sdd-verify = "opencode-go/deepseek-v4-pro";
        # nemotron-3.5-lightning-free: la clase más rápida/barata para copy-and-close.
        sdd-archive = "opencode/nemotron-3.5-lightning-free";
        # mimo-v2.5-free: walkthrough guiado barato.
        sdd-onboard = "opencode/mimo-v2.5-free";
        # nemotron-3-ultra-free: default balanceado.
        neutral = "opencode/nemotron-3-ultra-free";
      };
    }
    {
      name = "openai-full";
      # Model fit audit 2026-09-11: ChatGPT OAuth exposes Sol, Terra, and Luna
      # locally, and each completed a shell-tool smoke test. OpenAI positions
      # Sol for complex judgment, Terra for everyday tool use, and Luna for
      # bounded high-volume work. Do not use the `-fast` aliases: OpenCode
      # issue #36241 reports a long tool-loop stream abort for Sol Fast.
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
    assert lib.assertMsg (lib.length names == lib.length (lib.unique names))
      "providers-base.nix: duplicate provider name in providers list";
    true;

  activeProvider = builtins.foldl'
    (
      acc: p: if p.name == activeProviderName then p else acc
    )
    null
    (assert _assertUniqueProviderNames; providers);
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
