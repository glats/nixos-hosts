{ config, lib, ... }:

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

    # Generate OpenFang config.toml with Telegram channel enabled
    home.file.".openfang/config.toml" = {
      force = true;
      text = ''
        [channels.telegram]
        enabled = true
        bot_token_env = "TELEGRAM_BOT_TOKEN"
      '';
    };

    # Export Telegram bot token from sops secret to shell environment
    # This enables `openfang status` and other commands in the terminal
    programs.zsh.initContent = lib.mkAfter ''
      if [ -f "${config.sops.secrets."openfang/telegram_bot_token".path}" ]; then
        export TELEGRAM_BOT_TOKEN="$(cat ${config.sops.secrets."openfang/telegram_bot_token".path})"
      fi
    '';

    # Systemd user service to run OpenFang automatically on login
    systemd.user.services.openfang = {
      Unit = {
        Description = "OpenFang AI coding agent with Telegram integration";
        After = [ "default.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.openfang}/bin/openfang start";
        Restart = "on-failure";
        RestartSec = "5s";

        # Pass Telegram bot token directly from sops secret
        # Systemd services do not inherit shell environment variables
        Environment = [
          "TELEGRAM_BOT_TOKEN=${config.sops.secrets."openfang/telegram_bot_token".path}"
        ];
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
