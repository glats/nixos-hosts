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
        hash = "sha512-XTGFTiZTgugps6rgTXp4mPjOM8klsa5uHn/Shcms2o3k1bjSA3Sgl6O4yJ48y18WWxn9My5Pxt7JKcLID7LOHg==";
      };
      aarch64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
        hash = "sha512-NCCltb8h/8WL30X9o2KTm3UFX0lmfk48lG8tglXJN9moscxeB7w2qOmfHVa32iFngk0iVAKH4xRPlBc88Y0qlw==";
      };
      x86_64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz";
        hash = "sha512-oK46aktdkYIAlkFs72I4JNgFS+cEgrks/HAykoKXwcZTW3XlGY1GlhTfdp55XRw9XTfTCqHvtCtvD9IgCnGhQA==";
      };
      aarch64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
        hash = "sha512-y3q/sghk/xCengTlv1pH2+5t9j0cuxXcEAY9yvyM7loKLQIYE1eSLEkDacCAVNyfnATd3D2JpueFSEB/i6A0Qg==";
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
