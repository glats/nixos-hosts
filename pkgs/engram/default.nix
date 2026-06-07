{ lib
, stdenvNoCC
, fetchurl
,
}:

let
  version = "1.16.1";

  system = stdenvNoCC.hostPlatform.system;
  isLinux = lib.hasSuffix "linux" system;
  isDarwin = lib.hasSuffix "darwin" system;

  platformSrc =
    if isLinux then
      {
        url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_linux_amd64.tar.gz";
        sha256 = "sha256-2VIC8ZJ9FCz+DXZPTEvHqiFx6FuZ+upq7fzJArc9vfc=";
      }
    else if isDarwin then
      {
        url = "https://github.com/Gentleman-Programming/engram/releases/download/v${version}/engram_${version}_darwin_amd64.tar.gz";
        sha256 = "sha256-CjJ1A0teQUDjq9XFN4qKer73sLAAfAtcRZnAnz0ZicI=";
      }
    else
      throw "Unsupported system: ${system}";
in
stdenvNoCC.mkDerivation {
  pname = "engram";
  inherit version;

  src = fetchurl {
    inherit (platformSrc) url sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp engram $out/bin/
    chmod +x $out/bin/engram
  '';

  meta = with lib; {
    description = "Persistent memory system for AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = [ ];
  };
}
