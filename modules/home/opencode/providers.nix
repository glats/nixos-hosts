{ lib ? throw "providers.nix must be imported with lib" }:

let
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

  allProviders = nvidiaProvider;

  activeProviderName = "nvidia";

  providers = [
    {
      name = "nvidia";
      phases = {
        sdd-orchestrator = "nvidia/z-ai/glm-5.1";
        sdd-init = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-explore = "nvidia/z-ai/glm-5.1";
        sdd-propose = "nvidia/z-ai/glm-5.1";
        sdd-spec = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-design = "nvidia/z-ai/glm-5.1";
        sdd-tasks = "nvidia/nvidia/nemotron-3-super-120b-a12b";
        sdd-apply = "nvidia/minimaxai/minimax-m2.7";
        sdd-verify = "nvidia/z-ai/glm-5.1";
        sdd-archive = "nvidia/z-ai/glm-5.1";
        sdd-onboard = "nvidia/z-ai/glm-5.1";
        neutral = "nvidia/z-ai/glm-5.1";
      };
    }
    {
      name = "github-copilot";
      phases = {
        sdd-orchestrator = "github-copilot/gpt-5.4";
        sdd-init = "github-copilot/gpt-5.4-mini";
        sdd-explore = "github-copilot/gpt-5.4";
        sdd-propose = "github-copilot/claude-sonnet-4.6";
        sdd-spec = "github-copilot/claude-sonnet-4.6";
        sdd-design = "github-copilot/claude-sonnet-4.6";
        sdd-tasks = "github-copilot/claude-sonnet-4.6";
        sdd-apply = "github-copilot/gpt-5.4";
        sdd-verify = "github-copilot/gpt-5.4-mini";
        sdd-archive = "github-copilot/claude-haiku-4.5";
        sdd-onboard = "github-copilot/gpt-5.4-mini";
        neutral = "github-copilot/claude-sonnet-4.6";
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
  inherit nvidiaProvider allProviders providers activeProviderName activeProvider getModelForPhase;
}
