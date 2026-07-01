{ lib
, buildGoModule
, engram-src
}:

buildGoModule {
  pname = "engram";
  version = engram-src.rev or "unstable";

  src = engram-src;

  subPackages = [ "cmd/engram" ];

  vendorHash = "sha256-O+pC4x4DKNUWr7Sx9iZOjK6a64wrQA4/lnjvkNLBX64=";

  doCheck = false;

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
