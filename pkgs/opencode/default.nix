{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  stdenv,
}:

let
  version = "2.2.2";
  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;

  platformSrc =
    {
      x86_64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
        hash = "sha512-wa0ol1HUaKNDTqjfqJwqmq3n4tlejBy2UT48wVRCypRUGy9WbIpXeL9xlHmljAodQD6HcZR2dqiJYFTlDMqIVA==";
      };
      aarch64-linux = {
        url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
        hash = "sha512-cyp6l1SLFGV7NxXd5FgBIJT8V5mQhBjs+F9vh4pRSam9kRGmv/nUEvgPMXKfNrZdsllTlLoPvzgHWzQZz2ff1A==";
      };
      x86_64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-x64/-/cli-darwin-x64-${version}.tgz";
        hash = "sha512-WMGuo8lsislGiq+bu02LOn0sQC3vAbIBrgV+FuEL4GlMgzUct/I1UOFHjwfy/W8MshyTQeStFlLCJfk2uhlytQ==";
      };
      aarch64-darwin = {
        url = "https://registry.npmjs.org/@opencode/cli-darwin-arm64/-/cli-darwin-arm64-${version}.tgz";
        hash = "sha512-cH6cZvu4OuuB926Jw4QBE6F6jyzlMr7d5TTgRZw8iON7XQ3DyyQG3bS6yHo+yHwp+rKbwGoygnpua6YIIIZV9w==";
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
