{ lib
, buildGoModule
, gentle-ai-src
}:

buildGoModule {
  pname = "gentle-ai";
  version = gentle-ai-src.rev or "unstable";

  src = gentle-ai-src;

  subPackages = [ "cmd/gentle-ai" ];

  vendorHash = "sha256-ZZl0nPB4HDjmlYyhXLlCM4le0k5dvIUZtX9RB4FEn/M=";

  meta = with lib; {
    description = "AI ecosystem configurator with persistent memory and SDD workflow";
    homepage = "https://github.com/Gentleman-Programming/gentle-ai";
    license = licenses.mit;
    platforms = [
      "x86_64-linux"
      "x86_64-darwin"
    ];
    maintainers = [ ];
  };
}
