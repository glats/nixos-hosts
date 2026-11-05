{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.gastown;
in
{
  options.gastown = {
    enable = lib.mkEnableOption "the pinned Gas Town toolchain and gastown-run (on-demand, no service)";

    toolPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.go pkgs.gnumake ]";
      description = ''
        Packages placed on PATH for the sandboxed Codex executor and for the
        trusted checks gastown-run runs. bash, coreutils, git, grep, sed, awk, find,
        diff and make are always present; add the toolchain of the projects
        you run tasks on.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.gastown
      (pkgs.gastown-run.override { toolPackages = cfg.toolPackages; })
    ];
  };
}
