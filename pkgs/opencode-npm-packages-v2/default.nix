{
  lib,
  buildNpmPackage,
  importNpmLock,
}:

let
  package = lib.importJSON ./package.json;
in
buildNpmPackage {
  pname = "opencode-npm-packages-v2";
  version = package.dependencies."@opencode/plugin";
  src = ./.;
  npmDeps = importNpmLock { npmRoot = ./.; };
  npmConfigHook = importNpmLock.npmConfigHook;
  dontNpmBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    cp -a node_modules "$out/lib/node_modules"
    echo '${builtins.toJSON package.dependencies}' > "$out/package.json"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    node check.mjs "$out"
    runHook postInstallCheck
  '';
  meta = with lib; {
    description = "Pinned OpenCode V2 plugin API production dependency closure";
    platforms = platforms.all;
  };
}
