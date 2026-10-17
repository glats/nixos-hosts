{
  self,
  inputs,
}:
final: prev: {
  inherit (self.packages.${prev.stdenv.hostPlatform.system})
    nixos-scripts
    gentle-ai
    engram
    gentle-ai-assets
    caveman-assets
    ponytail-assets
    local-ai-assets
    engram-assets
    engram-assets-vanilla
    opencode-npm-packages-v2
    browsermcp-v2
    opencode
    leaf
    herdr
    openfang
    mcp-supermercados-cl
    claude-code
    ;

  asus-fan-control = final.callPackage ../pkgs/asus-fan-control {
    asus-fan-control-src = inputs.asus-fan-control-src;
  };
  pipewire-module-xrdp = final.callPackage ../pkgs/pipewire-module-xrdp {
    pipewire-module-xrdp-src = inputs.pipewire-module-xrdp-src;
  };
  thinkfan-ui = final.callPackage ../pkgs/thinkfan-ui {
    thinkfan-ui-src = inputs.thinkfan-ui-src;
    wrapQtAppsHook = final.qt6.wrapQtAppsHook;
    qtbase = final.qt6.qtbase;
    qtsvg = final.qt6.qtsvg;
  };
  wstunnel-relay = final.callPackage ../pkgs/wstunnel-relay { };

  teams-for-linux =
    let
      tfl-src = prev.fetchFromGitHub {
        owner = "IsmaelMartinez";
        repo = "teams-for-linux";
        tag = "v2.15.0";
        hash = "sha256-PYRl0Q7vsx7nKz7pkoCg3f3rRIcgCAvGiALQxHEOIjE=";
      };
    in
    prev.teams-for-linux.overrideAttrs (oldAttrs: {
      version = "2.15.0";
      src = tfl-src;
      npmDeps = prev.fetchNpmDeps {
        src = tfl-src;
        hash = "sha256-FPnkCO1zf5Ts2arOa0InC7l4esRs4AuXYlVF/OYR6AI=";
      };
    });

  symbola = prev.symbola.overrideAttrs (oldAttrs: {
    src = prev.fetchzip {
      url = "https://slackware.uk/salix/i486/extra-15.0/source/system/symbola-font-ttf/Symbola.zip";
      stripRoot = false;
      hash = "sha256-TsHWmzkEyMa8JOZDyjvk7PDhm239oH/FNllizNFf398=";
    };
  });

  libmateweather = prev.libmateweather.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace libmateweather/weather-metar.c \
        --replace-fail 'p += WEATHER_LOCATION_CODE_LEN + 11;' 'p += WEATHER_LOCATION_CODE_LEN + 17;'
    '';
  });

  mate-media = prev.mate-media.overrideAttrs (oldAttrs: {
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ final.mate-settings-daemon ];
  });

  afdko-4_0_3 = prev.python3.pkgs.afdko.overridePythonAttrs (_: {
    pname = "afdko";
    version = "4.0.3";
    src = prev.fetchFromGitHub {
      owner = "adobe-type-tools";
      repo = "afdko";
      rev = "4.0.3";
      hash = "sha256-sQka6Szb8A68RFrwaNM5fN3PAeYJ+PGQ/b2ALYT07i4=";
    };
    patches = [ ];
    nativeBuildInputs = [
      prev.python3.pkgs.scikit-build
    ];
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
    doCheck = false;
    dontUsePytestCheck = true;
  });

  cffsubr = prev.python3.pkgs.cffsubr.override { afdko = final.afdko-4_0_3; };

  cantarell-fonts = prev.cantarell-fonts.overrideAttrs (oldAttrs: {
    nativeBuildInputs = map (
      inp:
      if (inp.pname or "") == "afdko" || (inp.pname or "") == "cffsubr" then
        if (inp.pname or "") == "afdko" then final.afdko-4_0_3 else final.cffsubr
      else
        inp
    ) oldAttrs.nativeBuildInputs;
  });
}
