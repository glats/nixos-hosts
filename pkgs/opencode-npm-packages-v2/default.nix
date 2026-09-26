{
  lib,
  stdenvNoCC,
  fetchurl,
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
  pname = "opencode-npm-packages-v2";
  version = versions."@opencode/plugin";
  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    mkdir -p "$out/lib/node_modules"
    ${copyCommands}
    echo '${builtins.toJSON versions}' > "$out/package.json"
  '';

  installPhase = "true";

  meta = with lib; {
    description = "Pinned OpenCode V2 plugin API production dependency closure";
    platforms = platforms.all;
  };
}
