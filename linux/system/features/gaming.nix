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
      description = "Standalone emulators (PCSX2, Dolphin, PPSSPP, Azahar)";
    };
    switch.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Ryubing, the Nintendo Switch emulator";
    };
    aspirational.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Heavy standalone emulators — RPCS3 (slow builds, laptop APU may throttle)";
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
            fceumm
            snes9x
            genesis-plus-gx
            mgba
            sameboy
            fbneo
            mupen64plus
            parallel-n64
            melonds
            beetle-psx-hw
            beetle-saturn
            flycast
            ppsspp
            stella
            handy
          ]
        ))
        pkgs.retroarch-assets
        pkgs.libretro-shaders-slang
      ]
      ++ lib.optionals cfg.standalone.enable [
        pkgs.pcsx2
        pkgs.dolphin-emu
        pkgs.ppsspp
        pkgs.azahar
      ]
      ++ lib.optionals cfg.switch.enable [ pkgs.ryubing ]
      ++ lib.optionals cfg.aspirational.enable [ pkgs.rpcs3 ]
      ++ lib.optionals cfg.pegasus.enable [
        pkgs.pegasus-frontend
      ];
  };
}
