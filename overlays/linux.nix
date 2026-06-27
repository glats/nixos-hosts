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
}
