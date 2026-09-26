{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  nodejs,
}:

let
  versions = lib.importJSON ./versions.json;
  hashes = lib.importJSON ./node-modules.json;
  tarballName = name: if lib.hasPrefix "@" name then lib.last (lib.splitString "/" name) else name;
  sources = lib.genAttrs (lib.attrNames versions) (
    name:
    fetchurl {
      url = "https://registry.npmjs.org/${
        lib.replaceStrings [ "/" ] [ "%2F" ] name
      }/-/${tarballName name}-${versions.${name}}.tgz";
      hash = hashes.${name};
    }
  );
  copyCommands = lib.concatStrings (
    lib.mapAttrsToList (name: src: ''
      mkdir -p "$out/lib/node_modules/${name}"
      tar -xzf ${src} -C "$out/lib/node_modules/${name}" --strip-components=1
    '') sources
  );
in
stdenvNoCC.mkDerivation {
  pname = "browsermcp-v2";
  version = versions."@browsermcp/mcp";
  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    mkdir -p "$out/lib/node_modules"
    ${copyCommands}
    # BrowserMCP 0.1.3 keeps a resources/list handler, but OpenCode V2 must not
    # negotiate the incomplete resource-template capability. The bundled SDK
    # otherwise rejects registering that retained handler after the capability
    # is deliberately removed below.
    substituteInPlace "$out/lib/node_modules/@modelcontextprotocol/sdk/dist/esm/server/index.js" \
      --replace-fail 'if (!this._capabilities.resources)' 'if (false)'
    substituteInPlace "$out/lib/node_modules/@browsermcp/mcp/dist/index.js" \
      --replace-fail $'        tools: {},\n        resources: {}' $'        tools: {}'
    mkdir -p "$out/bin"
    makeWrapper ${nodejs}/bin/node "$out/bin/mcp-server-browsermcp" \
      --add-flags "$out/lib/node_modules/@browsermcp/mcp/dist/index.js" \
      --set NODE_PATH "$out/lib/node_modules"
  '';

  nativeBuildInputs = [ makeWrapper ];
  installPhase = "true";
  meta = with lib; {
    description = "Pinned BrowserMCP 0.1.3 with the incompatible resources capability removed";
    platforms = platforms.all;
  };
}
