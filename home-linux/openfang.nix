{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.home.openfang;
in
{
  options.home.openfang = {
    enable = mkEnableOption "OpenFang Telegram channel configuration" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    # Ensure systemd user services are enabled
    systemd.user.enable = true;

    # Generate OpenFang config.toml with Telegram and OpenCode Go via proxy
    home.file.".openfang/config.toml" = {
      force = true;
      text = ''
        [channels.telegram]
        enabled = true
        bot_token_env = "TELEGRAM_BOT_TOKEN"

        [channels.telegram.overrides]
        lifecycle_reactions = false

        [default_model]
        provider = "openai"
        model = "qwen3.6-plus"
        api_key_env = "OPENCODE_API_KEY"
        base_url = "http://127.0.0.1:9999/v1"

        [memory]
        embedding_provider = "ollama"

        [exec_policy]
        mode = "allowlist"
        safe_bins = [
          "cat", "ls", "grep", "find", "head", "tail", "echo",
          "ps", "top", "df", "du", "id", "whoami", "pwd", "env",
          "which", "file", "stat", "readlink", "sensors",
          "uname", "hostname", "free", "lsblk", "lscpu", "wc",
          "sort", "uniq", "cut", "tr", "date", "printf",
          "basename", "dirname"
        ]
        allowed_commands = [
          "git status", "git log", "git diff", "git show", "git branch",
          "journalctl --user", "systemctl --user status",
          "nixos-version", "df -h", "ps aux", "ls -la",
          "free -h", "nix flake check --dry-run"
        ]
        timeout_secs = 30
        max_output_bytes = 102400

        [approval]
        require_approval = [
          "shell_exec", "file_write", "apply_patch",
          "process_kill", "agent_kill", "agent_spawn",
          "cron_create", "docker_exec", "browser_run_js",
          "schedule_create", "schedule_delete", "event_publish"
        ]
        auto_approve = false
        timeout_secs = 60
      '';
    };

    # Export secrets from sops to shell environment
    # This enables `openfang status` and other commands in the terminal
    programs.zsh.initContent = lib.mkAfter ''
      if [ -f "${config.sops.secrets."openfang/telegram_bot_token".path}" ]; then
        export TELEGRAM_BOT_TOKEN="$(cat ${config.sops.secrets."openfang/telegram_bot_token".path})"
      fi
      if [ -f "${config.sops.secrets."openfang/api_key".path}" ]; then
        export OPENCODE_API_KEY="$(cat ${config.sops.secrets."openfang/api_key".path})"
      fi
    '';

    # Wrapper script that reads sops secrets and exports them before starting openfang
    home.file.".local/bin/openfang-start" = {
      executable = true;
      text = ''
        #!/usr/bin/env bash
        export TELEGRAM_BOT_TOKEN="$(cat ${config.sops.secrets."openfang/telegram_bot_token".path})"
        export OPENCODE_API_KEY="$(cat ${config.sops.secrets."openfang/api_key".path})"
        exec ${pkgs.openfang}/bin/openfang start
      '';
    };

    # Systemd user service for OpenCode Go proxy
    systemd.user.services.opencode-go-proxy = {
      Unit = {
        Description = "OpenCode Go proxy with thinking disabled";
        After = [ "default.target" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.python3}/bin/python3 ${config.home.homeDirectory}/.local/bin/opencode-go-proxy.py";
        Restart = "on-failure";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };

    # Systemd user service to run OpenFang automatically on graphical login
    systemd.user.services.openfang = {
      Unit = {
        Description = "OpenFang AI coding agent with Telegram integration";
        After = [
          "default.target"
          "opencode-go-proxy.service"
        ];
        Requires = [ "opencode-go-proxy.service" ];
      };

      Service = {
        Type = "simple";
        ExecStart = "${config.home.homeDirectory}/.local/bin/openfang-start";
        Restart = "always";
        RestartSec = "5s";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
}
