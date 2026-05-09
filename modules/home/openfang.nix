{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.home.openfang;
in
{
  options.home.openfang = {
    enable = mkEnableOption "OpenFang Telegram channel configuration" // { default = true; };
  };

  config = mkIf cfg.enable {
    # Ensure systemd user services are enabled
    systemd.user.enable = true;

    # Generate OpenFang config.toml with Telegram and NVIDIA NIM provider
    home.file.".openfang/config.toml" = {
      force = true;
      text = ''
        [channels.telegram]
        enabled = true
        bot_token_env = "TELEGRAM_BOT_TOKEN"

        [channels.telegram.overrides]
        lifecycle_reactions = false

        [default_model]
        provider = "nvidia"
          model = "z-ai/glm5"
        api_key_env = "NVIDIA_API_KEY"

        [exec_policy]
        mode = "full"

        [provider_urls]
        nvidia = "https://integrate.api.nvidia.com/v1"
      '';
    };

    # Export secrets from sops to shell environment
    # This enables `openfang status` and other commands in the terminal
    programs.zsh.initContent = lib.mkAfter ''
      if [ -f "${config.sops.secrets."openfang/telegram_bot_token".path}" ]; then
        export TELEGRAM_BOT_TOKEN="$(cat ${config.sops.secrets."openfang/telegram_bot_token".path})"
      fi
      if [ -f "${config.sops.secrets."opencode/nvidia_api_key".path}" ]; then
        export NVIDIA_API_KEY="$(cat ${config.sops.secrets."opencode/nvidia_api_key".path})"
      fi
    '';

    # Wrapper script that reads sops secrets and exports them before starting openfang
    home.file.".local/bin/openfang-start" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        export TELEGRAM_BOT_TOKEN="$(cat ${config.sops.secrets."openfang/telegram_bot_token".path})"
        export NVIDIA_API_KEY="$(cat ${config.sops.secrets."opencode/nvidia_api_key".path})"
        exec ${pkgs.openfang}/bin/openfang start
      '';
    };

    # Systemd user service to run OpenFang automatically on login
    systemd.user.services.openfang = {
      Unit = {
        Description = "OpenFang AI coding agent with Telegram integration";
        After = [ "default.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${config.home.homeDirectory}/.local/bin/openfang-start";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
