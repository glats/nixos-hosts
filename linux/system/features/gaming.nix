{ lib
, config
, pkgs
, ...
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
    # Single merged systemPackages — NixOS does not allow duplicate keys.
    environment.systemPackages =
      lib.optionals cfg.retroarch.enable [
        (pkgs.retroarch.withCores (
          cores: with cores; [
            snes9x # SNES
            genesis-plus-gx # Genesis / Mega Drive / Game Gear
            mgba # Game Boy / Color / Advance
            sameboy # Game Boy / Color (high accuracy)
            fbneo # Neo Geo / CPS / arcade
            mupen64plus # N64
            beetle-psx-hw # PSX (hardware-rendered)
            flycast # Dreamcast / Naomi / Atomiswave
            ppsspp # PSP (libretro core)
          ]
        ))
        pkgs.retroarch-assets
        pkgs.libretro-shaders-slang
      ]
      ++ lib.optionals cfg.standalone.enable [
        pkgs.pcsx2 # PS2
        pkgs.dolphin-emu # GameCube / Wii
        pkgs.ppsspp # PSP standalone
      ]
      ++ lib.optionals cfg.aspirational.enable [
        pkgs.rpcs3 # PS3 (slow build ~20min, APU may throttle)
        pkgs.ryubing # Switch (community fork, experimental)
      ]
      ++ lib.optionals cfg.pegasus.enable [
        pkgs.pegasus-frontend
      ];
  };
}
