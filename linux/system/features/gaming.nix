{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.my.gaming;
in
{
  options.my.gaming = {
    enable = lib.mkEnableOption "emulation stack (RetroArch + standalone emulators)";
    retroarch.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "RetroArch with curated libretro cores";
    };
    standalone.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Standalone emulators (PCSX2, Dolphin, PPSSPP)";
    };
    aspirational.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Heavy standalone emulators — RPCS3 + Ryubing (slow builds, laptop APU may throttle)";
    };
    pegasus.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Pegasus frontend for controller-navigable catalog browsing";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      lib.optionals cfg.retroarch.enable [
        (pkgs.retroarch.withCores (
          cores: with cores; [
            snes9x
            genesis-plus-gx
            mgba
            sameboy
            fbneo
            mupen64plus
            beetle-psx-hw
            flycast
            ppsspp
          ]
        ))
        pkgs.retroarch-assets
        pkgs.libretro-shaders-slang
      ]
      ++ lib.optionals cfg.standalone.enable [
        pkgs.pcsx2
        pkgs.dolphin-emu
        pkgs.ppsspp
      ]
      ++ lib.optionals cfg.aspirational.enable [
        pkgs.rpcs3
        pkgs.ryubing
      ]
      ++ lib.optionals cfg.pegasus.enable [
        pkgs.pegasus-frontend
      ];
  };
}
