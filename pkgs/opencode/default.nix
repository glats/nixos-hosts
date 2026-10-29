{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:

let
  version = "2.2.0";
  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
        sha256 = "sha256-/jBGuGhy5iT2ImgFj0gBofHv/8GTEDqZiCOMiRuMoCg=";
      };
      aarch64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
        sha256 = "sha256-akBkPA3KOv+dN8h8JsDuADxGq7gQ4cbd3glP+/dGC4s=";
      };
      x86_64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz";
        sha256 = "sha256-6X52G9W1abhVQ/XtFaewwPUoBreVOFeN/fEFnGc6iCM=";
      };
      aarch64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
        sha256 = "sha256-wT4DNSXsdPohr49e8GKKpVU+OkAPV8eOkZUv79CKVog=";
      };
    }
    .${system} or (throw "Unsupported system: ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
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
