# Specification: awesome-free-llm-apis para nuestros models en providers nix

## Context
The user wants to:
1. Create a **Python script** that verifies which models actually respond to API calls (not just what docs say)
2. Update **providers.nix** model lists based on what actually works
3. Reconfigure all **tiers** (except `opencode-go`, `github-copilot`, `github-copilot-student`) with best-fit models per SDD phase

### User Decisions
- `nvidia/nemotron-3-super-120b-a12b` — WORKS for them despite NIM tagging it "Downloadable"
- `deepseek-ai/deepseek-v4-flash/pro` — gave errors in OpenCode, OK to remove
- Will register for OpenRouter and Mistral AI keys (no credit card needed)
- Only tiers to preserve unchanged: `opencode-go`, `github-copilot`, `github-copilot-student`
- Key insight: "Sometimes models say they're available but give errors in OpenCode" — need real verification

### Available API Keys
- NVIDIA_API_KEY ✅ (70 chars)
- GROQ_API_KEY ✅ (56 chars)
- CEREBRAS_API_KEY ✅ (52 chars)
- OPENCODE_API_KEY ❌ (not in env)
- OPENROUTER_API_KEY — will register
- MISTRAL_API_KEY — will register

## Requirements

### REQ-1: Python Model Verification Script
**Location**: `/home/glats/.nixos/scripts/verify-models.py`

The script must:
1. Accept a config file path (default: the generated opencode.json) OR read providers directly
2. For each provider and model, make a real `chat/completions` API call with a minimal prompt
3. Report per-model: ✅ OK or ❌ ERROR with the error type (auth, model_not_found, rate_limit, timeout, etc.)
4. Support these providers: NVIDIA NIM, Groq, Cerebras, OpenCode Zen, OpenRouter, Mistral AI
5. Read API keys from environment variables (same as opencode uses)
6. Output a summary table to terminal
7. Optionally output JSON for programmatic use
8. Have a `--quick` mode that only checks model listing endpoint (not full completion) when available
9. Be executable with `#!/usr/bin/env python3`
10. Use only stdlib + `urllib` (no pip dependencies, must work on NixOS without extra packages)

### REQ-2: Update Provider Model Lists

**NVIDIA provider** — Current → New:
- REMOVE: `deepseek-ai/deepseek-v4-flash`, `deepseek-ai/deepseek-v4-pro` (error in OpenCode)
- KEEP: `z-ai/glm-5.1` (works), `minimaxai/minimax-m2.7` (works), `nvidia/nemotron-3-super-120b-a12b` (works for user)
- ADD candidates (from awesome-free-llm-apis, need verification):
  - `deepseek-ai/deepseek-r1` (⚠️ may be deprecated per build.nvidia.com)
  - `nvidia/llama-3.1-nemotron-ultra-253b-v1`
  - `nvidia/nemotron-3-nano-30b-a3b`
  - `meta/llama-3.1-405b-instruct`
  - `qwen/qwen2.5-72b-instruct`
  - `google/gemma-4-31b`
  - `mistralai/mistral-large-2-instruct`
  - `moonshotai/kimi-k2-instruct`
  - `qwen/qwen3-coder-480b-a35b-instruct`

**Groq provider** — Current → New:
- REMOVE: `gpt-oss-20b` (not in awesome-free-llm-apis)
- KEEP: `llama-3.1-8b-instant`, `llama-3.3-70b-versatile`, `deepseek-r1-distill-llama-70b`, `gpt-oss-120b`
- ADD candidates:
  - `qwen3-32b`
  - `kimi-k2-instruct`
  - `llama-4-scout-17b-16e-instruct`
  - `llama-4-maverick-17b-128e-instruct`

**Cerebras provider** — Current → New:
- REMOVE: `llama-3.3-70b` (deprecated)
- KEEP: `llama-3.1-8b`, `gpt-oss-120b`
- ADD candidates:
  - `qwen-3-235b-a22b-instruct-2507`
  - `zai-glm-4.7`

**NEW OpenRouter provider:**
- baseURL: `https://openrouter.ai/api/v1`
- apiKey: `{env:OPENROUTER_API_KEY}`
- Models (all `:free` suffix):
  - `deepseek/deepseek-r1-0528:free`
  - `deepseek/deepseek-chat-v3-0324:free`
  - `qwen/qwen3.6-plus:free`
  - `qwen/qwen3-coder-480b-a35b:free`
  - `meta-llama/llama-4-scout:free`
  - `meta-llama/llama-4-maverick:free`
  - `meta-llama/llama-3.3-70b-instruct:free`
  - `google/gemma-4-31b-it:free`
  - `nvidia/nemotron-3-super-120b-a12b:free`
  - `openai/gpt-oss-120b:free`
  - `minimax/minimax-m2.5:free`
  - `mistralai/devstral-2512:free`

**NEW Mistral AI provider:**
- baseURL: `https://api.mistral.ai/v1`
- apiKey: `{env:MISTRAL_API_KEY}`
- Models:
  - `mistral-small-4` (256K, text+image+code)
  - `mistral-medium-3` (128K)
  - `mistral-large-3` (256K)
  - `open-mistral-nemo` (128K)
  - `codestral` (256K, code)

### REQ-3: Reconfigure Tiers
For all tiers EXCEPT `opencode-go`, `github-copilot`, `github-copilot-student`, assign best-fit models per SDD phase based on:
- Phase requirements (orchestrator needs large context, coding needs code models, etc.)
- Actual verified availability from the Python script results
- Rate limits (avoid putting rate-limited models in high-frequency phases)

The script must be run FIRST, and its results drive which models go into which tier.

### REQ-4: Sops Integration
- Add `OPENROUTER_API_KEY` and `MISTRAL_API_KEY` to sops secrets
- Add environment variable exports in opencode.nix (like existing NVIDIA/Groq/Cerebras)

## Scenarios

**SCN-1**: User runs `python3 scripts/verify-models.py` → sees which models work → uses results to configure providers.nix
**SCN-2**: A model listed as "free" in awesome-free-llm-apis gives 403 error → script reports it → we don't add it
**SCN-3**: A model works but has severe rate limits → script reports rate limit info → we assign it only to low-frequency phases
**SCN-4**: User gets new API key → adds to sops → re-runs script → updates providers.nix

## Out of Scope
- GitHub Models, Gemini, OVHcloud, Cloudflare, SiliconFlow, LLM7, Kilo Code (deferred)
- `opencode-go`, `github-copilot`, `github-copilot-student` tiers (preserve as-is)
- OpenCode Zen provider changes (preserve as-is for now)