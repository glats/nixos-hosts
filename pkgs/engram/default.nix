{
  lib,
  buildGoModule,
  go_1_27,
  engram-src,
}:

(buildGoModule.override { go = go_1_27; }) {
  pname = "engram";
  version = engram-src.rev or "unstable";

  src = engram-src;

  subPackages = [ "cmd/engram" ];

  vendorHash = "sha256-hkwwuqar4ngDUWM2XctkiVm8TpfQWnUws/sDxDyvQxU=";

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
