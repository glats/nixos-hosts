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
        # RISKY: glm-5.1 "gives up too quickly" on failures. OK for exploration, not for worker/verify.
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
        # Use nemotron-3-ultra for orchestration and judgment roles instead.
        "deepseek-ai/deepseek-v4-pro" = {
          name = "DeepSeek V4 Pro";
        };
        "nvidia/nemotron-3-ultra-550b-a55b" = {
          name = "Nemotron 3 Ultra";
        };
        # 2026-10-09: Same-backend native V2 alias; no routing/model replacement.
        # OpenCode v2.0.14: schema/config/provider.ts modelID; model-resolver.ts:232.
        # https://opencode.ai/v2/docs/providers (custom model mapping).
        "nemotron-3-ultra-550b-a55b" = {
          name = "Nemotron 3 Ultra";
          modelID = "nvidia/nemotron-3-ultra-550b-a55b";
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

  # V2 provider policy uses this ordered allowlist. Keep NVIDIA as a named
  # native provider declaration for the shared agent profile data.
  providerAllowlist = [
    "opencode"
    "opencode-go"
    "anthropic"
    "openai"
    "github-copilot"
    "nvidia"
  ];

  # Fit 2026-10-08: Opus owns judgment; OpenAI supplies the bounded workforce.
  # User observation: Sol is insufficient as the primary quality anchor.
  # Sources: platform.claude.com/docs/en/models/opus-5-5/overview (agentic
  # work, $4/$20 per MTok) and learn.chatgpt.com/docs/models (Sol for complex
  # engineering, Luna for focused/repeatable work; both included in Plus).
  # RISKY, not runtime-certified: subscription auth is not officially
  # supported by Anthropic; keep the existing login/plugin, never add paid
  # API fallback. See code.claude.com/docs/en/legal-and-compliance.
  # Native Messages with normal tool choice only: Opus rejects forced tools
  # (opencode#46735). Copilot hangs (#53747) are not this provider route.
  # OpenAI uses native HTTP Responses below, avoiding the WebSocket route
  # implicated in #53762/#53896; long-run HTTP reliability remains unmeasured.
  # Cache/compaction cost risk remains (#51109/#52761); no invented TTL option.
  anthropicOpenaiRoles = {
    gentle-orchestrator = "anthropic/claude-opus-5-5";
    # Sol is a worker, not the final authority on architecture or acceptance.
    gentle-ai-explore = "openai/gpt-6.1-sol";
    gentle-ai-worker = "openai/gpt-6.1-sol";
    jd-fix-agent = "openai/gpt-6.1-sol";
    # Opus's documented long-horizon fit and the user's quality requirement
    # outweigh quota savings at these once-shot judgment boundaries.
    gentle-ai-verify = "anthropic/claude-opus-5-5";
    jd-judge-a = "anthropic/claude-opus-5-5";
    # Cross-family reviews counter vendor blind spots; gentle-ai-verify stays Opus.
    jd-judge-b = "openai/gpt-6.1-sol";
    review-readability = "openai/gpt-6.1-sol";
    review-reliability = "openai/gpt-6.1-sol";
    review-resilience = "openai/gpt-6.1-sol";
    review-validator = "openai/gpt-6.1-sol";
    review-refuter = "anthropic/claude-opus-5-5";
    review-risk = "anthropic/claude-opus-5-5";
    neutral = "anthropic/claude-opus-5-5";
  };

  # ============================================================
  # CANONICAL: evidence-backed, manually-selected profiles.
  # Order here is a structural guarantee (canonicalProviders is
  # concatenated before legacyProviders below), not a comment
  # convention — see historical provider-routing decision.
  # ============================================================
  canonicalProviders = [
    {
      name = "openai-anthropic-go";
      # Fit 2026-10-08: preserve medium's Opus judgment and OpenAI workers;
      # move only worker, verifier, and onboarding roles onto a separate Go allowance.
      # Sources: opencode.ai/v2/docs/console/go (GPT 6 Luna, native Responses,
      # $15 monthly model allowance on Go, $60 on Go Plus) and
      # learn.chatgpt.com/docs/models (Luna for focused/repeatable work).
      # models.dev/api.json confirms tools and the model's @ai-sdk/openai
      # override: do not send it through Go's default Chat Completions route.
      # RISKY: account-specific Go entitlement/403 reports (#52267), provider
      # discovery (#52363), and quota accounting (#41206) remain open.
      # Catalog availability is not an entitlement or runtime reliability test.
      # Keep existing credentials and two-provider rollback profiles; do not
      # enable Console "Use balance" or add an automatic paid fallback.
      roles = anthropicOpenaiRoles;
    }
    {
      name = "openai-anthropic-light";
      # Same Opus judgment as medium; use only for bounded implementation.
      # Luna is recommended for focused edits: learn.chatgpt.com/docs/models.
      roles = anthropicOpenaiRoles // {
        gentle-ai-worker = "openai/gpt-6-luna";
        jd-fix-agent = "openai/gpt-6-luna";
      };
    }
    {
      name = "openai-anthropic-medium";
      # Default balance: OpenAI tool loops, Opus decisions and final gate.
      roles = anthropicOpenaiRoles;
    }
    {
      name = "openai-anthropic-full";
      # Explicit high-consumption option, not the default: move the hardest
      # workers to Opus's documented long-running agentic path.
      roles = anthropicOpenaiRoles // {
        gentle-ai-explore = "anthropic/claude-opus-5-5";
        gentle-ai-worker = "anthropic/claude-opus-5-5";
        jd-fix-agent = "anthropic/claude-opus-5-5";
      };
    }
    {
      # 2026-10-09: Retired opencode-free, anthropic-opencode-free and
      # anthropic-opencode-go by operator decision; no replacement or paid fallback.
      # MiMo is deprecated in https://models.opencode.ai/api.json;
      # OpenCode v2.0.14 models-dev loader filters deprecated entries.
      name = "work-copilot-anthropic";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-6.1-sol";
        gentle-ai-explore = "anthropic/claude-sonnet-5-5";
        # Re-fit 2026-09-23: worker is the only looping role in this profile,
        # so it stays on the already-routed Copilot Sonnet 5.5 workforce.
        # Re-fit 2026-10-07: native judgment gates move from Sonnet 4.6 ($3/$15)
        # to Sonnet 5.5 ($2/$10); native verification moves to Haiku 5.5 (day-0).
        # Sources: docs.github.com/copilot/reference/copilot-billing/models-and-pricing
        # and docs.anthropic.com/en/docs/about-claude/pricing.
        gentle-ai-worker = "github-copilot/claude-sonnet-5.5";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        # Re-fit 2026-09-23: corrections may loop, so use the already-routed
        # Copilot workforce; reserve native quota for independent judgments.
        jd-fix-agent = "github-copilot/claude-sonnet-5.5";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "github-copilot/gpt-5.6-luna";
      };
    }
    {
      name = "anthropic-openai-opencode";
      roles = {
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "opencode-go/glm-5.3-flash";
        gentle-ai-worker = "openai/gpt-6-luna";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "opencode-go/glm-5.3-flash";
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
      # Re-fit 2026-10-07: Claude 5.5 family. Sonnet 5.5 keeps Sonnet 5 pricing
      # ($2/$10 per MTok) with 30%+ faster output and up to 30% less per task.
      # Haiku 5.5 ($0.10/$0.50 for prompts under 100K tokens, 1M ctx, 128K out)
      # takes the worker and verification roles. Haiku 5.5 is day-0 (released 2026-10-07):
      # if worker/verify/onboarding regress, roll back to claude-haiku-4-5.
      # Sources: anthropic.com/claude-sonnet-5-5, anthropic.com/claude-haiku-5-5,
      # platform.claude.com/docs/en/models/haiku-5-5/overview.
      roles = {
        # Opus 5.5 orchestrator is a deliberate choice for this tier. Known issue:
        # opencode#52735 (native Opus 5.5 may store pre-tool-call user text as a
        # collapsed reasoning part). Rollback: claude-sonnet-5-5.
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
        neutral = "anthropic/claude-sonnet-5-5";
      };
    }
    {
      name = "anthropic-medium";
      # Re-fit 2026-10-07: Opus 5.5 ($4/$20 per MTok, cheaper than Opus 5 at
      # $5/$25) handles orchestration and once-shot proposal/architecture judgment.
      # Sonnet 5.5 covers worker and review roles, and Haiku 5.5 (day-0) covers
      # exploration and onboarding. Fable 5.1 ($10/$50) is still not cost-justified.
      # Source: platform.claude.com/docs/en/models/sonnet-5-5/overview (model table).
      roles = {
        # Opus 5.5: see opencode#52735 (pre-tool-call text lands in reasoning).
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
        neutral = "anthropic/claude-sonnet-5-5";
      };
    }
    {
      name = "anthropic-full";
      # Re-fit 2026-10-07: anthropic-medium plus Opus 5.5 on every once-shot
      # judgment gate (verify, judgment-day judges, review lenses), where a missed
      # defect costs a full worker/verify re-loop. Looping roles (worker,
      # jd-fix-agent) stay on Sonnet 5.5 for cost per loop. Fable 5.1 costs 2.5x
      # Opus 5.5 and is reserved for demonstrated Opus capability gaps.
      # Sources: anthropic.com/claude-opus-5-5, platform.claude.com/docs/en/models/sonnet-5-5/overview.
      roles = {
        # Opus 5.5: see opencode#52735 (pre-tool-call text lands in reasoning).
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
      name = "reliable";
      # Evidence: Anthropic native OAuth transport only, zero BROKEN-annotated models,
      # Re-fit 2026-10-07: Sonnet 4.6 -> Sonnet 5.5 and Opus 4.8 -> Opus 5.5 (both
      # cheaper, 1M ctx). Haiku stays on 4.5 here: Haiku 5.5 is day-0 and this
      # profile is defined by proven stability; promote it after a clean run elsewhere.
      # no cross-provider indirection — Opus reserved for the heaviest judgment phase.
      roles = {
        # claude-opus-5-5: unified orchestrator across Anthropic profiles (2026-10-07, user request);
        # no open tool-call issue on native OAuth. Known: opencode#52735 (display only).
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
        neutral = "anthropic/claude-sonnet-5-5";
      };
    }
    {
      name = "opencode-high";
      # Evidence: OpenCode Go tier — kimi-k3 orchestrator (best model on the Go
      # catalog, amended 2026-09-10, was glm-5.3-flash) and deepseek-v4-pro/flash
      # for the tool-intensive roles, matching `opencode-go-*`/`openai-opencode-balanced` precedent.
      roles = {
        # kimi-k3: agent-first generation (long-horizon agent work; tools +
        # reasoning + structured). Rollback: glm-5.3-flash (1M ctx, structured
        # tool calls, highest Go request headroom).
        gentle-orchestrator = "opencode-go/kimi-k3";
        # deepseek-v4-pro: heaviest read/MCP-research phase needs the larger reasoning budget.
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/glm-5.3-flash";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "quality";
      # Evidence: Opus-heavy Anthropic tier for maximum judgment quality; only
      # worker and verification roles (explore/verify/onboarding) step down to Sonnet.
      roles = {
        # claude-opus-5-5: strongest non-Fable reasoning for orchestration judgment.
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "anthropic/claude-opus-5-5";
        gentle-ai-worker = "anthropic/claude-opus-5-5";
        gentle-ai-verify = "anthropic/claude-opus-5-5";
        jd-judge-a = "anthropic/claude-opus-5-5";
        jd-judge-b = "anthropic/claude-opus-5-5";
        jd-fix-agent = "anthropic/claude-opus-5-5";
        review-readability = "anthropic/claude-opus-5-5";
        review-refuter = "anthropic/claude-opus-5-5";
        review-reliability = "anthropic/claude-opus-5-5";
        review-resilience = "anthropic/claude-opus-5-5";
        review-risk = "anthropic/claude-opus-5-5";
        review-validator = "anthropic/claude-opus-5-5";
        neutral = "anthropic/claude-opus-5-5";
      };
    }
    {
      name = "cross-provider-review";
      # Evidence: intentionally spans 4 provider prefixes (anthropic, github-copilot,
      # opencode-go, openai) so review/verification isn't anchored to one vendor's
      # blind spots — no BROKEN-annotated models used.
      roles = {
        # anthropic/claude-opus-5-5: unified orchestrator across Anthropic profiles (2026-10-07).
        gentle-orchestrator = "anthropic/claude-opus-5-5";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/glm-5.3-flash";
        gentle-ai-verify = "anthropic/claude-sonnet-5-5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "opencode-go/glm-5.3-flash";
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
      name = "openai-opencode";
      # Audit 2026-09-18: OpenCode Go is the high-volume workforce; reserve
      # OpenAI for architecture, implementation, and acceptance judgment.
      # Sources: https://opencode.ai/docs/go/ (Go request headroom, 0-day
      # retention) and https://opencode.ai/docs/zen/ (GPT 5.6 pricing/models).
      roles = {
        # GPT 5.6 Terra: quality anchor for the coordinating agent; the
        # worker roles below keep the OpenCode Go request headroom.
        gentle-orchestrator = "openai/gpt-6.1-sol";
        # DeepSeek V4 Pro: the larger Go worker for repository/MCP research.
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        # GPT 5.6 Terra: implementation and acceptance are the costly failure
        # boundaries, so reserve the premium OpenAI path for them.
        gentle-ai-worker = "openai/gpt-6.1-sol";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "openai-opencode-heavy";
      roles = {
        gentle-orchestrator = "openai/gpt-6.1-sol";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "openai/gpt-6.1-sol";
        gentle-ai-verify = "openai/gpt-6.1-sol";
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
      roles = {
        gentle-orchestrator = "openai/gpt-6.1-sol";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
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
        neutral = "openai/gpt-6.1-sol";
      };
    }
    {
      name = "opencode-go-openai";
      roles = {
        gentle-orchestrator = "opencode-go/kimi-k3";
        gentle-ai-explore = "openai/gpt-6.1-sol";
        gentle-ai-worker = "openai/gpt-5.6-luna";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-6.1-sol";
        neutral = "openai/gpt-6.1-sol";
      };
    }
    {
      name = "openai-full";
      roles = {
        gentle-orchestrator = "openai/gpt-5.6-sol";
        gentle-ai-explore = "openai/gpt-5.6-sol";
        gentle-ai-worker = "openai/gpt-5.6-luna";
        gentle-ai-verify = "openai/gpt-5.6-sol";
        jd-judge-a = "openai/gpt-5.6-sol";
        jd-judge-b = "openai/gpt-5.6-sol";
        jd-fix-agent = "openai/gpt-6.1-sol";
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
      # Balanced OpenAI tier: Terra for normal judgment and tool work;
      # Luna for bounded helper work and mechanical worker loops.
      roles = {
        gentle-orchestrator = "openai/gpt-6.1-sol";
        gentle-ai-explore = "openai/gpt-6.1-sol";
        gentle-ai-worker = "openai/gpt-5.6-luna";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-5.6-luna";
        neutral = "openai/gpt-6.1-sol";
      };
    }
    {
      name = "openai-light";
      # Luna handles cheap, bounded work. Terra protects the judgment,
      # retrieval and acceptance roles where Luna is a weaker fit.
      roles = {
        gentle-orchestrator = "openai/gpt-5.6-luna";
        gentle-ai-explore = "openai/gpt-6.1-sol";
        gentle-ai-worker = "openai/gpt-5.6-luna";
        gentle-ai-verify = "openai/gpt-6.1-sol";
        jd-judge-a = "openai/gpt-6.1-sol";
        jd-judge-b = "openai/gpt-6.1-sol";
        jd-fix-agent = "openai/gpt-5.6-luna";
        review-readability = "openai/gpt-6.1-sol";
        review-refuter = "openai/gpt-6.1-sol";
        review-reliability = "openai/gpt-6.1-sol";
        review-resilience = "openai/gpt-6.1-sol";
        review-risk = "openai/gpt-6.1-sol";
        review-validator = "openai/gpt-5.6-luna";
        neutral = "openai/gpt-5.6-luna";
      };
    }
    # Re-fit 2026-09-29: balance cost and capability by phase instead of locking
    # every tier to one vendor. GPT-5.4 mini handles mechanical work, GPT-5.3
    # Codex edits code, Sonnet 5.5 covers balanced reasoning, and Astra/Opus
    # are reserved for scarce full-tier judgment. The Copilot catalog marks all
    # selected models active with tool calling.
    # Do not route Copilot Gemini models (#15315) or GPT-5.4 (#17454); keep the
    # GPT-5.6 family out until its OpenCode access failures (#36575) are resolved.
    # Live smoke tests remain deferred to macm5 because this Linux account has
    # no Copilot entitlement.
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
  ];

  # ============================================================
  # LEGACY: non-replaced profiles, mappings unchanged, moved as-is.
  # ============================================================
  legacyProviders = [
    {
      name = "copilot-custom";
      roles = {
        gentle-orchestrator = "github-copilot/gpt-5.6-luna";
        gentle-ai-explore = "github-copilot/gpt-6.1-sol";
        gentle-ai-worker = "github-copilot/claude-sonnet-5.5";
        gentle-ai-verify = "github-copilot/claude-sonnet-5.5";
        jd-judge-a = "anthropic/claude-sonnet-5-5";
        jd-judge-b = "anthropic/claude-sonnet-5-5";
        jd-fix-agent = "anthropic/claude-sonnet-5-5";
        review-readability = "anthropic/claude-sonnet-5-5";
        review-refuter = "anthropic/claude-sonnet-5-5";
        review-reliability = "anthropic/claude-sonnet-5-5";
        review-resilience = "anthropic/claude-sonnet-5-5";
        review-risk = "anthropic/claude-sonnet-5-5";
        review-validator = "anthropic/claude-sonnet-5-5";
        neutral = "github-copilot/gpt-5.6-luna";
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
      roles = {
        # gpt-5.4: fast execution + tool orchestration (binaryverseai), 400K ctx
        gentle-orchestrator = "github-copilot/gpt-5.4";
        # gpt-5.4: 400K ctx for large repo exploration, fast tool calls
        gentle-ai-explore = "github-copilot/gpt-5.4";
        # gpt-5.3-codex: precision coding + terminal workflows (Stefan Stranger), 400K ctx
        gentle-ai-worker = "github-copilot/gpt-5.3-codex";
        # claude-sonnet-4.6: better code-quality recall (0.71) than gpt-5.4 for verification fit
        gentle-ai-verify = "github-copilot/claude-sonnet-4.6";
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
      roles = {
        # claude-sonnet-5: GitHub positions it for general-purpose coding and agent tasks.
        # Safer update than 5.6 because there are current 5.6 access reports and an open
        # OpenCode subagent model-selection bug (#36250) not tied to Sonnet 5 specifically.
        gentle-orchestrator = "github-copilot/gpt-5.5";
        # claude-sonnet-5: 1M context + agent-task positioning makes it a good explore/default upgrade.
        gentle-ai-explore = "github-copilot/claude-sonnet-5.5";
        # gpt-5.3-codex: coding-specialized and already stable in the current tier.
        gentle-ai-worker = "github-copilot/gpt-5.3-codex";
        # claude-sonnet-5: strong review/reasoning default without jumping to risky 5.6.
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
      name = "github-copilot-pro";
      roles = {
        # claude-sonnet-5: GitHub positions it for general-purpose coding and agent tasks.
        # Safer update than 5.6 because there are current 5.6 access reports and an open
        # OpenCode subagent model-selection bug (#36250) not tied to Sonnet 5 specifically.
        gentle-orchestrator = "github-copilot/gpt-5.4";
        # claude-sonnet-5: 1M context + agent-task positioning makes it a good explore/default upgrade.
        gentle-ai-explore = "github-copilot/claude-sonnet-5.5";
        # gpt-5.3-codex: coding-specialized and already stable in the current tier.
        gentle-ai-worker = "github-copilot/gpt-5.3-codex";
        # claude-sonnet-5: strong review/reasoning default without jumping to risky 5.6.
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
      name = "github-copilot-experimental";
      roles = {
        # EXPERIMENTAL / ACCOUNT-DEPENDENT:
        # GitHub documents GPT-5.6 Luna/Sol/Terra as supported, but OpenCode has reports of
        # 403/model access issues for some Copilot integrations/accounts (#36575, #38722).
        # Keep this tier opt-in only until upstream access is consistently reliable.
        # gpt-5.6-sol: GitHub recommends it for deep reasoning and long-running agentic work.
        gentle-orchestrator = "github-copilot/gpt-5.6-sol";
        gentle-ai-explore = "github-copilot/gpt-5.6-sol";
        gentle-ai-worker = "github-copilot/gpt-5.6-sol";
        gentle-ai-verify = "github-copilot/gpt-5.6-sol";
        neutral = "github-copilot/gpt-5.6-sol";
      };
    }
    {
      name = "opencode-go-full";
      roles = {
        gentle-orchestrator = "opencode-go/deepseek-v4-pro";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/deepseek-v4-pro";
        gentle-ai-verify = "opencode-go/glm-5.3";
        neutral = "opencode-go/deepseek-v4-pro";
      };
    }
    {
      name = "opencode-go-medium";
      roles = {
        gentle-orchestrator = "opencode-go/deepseek-v4-pro";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        # minimax-m3: 1M ctx (kimi-k2.7-code solo 262K) — apply grandes no explotan. Messages transport, sin issues frescos.
        gentle-ai-worker = "opencode-go/minimax-m3";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
        neutral = "opencode-go/deepseek-v4-flash";
      };
    }
    {
      name = "opencode-go-light";
      roles = {
        gentle-orchestrator = "opencode-go/deepseek-v4-flash";
        gentle-ai-explore = "opencode-go/deepseek-v4-pro";
        gentle-ai-worker = "opencode-go/deepseek-v4-flash";
        gentle-ai-verify = "opencode-go/deepseek-v4-pro";
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
