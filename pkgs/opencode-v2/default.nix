{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
  stdenv,
}:

let
  version = "2.0.14";
  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
        sha256 = "sha256-o4JMwNCA/WnpXEeudRqLpJtmj2SS/P43f1yUHDN+U6k=";
      };
      aarch64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
        sha256 = "sha256-4PuS9EGRN5+rjMhpWVE9sJ5NSynn4mS87q7W32X2k+8=";
      };
      x86_64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz";
        sha256 = "sha256-wMv2X0hUfS4zHW4SxUqca8jrBaJTiFJhtGs8p8K23yE=";
      };
      aarch64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
        sha256 = "sha256-DDBy4nQnhF7HLwWOpsHjm/6gMGue6mHyQdZsHROzcLI=";
      };
    }
    .${system} or (throw "Unsupported system: ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode-v2";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeBinaryWrapper ] ++ lib.optionals isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals isLinux [ stdenv.cc.cc.lib ];

  dontStrip = true;

  installPhase = ''
    mkdir -p $out/bin
    install -m755 bin/opencode $out/bin/.opencode2-unwrapped
    makeBinaryWrapper $out/bin/.opencode2-unwrapped $out/bin/opencode2
  '';

  meta = with lib; {
    description = "OpenCode v2 native CLI";
    homepage = "https://opencode.ai";
    license = licenses.mit;
    sourceProvenance = [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "opencode2";
  };
}
