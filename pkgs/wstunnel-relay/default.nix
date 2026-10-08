{
  fetchurl,
  file,
  gnutar,
  gzip,
  lib,
  stdenvNoCC,
}:

let
  assets = {
    "x86_64-linux" = {
      name = "wstunnel_11.0.0_linux_amd64.tar.gz";
      hash = "sha256-lwiplxe1qVFFPC/3wUwl00GNAsp/y5b9s4Ko8gg7q14=";
    };
    "aarch64-darwin" = {
      name = "wstunnel_11.0.0_darwin_arm64.tar.gz";
      hash = "sha256-FQ5DnIuUhZFUkD1xMTtMCzE6ycz5lDevQlcxNOUFHcQ=";
    };
  };
  system = stdenvNoCC.hostPlatform.system;
  canExecute = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  asset =
    if builtins.hasAttr system assets then
      assets.${system}
    else
      throw "wstunnel-relay: unsupported platform ${system}; only x86_64-linux and aarch64-darwin are pinned";
in
stdenvNoCC.mkDerivation {
  pname = "wstunnel-relay";
  version = "11.0.0";

  src = fetchurl {
    url = "https://github.com/erebe/wstunnel/releases/download/v11.0.0/${asset.name}";
    hash = asset.hash;
  };

  nativeBuildInputs = [
    file
    gnutar
    gzip
  ];

  dontStrip = true;

  unpackPhase = "true";

  installPhase = ''
    runHook preInstall
    mkdir -p unpack
    tar -xzf "$src" -C unpack
    install -Dm755 unpack/wstunnel "$out/bin/wstunnel"
    runHook postInstall
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    file "$out/bin/wstunnel"
    test -x "$out/bin/wstunnel"
    ${lib.optionalString canExecute ''
      "$out/bin/wstunnel" --version
      "$out/bin/wstunnel" --help >/dev/null
    ''}
    runHook postInstallCheck
  '';

  doInstallCheck = true;

  meta = {
    description = "Official precompiled wstunnel relay transport";
    homepage = "https://github.com/erebe/wstunnel";
    license = lib.licenses.bsd3;
    mainProgram = "wstunnel";
    platforms = builtins.attrNames assets;
  };
}
