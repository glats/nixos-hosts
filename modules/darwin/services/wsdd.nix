{ config
, lib
, pkgs
, host
, ...
}:
let
  cfg = config.services.wsdd;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    optionals
    ;
  programArgs = [
    "${cfg.package}/bin/wsdd"
    "--hostname"
    cfg.hostname
  ]
  ++ optionals (cfg.workgroup != null) [
    "--workgroup"
    cfg.workgroup
  ]
  ++ optionals (cfg.interface != null) [
    "--interface"
    cfg.interface
  ]
  ++ cfg.extraArgs;
in
{
  options.services.wsdd = {
    enable = mkEnableOption "WS-Discovery daemon for SMB discovery on Windows";

    package = mkOption {
      type = types.package;
      default = pkgs.wsdd;
      description = "Package that provides the wsdd binary.";
    };

    hostname = mkOption {
      type = types.str;
      default = host;
      description = "Hostname advertised to Windows clients.";
    };

    interface = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional network interface name to bind (e.g. en0).";
    };

    workgroup = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional SMB workgroup name.";
    };

    extraArgs = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional command-line flags for wsdd.";
    };

    logFile = mkOption {
      type = types.str;
      default = "/var/log/wsdd.log";
      description = "Location for stdout/stderr logs.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    launchd.daemons.wsdd = {
      serviceConfig = {
        ProgramArguments = programArgs;
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = cfg.logFile;
        StandardErrorPath = cfg.logFile;
        ProcessType = "Background";
      };
    };
  };
}
