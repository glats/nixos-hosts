{ config, ... }:

{
  # Shared sops configuration — imported by home-linux and home-darwin
  sops.defaultSopsFile = ../secrets/user/opencode.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  # OpenCode API keys (cross-platform)
  sops.secrets."opencode/nvidia_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/opencode_go_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/groq_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/cerebras_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/openrouter_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/mistral_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/cohere_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/gemini_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/cloudflare_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/cloudflare_account_id" = {
    mode = "0400";
  };
  sops.secrets."opencode/huggingface_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/kilo_api_key" = {
    mode = "0400";
  };

  # GitHub PAT (also declared at NixOS level for MCP wrapper)
  sops.secrets."github/pat" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/pat_jcuzmar" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
}
