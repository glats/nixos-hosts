{
  lib,
  buildGoModule,
  gentle-ai-src,
  go,
}:

assert lib.versionAtLeast go.version "1.25.10";
(buildGoModule.override { inherit go; }) {
  pname = "gentle-ai";
  version = "4.1.1";

  src = gentle-ai-src;

  subPackages = [ "cmd/gentle-ai" ];

  vendorHash = "sha256-YL4Slz/UuY+HEcJTW+pMphcdB6xtpam+E4uTDWifEcY=";
  ldflags = [
    "-s"
    "-w"
    "-X main.version=4.1.1"
  ];

  meta = with lib; {
    description = "AI ecosystem configurator with persistent memory and ODD workflow";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    maintainers = [ ];
  };
}
