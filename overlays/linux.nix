# Linux-specific overlay
# Provides packages and overrides needed by NixOS hosts
{ self
, inputs
,
}:
final: prev: {
  # Cross-platform packages from flake outputs
  inherit (self.packages.${prev.stdenv.hostPlatform.system})
    nixos-scripts
    gentle-ai
    engram
    gentle-ai-assets
    gentle-ai-assets-vanilla
    engram-assets
    engram-assets-vanilla
    secret-guard-assets
    opencode-npm-packages
    opencode
    openfang
    ;

  # Local pkgs/ derivations
  asus-fan-control = final.callPackage ../pkgs/asus-fan-control {
    asus-fan-control-src = inputs.asus-fan-control-src;
  };
  pipewire-module-xrdp = final.callPackage ../pkgs/pipewire-module-xrdp {
    pipewire-module-xrdp-src = inputs.pipewire-module-xrdp-src;
  };

  # linuxPackages_zen is used as-is from nixpkgs (pinned via flake.lock).
  # The kernel produces vmlinuz instead of bzImage on 7.x (nixpkgs#521113).
  # Instead of overriding the kernel (which changes the hash and forces a
  # from-source rebuild), we set system.boot.loader.kernelFile = "vmlinuz"
  # in modules/features/boot.nix. The file IS a valid bzImage — just
  # named vmlinuz. The kernel stays in cache.nixos.org.

  # Symbola font: archive.org is unreliable and frequently drops snapshots or
  # times out. Use a stable mirror (Slackware UK Salix) instead.
  symbola = prev.symbola.overrideAttrs (oldAttrs: {
    src = prev.fetchzip {
      url = "https://slackware.uk/salix/i486/extra-15.0/source/system/symbola-font-ttf/Symbola.zip";
      stripRoot = false;
      hash = "sha256-TsHWmzkEyMa8JOZDyjvk7PDhm239oH/FNllizNFf398=";
    };
  });

  libmateweather = prev.libmateweather.overrideAttrs (oldAttrs: {
    # Fix pointer offset bug in METAR parsing
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace libmateweather/weather-metar.c \
        --replace-fail 'p += WEATHER_LOCATION_CODE_LEN + 11;' 'p += WEATHER_LOCATION_CODE_LEN + 17;'
    '';
  });

  # Shared afdko 4.0.3 override. Pin afdko back to 4.0.3 (which cantarell-fonts
  # upstream tests against and pins in its uv.lock) because nixpkgs' afdko
  # 5.0.1 regresses VF hinting and crashes otfautohint with
  # `assert lo is not None and hi is not None` on Cantarell-VF.otf
  # (NixOS/nixpkgs#535887).
  # TODO: remove when NixOS/nixpkgs#535887 is fixed upstream.
  afdko-4_0_3 = prev.python3.pkgs.afdko.overridePythonAttrs (_: {
    pname = "afdko";
    version = "4.0.3";
    src = prev.fetchFromGitHub {
      owner = "adobe-type-tools";
      repo = "afdko";
      rev = "4.0.3";
      hash = "sha256-sQka6Szb8A68RFrwaNM5fN3PAeYJ+PGQ/b2ALYT07i4=";
    };
    # 4.0.3 has a different source layout (no third_party/); the
    # 5.0.1 patches target paths that don't exist in 4.0.3.
    patches = [ ];
    # 4.0.3's pyproject.toml declares `scikit-build` (legacy) as a
    # build-system requirement, while nixpkgs' afdko 5.0.1 uses
    # `scikit-build-core`. Add the legacy package so the wheel
    # build can find `skbuild`.
    nativeBuildInputs = [
      prev.python3.pkgs.scikit-build
    ];
    # 4.0.3's build clones antlr4 from GitHub via
    # ExternalAntlr4Cpp.cmake, which fails in a network-less Nix
    # sandbox. Replace the include with an imported target that
    # points at the system antlr4-runtime. 4.0.3's CMakeLists.txt
    # honours FORCE_SYSTEM_LIBXML2 natively.
    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail 'include(ExternalAntlr4Cpp)' \
                      'add_library(antlr4_static STATIC IMPORTED)
      set_target_properties(antlr4_static PROPERTIES
        IMPORTED_LOCATION "${prev.antlr4_13.runtime.cpp}/lib/libantlr4-runtime.a"
        INTERFACE_INCLUDE_DIRECTORIES "${prev.antlr4_13.runtime.cpp.dev}/include/antlr4-runtime")'
    '';
    cmakeFlags = [
      "-DANTLR4_INCLUDE_DIRS=${prev.antlr4_13.runtime.cpp.dev}/include/antlr4-runtime"
    ];
    env = {
      FORCE_SYSTEM_LIBXML2 = "true";
    };
    # 4.0.3's pytest test files don't exist in the same shape as
    # 5.0.1's; disable pytest (doCheck=false alone doesn't unhook
    # pytest because pytest-check-hook registers unconditionally).
    doCheck = false;
    dontUsePytestCheck = true;
  });

  # cffsubr 0.4.0 ships a bundled `tx` (from afdko 5.0.1) with hard-coded
  # paths to afdko 5.0.1's site-packages. Rebuild cffsubr against the
  # 4.0.3 afdko above so its wrapper points at the 4.0.3 path.
  cffsubr = prev.python3.pkgs.cffsubr.override { afdko = final.afdko-4_0_3; };

  # cantarell-fonts 0.311's build:
  #   1. Calls `otfautohint` from afdko (we want 4.0.3 to avoid the regression)
  #   2. Runs `cffsubr.subroutinize` which internally invokes a bundled `tx`
  #      (from cffsubr; cffsubr's `tx` is rebuilt above against afdko 4.0.3)
  # Both deps must be the 4.0.3 builds.
  cantarell-fonts = prev.cantarell-fonts.overrideAttrs (oldAttrs: {
    nativeBuildInputs = map
      (
        inp:
        if (inp.pname or "") == "afdko" || (inp.pname or "") == "cffsubr" then
          if (inp.pname or "") == "afdko" then final.afdko-4_0_3 else final.cffsubr
        else
          inp
      )
      oldAttrs.nativeBuildInputs;
  });
}
