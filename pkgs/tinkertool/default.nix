{
  lib,
  stdenvNoCC,
  curl,
  cacert,
  _7zz,
}:

stdenvNoCC.mkDerivation rec {
  pname = "tinkertool";
  version = "11.71";

  # Upstream serves only the latest DMG, through a session-keyed form, so a
  # fixed-output derivation replays that form. The hash is the official
  # SHA-256 from the download page; bump version and hash on new releases.
  src = stdenvNoCC.mkDerivation {
    name = "TinkerTool-${version}.dmg";
    nativeBuildInputs = [ curl ];
    SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";
    impureEnvVars = lib.fetchers.proxyImpureEnvVars;
    outputHashMode = "flat";
    outputHashAlgo = "sha256";
    outputHash = "5e3d30d2daabc5462f4015d9921a2b6e93bec393e8803a15f19f69b6c989656c";

    buildCommand = ''
      page=https://www.bresink.com/osx/0TinkerTool/download.php
      fetch() { curl --fail --silent --show-error --location --retry 3 \
        --user-agent Mozilla/5.0 --cookie-jar cookies --cookie cookies "$@"; }

      form=$(fetch "$page" | tr '\n' ' ' | grep -o '<form[^>]*download2\.php.*</form>')
      action=$(printf '%s' "$form" | grep -o 'action="[^"]*"' | cut -d'"' -f2 | sed 's/&amp;/\&/g')
      field() { printf '%s' "$form" | grep -o "value=\"[^\"]*\" id=\"$1\"" | cut -d'"' -f2; }

      next=$(fetch --referer "$page" --data Download=Download \
        --data "key1=$(field key1)" --data "key2=$(field key2)" --data "key3=$(field key3)" \
        "$action" | grep -o 'download3\.php?PHPSESSID=[A-Za-z0-9]*' | head -n 1)
      [ -n "$next" ] || { echo "TinkerTool download form changed upstream" >&2; exit 1; }

      fetch --referer "$action" --output "$out" "''${action%/download2.php*}/$next"
    '';
  };

  nativeBuildInputs = [ _7zz ];
  # The DMG wraps an HFS image inside an Apple partition map: extract twice.
  unpackPhase = ''
    runHook preUnpack
    7zz x -y "$src" >/dev/null
    7zz x -y -sns- '2.disk image' >/dev/null
    runHook postUnpack
  '';
  dontBuild = true;
  # Preserve the upstream notarized signature.
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/Applications"
    cp -R "TinkerTool ${version}/TinkerTool.app" "$out/Applications/"
    runHook postInstall
  '';

  meta = {
    description = "Access additional hidden preference settings built into macOS";
    homepage = "https://www.bresink.com/osx/TinkerTool.html";
    license = lib.licenses.unfree;
    platforms = lib.platforms.darwin;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
