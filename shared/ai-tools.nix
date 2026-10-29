{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.home.ai-tools = {
    enable = lib.mkEnableOption "Shared AI command-line tools";
    gentlePackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gentle-ai;
      description = "Gentle AI package, optionally wrapped by a client integration.";
    };
  };

  config = lib.mkIf config.home.ai-tools.enable {
    home.packages = [
      config.home.ai-tools.gentlePackage
      pkgs.engram
      pkgs.rtk
      pkgs.poppler-utils
    ];
    home.sessionVariables.RTK_TELEMETRY_DISABLED = "1";
  };
}
