# Linux-specific overlay
# Provides packages and overrides needed by NixOS hosts
{
  self,
  inputs,
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
    openfang
    ;

  # Local pkgs/ derivations
  asus-fan-control = final.callPackage ../pkgs/asus-fan-control {
    asus-fan-control-src = inputs.asus-fan-control-src;
  };
  pipewire-module-xrdp = final.callPackage ../pkgs/pipewire-module-xrdp {
    pipewire-module-xrdp-src = inputs.pipewire-module-xrdp-src;
  };

  libmateweather = prev.libmateweather.overrideAttrs (oldAttrs: {
    # Fix pointer offset bug in METAR parsing
    postPatch = (oldAttrs.postPatch or "") + ''
      substituteInPlace libmateweather/weather-metar.c \
        --replace-fail 'p += WEATHER_LOCATION_CODE_LEN + 11;' 'p += WEATHER_LOCATION_CODE_LEN + 17;'
    '';
  });
}
