{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.home.shell-gpt;
in
{
  options.home.shell-gpt = {
    enable = mkEnableOption "ShellGPT AI-powered shell command assistant using nvidia NIM (nemotron-3-ultra). Usage: sgpt --shell \"<natural language request>\"";

    model = mkOption {
      type = types.str;
      default = "nvidia/nemotron-3-ultra-550b-a55b";
      description = "Model ID sent to nvidia NIM. Override per host for flash/cheaper models.";
    };

    baseUrl = mkOption {
      type = types.str;
      default = "https://integrate.api.nvidia.com/v1";
      description = "OpenAI-compatible API base URL. Change to switch providers (ollama, opencode-go, etc.).";
    };

    provider = mkOption {
      type = types.str;
      default = "nvidia";
      description = "Provider identifier for documentation. Not consumed by shell-gpt directly.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.shell-gpt ];

    home.sessionVariables = {
      API_BASE_URL = cfg.baseUrl;
      OPENAI_API_KEY = "$(cat ${config.sops.secrets."opencode/nvidia_api_key".path})";
      DEFAULT_MODEL = cfg.model;
      SHELL_INTERACTION = "true";
      DEFAULT_EXECUTE_SHELL_CMD = "false";
    };
  };
}
