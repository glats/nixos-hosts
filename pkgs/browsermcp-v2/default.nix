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
  postInstall = ''
    # BrowserMCP 0.1.3 keeps a resources/list handler, but OpenCode V2 must not
    # negotiate the incomplete resource-template capability. The bundled SDK
    # otherwise rejects registering that retained handler after the capability
    # is deliberately removed below.
    substituteInPlace "$out/lib/node_modules/@modelcontextprotocol/sdk/dist/esm/server/index.js" \
      --replace-fail 'if (!this._capabilities.resources)' 'if (false)'
    substituteInPlace "$out/lib/node_modules/@browsermcp/mcp/dist/index.js" \
       --replace-fail $'        tools: {},\n        resources: {}' $'        tools: {}'
    # BrowserMCP 0.1.3 kills whichever process owns its fixed extension port
    # before starting. The V2 singleton owns that lifecycle, so leave a busy
    # port to fail normally instead of killing an unrelated process.
    substituteInPlace "$out/lib/node_modules/@browsermcp/mcp/dist/index.js" \
      --replace-fail $'  killProcessOnPort(port);\n' ""
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    node check.mjs "$out"
    runHook postInstallCheck
  '';
  meta = with lib; {
    description = "Pinned BrowserMCP 0.1.3 with compatible capabilities and safe port ownership";
    platforms = platforms.all;
  };
}
