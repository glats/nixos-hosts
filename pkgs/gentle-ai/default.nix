{ lib
, buildGoModule
, gentle-ai-src
}:

buildGoModule {
  pname = "gentle-ai";
  version = gentle-ai-src.rev or "unstable";

  src = gentle-ai-src;

  subPackages = [ "cmd/gentle-ai" ];

  vendorHash = "sha256-todsAjNOtV/fX4agsaqFwC0MHerMCVB0ufJk1sGSm/Y=";

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
