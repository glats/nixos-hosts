{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:

let
  version = "2.3.2";
  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
        hash = "sha512-E9txUc4fNtvuEQUiEx84h4/bd/LJZcAHdIu0yfZRP8KDVP79WhzhEd7BTckJUyvWUc58ZP/o+nfgcnTQnvfJgw==";
      };
      aarch64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
        hash = "sha512-t44ZuW5CKaWiRSp4gWUDurMf4edyXw/SmUty1pRi827zda0T2RatKWj4LnMUewNCL05COLB1Ppg8RWicswhFaQ==";
      };
      x86_64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz";
        hash = "sha512-vNLWgHc2I/hAbW37OOANepj6VNS8mbbLp9TbWgEKY6MMvzZlx0ifsrcwUuLI0Qoso82UEj6RV20xcBWyZdF84w==";
      };
      aarch64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
        hash = "sha512-cYrIzW8CvYc52INFA/cXmw7U2mk+JNWaV+olH7AflYqa/5srSrA/hbLwF7G1N4QTRMtOFrmeTM0LVN81q396sg==";
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
