{ config, ... }:

{
  # Home-manager sops config - uses user key for user-specific secrets
  sops.defaultSopsFile = ../../secrets/user/api_keys.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # NVIDIA NIM API key for OpenCode provider
  sops.secrets."opencode/nvidia_api_key" = {
    mode = "0400";
  };

  # Groq API key for OpenCode provider
  sops.secrets."opencode/groq_api_key" = {
    mode = "0400";
  };

  # Cerebras API key for OpenCode provider
  sops.secrets."opencode/cerebras_api_key" = {
    mode = "0400";
  };

  # OpenCode Go API key
  sops.secrets."opencode/opencode_go_api_key" = {
    mode = "0400";
  };

  # OpenRouter API key
  sops.secrets."opencode/openrouter_api_key" = {
    mode = "0400";
  };

  # Mistral API key
  sops.secrets."opencode/mistral_api_key" = {
    mode = "0400";
  };

  # Cohere API key
  sops.secrets."opencode/cohere_api_key" = {
    mode = "0400";
  };

  # Gemini API key
  sops.secrets."opencode/gemini_api_key" = {
    mode = "0400";
  };

  # Cloudflare API key
  sops.secrets."opencode/cloudflare_api_key" = {
    mode = "0400";
  };

  # Cloudflare Account ID
  sops.secrets."opencode/cloudflare_account_id" = {
    mode = "0400";
  };

  # HuggingFace API key
  sops.secrets."opencode/huggingface_api_key" = {
    mode = "0400";
  };

  # Kilo API key
  sops.secrets."opencode/kilo_api_key" = {
    mode = "0400";
  };
}
