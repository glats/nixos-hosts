{ libretro }:
libretro.snes9x.overrideAttrs (old: {
  installPhase = ''
    runHook preInstall
    install -Dt "$out/lib/retroarch/cores" snes9x_libretro.dylib
    runHook postInstall
  '';

  meta = (builtins.removeAttrs old.meta [ "mainProgram" ]) // {
    platforms = [ "aarch64-darwin" ];
  };
})
