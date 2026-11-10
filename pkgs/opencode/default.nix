{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:

let
  version = "2.2.7";
  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
        hash = "sha512-wk/DPHxr4maiW+FmQp8ztoXlo/vC5qsmEIHsLNaNLZL2iaIYfhyqFRe6CRsCVxy+ib0sfK07X2IepFw7ZSKqNQ==";
      };
      aarch64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
        hash = "sha512-AgxoB3IxewSilPpWjU6GrdyJ/dSBnjncpHoZRK7Kul96bgVSEUKuPwC8nUYjTTXgLHqM+tqImwMLOlwCulzSxw==";
      };
      x86_64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz";
        hash = "sha512-6+US0PhgH8BaCQzkUGey+tz1gtHlhGxnKJspnETlcWOuZWQmyaZaF3wFf3L8+9+ukQsXV191tMG+jDIZefPjrg==";
      };
      aarch64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
        hash = "sha512-KH45DjiTcsHcnVLDrAEP3kdG57olO2BndtpYi+iGc7/cBrZfUs6YYrVpsZ40lr4izTupSIxwTbvSwKHutuq5uw==";
      };
    }
    .${system} or (throw "Unsupported system: ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url hash;
  };

  sourceRoot = "package";

  nativeBuildInputs = lib.optionals isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals isLinux [ stdenv.cc.cc.lib ];
  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    install -m755 bin/opencode $out/bin/opencode
  '';

  meta = with lib; {
    description = "OpenCode native CLI";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    sourceProvenance = [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "opencode";
  };
}
