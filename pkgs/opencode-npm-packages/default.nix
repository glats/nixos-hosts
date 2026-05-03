{ lib, stdenvNoCC, fetchurl }:

let
  versions = lib.importJSON ./versions.json;
  rawHashes = lib.importJSON ./node-modules.json;

  toHash = h: if lib.hasPrefix "sha256-" h then h else "sha256-${h}";

  # Compute tarball name from package name:
  # @scope/name -> name (e.g. @opencode-ai/sdk -> sdk)
  # unscoped -> same (e.g. unique-names-generator -> unique-names-generator)
  tarballName = name:
    if lib.hasPrefix "@" name then
      lib.last (lib.splitString "/" name)
    else
      name;

  sources = lib.genAttrs (lib.attrNames versions) (name:
    let
      encodedName = lib.replaceStrings [ "/" ] [ "%2F" ] name;
      version = versions.${name};
      nameInTarball = tarballName name;
      url = "https://registry.npmjs.org/${encodedName}/-/${nameInTarball}-${version}.tgz";
    in
    fetchurl {
      inherit url;
      hash = toHash rawHashes.${name};
    }
  );

  copyCommands = lib.concatStrings (lib.mapAttrsToList
    (name: src: ''
      mkdir -p $out/lib/node_modules/${name}
      tar -xzf ${src} -C $out/lib/node_modules/${name} --strip-components=1
    '')
    sources);

  packageJson = builtins.toJSON (
    lib.mapAttrs (n: v: "^${v}") versions
  );
in

stdenvNoCC.mkDerivation {
  pname = "opencode-npm-packages";
  version = "1.0.0";

  dontUnpack = true;
  dontConfigure = true;

  buildPhase = ''
    mkdir -p $out/lib/node_modules
    ${copyCommands}
    echo '${packageJson}' > $out/package.json
  '';

  installPhase = "true";

  meta = with lib; {
    description = "OpenCode npm packages — @opencode-ai/sdk, @opencode-ai/plugin, unique-names-generator, TUI plugins";
    platforms = platforms.all;
  };
}
