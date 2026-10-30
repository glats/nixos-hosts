{
  lib,
  buildNpmPackage,
  importNpmLock,
  makeWrapper,
  nodejs,
}:

buildNpmPackage {
  pname = "browsermcp-v2";
  version = (lib.importJSON ./package.json).dependencies."@browsermcp/mcp";
  src = ./.;
  npmDeps = importNpmLock { npmRoot = ./.; };
  npmConfigHook = importNpmLock.npmConfigHook;
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    cp -a node_modules "$out/lib/node_modules"
    mkdir -p "$out/bin"
    makeWrapper ${nodejs}/bin/node "$out/bin/mcp-server-browsermcp" \
      --add-flags "$out/lib/node_modules/@browsermcp/mcp/dist/index.js" \
      --set NODE_PATH "$out/lib/node_modules"
    runHook postInstall
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    node check.mjs "$out"
    runHook postInstallCheck
  '';
  meta = with lib; {
    description = "Pinned BrowserMCP server";
    platforms = platforms.all;
  };
}
