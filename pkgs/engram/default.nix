{
  lib,
  buildGoModule,
  engram-src,
}:

buildGoModule {
  pname = "engram";
  version = engram-src.rev or "unstable";

  src = engram-src;

  subPackages = [ "cmd/engram" ];

  vendorHash = "sha256-LH8sSmer918+KL5hnOju7b5NsZo+W9sd3HhkQgjS2Ho=";

  doCheck = false;

  meta = with lib; {
    description = "Persistent memory system for AI coding agents";
    homepage = "https://github.com/Gentleman-Programming/engram";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
