{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  versions = lib.importJSON ./versions.json;
  hashes = lib.importJSON ./node-modules.json;
  package = "@opencode/plugin";
  version = versions.${package};
in
stdenvNoCC.mkDerivation {
  pname = "opencode-npm-packages-v2";
  inherit version;
  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    mkdir -p "$out/lib/node_modules/${package}"
    tar -xzf ${fetchurl {
      url = "https://registry.npmjs.org/%40opencode%2Fplugin/-/plugin-${version}.tgz";
      hash = hashes.${package};
    }} -C "$out/lib/node_modules/${package}" --strip-components=1
    echo '${builtins.toJSON versions}' > "$out/package.json"
  '';

  installPhase = "true";

  meta = with lib; {
    description = "Pinned OpenCode V2 plugin API package";
    platforms = platforms.all;
  };
}
