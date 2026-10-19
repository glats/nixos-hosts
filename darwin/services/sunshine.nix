{
  config,
  lib,
  pkgs,
  host,
  ...
}:
let
  cfg = config.services.sunshine;
  inherit (lib)
    mkEnableOption
    mkDefault
    mkIf
    mkOption
    types
    mapAttrsToList
    ;
  userHome = config.users.users.${config.system.primaryUser}.home;
in
{
  options.services.sunshine = {
    enable = mkEnableOption "Sunshine game-stream host for Moonlight clients";

    package = mkOption {
      type = types.package;
      default = pkgs.sunshine;
      description = "Package that provides the sunshine binary.";
    };

    settings = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Sunshine options passed as name=value arguments; the defaults restrict the web UI to localhost and disable the macOS tray icon, which crashes Sunshine during pairing.";
    };

    logFile = mkOption {
      type = types.str;
      default = "${userHome}/Library/Logs/sunshine.log";
      description = "Location for stdout/stderr logs.";
    };
  };

  config = mkIf cfg.enable {
    services.sunshine.settings = {
      sunshine_name = mkDefault host;
      origin_web_ui_allowed = mkDefault "pc";
      system_tray = mkDefault "disabled";
    };

    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.sunshine = {
      serviceConfig = {
        ProgramArguments = [
          "${cfg.package}/bin/sunshine"
        ]
        ++ mapAttrsToList (name: value: "${name}=${value}") cfg.settings;
        KeepAlive.SuccessfulExit = false;
        ThrottleInterval = 30;
        RunAtLoad = true;
        StandardOutPath = cfg.logFile;
        StandardErrorPath = cfg.logFile;
        ProcessType = "Interactive";
      };
    };
  };
}
