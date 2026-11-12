{ config, ... }:

{
  sops.defaultSopsFile = ../secrets/user/opencode.yaml;
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

  sops.secrets."opencode/nvidia_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/ollama_api_key" = {
    mode = "0400";
  };
  sops.secrets."opencode/groq_api_key" = {
    mode = "0400";
  };
  sops.secrets."link_grabber/telegram_token" = {
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

  sops.secrets."github/work_user" = {
    sopsFile = ../secrets/user/github.yaml;
    mode = "0400";
  };
  sops.secrets."github/work_account" = {
    sopsFile = ../secrets/user/github.yaml;
    mode = "0400";
  };

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

  sops.templates."gpg-unlock-keys" = {
    content = ''
      ${config.sops.placeholder."github/personal_gpg_fingerprint"}
      ${config.sops.placeholder."github/work_gpg_fingerprint"}
    '';
    mode = "0400";
  };
}
