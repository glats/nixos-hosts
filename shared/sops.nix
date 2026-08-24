{ config, ... }:

{
  # Shared sops configuration — imported by linux/home and darwin/home
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
  sops.secrets."opencode/aihubmix_api_key" = {
    mode = "0400";
  };

  # Scoped client key for the rog-hosted `openai-proxy` gateway
  # (https://oai.glats.org/v1). Used by mact2 (and any other host
  # pointing at the proxy) via OPENAI_PROXY_API_KEY. The upstream
  # credential stays server-side on rog. Lives in the rog host
  # secret file but the .sops.yaml creation rule for that file
  # explicitly includes the mact2 host key, so mact2 can decrypt.
  sops.secrets."openai_proxy/client_key" = {
    sopsFile = ../secrets/host/rog/openai-proxy.yaml;
    mode = "0400";
  };

  # Identity values from sops (name + email for git/GPG) — flat strings per sops requirement
  sops.secrets."identities/personal_name" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
  sops.secrets."identities/personal_email" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
  sops.secrets."identities/work_name" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };
  sops.secrets."identities/work_email" = {
    sopsFile = ../secrets/user/identities.yaml;
    mode = "0400";
  };

  # GPG keys per identity (new named paths)
  sops.secrets."github/personal_gpg_fingerprint" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/personal_gpg_key" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/work_gpg_fingerprint" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
  sops.secrets."github/work_gpg_key" = {
    sopsFile = ../secrets/shared/passwords.yaml;
    mode = "0400";
  };
}
