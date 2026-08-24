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
