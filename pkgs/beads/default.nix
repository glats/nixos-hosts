{
  lib,
  buildGoModule,
  fetchFromGitHub,
  icu,
  pkg-config,
}:

buildGoModule (finalAttrs: {
  pname = "beads";
  version = "1.0.5";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    tag = "v${finalAttrs.version}";
    hash = "sha256-zX4rrZfFG7panBty1iE7bL2ZVazmvktFY5kYK8Xax1c=";
  };

  subPackages = [ "cmd/bd" ];

  vendorHash = "sha256-7x8ZOWWM5S2Bvqv1SDZZw3w+fvZJldkzddcXZ0DehZU=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ icu ];

  env.CGO_ENABLED = "1";

  doCheck = false;

  meta = with lib; {
    description = "Beads issue tracker CLI used by Gas Town (pinned release)";
    homepage = "https://github.com/steveyegge/beads";
    license = licenses.mit;
    mainProgram = "bd";
    platforms = [ "x86_64-linux" ];
  };
})
